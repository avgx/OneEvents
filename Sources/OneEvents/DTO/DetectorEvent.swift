import Foundation
import OneWireFormat

/// Detector event emitted as `detector_event`.
public struct DetectorEvent: Codable, Sendable, Identifiable, Equatable {
    /// Detector event phase values used by the WebSocket feed.
    public enum Phase: Int, Codable, Sendable, Hashable {
        case happened = 0
        case began = 1
        case ended = 2
        case specified = 3
    }

    /// Event identifier.
    public let id: String

    /// Wire event type. Expected to be `detector_event`.
    public let type: String

    /// Detector-specific event type, for example `MotionDetected` or `plateRecognized`.
    public let eventType: String

    /// Camera access point.
    public let source: AccessPoint

    /// Raw detector phase value.
    public let state: Int?

    /// Server timestamp in ASIP format.
    public let timestamp: String

    /// Detection rectangles in normalized coordinates.
    public let rectangles: [EventRectangle]?

    /// Full license plate value for LPR events.
    public let plateFull: String?

    /// Matched list details for list-based detector events.
    public let listedInfo: ListedInfo?

    /// Parsed detector phase.
    public var phase: Phase? {
        state.flatMap(Phase.init(rawValue:))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case eventType = "event_type"
        case source
        case state
        case timestamp
        case rectangles
        case plateFull = "plate_full"
        case listedInfo
    }
}

/// Details about a list match included in detector payloads.
public struct ListedInfo: Codable, Sendable, Equatable {
    /// Matched item identifier.
    public let itemId: String

    /// Matched item display name.
    public let itemName: String

    /// Matched list identifier when present.
    public let listId: String?

    /// Matched list display name when present.
    public let listName: String?

    /// License plate included in the matched item.
    public let plate: String?

    /// Detailed list matches returned by some server versions.
    public let listsInfo: [Detail]?

    /// Match timestamp for list-based events.
    public let matchedEventTime: String?

    enum CodingKeys: String, CodingKey {
        case itemId
        case itemName
        case listId
        case listName
        case plate
        case listsInfo = "lists_Info"
        case matchedEventTime = "matched_event_time"
    }

    /// Single matched list descriptor.
    public struct Detail: Codable, Sendable, Equatable {
        /// List identifier.
        public let list_id: String

        /// List display name.
        public let list_name: String
    }
}

/// Normalized rectangle included in detector event payloads.
public struct EventRectangle: Codable, Sendable, Equatable {
    /// Optional rectangle index.
    public let index: Int?

    /// Bottom coordinate in normalized image space.
    public let bottom: Double?

    /// Left coordinate in normalized image space.
    public let left: Double?

    /// Right coordinate in normalized image space.
    public let right: Double?

    /// Top coordinate in normalized image space.
    public let top: Double?
}

