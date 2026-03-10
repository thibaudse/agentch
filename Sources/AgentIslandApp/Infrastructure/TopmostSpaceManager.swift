import AppKit
import Darwin
import Foundation

@MainActor
final class TopmostSpaceManager {
    private typealias ConnectionID = Int32
    private typealias SpaceID = Int32

    private typealias MainConnectionFn = @convention(c) () -> ConnectionID
    private typealias SpaceCreateFn = @convention(c) (ConnectionID, Int32, Int32) -> SpaceID
    private typealias SpaceSetAbsoluteLevelFn = @convention(c) (ConnectionID, SpaceID, Int32) -> Int32
    private typealias ShowSpacesFn = @convention(c) (ConnectionID, CFArray) -> Int32
    private typealias AddWindowAndRemoveFromSpacesFn = @convention(c) (ConnectionID, SpaceID, CFArray, Int32) -> Int32
    private typealias RemoveWindowsFromSpacesFn = @convention(c) (ConnectionID, CFArray, CFArray) -> Int32

    private let isEnabled: Bool

    private var attemptedSetup = false
    private var skyLightHandle: UnsafeMutableRawPointer?

    private var mainConnection: MainConnectionFn?
    private var spaceCreate: SpaceCreateFn?
    private var spaceSetAbsoluteLevel: SpaceSetAbsoluteLevelFn?
    private var showSpaces: ShowSpacesFn?
    private var addWindowAndRemoveFromSpaces: AddWindowAndRemoveFromSpacesFn?
    private var removeWindowsFromSpaces: RemoveWindowsFromSpacesFn?

    private var connectionID: ConnectionID = 0
    private var spaceID: SpaceID = 0

    init(isEnabled: Bool = AppConfig.enablePrivateTopSpace) {
        self.isEnabled = isEnabled
    }

    deinit {
        if let handle = skyLightHandle {
            dlclose(handle)
        }
    }

    func attach(window: NSWindow) {
        guard ensureSpace() else { return }
        guard let addWindowAndRemoveFromSpaces else { return }
        guard window.windowNumber > 0 else { return }

        _ = addWindowAndRemoveFromSpaces(
            connectionID,
            spaceID,
            [window.windowNumber] as CFArray,
            7
        )
    }

    func detach(window: NSWindow) {
        guard ensureSpace() else { return }
        guard let removeWindowsFromSpaces else { return }
        guard window.windowNumber > 0 else { return }

        _ = removeWindowsFromSpaces(
            connectionID,
            [window.windowNumber] as CFArray,
            [spaceID] as CFArray
        )
    }

    private func ensureSpace() -> Bool {
        guard isEnabled else { return false }
        loadSymbolsAndCreateSpaceIfNeeded()
        return connectionID != 0 && spaceID != 0
    }

    private func loadSymbolsAndCreateSpaceIfNeeded() {
        guard !attemptedSetup else { return }
        attemptedSetup = true

        let frameworkPath = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
        skyLightHandle = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL)
        guard skyLightHandle != nil else {
            NSLog("AgentIsland: SkyLight unavailable, falling back to public window stacking")
            return
        }

        mainConnection = loadSymbol(named: "SLSMainConnectionID", as: MainConnectionFn.self)
        spaceCreate = loadSymbol(named: "SLSSpaceCreate", as: SpaceCreateFn.self)
        spaceSetAbsoluteLevel = loadSymbol(named: "SLSSpaceSetAbsoluteLevel", as: SpaceSetAbsoluteLevelFn.self)
        showSpaces = loadSymbol(named: "SLSShowSpaces", as: ShowSpacesFn.self)
        addWindowAndRemoveFromSpaces = loadSymbol(
            named: "SLSSpaceAddWindowsAndRemoveFromSpaces",
            as: AddWindowAndRemoveFromSpacesFn.self
        )
        removeWindowsFromSpaces = loadSymbol(named: "SLSRemoveWindowsFromSpaces", as: RemoveWindowsFromSpacesFn.self)

        guard
            let mainConnection,
            let spaceCreate,
            let spaceSetAbsoluteLevel,
            let showSpaces
        else {
            NSLog("AgentIsland: SkyLight symbols not fully available, falling back")
            return
        }

        let connectionID = mainConnection()
        let createdSpace = spaceCreate(connectionID, 1, 0)
        guard connectionID != 0, createdSpace != 0 else {
            NSLog("AgentIsland: Unable to create SkyLight top space")
            return
        }

        _ = spaceSetAbsoluteLevel(connectionID, createdSpace, 400)
        _ = showSpaces(connectionID, [createdSpace] as CFArray)

        self.connectionID = connectionID
        self.spaceID = createdSpace
        NSLog("AgentIsland: SkyLight top space enabled")
    }

    private func loadSymbol<T>(named name: String, as type: T.Type) -> T? {
        guard let skyLightHandle else { return nil }
        guard let rawSymbol = dlsym(skyLightHandle, name) else { return nil }
        return unsafeBitCast(rawSymbol, to: type)
    }
}
