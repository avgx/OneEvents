import SwiftUI

/// Observable store for camera record states keyed by access point.
@MainActor
public final class CameraRecordStateManager: ObservableObject {
    /// Latest arm state by camera access point.
    @Published public private(set) var states: [AccessPoint: ArchiveRecordState?] = [:]

    private var task: Task<Void, Never>?

    /// Creates a camera arm-state manager.
    public init() {}

    deinit {
        task?.cancel()
    }

    /// Binds this manager to camera arm updates published by the dispatcher.
    public func bindCameraRecordStateChannel(_ dispatcher: EventDispatcher) {
        task?.cancel()
        task = Task { @MainActor in
            let stream = await dispatcher.cameraRecordStateEvents()
            for await update in stream {
                apply(update)
            }
        }
    }

    private func apply(_ update: CameraRecordStateEvent) {
        states[update.source] = update.state.value
    }
}
