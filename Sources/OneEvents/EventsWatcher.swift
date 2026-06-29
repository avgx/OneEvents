import Foundation
import WS
import OneWireFormat

/// Client-side wrapper for the One `/events` WebSocket feed.
public actor EventsWatcher {
    let socket: WebSocket
    let dispatcher: EventDispatcher
    
    private var activeSubscriptions = Set<AccessPoint>()
    private var ownerSubscriptions: [String: Set<AccessPoint>] = [:]
    private var lastAuthToken: String?
    private var connectedObserver: Task<Void, Never>?
    private var readTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var shouldBeActive = false

    /// Creates an events watcher around a WebSocket built by the account runtime.
    public init(socket: WebSocket, dispatcher: EventDispatcher) {
        self.socket = socket
        self.dispatcher = dispatcher
    }

    /// Default WebSocket configuration for the `/events` feed.
    public static var feedConfiguration: WebSocket.Configuration {
        var configuration = WebSocket.Configuration.checked
        configuration.connectionHandshakeTimeout = 25
        return configuration
    }

    deinit {
        connectedObserver?.cancel()
        readTask?.cancel()
        connectTask?.cancel()
    }

    /// Starts the WebSocket connection and keeps subscription replay active.
    public func start() async {
        await setActive(true)
    }

    /// Stops the WebSocket connection and cancels background watcher tasks.
    public func stop() async {
        await setActive(false)
    }

    /// Enables or disables the WebSocket connection without losing desired subscriptions.
    public func setActive(_ active: Bool) async {
        guard shouldBeActive != active else { return }
        shouldBeActive = active

        if active {
            startTasksIfNeeded()
            connectTask?.cancel()
            connectTask = Task { await self.socket.connect() }
        } else {
            connectedObserver?.cancel()
            connectedObserver = nil
            readTask?.cancel()
            readTask = nil
            connectTask?.cancel()
            connectTask = nil
            await self.socket.disconnect()
        }
    }

    /// Returns connection state updates from the underlying WebSocket.
    public func connectionStateUpdates() async -> AsyncStream<WebSocket.State> {
        await socket.connectionStateUpdates()
    }

    /// Subscribes to events for a single access point.
    public func subscribe(_ accessPoint: AccessPoint) async throws {
        activeSubscriptions.insert(accessPoint)
        try await sendCurrentSubscriptions()
    }

    /// Unsubscribes from events for a single access point.
    public func unsubscribe(_ accessPoint: AccessPoint) async throws {
        activeSubscriptions.remove(accessPoint)
        let cmd = EventSubscription(include: desiredSubscriptions(), exclude: [accessPoint])
        try await socket.sendString(try cmd.jsonFormatted())
    }

    /// Replaces the desired watch list owned by the provided identifier.
    public func watch(ownerID: String, accessPoints: [AccessPoint]) async throws {
        ownerSubscriptions[ownerID] = Set(accessPoints)
        try await sendCurrentSubscriptions()
    }

    /// Removes all access points owned by the provided identifier.
    public func unwatch(ownerID: String) async throws {
        ownerSubscriptions.removeValue(forKey: ownerID)
        try await sendCurrentSubscriptions()
    }

    /// Sends a new authorization token on the active WebSocket connection.
    public func updateToken(_ authToken: String) async throws {
        lastAuthToken = authToken
        let cmd = UpdateToken(auth_token: authToken)
        try await socket.sendString(try cmd.jsonFormatted())
    }

    /// Returns a snapshot of transport state and byte counters.
    public func transportSnapshot() async -> (state: WebSocket.State, sent: UInt64, received: UInt64) {
        async let state = socket.connectionState()
        let metrics = await socket.transportMetrics()
        return (await state, metrics.bytesSent, metrics.bytesReceived)
    }

    private func startTasksIfNeeded() {
        if connectedObserver == nil {
            connectedObserver = Task {
                await self.runConnectedObserver()
            }
        }
        if readTask == nil {
            readTask = Task {
                await self.read()
            }
        }
    }

    private func desiredSubscriptions() -> [AccessPoint] {
        Array(
            ownerSubscriptions.values.reduce(activeSubscriptions) { partial, next in
                partial.union(next)
            }
        )
        .sorted()
    }

    private func sendCurrentSubscriptions() async throws {
        let cmd = EventSubscription(include: desiredSubscriptions())
        try await socket.sendString(try cmd.jsonFormatted())
    }

    private func resendLastAuthTokenIfNeeded() async throws {
        guard let lastAuthToken else { return }
        let cmd = UpdateToken(auth_token: lastAuthToken)
        try await socket.sendString(try cmd.jsonFormatted())
    }

    private func runConnectedObserver() async {
        let states = await socket.connectionStateUpdates()
        for await state in states {
            guard !Task.isCancelled else { break }
            guard case .connected = state else { continue }
            await replayConnectionState()
        }
    }

    private func replayConnectionState() async {
        do {
            try await sendCurrentSubscriptions()
            try await resendLastAuthTokenIfNeeded()
        } catch {
            await dispatcher.reportDecodingIssue(
                EventDecodingIssue(type: "transport", id: nil, message: String(describing: error))
            )
        }
    }
}
