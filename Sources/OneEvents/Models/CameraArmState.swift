import Foundation
import OneWireFormat

/// Camera arming states returned by `cameraarmstateevent`.
public enum CameraArmState: String, Codable, CaseIterable, Sendable {
    /// Camera is disarmed.
    case disarm = "CS_Disarm"

    /// Camera is armed.
    case arm = "CS_Arm"

    /// Camera is armed in private mode.
    case armPrivate = "CS_ArmPrivate"
}

