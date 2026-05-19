import SwiftUI

/// Observable store for camera arm states keyed by access point.
@MainActor
public final class CameraArmManager: ObservableObject {
    /// Latest arm state by camera access point.
    @Published public private(set) var states: [AccessPoint: CameraArmState] = [:]

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
            let stream = await dispatcher.cameraArmUpdates()
            for await update in stream {
                apply(update)
            }
        }
    }

    private func apply(_ update: CameraArmUpdate) {
        states[update.source] = update.state
    }
}
