import Foundation
import OneWireFormat

/// Object activation event emitted as `ObjectActivatedEvent`.
public struct ObjectActivatedEvent: Codable, Sendable, Equatable {
    /// Wire event type. Expected to be `ObjectActivatedEvent`.
    public let type: String

    /// Event identifier when the server includes it.
    public let guid: String?

    /// Whether the object is currently active.
    public let isActivated: Bool

    /// Server timestamp in ASIP format when present.
    public let timestampRaw: String?

    /// Parsed ``timestampRaw``.
    public var timestamp: Date? {
        WireTimestampParsing.date(from: timestampRaw)
    }

    /// Node details for the object.
    public let nodeInfo: NodeInfo

    /// Activated object identifier.
    public let objectIdExt: ObjectIdExt

    enum CodingKeys: String, CodingKey {
        case type
        case guid
        case isActivated
        case timestampRaw = "timestamp"
        case nodeInfo
        case objectIdExt
    }

    /// Node details included in object activation events.
    public struct NodeInfo: Codable, Sendable, Equatable {
        /// Node technical name.
        public let name: String

        /// Node display name.
        public let friendlyName: String
    }

    /// Object identifier details included in object activation events.
    public struct ObjectIdExt: Codable, Sendable, Equatable {
        /// Object access point.
        public let accessPoint: String

        /// Object group.
        public let group: String

        /// Object display name.
        public let friendlyName: String
    }
}
