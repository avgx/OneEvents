import Foundation
import OneWireFormat

enum WireTimestampParsing {
    static func date(from raw: String) -> Date {
        Timestamp.utc.date(from: raw) ?? .distantPast
    }

    static func date(from raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return Timestamp.utc.date(from: raw)
    }
}
