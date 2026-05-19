import SwiftUI

/// Bridges SwiftUI `ScenePhase` changes to an `EventsWatcher`.
@MainActor
public final class EventsScenePhaseController: ObservableObject {
    private let watcher: EventsWatcher

    /// Creates a scene phase controller for the provided watcher.
    public init(watcher: EventsWatcher) {
        self.watcher = watcher
    }

    /// Applies the current scene phase to the watcher active state.
    public func setScenePhase(_ scenePhase: ScenePhase) {
        let active = scenePhase == .active
        Task {
            await watcher.setActive(active)
        }
    }
}
