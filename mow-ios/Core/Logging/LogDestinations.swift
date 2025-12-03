import Foundation
import os

protocol LogDestination: Sendable {
    func write(_ entry: LogEntry) async
    func flush() async
}

// MARK: - Console

final class ConsoleLogDestination: LogDestination {
    private let subsystem: String
    private let showIcon: Bool
    private let logger: os.Logger
    private let formatter = ConsoleLogFormatter()

    init(subsystem: String, showIcon: Bool) {
        self.subsystem = subsystem
        self.showIcon = showIcon
        self.logger = os.Logger(subsystem: subsystem, category: "app")
    }

    func write(_ entry: LogEntry) async {
        let payload = formatter.render(entry: entry, showIcon: showIcon)
        logger.log(level: entry.osLogType, "\(payload, privacy: .public)")
    }

    func flush() async {}
}

private struct ConsoleLogFormatter {
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    func render(entry: LogEntry, showIcon: Bool) -> String {
        let timestamp = timestampFormatter.string(from: entry.timestamp)
        let metadata = ConsoleLogFormatter.metadataString(from: entry.metadata, scope: entry.scope)
        let piiNote = entry.pii.isEmpty ? "" : " pii:\(entry.pii.keys.joined(separator: ","))"
        if showIcon {
            return "\(entry.level.icon) [\(timestamp)] [\(entry.level.label)] [\(entry.category.rawValue)] \(entry.message)\(metadata)\(piiNote)"
        } else {
            return "[\(timestamp)] [\(entry.level.label)] [\(entry.category.rawValue)] \(entry.message)\(metadata)\(piiNote)"
        }
    }

    private static func metadataString(from metadata: [String: LogValue], scope: [String: LogValue]) -> String {
        let merged = metadata.merging(scope) { value, _ in value }
        guard !merged.isEmpty else { return "" }
        let pairs = merged
            .map { "\($0.key)=\(Self.render(value: $0.value))" }
            .sorted()
            .joined(separator: " ")
        return " {\(pairs)}"
    }

    private static func render(value: LogValue) -> String {
        switch value {
        case let .string(value): return "\"\(value)\""
        case let .int(value): return "\(value)"
        case let .double(value): return "\(value)"
        case let .bool(value): return "\(value)"
        case let .array(values): return "[\(values.map { render(value: $0) }.joined(separator: ","))]"
        case let .dictionary(dictionary):
            let entries = dictionary
                .map { "\($0.key):\(render(value: $0.value))" }
                .joined(separator: ",")
            return "{\(entries)}"
        case .null: return "null"
        }
    }
}

private extension LogEntry {
    var osLogType: OSLogType {
        switch level {
        case .trace, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - File

actor FileLogDestination: LogDestination {
    private let directoryURL: URL
    private let config: LoggingConfiguration.DestinationConfiguration.File
    // Note: fileHandle is kept open for the lifetime of this destination.
    // It is closed on rotation and when the actor is deallocated.
    private var fileHandle: FileHandle?

    init(baseDirectory: URL, config: LoggingConfiguration.DestinationConfiguration.File) {
        self.directoryURL = baseDirectory.appendingPathComponent(config.directoryName, isDirectory: true)
        self.config = config
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func write(_ entry: LogEntry) async {
        guard config.isEnabled else { return }
        do {
            var payload = try encode(entry)
            payload.append(0x0A)
            try await append(payload)
        } catch {
            print("FileLogger error:", error)
        }
    }

    func flush() async {
        try? fileHandle?.synchronize()
    }

    private func append(_ data: Data) async throws {
        if fileHandle == nil {
            try openFile()
        }
        guard let handle = fileHandle else { return }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try rotateIfNeeded()
    }

    private func openFile() throws {
        let currentURL = activeFileURL
        if !FileManager.default.fileExists(atPath: currentURL.path) {
            FileManager.default.createFile(atPath: currentURL.path, contents: nil)
        }
        fileHandle = try FileHandle(forUpdating: currentURL)
        try fileHandle?.seekToEnd()
    }

    private var activeFileURL: URL {
        directoryURL.appendingPathComponent("app.log")
    }

    private func rotateIfNeeded() throws {
        guard config.maxFiles > 0 else { return }
        let attributes = try FileManager.default.attributesOfItem(atPath: activeFileURL.path)
        let size = attributes[.size] as? NSNumber ?? 0
        if size.intValue < config.maxFileBytes { return }

        try fileHandle?.close()
        fileHandle = nil

        for index in stride(from: config.maxFiles - 1, through: 0, by: -1) {
            let source = index == 0 ? activeFileURL : directoryURL.appendingPathComponent("app-\(index).log")
            let destination = directoryURL.appendingPathComponent("app-\(index + 1).log")

            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }

            if FileManager.default.fileExists(atPath: source.path) {
                try FileManager.default.moveItem(at: source, to: destination)
            }
        }

        FileManager.default.createFile(atPath: activeFileURL.path, contents: nil)
        fileHandle = try FileHandle(forUpdating: activeFileURL)
    }
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    private func encode(_ entry: LogEntry) throws -> Data {
        return try encoder.encode(EncodableLogEntry(entry: entry))
    }

    private struct EncodableLogEntry: Encodable {
        let id: UUID
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
        let metadata: [String: LogValue]
        let pii: [String: LogPIIRepresentation]
        let scope: [String: LogValue]
        let source: LogSource
        let threadID: UInt64
        let sequence: UInt64

        init(entry: LogEntry) {
            self.id = entry.id
            self.timestamp = entry.timestamp
            self.level = entry.level
            self.category = entry.category
            self.message = entry.message
            self.metadata = entry.metadata
            self.pii = entry.pii
            self.scope = entry.scope
            self.source = entry.source
            self.threadID = entry.threadID
            self.sequence = entry.sequence
        }
    }
}

// MARK: - In-memory

protocol LogHistoryProviding: Actor {
    func snapshot(limit: Int?) async -> [LogEntry]
    func stream() -> AsyncStream<[LogEntry]>
    func exportArchive() async throws -> URL
}

actor InMemoryLogDestination: LogDestination, LogHistoryProviding {
    private let limit: Int
    private var entries: [LogEntry] = []
    private var listeners: [UUID: AsyncStream<[LogEntry]>.Continuation] = [:]
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }()

    init(limit: Int) {
        self.limit = limit
    }

    func write(_ entry: LogEntry) async {
        entries.append(entry)
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        listeners.values.forEach { $0.yield(entries) }
    }

    func flush() async {}

    func snapshot(limit override: Int? = nil) async -> [LogEntry] {
        guard let override else { return entries }
        return Array(entries.suffix(override))
    }

    func stream() -> AsyncStream<[LogEntry]> {
        AsyncStream { continuation in
            let id = UUID()
            listeners[id] = continuation
            continuation.yield(entries)
            continuation.onTermination = { _ in
                Task { await self.removeListener(id: id) }
            }
        }
    }

    private func removeListener(id: UUID) {
        listeners[id] = nil
    }

    func exportArchive() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mow-logs-\(UUID().uuidString).json")
        let data = try encoder.encode(entries)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
