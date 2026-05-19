import Foundation
import Logging

@MainActor
public class TestsLogging {

    private static var configured = false

    public static func bootstrap() {

        guard !configured else { return }
        configured = true

        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug
            return handler
        }
        
    }
}
