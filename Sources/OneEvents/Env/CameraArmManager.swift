import DebugThings
import SwiftUI

/// Observable store for camera arm states keyed by access point.
@MainActor
public final class CameraArmManager: ObservableObject, Loggable {
    /// Latest arm state by camera access point.
    public private(set) var states: [AccessPoint: CameraArmState?] = [:]

    private var task: Task<Void, Never>?
    private lazy var coalescer = EventStateCoalescer<CameraArmState?>(onFlush: { [weak self] batch in
        self?.flush(batch)
    })

    /// Creates a camera arm-state manager.
    public init() {}

    deinit {
        task?.cancel()
    }

    /// Binds this manager to camera arm updates published by the dispatcher.
    public func bindCameraArmChannel(_ dispatcher: EventDispatcher) {
        task?.cancel()
        coalescer.cancel()
        task = Task { @MainActor in
            let stream = await dispatcher.cameraArmEvents()
            for await update in stream {
                enqueue(update)
            }
        }
    }

    /// Seeds initial arm states from domain camera config (`Camera.armed`) before WS events arrive.
    public func seedInitialStates(_ seeds: [AccessPoint: CameraArmState]) {
        let additions = seeds.filter { states[$0.key] == nil }
        guard !additions.isEmpty else { return }
        objectWillChange.send()
        for (accessPoint, state) in additions {
            states[accessPoint] = state
        }
    }

    private func enqueue(_ update: CameraArmStateEvent) {
        let newValue = update.state.value
        coalescer.enqueue(key: update.source, value: newValue, current: states[update.source] ?? nil)
    }

    private func flush(_ batch: [AccessPoint: CameraArmState?]) {
        let changes = changedStateBatch(batch, comparedTo: states)
        guard !changes.isEmpty else { return }
        objectWillChange.send()
        for change in changes {
            states[change.key] = change.value
        }
        let message = stateBatchLogMessage(
            kind: "arm",
            changes: changes,
            valueLabel: { value in value.map { String(describing: $0) } ?? "nil" }
        )
        logger.debug("\(message)")
    }
}
