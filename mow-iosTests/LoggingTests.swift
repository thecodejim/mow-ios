import Testing
import Foundation
@testable import mow_ios

// MARK: - Test Mocks

actor TestLogDestination: LogDestination {
    private(set) var writtenEntries: [LogEntry] = []
    private(set) var flushCallCount = 0
    
    func write(_ entry: LogEntry) async {
        writtenEntries.append(entry)
    }
    
    func flush() async {
        flushCallCount += 1
    }
    
    func reset() {
        writtenEntries = []
        flushCallCount = 0
    }
}

// MARK: - LogLevel Tests

@Suite("LogLevel Tests")
@MainActor
struct LogLevelTests {
    
    @Test("LogLevel comparison works correctly")
    func logLevelComparisonWorksCorrectly() {
        // Given: Different log levels
        let trace = LogLevel.trace
        let debug = LogLevel.debug
        let info = LogLevel.info
        let warning = LogLevel.warning
        let error = LogLevel.error
        let critical = LogLevel.critical
        
        // When: We compare levels
        // Then: Lower severity levels are less than higher severity levels
        #expect(trace < debug)
        #expect(debug < info)
        #expect(info < warning)
        #expect(warning < error)
        #expect(error < critical)
    }
    
    @Test("LogLevel labels are correct")
    func logLevelLabelsAreCorrect() {
        // Given: All log levels
        // When: We check their labels
        // Then: Labels match expected values
        #expect(LogLevel.trace.label == "TRACE")
        #expect(LogLevel.debug.label == "DEBUG")
        #expect(LogLevel.info.label == "INFO")
        #expect(LogLevel.warning.label == "WARN")
        #expect(LogLevel.error.label == "ERROR")
        #expect(LogLevel.critical.label == "CRITICAL")
    }
    
    @Test("LogLevel icons are defined")
    func logLevelIconsAreDefined() {
        // Given: All log levels
        // When: We check their icons
        // Then: Each level has a unique icon
        #expect(LogLevel.trace.icon == "⚪️")
        #expect(LogLevel.debug.icon == "🔵")
        #expect(LogLevel.info.icon == "🟢")
        #expect(LogLevel.warning.icon == "🟡")
        #expect(LogLevel.error.icon == "🟠")
        #expect(LogLevel.critical.icon == "🔴")
    }
    
    @Test("LogLevel raw values are correct")
    func logLevelRawValuesAreCorrect() {
        // Given: All log levels
        // When: We check their raw values
        // Then: Raw values are correctly spaced for filtering
        #expect(LogLevel.trace.rawValue == 0)
        #expect(LogLevel.debug.rawValue == 10)
        #expect(LogLevel.info.rawValue == 20)
        #expect(LogLevel.warning.rawValue == 30)
        #expect(LogLevel.error.rawValue == 40)
        #expect(LogLevel.critical.rawValue == 50)
    }
}

// MARK: - LogCategory Tests

@Suite("LogCategory Tests")
@MainActor
struct LogCategoryTests {
    
    @Test("LogCategory can be created from string")
    func logCategoryCanBeCreatedFromString() {
        // Given: A string value
        let categoryString = "custom-category"
        
        // When: We create a category
        let category = LogCategory(categoryString)
        
        // Then: Category has the correct raw value
        #expect(category.rawValue == categoryString)
    }
    
    @Test("LogCategory can be created from string literal")
    func logCategoryCanBeCreatedFromStringLiteral() {
        // Given: String literal
        // When: We create a category using string literal
        let category: LogCategory = "test-category"
        
        // Then: Category has the correct raw value
        #expect(category.rawValue == "test-category")
    }
    
    @Test("Default categories are defined")
    func defaultCategoriesAreDefined() {
        // Given: Default categories
        // When: We check their values
        // Then: All default categories have correct raw values
        #expect(LogCategory.app.rawValue == "app")
        #expect(LogCategory.ui.rawValue == "ui")
        #expect(LogCategory.network.rawValue == "network")
        #expect(LogCategory.database.rawValue == "database")
        #expect(LogCategory.auth.rawValue == "auth")
        #expect(LogCategory.businessLogic.rawValue == "business-logic")
        #expect(LogCategory.storage.rawValue == "storage")
        #expect(LogCategory.analytics.rawValue == "analytics")
        #expect(LogCategory.coordinator.rawValue == "coordinator")
    }
    
    @Test("LogCategory is hashable")
    func logCategoryIsHashable() {
        // Given: Two categories with same raw value
        let category1 = LogCategory("test")
        let category2 = LogCategory("test")
        
        // When: We compare them
        // Then: They are equal
        #expect(category1 == category2)
        
        // And: Can be used in dictionaries
        let dict: [LogCategory: String] = [category1: "value"]
        #expect(dict[category2] == "value")
    }
}

