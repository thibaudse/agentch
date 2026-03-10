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

    var collapsedScaleX: CGFloat {
        notchWidth / expandedWidth
    }

    var collapsedScaleY: CGFloat {
        notchHeight / expandedHeight
    }

    var windowFrame: CGRect {
        let originX = screenFrame.midX - expandedWidth / 2
        let originY = screenFrame.maxY - expandedHeight
        return CGRect(x: originX, y: originY, width: expandedWidth, height: expandedHeight)
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
