import Foundation

/// Known `type` values emitted by the One `/events` WebSocket feed.
public enum EventType: String, Codable, Sendable, CaseIterable, Hashable {
    case deviceStateChanged = "devicestatechanged"
    case cameraRecordState = "camera_record_state"
    case detector = "detector_event"
    case alertState = "alert_state"
    case alert = "alert"
    case cameraState = "camera_state"
    case cameraArmState = "cameraarmstateevent"
    case cameraListUpdate = "cameralistupdate"
    case configChanged = "ConfigChangedEvent"
    case configLinkageChanged = "ConfigLinkageChangedEvent"
    case objectActivated = "ObjectActivatedEvent"
}

