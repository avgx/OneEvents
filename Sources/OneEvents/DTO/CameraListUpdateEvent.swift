import Foundation
import OneWireFormat
import SafeEnum

/// Camera list change event emitted as `cameralistupdate`.
public struct CameraListUpdateEvent: Codable, Sendable, Equatable {
    /// Change state values returned by the events endpoint.
    public enum State: String, Codable, Sendable, Equatable {
        case added
        case removed
        case changed
    }

    /// Event identifier when the server includes it.
    public let id: String?

    /// Wire event type. Expected to be `cameralistupdate`.
    public let type: String

    /// Camera list change state.
    public let state: SafeEnum<State>

    /// Camera access point.
    public let name: AccessPoint
}

