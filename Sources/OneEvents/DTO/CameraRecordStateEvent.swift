import Foundation
import OneWireFormat
import SafeEnum

/// Camera archive recording state event emitted as `camera_record_state`.
public struct CameraRecordStateEvent: Codable, Sendable, Equatable {
    /// Wire event type. Expected to be `camera_record_state`.
    public let type: String

    /// Current archive recording state.
    public let state: SafeEnum<ArchiveRecordState>

    /// Camera access point.
    public let source: AccessPoint
}

/// Archive recording states returned by the events endpoint.
public enum ArchiveRecordState: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    /// Stable identifier equal to the raw wire value.
    public var id: String { return self.rawValue }

    /// Camera has archives but recording is not active.
    case gray

    /// Camera is not recording or is not bound to an archive.
    case off

    /// Camera is recording to an archive.
    case on
}

