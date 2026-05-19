# OneEvents

Events feed over WebSocket for the One backend.

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
let watcher = EventsWatcher(request: request, requestAdapter: adapter, dispatcher: dispatcher)
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

`OneAccountDemo` integration is intentionally left for the next step: add the package dependency,
create the watcher/dispatcher pair at the app runtime level, bind `Env` adapters to UI state, and
forward `scenePhase` to `EventsWatcher.setActive(_:)`.