// MARK: - LogValue Tests

@Suite("LogValue Tests")
@MainActor
struct LogValueTests {
    
    @Test("LogValue string encodes and decodes correctly")
    func logValueStringEncodesAndDecodesCorrectly() throws {
        // Given: A string log value
        let value = LogValue.string("test string")
        
        // When: We encode and decode it
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(LogValue.self, from: encoded)
        
        // Then: Decoded value matches original
        if case .string(let str) = decoded {
            #expect(str == "test string")
        } else {
            Issue.record("Expected string value")
        }
    }
    
    @Test("LogValue int encodes and decodes correctly")
    func logValueIntEncodesAndDecodesCorrectly() throws {
        // Given: An int log value
        let value = LogValue.int(42)
        
        // When: We encode and decode it
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(LogValue.self, from: encoded)
        
        // Then: Decoded value matches original
        if case .int(let num) = decoded {
            #expect(num == 42)
        } else {
            Issue.record("Expected int value")
        }
    }
    
    @Test("LogValue double encodes and decodes correctly")
    func logValueDoubleEncodesAndDecodesCorrectly() throws {
        // Given: A double log value
        let value = LogValue.double(3.14)
        
        // When: We encode and decode it
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(LogValue.self, from: encoded)
        
        // Then: Decoded value matches original
        if case .double(let num) = decoded {
            #expect(num == 3.14)
        } else {
            Issue.record("Expected double value")
        }
    }
    
    @Test("LogValue bool encodes and decodes correctly")
    func logValueBoolEncodesAndDecodesCorrectly() throws {
        // Given: A bool log value
        let value = LogValue.bool(true)
        
        // When: We encode and decode it
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(LogValue.self, from: encoded)
        
        // Then: Decoded value matches original
        if case .bool(let flag) = decoded {
            #expect(flag == true)
        } else {
            Issue.record("Expected bool value")
        }
    }
    
    @Test("LogValue array encodes and decodes correctly")
    func logValueArrayEncodesAndDecodesCorrectly() throws {
        // Given: An array log value
        let value = LogValue.array([.string("one"), .int(2), .bool(true)])
        
        // When: We encode and decode it
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(LogValue.self, from: encoded)
        
        // Then: Decoded value matches original
        if case .array(let arr) = decoded {
            #expect(arr.count == 3)
        } else {
            Issue.record("Expected array value")
        }
    }
    
    @Test("LogValue dictionary encodes and decodes correctly")
    func logValueDictionaryEncodesAndDecodesCorrectly() throws {
        // Given: A dictionary log value
        let value = LogValue.dictionary([
            "key1": .string("value1"),
            "key2": .int(42)
        ])
        
        // When: We encode and decode it
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(LogValue.self, from: encoded)
        
        // Then: Decoded value matches original
        if case .dictionary(let dict) = decoded {
            #expect(dict.count == 2)
            #expect(dict["key1"] != nil)
            #expect(dict["key2"] != nil)
        } else {
            Issue.record("Expected dictionary value")
        }
    }
    
    @Test("LogValue null encodes and decodes correctly")
    func logValueNullEncodesAndDecodesCorrectly() throws {
        // Given: A null log value
        let value = LogValue.null
        
        // When: We encode and decode it
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(LogValue.self, from: encoded)
        
        // Then: Decoded value is null
        if case .null = decoded {
            #expect(true)
        } else {
            Issue.record("Expected null value")
        }
    }
    
    @Test("LogValue readable description formats correctly")
    func logValueReadableDescriptionFormatsCorrectly() {
        // Given: Different log values
        let string = LogValue.string("test")
        let int = LogValue.int(42)
        let double = LogValue.double(3.14)
        let bool = LogValue.bool(true)
        let array = LogValue.array([.string("a"), .int(1)])
        let dict = LogValue.dictionary(["key": .string("value")])
        let null = LogValue.null
        
        // When: We get readable descriptions
        // Then: Descriptions are formatted correctly
        #expect(string.readableDescription == "test")
        #expect(int.readableDescription == "42")
        #expect(double.readableDescription == "3.14")
        #expect(bool.readableDescription == "true")
        #expect(array.readableDescription.contains("a"))
        #expect(dict.readableDescription.contains("key"))
        #expect(null.readableDescription == "null")
    }
}

// MARK: - LogValueConvertible Tests

@Suite("LogValueConvertible Tests")
@MainActor
struct LogValueConvertibleTests {
    
    @Test("String converts to LogValue")
    func stringConvertsToLogValue() {
        // Given: A string
        let value = "test"
        
        // When: We convert it to LogValue
        let logValue = value.asLogValue()
        
        // Then: It's a string LogValue
        if case .string(let str) = logValue {
            #expect(str == "test")
        } else {
            Issue.record("Expected string LogValue")
        }
    }
    
