import Foundation

struct MockLogger: Logger {
    func log(
        level: LogLevel,
        _ message: @autoclosure () -> String,
        category: LogCategory,
        metadata: LogMetadataFields,
        pii: [String: PIIValue],
        file: StaticString,
        function: StaticString,
        line: UInt
    ) {}

    func scoped(metadata: LogMetadataFields, pii: [String: PIIValue]) -> Logger {
        self
    }

    func flush() async {}
}

actor MockLogHistoryProvider: LogHistoryProviding {
    func snapshot(limit: Int?) async -> [LogEntry] {
        []
    }

    func stream() -> AsyncStream<[LogEntry]> {
        AsyncStream { continuation in
            continuation.yield([])
            continuation.finish()
        }
    }

    func exportArchive() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mock-log.json")
        let data = Data("{}".utf8)
        try data.write(to: url, options: .atomic)
        return url
    }
}
