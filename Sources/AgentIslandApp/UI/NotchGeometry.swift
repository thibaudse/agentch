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

    var fullExpandedHeight: CGFloat {
        notchHeight + AppConfig.fullExpandedExtraHeight
    }

    var fullExpandedWidth: CGFloat {
        max(interactiveWidth, AppConfig.minFullExpandedWidth)
    }

    func effectiveWidth(interactive: Bool, fullExpanded: Bool = false) -> CGFloat {
        if fullExpanded { return fullExpandedWidth }
        return interactive ? interactiveWidth : expandedWidth
    }

    func effectiveHeight(interactive: Bool, fullExpanded: Bool = false) -> CGFloat {
        if fullExpanded { return fullExpandedHeight }
        return interactive ? interactiveHeight : expandedHeight
    }

    func collapsedScaleX(interactive: Bool, fullExpanded: Bool = false) -> CGFloat {
        notchWidth / effectiveWidth(interactive: interactive, fullExpanded: fullExpanded)
    }

    func collapsedScaleY(interactive: Bool, fullExpanded: Bool = false) -> CGFloat {
        notchHeight / effectiveHeight(interactive: interactive, fullExpanded: fullExpanded)
    }

    func windowFrame(interactive: Bool = false, fullExpanded: Bool = false) -> CGRect {
        let width = effectiveWidth(interactive: interactive, fullExpanded: fullExpanded)
        let height = effectiveHeight(interactive: interactive, fullExpanded: fullExpanded)
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
