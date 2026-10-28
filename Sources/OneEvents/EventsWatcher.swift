import Foundation
import WS
import OneWireFormat

/// Client-side wrapper for the One `/events` WebSocket feed.
///
/// Owns its socket: it is the only reader of `socket.messages` and `socket.states`. Frames go to the dispatcher;
/// states are forwarded through ``states`` after the watcher has reacted to them (subscriptions and the auth
/// token are replayed on every ``WebSocket/State/connected``).
///
/// Lifetime: `start()` once, `setActive(_:)` any number of times (scene phase), `stop()` once at the end.
public actor EventsWatcher {
    let socket: WebSocket
    let dispatcher: EventDispatcher

    /// Connection states of the feed, in order, starting with ``WebSocket/State/idle``.
    ///
    /// One consumer for the whole lifetime of the watcher (e.g. ``EventsMonitor``); ends after `stop()`.
    /// Cancelling the iterating task ends it for good.
    public nonisolated let states: AsyncStream<WebSocket.State>
    private let statesContinuation: AsyncStream<WebSocket.State>.Continuation

    private var activeSubscriptions = Set<AccessPoint>()
    private var ownerSubscriptions: [String: Set<AccessPoint>] = [:]
    private var lastAuthToken: String?
    private var readTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var shouldBeActive = false
    private var isStopped = false

    /// Creates a watcher around a socket built by the account runtime. The watcher becomes the socket's owner:
    /// nobody else may read its `messages` or `states`.
    public init(socket: WebSocket, dispatcher: EventDispatcher) {
        self.socket = socket
        self.dispatcher = dispatcher
        (states, statesContinuation) = AsyncStream.makeStream(of: WebSocket.State.self)
    }

    /// WebSocket configuration for the `/events` feed: ping and read-idle watchdog, endless reconnect with backoff.
    public static var feedConfiguration: WebSocket.Configuration {
        var configuration = WebSocket.Configuration.checked
        configuration.connectionHandshakeTimeout = 25
        configuration.reconnect = .exponential()
        return configuration
    }

    deinit {
        readTask?.cancel()
        stateTask?.cancel()
        statesContinuation.finish()
    }

    /// Starts the feed: readers plus `setActive(true)`. Returns at once; the link comes up in the background.
    public func start() async {
        await setActive(true)
    }

    /// Final stop: shuts the socket down, which ends the readers and ``states``. Later calls do nothing.
    public func stop() async {
        guard !isStopped else { return }
        isStopped = true
        shouldBeActive = false
        await socket.shutdown()
        if stateTask == nil {
            statesContinuation.finish()
        }
    }

    /// Wants the link (`true`) or lets it go for now (`false`, e.g. app in background) without losing desired
    /// subscriptions. Returns quickly: `true` only registers the request; `false` returns after teardown.
    ///
    /// Calls from independent unstructured `Task`s run in no particular order: serialize them on the caller side
    /// (see ``EventsScenePhaseController``). No-op after `stop()`.
    public func setActive(_ active: Bool) async {
        guard !isStopped, shouldBeActive != active else { return }
        shouldBeActive = active

        if active {
            startReadersIfNeeded()
            await socket.connect()
        } else {
            await socket.disconnect(reason: .backgroundSuspended)
        }
    }

    /// Subscribes to events for a single access point. Sent now if connected, and on every reconnect.
    public func subscribe(_ accessPoint: AccessPoint) async throws {
        activeSubscriptions.insert(accessPoint)
        try await sendCurrentSubscriptions()
    }

    /// Unsubscribes from events for a single access point. Sent now if connected; later connections simply do not
    /// include it.
    public func unsubscribe(_ accessPoint: AccessPoint) async throws {
        activeSubscriptions.remove(accessPoint)
        let cmd = EventSubscription(include: desiredSubscriptions(), exclude: [accessPoint])
        try await sendIfConnected(try cmd.jsonFormatted())
    }

    /// Replaces the desired watch list owned by the provided identifier. Sent now if connected, and on every
    /// reconnect.
    public func watch(ownerID: String, accessPoints: [AccessPoint]) async throws {
        ownerSubscriptions[ownerID] = Set(accessPoints)
        try await sendCurrentSubscriptions()
    }

    /// Removes all access points owned by the provided identifier.
    public func unwatch(ownerID: String) async throws {
        ownerSubscriptions.removeValue(forKey: ownerID)
        try await sendCurrentSubscriptions()
    }

    /// Sends a new authorization token on the active connection and remembers it for every reconnect.
    public func updateToken(_ authToken: String) async throws {
        lastAuthToken = authToken
        let cmd = UpdateToken(auth_token: authToken)
        try await sendIfConnected(try cmd.jsonFormatted())
    }

    /// Snapshot of transport state and byte counters, for periodic diagnostics.
    public func transportSnapshot() async -> (state: WebSocket.State, sent: UInt64, received: UInt64) {
        async let state = socket.connectionState()
        let metrics = await socket.transportMetrics()
        return (await state, metrics.bytesSent, metrics.bytesReceived)
    }

    /// Starts the two lifetime readers once. They end when the socket is shut down.
    private func startReadersIfNeeded() {
        if readTask == nil {
            readTask = Task { await self.read() }
        }
        if stateTask == nil {
            stateTask = Task { await self.observeStates() }
        }
    }

    /// The only reader of `socket.states`: replays subscriptions on every connection, forwards every state.
    private func observeStates() async {
        for await state in socket.states {
            statesContinuation.yield(state)
            if case .connected = state {
                await replayConnectionState()
            }
        }
        statesContinuation.finish()
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
        try await sendIfConnected(try cmd.jsonFormatted())
    }

    /// Sends now, or does nothing when there is no link: the next connection replays the desired state anyway.
    private func sendIfConnected(_ text: String) async throws {
        do {
            try await socket.sendString(text)
        } catch WebSocketError.notConnected {
            return
        }
    }

    private func replayConnectionState() async {
        do {
            try await sendCurrentSubscriptions()
            if let lastAuthToken {
                try await sendIfConnected(try UpdateToken(auth_token: lastAuthToken).jsonFormatted())
            }
        } catch {
            await dispatcher.reportDecodingIssue(
                EventDecodingIssue(type: "transport", id: nil, message: String(describing: error))
            )
        }
    }
}
