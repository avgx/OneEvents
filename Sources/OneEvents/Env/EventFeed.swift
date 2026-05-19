import Combine
import Foundation

/// Observable store for the latest live detector events.
@MainActor
public final class EventFeed: ObservableObject {
    /// Latest detector events sorted by newest timestamp first.
    @Published public private(set) var events: [DetectorEvent] = []

    /// Maximum number of detector events retained by the feed.
    public let capacity: Int

    private let acceptedPhases: Set<DetectorEvent.Phase>
    private var task: Task<Void, Never>?

    /// Creates a detector event feed.
    public init(
        capacity: Int = 100,
        acceptedPhases: Set<DetectorEvent.Phase> = [.happened, .began]
    ) {
        self.capacity = max(0, capacity)
        self.acceptedPhases = acceptedPhases
    }

    deinit {
        task?.cancel()
    }

    /// Binds the feed to detector events published by the dispatcher.
    public func bind(_ dispatcher: EventDispatcher) {
        task?.cancel()
        task = Task { @MainActor in
            let stream = await dispatcher.detectorEvents()
            for await event in stream {
                append(event)
            }
        }
    }

    /// Appends a detector event if it matches the configured phase filter.
    public func append(_ event: DetectorEvent) {
        if let phase = event.phase, !acceptedPhases.contains(phase) {
            return
        }

        events.removeAll { $0.id == event.id }
        events.append(event)
        events.sort { lhs, rhs in
            lhs.timestamp > rhs.timestamp
        }

        if events.count > capacity {
            events.removeSubrange(capacity..<events.count)
        }
    }

    /// Removes all retained detector events.
    public func reset() {
        events.removeAll()
    }
}
