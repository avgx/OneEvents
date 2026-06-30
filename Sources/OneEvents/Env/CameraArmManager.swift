import DebugThings
import SwiftUI

/// Observable store for camera arm states keyed by access point.
@MainActor
public final class CameraArmManager: ObservableObject, Loggable {
    /// Latest arm state by camera access point.
    @Published public private(set) var states: [AccessPoint: CameraArmState?] = [:]

    private var task: Task<Void, Never>?

    /// Creates a camera arm-state manager.
    public init() {}

    deinit {
        task?.cancel()
    }

    /// Binds this manager to camera arm updates published by the dispatcher.
    public func bindCameraArmChannel(_ dispatcher: EventDispatcher) {
        task?.cancel()
        task = Task { @MainActor in
            let stream = await dispatcher.cameraArmEvents()
            for await update in stream {
                apply(update)
            }
        }
    }

    /// Seeds initial arm states from domain camera config (`Camera.armed`) before WS events arrive.
    public func seedInitialStates(_ seeds: [AccessPoint: CameraArmState]) {
        for (accessPoint, state) in seeds where states[accessPoint] == nil {
            states[accessPoint] = state
        }
    }

    private func apply(_ update: CameraArmStateEvent) {
        let newValue = update.state.value
        guard states[update.source] != newValue else { return }
        states[update.source] = newValue
        logger.debug("\(update.source) arm=\(update.state)")
    }
}
