import DebugThings
import SwiftUI

/// Observable store for camera record states keyed by access point.
@MainActor
public final class CameraRecordStateManager: ObservableObject, Loggable {
    /// Latest record state by camera access point.
    public private(set) var states: [AccessPoint: ArchiveRecordState?] = [:]

    private var task: Task<Void, Never>?
    private lazy var coalescer = EventStateCoalescer<ArchiveRecordState?>(onFlush: { [weak self] batch in
        self?.flush(batch)
    })

    /// Creates a camera record-state manager.
    public init() {}

    deinit {
        task?.cancel()
    }

    /// Binds this manager to camera record updates published by the dispatcher.
    public func bindCameraRecordStateChannel(_ dispatcher: EventDispatcher) {
        task?.cancel()
        coalescer.cancel()
        task = Task { @MainActor in
            let stream = await dispatcher.cameraRecordStateEvents()
            for await update in stream {
                enqueue(update)
            }
        }
    }

    private func enqueue(_ update: CameraRecordStateEvent) {
        let newValue = update.state.value
        coalescer.enqueue(key: update.source, value: newValue, current: states[update.source] ?? nil)
    }

    private func flush(_ batch: [AccessPoint: ArchiveRecordState?]) {
        let changes = changedStateBatch(batch, comparedTo: states)
        guard !changes.isEmpty else { return }
        objectWillChange.send()
        for change in changes {
            states[change.key] = change.value
        }
        let message = stateBatchLogMessage(
            kind: "record",
            changes: changes,
            valueLabel: { value in value.map { String(describing: $0) } ?? "nil" }
        )
        logger.debug("\(message)")
    }
}
