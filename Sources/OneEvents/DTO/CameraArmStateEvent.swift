import Foundation
import OneWireFormat
import SafeEnum

/// Camera arming state event emitted as `cameraarmstateevent`.
public struct CameraArmStateEvent: Codable, Sendable, Equatable {
    /// Event identifier when the server includes it.
    public let id: String?

    /// Wire event type. Expected to be `cameraarmstateevent`.
    public let type: String

    /// New camera arming state.
    public let state: SafeEnum<CameraArmState>

    /// Camera access point.
    public let source: AccessPoint

    /// Server timestamp in ASIP format when present.
    public let timestampRaw: String?

    /// Parsed ``timestampRaw``.
    public var timestamp: Date? {
        WireTimestampParsing.date(from: timestampRaw)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case state
        case source
        case timestampRaw = "timestamp"
    }
}
