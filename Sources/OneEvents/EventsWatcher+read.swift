import Foundation
import HTTP
import WS
import Logging
import OneWireFormat

extension EventsWatcher {
    /// Reads WebSocket frames and dispatches decoded event objects.
    public func read() async {
        let eventsStream = await socket.messages()
        for await frame in eventsStream {
            if Task.isCancelled {
                break
            }
            guard case .string(let event) = frame else { continue }

            guard let data = event.data(using: .utf8) else {
                await dispatcher.reportDecodingIssue(
                    EventDecodingIssue(type: "frame", id: nil, message: "String frame was not valid UTF-8.")
                )
                continue
            }

            let objects: [OneWireFormat.WSString.Event]
            do {
                objects = try OneWireFormat.WSString.decodeEventsPack(from: data)
            } catch {
                await dispatcher.reportDecodingIssue(
                    EventDecodingIssue(type: "packet", id: nil, message: String(describing: error))
                )
                continue
            }

            for object in objects {
                await dispatcher.dispatch(object)
            }
        }
    }
}
