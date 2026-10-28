import SwiftUI

/// Bridges SwiftUI `ScenePhase` changes to an `EventsWatcher`, in the order they happen.
@MainActor
public final class EventsScenePhaseController: ObservableObject {
    private let watcher: EventsWatcher
    private var pending: Task<Void, Never>?

    /// Creates a scene phase controller for the provided watcher.
    public init(watcher: EventsWatcher) {
        self.watcher = watcher
    }

    /// Applies the scene phase to the watcher: `.active` wants the link, anything else lets it go.
    ///
    /// Call on every change, from the main actor. Each change waits for the previous one, so the watcher sees them
    /// in order and the last one wins (`setActive` returns quickly, so the chain does not lag).
    public func setScenePhase(_ scenePhase: ScenePhase) {
        let active = scenePhase == .active
        let previous = pending
        let watcher = self.watcher
        pending = Task {
            await previous?.value
            await watcher.setActive(active)
        }
    }
}
