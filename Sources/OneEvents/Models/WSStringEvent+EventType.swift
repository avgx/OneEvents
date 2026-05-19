import Foundation
import OneWireFormat
import SafeEnum

extension OneWireFormat.WSString.Event {
    /// Returns the event `type` as a known One event type when possible.
    public var eventType: EventType? {
        EventType(rawValue: type)
    }

    /// Returns the event `type` wrapped in `SafeEnum` for callers that need unknown preservation.
    public var knownType: SafeEnum<EventType> {
        SafeEnum<EventType>(rawValue: type)
    }
}

