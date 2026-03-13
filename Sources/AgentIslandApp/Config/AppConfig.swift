import AppKit
import Foundation

enum AppConfig {
    static let socketPath = "/tmp/agent-island.sock"
    static let defaultDisplayDuration: TimeInterval = 0

    static let minExpandedWidth: CGFloat = 520
    static let expandedPaddingWidth: CGFloat = 240
    static let expandedExtraHeight: CGFloat = 56

    static let minInteractiveWidth: CGFloat = 640
    static let interactivePaddingWidth: CGFloat = 380
    static let interactiveExtraHeight: CGFloat = 200

    static let fullExpandedExtraHeight: CGFloat = 480
    static let minFullExpandedWidth: CGFloat = 820

    /// Maximum extra height the island can grow beyond the notch (content-driven cap)
    static let maxIslandExtraHeight: CGFloat = 700

    static let appearDuration: TimeInterval = 0.4
    static let disappearDuration: TimeInterval = 0.3
    static let appearDelayNanos: UInt64 = 30_000_000
    static let hideDelayNanos: UInt64 = 450_000_000
    static let trackingIntervalNanos: UInt64 = 80_000_000

    static let processMonitorIntervalNanos: UInt64 = 2_000_000_000

    static let enablePrivateTopSpace = ProcessInfo.processInfo.environment["AGENTCH_DISABLE_PRIVATE_TOPSPACE"] != "1"

    static let panelWindowLevel = NSWindow.Level.mainMenu + 3
}