    @Test("Int converts to LogValue")
    func intConvertsToLogValue() {
        // Given: An int
        let value = 42
        
        // When: We convert it to LogValue
        let logValue = value.asLogValue()
        
        // Then: It's an int LogValue
        if case .int(let num) = logValue {
            #expect(num == 42)
        } else {
            Issue.record("Expected int LogValue")
        }
    }
    
    @Test("Double converts to LogValue")
    func doubleConvertsToLogValue() {
        // Given: A double
        let value = 3.14
        
        // When: We convert it to LogValue
        let logValue = value.asLogValue()
        
        // Then: It's a double LogValue
        if case .double(let num) = logValue {
            #expect(num == 3.14)
        } else {
            Issue.record("Expected double LogValue")
        }
    }
    
    @Test("Bool converts to LogValue")
    func boolConvertsToLogValue() {
        // Given: A bool
        let value = true
        
        // When: We convert it to LogValue
        let logValue = value.asLogValue()
        
        // Then: It's a bool LogValue
        if case .bool(let flag) = logValue {
            #expect(flag == true)
        } else {
            Issue.record("Expected bool LogValue")
        }
    }
    
    @Test("Date converts to LogValue as ISO8601 string")
    func dateConvertsToLogValueAsISO8601String() {
        // Given: A date
        let date = Date(timeIntervalSince1970: 1_000_000)
        
        // When: We convert it to LogValue
        let logValue = date.asLogValue()
        
        // Then: It's a string LogValue with ISO8601 format
        if case .string(let str) = logValue {
            #expect(str.contains("1970"))
        } else {
            Issue.record("Expected string LogValue")
        }
    }
    
    @Test("Array converts to LogValue")
    func arrayConvertsToLogValue() {
        // Given: An array of convertibles
        let value = [1, 2, 3]
        
        // When: We convert it to LogValue
        let logValue = value.asLogValue()
        
        // Then: It's an array LogValue
        if case .array(let arr) = logValue {
            #expect(arr.count == 3)
        } else {
            Issue.record("Expected array LogValue")
        }
    }
    
    @Test("Dictionary converts to LogValue")
    func dictionaryConvertsToLogValue() {
        // Given: A dictionary of convertibles
        let value = ["key": "value"]
        
        // When: We convert it to LogValue
        let logValue = value.asLogValue()
        
        // Then: It's a dictionary LogValue
        if case .dictionary(let dict) = logValue {
            #expect(dict.count == 1)
        } else {
            Issue.record("Expected dictionary LogValue")
        }
    }
}

// MARK: - PIIValue Tests

@Suite("PIIValue Tests")
@MainActor
struct PIIValueTests {
    
    @Test("PIIValue email is masked correctly")
    func piiValueEmailIsMaskedCorrectly() {
        // Given: An email PII value
        let pii = PIIValue.email("user@example.com")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: Email is masked showing only first char and domain
        #expect(redacted.hasPrefix("u"))
        #expect(redacted.contains("@example.com"))
        #expect(redacted.contains("•"))
    }
    
    @Test("PIIValue phone is masked correctly")
    func piiValuePhoneIsMaskedCorrectly() {
        // Given: A phone PII value
        let pii = PIIValue.phone("555-123-4567")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: Phone is masked showing only last 4 digits
        #expect(redacted.hasSuffix("4567"))
        #expect(redacted.contains("•"))
    }
    
    @Test("PIIValue name is masked correctly")
    func piiValueNameIsMaskedCorrectly() {
        // Given: A name PII value
        let pii = PIIValue.name("John Doe")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: Name is masked showing only first char
        #expect(redacted.hasPrefix("J"))
        #expect(redacted.contains("•"))
    }
    
    @Test("PIIValue token is masked correctly")
    func piiValueTokenIsMaskedCorrectly() {
        // Given: A token PII value
        let pii = PIIValue.token("abcd1234efgh5678")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: Token is masked showing first 4 and last 4 chars
        #expect(redacted.hasPrefix("abcd"))
        #expect(redacted.hasSuffix("5678"))
        #expect(redacted.contains("•"))
    }
    
    @Test("PIIValue raw is masked generically")
    func piiValueRawIsMaskedGenerically() {
        // Given: A raw PII value
        let pii = PIIValue.raw("sensitive data")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: Value is masked generically
        #expect(redacted.contains("•"))
    }
    
    @Test("PIIValue short email is not over-masked")
    func piiValueShortEmailIsNotOverMasked() {
        // Given: A single-char email
        let pii = PIIValue.email("a@example.com")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: Email shows the single char
        #expect(redacted == "a@example.com")
    }
    
