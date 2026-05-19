import Foundation
import RequestResponse

/// Request builders for the One events API.
public enum EventsApi {
    /// Creates a request descriptor for the `/events` WebSocket endpoint.
    public static func feed() -> Request<Void> {
        Request(path: "events", method: .get)
    }
}
