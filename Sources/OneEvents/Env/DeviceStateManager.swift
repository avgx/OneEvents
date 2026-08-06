import DebugThings
import SwiftUI

/// Observable store for device states keyed by access point.
@MainActor
public final class DeviceStateManager: ObservableObject, Loggable {
    /// Latest device state by access point.
    public private(set) var states: [AccessPoint: DeviceState?] = [:]

    private var task: Task<Void, Never>?
    private lazy var coalescer = EventStateCoalescer<DeviceState?>(onFlush: { [weak self] batch in
        self?.flush(batch)
    })

    /// Creates a device-state manager.
    public init() {}

    deinit {
        task?.cancel()
    }

    /// Binds this manager to device state updates published by the dispatcher.
    public func bindDeviceStateChannel(_ dispatcher: EventDispatcher) {
        task?.cancel()
        coalescer.cancel()
        task = Task { @MainActor in
            let stream = await dispatcher.deviceStateEvents()
            for await update in stream {
                enqueue(update)
            }
        }
    }

    private func enqueue(_ update: DeviceStateChangedEvent) {
        let newValue: DeviceState? = update.state
        coalescer.enqueue(key: update.name, value: newValue, current: states[update.name] ?? nil)
    }

    private func flush(_ batch: [AccessPoint: DeviceState?]) {
        let changes = changedStateBatch(batch, comparedTo: states)
        guard !changes.isEmpty else { return }
        objectWillChange.send()
        for change in changes {
            states[change.key] = change.value
        }
        let message = stateBatchLogMessage(
            kind: "device",
            changes: changes,
            valueLabel: { $0 ?? "nil" }
        )
        logger.debug("\(message)")
    }
}