    @Test("PIIValue short phone is fully masked")
    func piiValueShortPhoneIsFullyMasked() {
        // Given: A short phone number
        let pii = PIIValue.phone("123")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: All digits are masked
        #expect(redacted == "•••")
    }
    
    @Test("PIIValue single char name is not masked")
    func piiValueSingleCharNameIsNotMasked() {
        // Given: A single-char name
        let pii = PIIValue.name("H")
        
        // When: We get the redacted value
        let redacted = pii.redacted
        
        // Then: Name is shown
        #expect(redacted == "H")
    }
    
    @Test("PIIValue representation includes hash when requested")
    func piiValueRepresentationIncludesHashWhenRequested() {
        // Given: A PII value
        let pii = PIIValue.email("user@example.com")
        
        // When: We get representation with hash
        let representation = pii.representation(includeHash: true)
        
        // Then: Hash is included
        #expect(representation.hash != nil)
        #expect(representation.hash?.isEmpty == false)
        
        // And: Redacted value is present
        #expect(representation.redacted == pii.redacted)
        
        // And: Kind is correct
        #expect(representation.kind == .email)
    }
    
    @Test("PIIValue representation excludes hash when not requested")
    func piiValueRepresentationExcludesHashWhenNotRequested() {
        // Given: A PII value
        let pii = PIIValue.email("user@example.com")
        
        // When: We get representation without hash
        let representation = pii.representation(includeHash: false)
        
        // Then: Hash is not included
        #expect(representation.hash == nil)
    }
    
    @Test("PIIValue hash is consistent for same value")
    func piiValueHashIsConsistentForSameValue() {
        // Given: Two identical PII values
        let pii1 = PIIValue.email("test@example.com")
        let pii2 = PIIValue.email("test@example.com")
        
        // When: We get their hashes
        let hash1 = pii1.representation(includeHash: true).hash
        let hash2 = pii2.representation(includeHash: true).hash
        
        // Then: Hashes are identical
        #expect(hash1 == hash2)
    }
    
    @Test("PIIValue hash differs for different values")
    func piiValueHashDiffersForDifferentValues() {
        // Given: Two different PII values
        let pii1 = PIIValue.email("user1@example.com")
        let pii2 = PIIValue.email("user2@example.com")
        
        // When: We get their hashes
        let hash1 = pii1.representation(includeHash: true).hash
        let hash2 = pii2.representation(includeHash: true).hash
        
        // Then: Hashes are different
        #expect(hash1 != hash2)
    }
}

// MARK: - LogSequenceGenerator Tests

@Suite("LogSequenceGenerator Tests")
@MainActor
struct LogSequenceGeneratorTests {
    
    @Test("LogSequenceGenerator starts at zero")
    func logSequenceGeneratorStartsAtZero() {
        // Given: A new sequence generator
        let generator = LogSequenceGenerator()
        
        // When: We get the first sequence
        let sequence = generator.next()
        
        // Then: It's zero
        #expect(sequence == 0)
    }
    
    @Test("LogSequenceGenerator increments")
    func logSequenceGeneratorIncrements() {
        // Given: A sequence generator
        let generator = LogSequenceGenerator()
        
        // When: We get multiple sequences
        let seq1 = generator.next()
        let seq2 = generator.next()
        let seq3 = generator.next()
        
        // Then: They increment by 1
        #expect(seq1 == 0)
        #expect(seq2 == 1)
        #expect(seq3 == 2)
    }
    
    @Test("LogSequenceGenerator is thread-safe")
    func logSequenceGeneratorIsThreadSafe() async {
        // Given: A sequence generator
        let generator = LogSequenceGenerator()
        
        // When: We generate sequences concurrently
        await withTaskGroup(of: UInt64.self) { group in
            for _ in 0..<100 {
                group.addTask { @MainActor in
                    generator.next()
                }
            }
            
            var sequences: [UInt64] = []
            for await seq in group {
                sequences.append(seq)
            }
            
            // Then: All sequences are unique
            let uniqueSequences = Set(sequences)
            #expect(uniqueSequences.count == 100)
        }
    }
}

// MARK: - DefaultLogger Tests

@Suite("DefaultLogger Tests")
@MainActor
struct DefaultLoggerTests {
    
