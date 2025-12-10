import Foundation
import os
import os.lock

protocol Logger: Sendable {
    func log(
        level: LogLevel,
        _ message: @autoclosure () -> String,
        category: LogCategory,
        metadata: LogMetadataFields,
        pii: [String: PIIValue],
        file: StaticString,
        function: StaticString,
        line: UInt
    )

    func scoped(
        metadata: LogMetadataFields,
        pii: [String: PIIValue]
    ) -> Logger

    // flush() is a best effort not a guarantee
    func flush() async
}

extension Logger {
    func withScope<T>(
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        perform: (Logger) -> T
    ) -> T {
        let scoped = scoped(metadata: metadata, pii: pii)
        return perform(scoped)
    }

    func debug(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(level: .debug, message(), category: category, metadata: metadata, pii: pii, file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(level: .info, message(), category: category, metadata: metadata, pii: pii, file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(level: .warning, message(), category: category, metadata: metadata, pii: pii, file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(level: .error, message(), category: category, metadata: metadata, pii: pii, file: file, function: function, line: line)
    }

    func critical(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(level: .critical, message(), category: category, metadata: metadata, pii: pii, file: file, function: function, line: line)
    }
}

extension Logger {
    func error(
        _ message: @autoclosure () -> String,
        error: Error,
        category: LogCategory = .app,
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        var meta = metadata
        meta["error"] = .public(String(describing: error))
        self.error(message(), category: category, metadata: meta, pii: pii, file: file, function: function, line: line)
    }
}

// MARK: - Default logger

struct DefaultLogger: Logger {
    private let configuration: LoggingConfiguration
    private let pipeline: LogPipeline
    private let scopeMetadata: LogMetadataFields
    private let scopePII: [String: PIIValue]
    private let dateProvider: () -> Date
    private let sequenceGenerator: LogSequenceGenerator

    init(
        configuration: LoggingConfiguration,
        pipeline: LogPipeline,
        scopeMetadata: LogMetadataFields = [:],
        scopePII: [String: PIIValue] = [:],
        sequenceGenerator: LogSequenceGenerator,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.pipeline = pipeline
        self.scopeMetadata = scopeMetadata
        self.scopePII = scopePII
        self.sequenceGenerator = sequenceGenerator
        self.dateProvider = dateProvider
    }

    func log(
        level: LogLevel,
        _ message: @autoclosure () -> String,
        category: LogCategory,
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        guard shouldLog(level: level, category: category) else { return }

        let timestamp = dateProvider().addingTimeInterval(configuration.serverTimeOffset)
        let source = LogSource.current(file: file, function: function, line: line)
        let sequence = sequenceGenerator.next()

        let resolved = resolveMetadataLayers([
            configuration.globalMetadata,
            scopeMetadata,
            metadata
        ])

        let scopeResolved = resolveMetadataLayers([scopeMetadata])

        var piiPayload = resolved.pii
        piiPayload.merge(scopeResolved.pii) { _, new in new }
        piiPayload.merge(scopePII.mapValues { $0.representation(includeHash: configuration.piiBehavior.captureHashes) }) { _, new in new }
        piiPayload.merge(pii.mapValues { $0.representation(includeHash: configuration.piiBehavior.captureHashes) }) { _, new in new }

        let entry = LogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message(),
            metadata: resolved.values,
            pii: piiPayload,
            scope: scopeResolved.values,
            source: source,
            threadID: Thread.current.loggingThreadID,
            sequence: sequence
        )

        pipeline.submit(entry)
    }

    func scoped(
        metadata: LogMetadataFields = [:],
        pii: [String: PIIValue] = [:]
    ) -> Logger {
        DefaultLogger(
            configuration: configuration,
            pipeline: pipeline,
            scopeMetadata: scopeMetadata.merging(metadata) { _, new in new },
            scopePII: scopePII.merging(pii) { _, new in new },
            sequenceGenerator: sequenceGenerator,
            dateProvider: dateProvider
        )
    }

    func flush() async {
        await pipeline.flush()
    }

    private func shouldLog(level: LogLevel, category: LogCategory) -> Bool {
        let threshold = configuration.categoryLevels[category] ?? configuration.defaultLevel
        return level >= threshold
    }

    private func resolveMetadataLayers(_ layers: [LogMetadataFields]) -> (values: [String: LogValue], pii: [String: LogPIIRepresentation]) {
        var values: [String: LogValue] = [:]
        var pii: [String: LogPIIRepresentation] = [:]

        for layer in layers {
            for (key, field) in layer {
                switch field {
                case let .value(value):
                    values[key] = value
                case let .pii(piiValue):
                    values[key] = .string(piiValue.redacted)
                    pii[key] = piiValue.representation(includeHash: configuration.piiBehavior.captureHashes)
                }
            }
        }

        return (values, pii)
    }
}

// MARK: - Pipeline

struct LogPipeline {
    private let worker: Worker

    init(destinations: [LogDestination]) {
        self.worker = Worker(destinations: destinations)
    }

    func submit(_ entry: LogEntry) {
        Task(priority: .utility) {
            await worker.enqueue(entry)
        }
    }

    func flush() async {
        await worker.flush()
    }

    private actor Worker {
        private let destinations: [LogDestination]
        private var pending: [UInt64: LogEntry] = [:]
        private var nextSequence: UInt64 = 0

        init(destinations: [LogDestination]) {
            self.destinations = destinations
        }

        func enqueue(_ entry: LogEntry) async {
            pending[entry.sequence] = entry
            await drain()
        }

        private func drain() async {
            while let entry = pending.removeValue(forKey: nextSequence) {
                for destination in destinations {
                    await destination.write(entry)
                }
                nextSequence &+= 1
            }
        }

        func flush() async {
            await drain()
            for destination in destinations {
                await destination.flush()
            }
        }
    }
}

// MARK: - Sequence Generator

struct LogSequenceGenerator {
    private let lock = OSAllocatedUnfairLock<UInt64>(initialState: 0)

    func next() -> UInt64 {
        lock.withLock { value in
            defer { value &+= 1 }
            return value
        }
    }
}

// MARK: - Bootstrap

struct LoggingContainer {
    let logger: Logger
    let history: LogHistoryProviding
}

enum LoggingSystem {
    static func bootstrap(environment: AppEnvironment) -> LoggingContainer {
        let configuration = environment.loggingConfiguration
        let inMemory = InMemoryLogDestination(limit: configuration.destinations.inMemoryEntryLimit)
        var destinations: [LogDestination] = [inMemory]

        if configuration.destinations.console.isEnabled {
            let console = ConsoleLogDestination(
                subsystem: environment.bundleIdentifier,
                showIcon: configuration.destinations.console.showIcon
            )
            destinations.append(console)
        }

        if configuration.destinations.file.isEnabled {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let file = FileLogDestination(baseDirectory: directory, config: configuration.destinations.file)
            destinations.append(file)
        }

        let pipeline = LogPipeline(destinations: destinations)
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: configuration,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        return LoggingContainer(logger: logger, history: inMemory)
    }
}
