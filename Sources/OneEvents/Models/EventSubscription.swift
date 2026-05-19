import Foundation

/// WebSocket command that updates event subscriptions by access point.
public struct EventSubscription: Codable, Sendable {
    /// Access points to include in the subscription.
    public let include: [AccessPoint]

    /// Access points to exclude from the subscription.
    public let exclude: [AccessPoint]?
    
    /// Creates a subscription update command.
    public init(include: [AccessPoint], exclude: [AccessPoint]? = nil) {
        self.include = include
        self.exclude = exclude
    }
}
