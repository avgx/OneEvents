import Foundation
import OneWireFormat

/// Device state event emitted as `devicestatechanged`.
public struct DeviceStateChangedEvent: Codable, Sendable, Equatable {
    /// Wire event type. Expected to be `devicestatechanged`.
    public let type: String

    /// Server state string. Values vary by server version and localization.
    public let state: String

    /// Device or camera access point.
    public let name: AccessPoint

    /// Returns true when the state means the device is online.
    public var isOnline: Bool {
        let value = state.lowercased()
        return value == "connected" || value == "signal restored" || value == "signal_restored" || value == "online"
    }

    /// Returns true when the state means the device signal is lost.
    public var isSignalLost: Bool {
        let value = state.lowercased()
        return value == "signal lost" || value == "signal_lost"
    }
}

