import AppKit
import Foundation

enum AppConfig {
    static let socketPath = "/tmp/agent-island.sock"
    static let defaultDisplayDuration: TimeInterval = 0

    static let minExpandedWidth: CGFloat = 340
    static let expandedPaddingWidth: CGFloat = 120
    static let expandedExtraHeight: CGFloat = 40

    static let minInteractiveWidth: CGFloat = 440
    static let interactivePaddingWidth: CGFloat = 200
    static let interactiveExtraHeight: CGFloat = 130

    static let fullExpandedExtraHeight: CGFloat = 340
    static let minFullExpandedWidth: CGFloat = 620

    /// Maximum extra height the island can grow beyond the notch (content-driven cap)
    static let maxIslandExtraHeight: CGFloat = 500

    static let appearDuration: TimeInterval = 0.4
    static let disappearDuration: TimeInterval = 0.3
    static let appearDelayNanos: UInt64 = 30_000_000
    static let hideDelayNanos: UInt64 = 350_000_000
    static let trackingIntervalNanos: UInt64 = 80_000_000

    static let processMonitorIntervalNanos: UInt64 = 2_000_000_000

    static let enablePrivateTopSpace = ProcessInfo.processInfo.environment["AGENTCH_DISABLE_PRIVATE_TOPSPACE"] != "1"

    static let panelWindowLevel = NSWindow.Level.mainMenu + 3
}