    @Test("DefaultLogger filters logs below threshold")
    func defaultLoggerFiltersLogsBelowThreshold() async {
        // Given: Logger with info threshold and a test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .info,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log debug message (below threshold)
        logger.debug("Debug message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Message is not logged
        let entries = await destination.writtenEntries
        #expect(entries.isEmpty)
    }
    
    @Test("DefaultLogger logs at or above threshold")
    func defaultLoggerLogsAtOrAboveThreshold() async {
        // Given: Logger with info threshold and a test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .info,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log info message (at threshold)
        logger.info("Info message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Message is logged
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Info message")
        #expect(entries.first?.level == .info)
    }
    
    @Test("DefaultLogger respects category-specific thresholds")
    func defaultLoggerRespectsCategorySpecificThresholds() async {
        // Given: Logger with default info threshold but network at debug
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .info,
            categoryLevels: [.network: .debug],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log debug for network category
        logger.debug("Network debug", category: .network)
        
        // And: We log debug for app category
        logger.debug("App debug", category: .app)
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Only network debug is logged
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Network debug")
        #expect(entries.first?.category == .network)
    }
    
    @Test("DefaultLogger uses custom date provider")
    func defaultLoggerUsesCustomDateProvider() async {
        // Given: Logger with custom date provider
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence,
            dateProvider: { fixedDate }
        )
        
        // When: We log a message
        logger.info("Test message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Log entry uses custom date
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.timestamp == fixedDate)
    }
    
    @Test("DefaultLogger applies server time offset")
    func defaultLoggerAppliesServerTimeOffset() async {
        // Given: Logger with server time offset
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 3600 // 1 hour
        )
        let sequence = LogSequenceGenerator()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence,
            dateProvider: { baseDate }
        )
        
        // When: We log a message
        logger.info("Test message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Log entry has offset applied
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.timestamp == baseDate.addingTimeInterval(3600))
    }
    
    @Test("DefaultLogger merges global metadata")
    func defaultLoggerMergesGlobalMetadata() async {
        // Given: Logger with global metadata
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: ["globalKey": .public("globalValue")],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log a message
        logger.info("Test message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Entry includes global metadata
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.metadata["globalKey"] != nil)
    }
    
    @Test("DefaultLogger creates scoped logger with metadata")
    func defaultLoggerCreatesScopedLoggerWithMetadata() async {
        // Given: Logger with scope
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We create a scoped logger
        let scoped = logger.scoped(metadata: ["scopeKey": .public("scopeValue")])
        
        // And: Log with scoped logger
        scoped.info("Scoped message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Entry includes scope metadata
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.scope["scopeKey"] != nil)
    }
    
    @Test("DefaultLogger scoped logger merges parent and child metadata")
    func defaultLoggerScopedLoggerMergesParentAndChildMetadata() async {
        // Given: Logger with nested scopes
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We create nested scopes
        let scope1 = logger.scoped(metadata: ["key1": .public("value1")], pii: [:])
        let scope2 = scope1.scoped(metadata: ["key2": .public("value2")], pii: [:])
        
        // And: Log with nested scope
        scope2.info("Nested scope message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Entry includes both scope metadata
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.scope["key1"] != nil)
        #expect(entries.first?.scope["key2"] != nil)
    }
    
    @Test("DefaultLogger scoped logger child metadata overrides parent")
    func defaultLoggerScopedLoggerChildMetadataOverridesParent() async {
        // Given: Logger with overlapping scope keys
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We create scopes with same key
        let scope1 = logger.scoped(metadata: ["key": .public("parent")], pii: [:])
        let scope2 = scope1.scoped(metadata: ["key": .public("child")], pii: [:])
        
        // And: Log with nested scope
        scope2.info("Override message")
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Child value overrides parent
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        if case .string(let value) = entries.first?.scope["key"] {
            #expect(value == "child")
        } else {
            Issue.record("Expected string value")
        }
    }
    
    @Test("DefaultLogger handles PII in metadata")
    func defaultLoggerHandlesPIIInMetadata() async {
        // Given: Logger with PII capture disabled
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log with PII metadata
        logger.info("Test", metadata: ["email": .sensitive(.email("user@example.com"))])
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Metadata contains redacted value
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        if case .string(let value) = entries.first?.metadata["email"] {
            #expect(value.contains("•"))
        } else {
            Issue.record("Expected redacted string value")
        }
        
        // And: PII payload exists
        #expect(entries.first?.pii["email"] != nil)
    }
    
    @Test("DefaultLogger includes hash when PII capture enabled")
    func defaultLoggerIncludesHashWhenPIICaptureEnabled() async {
        // Given: Logger with PII capture enabled
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: true),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log with PII metadata
        logger.info("Test", metadata: ["email": .sensitive(.email("user@example.com"))])
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: PII representation includes hash
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.pii["email"]?.hash != nil)
    }
    
    @Test("DefaultLogger withScope helper executes block")
    func defaultLoggerWithScopeHelperExecutesBlock() {
        // Given: Logger
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use withScope helper
        let result = logger.withScope(metadata: ["key": .public("value")]) { scopedLogger in
            return "result"
        }
        
        // Then: Block is executed and returns value
        #expect(result == "result")
    }
    
    @Test("DefaultLogger error extension adds error to metadata")
    func defaultLoggerErrorExtensionAddsErrorToMetadata() async {
        // Given: Logger
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log with error
        struct TestError: Error {}
        logger.error("Error occurred", error: TestError())
        
        // And: Wait for pipeline to process
        await logger.flush()
        
        // Then: Metadata includes error
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.metadata["error"] != nil)
    }
}

