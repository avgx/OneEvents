import Foundation
import HTTP
import OneWireFormat
import Testing
import WS
@testable import OneEvents

/// Requires `EVENTS_WS_URL` (or `EVENTS_BASE_URL`), plus `EVENTS_USER` and `EVENTS_PASSWORD` in `.env` or the process environment.
@Test func eventsWatcherLongReadIntegration() async throws {
    let env = DotEnv.merged
    guard let user = env["EVENTS_USER"], !user.isEmpty,
          let password = env["EVENTS_PASSWORD"], !password.isEmpty,
          let wsUrlString = env["EVENTS_WS_URL"], !wsUrlString.isEmpty, let url = URL(string: wsUrlString)
    else {
        return
    }

    let readSeconds = UInt64(env["EVENTS_READ_SECONDS"].flatMap(Int.init) ?? 30)
    let dispatcher = EventDispatcher()
    let socket = WebSocket(
        request: URLRequest(url: url),
        configuration: EventsWatcher.feedConfiguration,
        requestAdapter: FixedAuthInterceptor(user: user, password: password)
    )
    let watcher = EventsWatcher(socket: socket, dispatcher: dispatcher)
    defer {
        Task {
            await watcher.stop()
        }
    }

    let stateStream = await watcher.connectionStateUpdates()
    let eventsStream = await dispatcher.events()

    await watcher.start()
    let connected = await waitForConnected(in: stateStream, timeoutNanoseconds: 25_000_000_000)
    #expect(connected, "WebSocket did not reach connected state.")
    guard connected else { return }

    let receivedCount = await countEvents(
        in: eventsStream,
        timeoutNanoseconds: max(1, readSeconds) * NSEC_PER_SEC
    )
    let snapshot = await watcher.transportSnapshot()

    #expect(snapshot.received > 0 || receivedCount > 0, "Expected bytes or events from the WebSocket stream.")
    await watcher.stop()
}

private func waitForConnected(
    in stream: AsyncStream<WebSocket.State>,
    timeoutNanoseconds: UInt64
) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            for await state in stream {
                if case .connected = state {
                    return true
                }
            }
            return false
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            return false
        }

        let result = await group.next() ?? false
        group.cancelAll()
        return result
    }
}

private func countEvents(
    in stream: AsyncStream<OneWireFormat.WSString.Event>,
    timeoutNanoseconds: UInt64
) async -> Int {
    await withTaskGroup(of: Int.self) { group in
        group.addTask {
            var iterator = stream.makeAsyncIterator()
            var count = 0
            while await iterator.next() != nil {
                count += 1
            }
            return count
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            return 0
        }

        let result = await group.next() ?? 0
        group.cancelAll()
        return result
    }
}
