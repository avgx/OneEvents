import Foundation

/// Multicast hub where each subscriber receives every published value.
public actor Hub<T: Sendable> {
    private struct Subscription {
        let id: UUID
        let continuation: AsyncStream<T>.Continuation
    }

    private var subscriptions: [Subscription] = []

    /// Creates a new stream subscribed to future values.
    public func subscribe() -> AsyncStream<T> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<T>.makeStream()
        continuation.onTermination = { @Sendable _ in
            Task { await self.remove(id: id) }
        }
        subscriptions.append(Subscription(id: id, continuation: continuation))
        return stream
    }

    /// Publishes a value to all current subscribers.
    public func publish(_ event: T) {
        for sub in subscriptions {
            sub.continuation.yield(event)
        }
    }

    private func remove(id: UUID) {
        subscriptions.removeAll { $0.id == id }
    }
}

/// Hub specialized for string payloads.
public typealias StringHub = Hub<String>

/// Hub specialized for binary payloads.
public typealias BinaryHub = Hub<Data>
