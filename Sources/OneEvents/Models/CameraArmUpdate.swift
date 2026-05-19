import Foundation
import OneWireFormat

/// A normalized camera arm-state update ready for consumers.
public struct CameraArmUpdate: Sendable, Equatable {
    /// Camera access point.
    public let source: AccessPoint

    /// New camera arming state.
    public let state: CameraArmState

    /// Server timestamp in ASIP format.
    public let timestamp: String?

    /// Creates a camera arm-state update.
    public init(source: AccessPoint, state: CameraArmState, timestamp: String?) {
        self.source = source
        self.state = state
        self.timestamp = timestamp
    }
}
