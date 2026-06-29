# OneEvents

Events feed over WebSocket.

`OneWireFormat.WSString.Event` is the single envelope for incoming JSON objects. `OneEvents`
keeps WebSocket lifecycle, subscriptions, typed dispatch, and UI-facing state adapters in one
package without adding another envelope layer.

## Layers

- `Watcher`: `EventsWatcher` owns `/events` WebSocket lifecycle, desired subscriptions, token updates, replay after reconnect, and `setActive(_:)` for external app lifecycle control.
- `Dispatch`: `EventDispatcher` routes `OneWireFormat.WSString.Event` into typed streams and publishes unknown events as `JSONValue`.
- `Parsing`: typed parsers decode DTOs from `WSString.Event.raw` only when a typed channel needs them.
- `Env`: UI-ready adapters such as `EventsMonitor`, `EventFeed`, `CameraArmManager`, and `EventsScenePhaseController`.

## Minimal Usage

```swift
let dispatcher = EventDispatcher()
let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
let url = try builder.url(for: EventsApi.feed()).wsURL
let socket = WebSocket(
    request: URLRequest(url: url),
    configuration: EventsWatcher.feedConfiguration,
    requestAdapter: adapter
)
let watcher = EventsWatcher(socket: socket, dispatcher: dispatcher)
let monitor = EventsMonitor(watcher: watcher, dispatcher: dispatcher)
let feed = EventFeed(capacity: 100)

feed.bind(dispatcher)
monitor.start()

await watcher.start()
try await watcher.watch(
    ownerID: "layout",
    accessPoints: ["hosts/Server/DeviceIpint.1/SourceEndpoint.video:0:0"]
)

// Forward SwiftUI scene phase changes from the app layer:
await watcher.setActive(scenePhase == .active)
```

## Integration in app preparation

Create the watcher at the account runtime level and pass the runtime endpoint URL plus the auth
request adapter from the account layer:

```swift
let dispatcher = EventDispatcher()
let baseURL = await runtime.account.endpoint.url
let adapter = /* request adapter from AccountRuntime/auth layer */
let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
let url = try builder.url(for: EventsApi.feed()).wsURL
let socket = await runtime.makeWebSocket(
    request: URLRequest(url: url),
    configuration: EventsWatcher.feedConfiguration,
    requestAdapter: adapter
)
let watcher = EventsWatcher(socket: socket, dispatcher: dispatcher)

let monitor = EventsMonitor(watcher: watcher, dispatcher: dispatcher)
let feed = EventFeed(capacity: 100)

feed.bind(dispatcher)
monitor.start()
await watcher.start()
```

Forward SwiftUI `scenePhase` changes to `EventsWatcher.setActive(_:)`. The watcher keeps desired
subscriptions while inactive and replays them after the next connection.

## Integration Test

The long-read WebSocket integration test is opt-in. Rename `.env.example` to `.env` and put values in.
Use `EVENTS_WS_URL` for a ready `ws`/`wss` feed URL, or `EVENTS_BASE_URL` to derive `…/events` manually.

Without these values, `swift test` runs the offline tests and reports that the integration test is
not configured.
