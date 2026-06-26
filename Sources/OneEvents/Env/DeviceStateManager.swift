import DebugThings
import SwiftUI

/// Observable store for device states keyed by access point.
@MainActor
public final class DeviceStateManager: ObservableObject, Loggable {
    /// Latest arm state by camera access point.
    @Published public private(set) var states: [AccessPoint: DeviceState?] = [:]

    private var task: Task<Void, Never>?

    /// Creates a camera arm-state manager.
    public init() {}

    deinit {
        task?.cancel()
    }

    /// Binds this manager to device state updates published by the dispatcher.
    public func bindDeviceStateChannel(_ dispatcher: EventDispatcher) {
        task?.cancel()
        task = Task { @MainActor in
            let stream = await dispatcher.deviceStateEvents()
            for await update in stream {
                apply(update)
            }
        }
    }

    private func apply(_ update: DeviceStateChangedEvent) {
        let newValue = update.state
        guard states[update.name] != newValue else { return }
        states[update.name] = newValue
        logger.debug("\(update.name) device=\(newValue)")
    }
}
