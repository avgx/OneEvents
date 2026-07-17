import Foundation
import OneWireFormat
import SafeEnum

/// Alert initiator kind on the WebSocket feed (`alert.initiator_type`).
public enum AlertWireInitiatorType: String, Codable, Sendable, Hashable {
    case macro
    case user
}

/// Active alert emitted as `alert`.
public struct AlertEvent: Codable, Sendable, Equatable, Identifiable {
    /// Alert identifier (UUID string on wire).
    public let id: String

    /// Wire event type. Expected to be `alert`.
    public let type: String

    /// Archive access point.
    public let archive: AccessPoint

    /// Initiator login or macro id.
    public let initiator: String

    /// Initiator kind.
    public let initiatorType: SafeEnum<AlertWireInitiatorType>

    /// Optional phase string (for example `started`).
    public let phase: String?

    /// Camera access point.
    public let source: AccessPoint

    /// Optional user state marker.
    public let stateUser: String?

    /// Optional macro state marker (for example `raise_alert`).
    public let stateMacro: String?

    /// Embedded state history (newest usually last).
    public let states: [AlertStateEvent]

    /// Server timestamp in ASIP format.
    public let timestamp: String

    /// Optional detector event reference.
    public let event: AlertEventRef?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case archive
        case initiator
        case initiatorType = "initiator_type"
        case phase
        case source
        case stateUser = "state_user"
        case stateMacro = "state_macro"
        case states
        case timestamp
        case event
    }
}

/// Detector event reference nested in an alert payload.
public struct AlertEventRef: Codable, Sendable, Equatable {
    /// Detector access point.
    public let detectorAccessPoint: AccessPoint

    /// Detector event id.
    public let eventId: String

    /// Detector event type string.
    public let eventType: String

    enum CodingKeys: String, CodingKey {
        case detectorAccessPoint = "detector_access_point"
        case eventId = "event_id"
        case eventType = "event_type"
    }
}
