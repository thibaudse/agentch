import AppKit
import Foundation

@MainActor
final class TopmostSpaceManager {
    private static let topSpaceLevel = 2_147_483_647
    private typealias ConnectionID = UInt
    private typealias SpaceID = UInt64

    private let isEnabled: Bool
    private var spaceID: SpaceID?
    private var attachedWindowNumbers: Set<Int> = []

    init(isEnabled: Bool = AppConfig.enablePrivateTopSpace) {
        self.isEnabled = isEnabled
        guard isEnabled else { return }

        let connection = _CGSDefaultConnection()
        let flag = 0x1
        let createdSpace = CGSSpaceCreate(connection, flag, nil)

        guard createdSpace != 0 else {
            NSLog("AgentIsland: Unable to create private top space")
            return
        }

        CGSSpaceSetAbsoluteLevel(connection, createdSpace, Self.topSpaceLevel)
        CGSShowSpaces(connection, [createdSpace] as NSArray)
        spaceID = createdSpace
        NSLog("AgentIsland: Private top space enabled")
    }

    deinit {
        guard let spaceID else { return }
        let connection = _CGSDefaultConnection()

        if !attachedWindowNumbers.isEmpty {
            CGSRemoveWindowsFromSpaces(
                connection,
                attachedWindowNumbers.map(NSNumber.init(value:)) as NSArray,
                [spaceID] as NSArray
            )
        }

        CGSHideSpaces(connection, [spaceID] as NSArray)
        CGSSpaceDestroy(connection, spaceID)
    }

    func attach(window: NSWindow) {
        guard isEnabled, let spaceID else { return }
        let windowNumber = window.windowNumber
        guard windowNumber > 0 else { return }
        attachedWindowNumbers.insert(windowNumber)

        let connection = _CGSDefaultConnection()
        CGSShowSpaces(connection, [spaceID] as NSArray)

        CGSAddWindowsToSpaces(
            connection,
            [windowNumber] as NSArray,
            [spaceID] as NSArray
        )
    }

    func detach(window: NSWindow) {
        guard isEnabled, let spaceID else { return }
        let windowNumber = window.windowNumber
        guard windowNumber > 0 else { return }
        attachedWindowNumbers.remove(windowNumber)

        CGSRemoveWindowsFromSpaces(
            _CGSDefaultConnection(),
            [windowNumber] as NSArray,
            [spaceID] as NSArray
        )
    }
}

// MARK: - Private CGS Symbols

private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ connection: CGSConnectionID, _ flag: Int, _ options: NSDictionary?) -> CGSSpaceID

@_silgen_name("CGSSpaceDestroy")
private func CGSSpaceDestroy(_ connection: CGSConnectionID, _ space: CGSSpaceID)

@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ connection: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)

@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ connection: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
private func CGSRemoveWindowsFromSpaces(_ connection: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSHideSpaces")
private func CGSHideSpaces(_ connection: CGSConnectionID, _ spaces: NSArray)

@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ connection: CGSConnectionID, _ spaces: NSArray)
