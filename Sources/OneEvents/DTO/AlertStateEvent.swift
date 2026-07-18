import Foundation
import OneWireFormat
import SafeEnum

/// Alert processing state values on the WebSocket feed (`alert_state.state`).
public enum AlertWireState: String, Codable, Sendable, Hashable, CaseIterable {
    case closed
    case reaction
    case processing
}

/// Alert severity values on the WebSocket feed (`alert_state.severity`).
public enum AlertWireSeverity: String, Codable, Sendable, Hashable, CaseIterable {
    case unclassified
    case alarm
    case warning
    case `false`
}

/// Alert reviewer type on the WebSocket feed (`alert_state.reviewer_type`).
public enum AlertWireReviewerType: String, Codable, Sendable, Hashable {
    case system
    case user
}

/// Alert priority on the WebSocket feed (`alert_state.priority`).
public enum AlertWirePriority: String, Codable, Sendable, Hashable, CaseIterable {
    case unspecified = "ALERT_PRIORITY_UNSPECIFIED"
    case minimum = "AP_MINIMUM"
    case low = "AP_LOW"
    case medium = "AP_MEDIUM"
    case high = "AP_HIGH"
    case maximum = "AP_MAXIMUM"
}

/// Alert state update emitted as `alert_state`.
public struct AlertStateEvent: Codable, Sendable, Equatable, Identifiable {
    /// State-event identifier.
    public let id: String

    /// Wire event type. Expected to be `alert_state`.
    public let type: String

    /// Parent alert identifier.
    public let alertId: String

    /// Optional reviewer comment.
    public let message: String?

    /// Camera access point associated with the state.
    public let name: AccessPoint

    /// Reviewer login or empty for system.
    public let reviewer: String

    /// Reviewer kind.
    public let reviewerType: SafeEnum<AlertWireReviewerType>

    /// Classification severity.
    public let severity: SafeEnum<AlertWireSeverity>

    /// Processing state.
    public let state: SafeEnum<AlertWireState>

    /// Priority when present.
    public let priority: SafeEnum<AlertWirePriority>?

    /// Optional wire `state_time` when present.
    public let stateTimeRaw: String?

    /// Parsed ``stateTimeRaw``.
    public var stateTime: Date? {
        WireTimestampParsing.date(from: stateTimeRaw)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case alertId = "alert_id"
        case message
        case name
        case reviewer
        case reviewerType = "reviewer_type"
        case severity
        case state
        case priority
        case stateTimeRaw = "state_time"
    }
}
