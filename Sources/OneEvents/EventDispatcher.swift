import Foundation
import JSONValue
import OneWireFormat

/// Routes wire events into typed streams and custom handlers.
public actor EventDispatcher {
    private let eventsHub = Hub<OneWireFormat.WSString.Event>()
    private let cameraArmHub = Hub<CameraArmUpdate>()
    private let detectorHub = Hub<DetectorEvent>()
    private let deviceStateHub = Hub<DeviceStateChangedEvent>()
    private let cameraRecordStateHub = Hub<CameraRecordStateEvent>()
    private let cameraListUpdateHub = Hub<CameraListUpdateEvent>()
    private let objectActivatedHub = Hub<ObjectActivatedEvent>()
    private let unknownHub = Hub<JSONValue>()
    private let decodingIssuesHub = Hub<EventDecodingIssue>()

    private var handlers: [String: [@Sendable (OneWireFormat.WSString.Event) async -> Void]] = [:]

    /// Creates an event dispatcher.
    public init() {}

    /// Subscribes to all wire events before typed dispatch.
    public func events() async -> AsyncStream<OneWireFormat.WSString.Event> {
        await eventsHub.subscribe()
    }

    /// Subscribes to camera arm-state updates.
    public func cameraArmUpdates() async -> AsyncStream<CameraArmUpdate> {
        await cameraArmHub.subscribe()
    }

    /// Subscribes to live detector events.
    public func detectorEvents() async -> AsyncStream<DetectorEvent> {
        await detectorHub.subscribe()
    }

    /// Subscribes to device state events.
    public func deviceStateEvents() async -> AsyncStream<DeviceStateChangedEvent> {
        await deviceStateHub.subscribe()
    }

    /// Subscribes to camera record-state events.
    public func cameraRecordStateEvents() async -> AsyncStream<CameraRecordStateEvent> {
        await cameraRecordStateHub.subscribe()
    }

    /// Subscribes to camera list update events.
    public func cameraListUpdateEvents() async -> AsyncStream<CameraListUpdateEvent> {
        await cameraListUpdateHub.subscribe()
    }

    /// Subscribes to object activation events.
    public func objectActivatedEvents() async -> AsyncStream<ObjectActivatedEvent> {
        await objectActivatedHub.subscribe()
    }

    /// Subscribes to unknown events decoded as structured JSON.
    public func unknownEvents() async -> AsyncStream<JSONValue> {
        await unknownHub.subscribe()
    }

    /// Subscribes to per-event decoding issues.
    public func decodingIssues() async -> AsyncStream<EventDecodingIssue> {
        await decodingIssuesHub.subscribe()
    }

    func reportDecodingIssue(_ issue: EventDecodingIssue) async {
        await decodingIssuesHub.publish(issue)
    }

    /// Registers a custom handler for a wire event type.
    public func register(
        type: String,
        handler: @escaping @Sendable (OneWireFormat.WSString.Event) async -> Void
    ) {
        handlers[type, default: []].append(handler)
    }

    /// Dispatches one wire event into typed streams and registered handlers.
    public func dispatch(_ event: OneWireFormat.WSString.Event) async {
        await eventsHub.publish(event)

        do {
            try await dispatchBuiltIn(event)
        } catch {
            await decodingIssuesHub.publish(
                EventDecodingIssue(type: event.type, id: event.id, message: String(describing: error))
            )
        }

        for handler in handlers[event.type] ?? [] {
            await handler(event)
        }
    }

    private func dispatchBuiltIn(_ event: OneWireFormat.WSString.Event) async throws {
        switch event.eventType {
        case .cameraArmState:
            if let update = try EventParsers.cameraArm(event) {
                await cameraArmHub.publish(update)
            }
        case .detector:
            if let detector = try EventParsers.detector(event) {
                await detectorHub.publish(detector)
            }
        case .deviceStateChanged:
            if let deviceState = try EventParsers.deviceStateChanged(event) {
                await deviceStateHub.publish(deviceState)
            }
        case .cameraRecordState:
            if let recordState = try EventParsers.cameraRecordState(event) {
                await cameraRecordStateHub.publish(recordState)
            }
        case .cameraListUpdate:
            if let listUpdate = try EventParsers.cameraListUpdate(event) {
                await cameraListUpdateHub.publish(listUpdate)
            }
        case .objectActivated:
            if let objectActivated = try EventParsers.objectActivated(event) {
                await objectActivatedHub.publish(objectActivated)
            }
        case nil:
            if let payload = try EventParsers.unknownJSON(event) {
                await unknownHub.publish(payload)
            }
        default:
            break
        }
    }
}
