import Foundation

/// WebSocket command that updates the authorization token.
public struct UpdateToken: Encodable, Sendable {
    /// Command method. Always `update_token`.
    public let method: String

    /// New authorization token.
    public let auth_token: String
    
    /// Creates an `update_token` command.
    public init(auth_token: String) {
        self.method = "update_token"
        self.auth_token = auth_token
    }
}
