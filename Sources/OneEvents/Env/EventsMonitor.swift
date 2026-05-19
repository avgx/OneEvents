import Combine
import Foundation
import WS

/// UI-ready snapshot of the events subsystem state.
public struct EventsSessionState: Sendable {
    /// Human-readable connection state reported by the WebSocket transport.
    public var connectionState: String

    /// Whether the WebSocket is currently connected.
    public var isConnected: Bool

    /// Number of bytes sent by the underlying transport.
    public var bytesSent: UInt64

    /// Number of bytes received by the underlying transport.
    public var bytesReceived: UInt64

    /// Number of WebSocket event objects received.
    public var eventsReceived: Int

    /// Number of received events grouped by wire type.
    public var eventsByType: [String: Int]

    /// Number of decoding issues reported by the dispatcher or watcher.
    public var decodeErrors: Int

    /// Date of the latest received event.
    public var lastEventAt: Date?

    /// Latest diagnostic error message.
    public var lastError: String?

    /// Creates an empty session state snapshot.
    public init(
        connectionState: String = "unknown",
        isConnected: Bool = false,
        bytesSent: UInt64 = 0,
        bytesReceived: UInt64 = 0,
        eventsReceived: Int = 0,
        eventsByType: [String: Int] = [:],
        decodeErrors: Int = 0,
        lastEventAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.connectionState = connectionState
        self.isConnected = isConnected
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.eventsReceived = eventsReceived
        self.eventsByType = eventsByType
        self.decodeErrors = decodeErrors
        self.lastEventAt = lastEventAt
        self.lastError = lastError
    }
}

/// Observable UI adapter that tracks events transport statistics and diagnostics.
@MainActor
public final class EventsMonitor: ObservableObject {
    /// Current events session state.
    @Published public private(set) var state: EventsSessionState

    private let watcher: EventsWatcher
    private let dispatcher: EventDispatcher
    private let snapshotIntervalNanoseconds: UInt64
    private var tasks: [Task<Void, Never>] = []

    /// Creates an events monitor for a watcher and dispatcher pair.
    public init(
        watcher: EventsWatcher,
        dispatcher: EventDispatcher,
        snapshotIntervalNanoseconds: UInt64 = 1_000_000_000,
        initialState: EventsSessionState = EventsSessionState()
    ) {
        self.watcher = watcher
        self.dispatcher = dispatcher
        self.snapshotIntervalNanoseconds = snapshotIntervalNanoseconds
        self.state = initialState
    }

    deinit {
        for task in tasks {
            task.cancel()
        }
    }

    /// Starts observing events, diagnostics, connection state, and transport metrics.
    public func start() {
        guard tasks.isEmpty else { return }

        tasks.append(Task { [weak self] in
            guard let self else { return }
            let stream = await dispatcher.events()
            for await event in stream {
                self.recordEvent(type: event.type)
            }
        })

        tasks.append(Task { [weak self] in
            guard let self else { return }
            let stream = await dispatcher.decodingIssues()
            for await issue in stream {
                self.recordIssue(issue)
            }
        })

        tasks.append(Task { [weak self] in
            guard let self else { return }
            let stream = await watcher.connectionStateUpdates()
            for await connectionState in stream {
                self.recordConnectionState(connectionState)
            }
        })

        tasks.append(Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshSnapshot()
                try? await Task.sleep(nanoseconds: snapshotIntervalNanoseconds)
            }
        })
    }

    /// Stops observing events and transport metrics.
    public func stop() {
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }

    /// Refreshes transport byte counters and connection state immediately.
    public func refreshSnapshot() async {
        let snapshot = await watcher.transportSnapshot()
        state.connectionState = String(describing: snapshot.state)
        state.isConnected = Self.isConnected(snapshot.state)
        state.bytesSent = snapshot.sent
        state.bytesReceived = snapshot.received
    }

    private func recordEvent(type: String) {
        state.eventsReceived += 1
        state.eventsByType[type, default: 0] += 1
        state.lastEventAt = Date()
    }

    private func recordIssue(_ issue: EventDecodingIssue) {
        state.decodeErrors += 1
        state.lastError = "\(issue.type): \(issue.message)"
    }

    private func recordConnectionState(_ connectionState: WebSocket.State) {
        state.connectionState = String(describing: connectionState)
        state.isConnected = Self.isConnected(connectionState)
    }

    private static func isConnected(_ connectionState: WebSocket.State) -> Bool {
        guard case .connected = connectionState else {
            return false
        }
        return true
    }
}
