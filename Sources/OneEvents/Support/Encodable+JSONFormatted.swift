import Foundation

extension Encodable {
    /// Encodes the value as formatted JSON suitable for WebSocket commands.
    func jsonFormatted() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                data,
                .init(codingPath: [], debugDescription: "Encoded JSON was not valid UTF-8.")
            )
        }
        return string
    }
}