// MARK: - LogPipeline Tests

@Suite("LogPipeline Tests")
@MainActor
struct LogPipelineTests {
    
    @Test("LogPipeline submits entries to destinations")
    func logPipelineSubmitsEntriesToDestinations() async {
        // Given: Pipeline with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        
        // When: We submit an entry
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "Test",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 0
        )
        pipeline.submit(entry)
        
        // And: Wait for processing
        await pipeline.flush()
        
        // Then: Entry is written to destination
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Test")
    }
    
    @Test("LogPipeline maintains entry order")
    func logPipelineMaintainsEntryOrder() async {
        // Given: Pipeline with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        
        // When: We submit entries in order
        for i in 0..<10 {
            let entry = LogEntry(
                timestamp: Date(),
                level: .info,
                category: .app,
                message: "Message \(i)",
                metadata: [:],
                pii: [:],
                scope: [:],
                source: .current(),
                sequence: UInt64(i)
            )
            pipeline.submit(entry)
        }
        
        // And: Wait for processing
        await pipeline.flush()
        
        // Then: Entries are in correct order
        let entries = await destination.writtenEntries
        #expect(entries.count == 10)
        for i in 0..<10 {
            #expect(entries[i].sequence == UInt64(i))
        }
    }
    
    @Test("LogPipeline handles out-of-order submissions")
    func logPipelineHandlesOutOfOrderSubmissions() async {
        // Given: Pipeline with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        
        // When: We submit entries out of order
        let entry2 = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "Second",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 1
        )
        let entry1 = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "First",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 0
        )
        
        pipeline.submit(entry2)
        pipeline.submit(entry1)
        
        // And: Wait for processing
        await pipeline.flush()
        
        // Then: Entries are written in correct order
        let entries = await destination.writtenEntries
        #expect(entries.count == 2)
        #expect(entries[0].message == "First")
        #expect(entries[1].message == "Second")
    }
    
    @Test("LogPipeline writes to multiple destinations")
    func logPipelineWritesToMultipleDestinations() async {
        // Given: Pipeline with multiple destinations
        let destination1 = TestLogDestination()
        let destination2 = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination1, destination2])
        
        // When: We submit an entry
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "Test",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 0
        )
        pipeline.submit(entry)
        
        // And: Wait for processing
        await pipeline.flush()
        
        // Then: Entry is written to all destinations
        let entries1 = await destination1.writtenEntries
        let entries2 = await destination2.writtenEntries
        #expect(entries1.count == 1)
        #expect(entries2.count == 1)
    }
    
    @Test("LogPipeline flush calls destination flush")
    func logPipelineFlushCallsDestinationFlush() async {
        // Given: Pipeline with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        
        // When: We flush pipeline
        await pipeline.flush()
        
        // Then: Destination flush is called
        let flushCount = await destination.flushCallCount
        #expect(flushCount == 1)
    }
}

// MARK: - InMemoryLogDestination Tests

@Suite("InMemoryLogDestination Tests")
@MainActor
struct InMemoryLogDestinationTests {
    
    @Test("InMemoryLogDestination stores entries")
    func inMemoryLogDestinationStoresEntries() async {
        // Given: In-memory destination with limit
        let destination = InMemoryLogDestination(limit: 100)
        
        // When: We write an entry
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "Test",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 0
        )
        await destination.write(entry)
        
