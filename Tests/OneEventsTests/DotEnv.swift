import Foundation

/// Loads `.env` from the package root. Process environment overrides file values.
enum DotEnv {
    private static let dotenv: [String: String] = loadDotEnv()

    static let merged: [String: String] = {
        var out = dotenv
        for (key, value) in ProcessInfo.processInfo.environment {
            out[key] = value
        }
        return out
    }()

    private static func loadDotEnv() -> [String: String] {
        let fromPackage = packageRootURL(from: URL(fileURLWithPath: #filePath)).appendingPathComponent(".env")
        let fromCwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".env")
        let url = [fromPackage, fromCwd].first { FileManager.default.isReadableFile(atPath: $0.path) }
        guard let url,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else {
            return [:]
        }

        var map: [String: String] = [:]
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let separator = line.firstIndex(of: "=") else { continue }

            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            var value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2 {
                let first = value.first!
                let last = value.last!
                if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                    value = String(value.dropFirst().dropLast())
                }
            }
            map[key] = value
        }
        return map
    }

    private static func packageRootURL(from fileURL: URL) -> URL {
        var directory = fileURL.deletingLastPathComponent()
        while true {
            let package = directory.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return directory
            }
            guard directory.path != "/" else {
                return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
            directory.deleteLastPathComponent()
        }
    }
}
