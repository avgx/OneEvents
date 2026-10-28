import Foundation
import HTTP
import WS
import Logging
import OneWireFormat

extension EventsWatcher {
    /// The only reader of `socket.messages`, for the whole lifetime of the watcher: decodes frames of every
    /// connection and dispatches event objects. Ends when the socket is shut down.
    func read() async {
        for await frame in socket.messages {
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