        // Then: Entry is stored
        let snapshot = await destination.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot.first?.message == "Test")
    }
    
    @Test("InMemoryLogDestination enforces limit")
    func inMemoryLogDestinationEnforcesLimit() async {
        // Given: In-memory destination with small limit
        let destination = InMemoryLogDestination(limit: 5)
        
        // When: We write more entries than limit
        for i in 0..<10 {
            let entry = LogEntry(
                timestamp: Date(),
                level: .info,
                category: .app,
                message: "Message \(i)",
                metadata: [:],
                pii: [:],
                scope: [:],
                source: .current(),
                sequence: UInt64(i)
            )
            await destination.write(entry)
        }
        
        // Then: Only last 5 entries are kept
        let snapshot = await destination.snapshot()
        #expect(snapshot.count == 5)
        #expect(snapshot.first?.message == "Message 5")
        #expect(snapshot.last?.message == "Message 9")
    }
    
    @Test("InMemoryLogDestination snapshot respects custom limit")
    func inMemoryLogDestinationSnapshotRespectsCustomLimit() async {
        // Given: In-memory destination with entries
        let destination = InMemoryLogDestination(limit: 100)
        for i in 0..<20 {
            let entry = LogEntry(
                timestamp: Date(),
                level: .info,
                category: .app,
                message: "Message \(i)",
                metadata: [:],
                pii: [:],
                scope: [:],
                source: .current(),
                sequence: UInt64(i)
            )
            await destination.write(entry)
        }
        
        // When: We get snapshot with custom limit
        let snapshot = await destination.snapshot(limit: 5)
        
        // Then: Only last 5 entries are returned
        #expect(snapshot.count == 5)
        #expect(snapshot.first?.message == "Message 15")
        #expect(snapshot.last?.message == "Message 19")
    }
    
    @Test("InMemoryLogDestination stream yields current entries")
    func inMemoryLogDestinationStreamYieldsCurrentEntries() async {
        // Given: In-memory destination with entries
        let destination = InMemoryLogDestination(limit: 100)
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "Test",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 0
        )
        await destination.write(entry)
        
        // When: We create a stream
        let stream = await destination.stream()
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        
        // Then: Stream yields current entries
        #expect(first?.count == 1)
        #expect(first?.first?.message == "Test")
    }
    
    @Test("InMemoryLogDestination stream yields new entries")
    func inMemoryLogDestinationStreamYieldsNewEntries() async {
        // Given: In-memory destination with stream
        let destination = InMemoryLogDestination(limit: 100)
        let stream = await destination.stream()
        
        // When: We write a new entry after creating stream
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "New entry",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 0
        )
        await destination.write(entry)
        
        // Then: Stream should yield the new entries
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // Skip initial empty
        let second = await iterator.next()
        #expect(second?.count == 1)
        #expect(second?.first?.message == "New entry")
    }
    
    @Test("InMemoryLogDestination exportArchive creates file")
    func inMemoryLogDestinationExportArchiveCreatesFile() async throws {
        // Given: In-memory destination with entries
        let destination = InMemoryLogDestination(limit: 100)
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .app,
            message: "Test",
            metadata: [:],
            pii: [:],
            scope: [:],
            source: .current(),
            sequence: 0
        )
        await destination.write(entry)
        
        // When: We export archive
        let url = try await destination.exportArchive()
        
        // Then: File exists
        #expect(FileManager.default.fileExists(atPath: url.path))
        
        // And: File contains JSON data
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([LogEntry].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded.first?.message == "Test")
        
        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Logger Convenience Methods Tests

@Suite("Logger Convenience Methods Tests")
@MainActor
struct LoggerConvenienceMethodsTests {
    
    @Test("Logger debug convenience method works")
    func loggerDebugConvenienceMethodWorks() async {
        // Given: Logger with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use debug convenience method
        logger.debug("Debug message")
        await logger.flush()
        
        // Then: Entry is logged with debug level
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.level == .debug)
        #expect(entries.first?.message == "Debug message")
    }
    
    @Test("Logger info convenience method works")
    func loggerInfoConvenienceMethodWorks() async {
        // Given: Logger with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use info convenience method
        logger.info("Info message")
        await logger.flush()
        
        // Then: Entry is logged with info level
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.level == .info)
    }
    
    @Test("Logger warning convenience method works")
    func loggerWarningConvenienceMethodWorks() async {
        // Given: Logger with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use warning convenience method
        logger.warning("Warning message")
        await logger.flush()
        
        // Then: Entry is logged with warning level
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.level == .warning)
    }
    
    @Test("Logger error convenience method works")
    func loggerErrorConvenienceMethodWorks() async {
        // Given: Logger with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use error convenience method
        logger.error("Error message")
        await logger.flush()
        
        // Then: Entry is logged with error level
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.level == .error)
    }
    
    @Test("Logger critical convenience method works")
    func loggerCriticalConvenienceMethodWorks() async {
        // Given: Logger with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use critical convenience method
        logger.critical("Critical message")
        await logger.flush()
        
        // Then: Entry is logged with critical level
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.level == .critical)
    }
    
    @Test("Logger convenience methods accept custom category")
    func loggerConvenienceMethodsAcceptCustomCategory() async {
        // Given: Logger with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use convenience method with custom category
        logger.info("Test", category: .network)
        await logger.flush()
        
        // Then: Entry has custom category
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.category == .network)
    }
    
    @Test("Logger convenience methods accept metadata and pii")
    func loggerConvenienceMethodsAcceptMetadataAndPii() async {
        // Given: Logger with test destination
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We use convenience method with metadata and pii
        logger.info(
            "Test",
            metadata: ["key": .public("value")],
            pii: ["email": .email("user@example.com")]
        )
        await logger.flush()
        
        // Then: Entry has metadata and pii
        let entries = await destination.writtenEntries
        #expect(entries.count == 1)
        #expect(entries.first?.metadata["key"] != nil)
        #expect(entries.first?.pii["email"] != nil)
    }
}

