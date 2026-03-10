import AppKit
import CoreGraphics

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var isBuiltInDisplay: Bool {
        guard let displayID else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }
}

struct NotchGeometry: Equatable {
    let screenFrame: CGRect
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let hasNotch: Bool

    var expandedWidth: CGFloat {
        max(notchWidth + AppConfig.expandedPaddingWidth, AppConfig.minExpandedWidth)
    }

    var expandedHeight: CGFloat {
        notchHeight + AppConfig.expandedExtraHeight
    }

    var interactiveWidth: CGFloat {
        max(notchWidth + AppConfig.interactivePaddingWidth, AppConfig.minInteractiveWidth)
    }

    var interactiveHeight: CGFloat {
        notchHeight + AppConfig.interactiveExtraHeight
    }

    func effectiveWidth(interactive: Bool) -> CGFloat {
        interactive ? interactiveWidth : expandedWidth
    }

    func effectiveHeight(interactive: Bool) -> CGFloat {
        interactive ? interactiveHeight : expandedHeight
    }

    func collapsedScaleX(interactive: Bool) -> CGFloat {
        notchWidth / effectiveWidth(interactive: interactive)
    }

    func collapsedScaleY(interactive: Bool) -> CGFloat {
        notchHeight / effectiveHeight(interactive: interactive)
    }

    func windowFrame(interactive: Bool = false) -> CGRect {
        let width = effectiveWidth(interactive: interactive)
        let height = effectiveHeight(interactive: interactive)
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.maxY - height
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    static func detect(on screen: NSScreen? = nil) -> NotchGeometry {
        let preferredScreen = screen
            ?? NSScreen.screens.first(where: { $0.isBuiltInDisplay })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = preferredScreen else {
            return NotchGeometry(
                screenFrame: .zero,
                notchWidth: 185,
                notchHeight: 32,
                hasNotch: false
            )
        }

        let frame = screen.frame
        let safeTop = screen.safeAreaInsets.top

        if safeTop > 0,
           let topLeft = screen.auxiliaryTopLeftArea,
           let topRight = screen.auxiliaryTopRightArea {
            let notchMaxX = topRight.minX
            let notchMinX = topLeft.maxX
            return NotchGeometry(
                screenFrame: frame,
                notchWidth: notchMaxX - notchMinX,
                notchHeight: safeTop,
                hasNotch: true
            )
        }

        return NotchGeometry(
            screenFrame: frame,
            notchWidth: 185,
            notchHeight: 32,
            hasNotch: false
        )
    }
}
