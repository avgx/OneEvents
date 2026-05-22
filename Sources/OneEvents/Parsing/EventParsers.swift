import Foundation
import JSONValue
import OneWireFormat

/// Parses typed event DTOs from `OneWireFormat.WSString.Event` envelopes.
public enum EventParsers {
    /// Parses a camera arm-state update when the wire event type matches.
    public static func cameraArm(_ event: OneWireFormat.WSString.Event, decoder: JSONDecoder = JSONDecoder()) throws -> CameraArmStateEvent? {
        guard event.eventType == .cameraArmState else { return nil }
        return try decoder.decode(CameraArmStateEvent.self, from: event.raw)
    }

    /// Decodes a detector event when the wire event type matches.
    public static func detector(_ event: OneWireFormat.WSString.Event, decoder: JSONDecoder = JSONDecoder()) throws -> DetectorEvent? {
        guard event.eventType == .detector else { return nil }
        return try decoder.decode(DetectorEvent.self, from: event.raw)
    }

    /// Decodes a device state event when the wire event type matches.
    public static func deviceStateChanged(_ event: OneWireFormat.WSString.Event, decoder: JSONDecoder = JSONDecoder()) throws -> DeviceStateChangedEvent? {
        guard event.eventType == .deviceStateChanged else { return nil }
        return try decoder.decode(DeviceStateChangedEvent.self, from: event.raw)
    }

    /// Decodes a camera record-state event when the wire event type matches.
    public static func cameraRecordState(_ event: OneWireFormat.WSString.Event, decoder: JSONDecoder = JSONDecoder()) throws -> CameraRecordStateEvent? {
        guard event.eventType == .cameraRecordState else { return nil }
        return try decoder.decode(CameraRecordStateEvent.self, from: event.raw)
    }

    /// Decodes a camera list update event when the wire event type matches.
    public static func cameraListUpdate(_ event: OneWireFormat.WSString.Event, decoder: JSONDecoder = JSONDecoder()) throws -> CameraListUpdateEvent? {
        guard event.eventType == .cameraListUpdate else { return nil }
        return try decoder.decode(CameraListUpdateEvent.self, from: event.raw)
    }

    /// Decodes an object activation event when the wire event type matches.
    public static func objectActivated(_ event: OneWireFormat.WSString.Event, decoder: JSONDecoder = JSONDecoder()) throws -> ObjectActivatedEvent? {
        guard event.eventType == .objectActivated else { return nil }
        return try decoder.decode(ObjectActivatedEvent.self, from: event.raw)
    }

    /// Decodes an unknown wire event as structured JSON.
    public static func unknownJSON(_ event: OneWireFormat.WSString.Event, decoder: JSONDecoder = JSONDecoder()) throws -> JSONValue? {
        guard event.eventType == nil else { return nil }
        return try decoder.decode(JSONValue.self, from: event.raw)
    }
}

/// A parsing failure for a single WebSocket event object.
public struct EventDecodingIssue: Sendable, Equatable {
    /// Wire event type that failed to decode.
    public let type: String

    /// Event identifier when available.
    public let id: String?

    /// Human-readable decoding error description.
    public let message: String

    init(type: String, id: String?, message: String) {
        self.type = type
        self.id = id
        self.message = message
    }
}