// MARK: - Integration Tests

@Suite("Logging Integration Tests")
@MainActor
struct LoggingIntegrationTests {
    
    @Test("Full logging flow from logger to destination")
    func fullLoggingFlowFromLoggerToDestination() async {
        // Given: Complete logging setup
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [.network: .info],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: ["appVersion": .public("1.0.0")],
            piiBehavior: .init(captureHashes: true),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence,
            dateProvider: { fixedDate }
        )
        
        // When: We log with various features
        logger.info(
            "User action",
            category: .ui,
            metadata: ["action": .public("button_tap"), "count": .public(1)],
            pii: ["userId": .raw("user123")]
        )
        
        logger.debug("Network debug", category: .network) // Should be filtered
        
        let scoped = logger.scoped(metadata: ["screen": .public("home")])
        scoped.warning("Low memory warning")
        
        // And: Wait for processing
        await logger.flush()
        
        // Then: Correct entries are logged with all features
        let entries = await destination.writtenEntries
        #expect(entries.count == 2) // debug filtered out
        
        // And: First entry has all expected data
        let firstEntry = entries[0]
        #expect(firstEntry.message == "User action")
        #expect(firstEntry.level == .info)
        #expect(firstEntry.category == .ui)
        #expect(firstEntry.metadata["action"] != nil)
        #expect(firstEntry.metadata["appVersion"] != nil) // global metadata
        #expect(firstEntry.pii["userId"] != nil)
        #expect(firstEntry.pii["userId"]?.hash != nil) // hash enabled
        #expect(firstEntry.timestamp == fixedDate)
        #expect(firstEntry.sequence == 0)
        
        // And: Second entry has scope
        let secondEntry = entries[1]
        #expect(secondEntry.message == "Low memory warning")
        #expect(secondEntry.scope["screen"] != nil)
        #expect(secondEntry.sequence == 1)
    }
    
    @Test("Concurrent logging maintains order and uniqueness")
    func concurrentLoggingMaintainsOrderAndUniqueness() async {
        // Given: Logging setup
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        // When: We log concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask { @MainActor in
                    logger.info("Message \(i)")
                }
            }
        }
        
        // And: Wait for processing
        await logger.flush()
        
        // Then: All messages are logged
        let entries = await destination.writtenEntries
        #expect(entries.count == 50)
        
        // And: All sequence numbers are unique
        let sequences = entries.map { $0.sequence }
        let uniqueSequences = Set(sequences)
        #expect(uniqueSequences.count == 50)
        
        // And: Sequences are in order (pipeline maintains order)
        let sortedSequences = sequences.sorted()
        #expect(sequences == sortedSequences)
    }
    
    @Test("Multiple scoped loggers with different contexts")
    func multipleScopedLoggersWithDifferentContexts() async {
        // Given: Base logger with multiple scopes
        let destination = TestLogDestination()
        let pipeline = LogPipeline(destinations: [destination])
        let config = LoggingConfiguration(
            defaultLevel: .debug,
            categoryLevels: [:],
            destinations: .init(
                console: .init(isEnabled: false, showIcon: false),
                file: .init(isEnabled: false, maxFileBytes: 0, maxFiles: 0, directoryName: ""),
                inMemoryEntryLimit: 100
            ),
            globalMetadata: [:],
            piiBehavior: .init(captureHashes: false),
            serverTimeOffset: 0
        )
        let sequence = LogSequenceGenerator()
        let logger = DefaultLogger(
            configuration: config,
            pipeline: pipeline,
            sequenceGenerator: sequence
        )
        
        let requestScope = logger.scoped(
            metadata: ["requestId": .public("req-123")],
            pii: ["userId": .raw("user-456")]
        )
        let networkScope = requestScope.scoped(metadata: ["component": .public("network")], pii: [:])
        let dbScope = requestScope.scoped(metadata: ["component": .public("database")], pii: [:])
        
        // When: We log from different scopes
        networkScope.info("API call started")
        dbScope.info("Query executed")
        requestScope.info("Request completed")
        
        // And: Wait for processing
        await logger.flush()
        
        // Then: Each entry has correct scope context
        let entries = await destination.writtenEntries
        #expect(entries.count == 3)
        
        // And: All entries have request scope
        for entry in entries {
            #expect(entry.scope["requestId"] != nil)
            #expect(entry.pii["userId"] != nil)
        }
        
        // And: Specific entries have their component scope
        if case .string(let component) = entries[0].scope["component"] {
            #expect(component == "network")
        } else {
            Issue.record("Expected network component")
        }
        
        if case .string(let component) = entries[1].scope["component"] {
            #expect(component == "database")
        } else {
            Issue.record("Expected database component")
        }
    }
}
