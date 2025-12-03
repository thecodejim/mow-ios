import CryptoKit
import Foundation

// MARK: - Levels

enum LogLevel: Int, Comparable, Codable, CaseIterable, Sendable {
    case trace = 0
    case debug = 10
    case info = 20
    case warning = 30
    case error = 40
    case critical = 50

    var label: String {
        switch self {
        case .trace: return "TRACE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    var icon: String {
        switch self {
        case .trace: return "⚪️"
        case .debug: return "🔵"
        case .info: return "🟢"
        case .warning: return "🟡"
        case .error: return "🟠"
        case .critical: return "🔴"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Categories

struct LogCategory: RawRepresentable, Hashable, Codable, ExpressibleByStringLiteral, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }
}

extension LogCategory {
    static let app = LogCategory("app")
    static let ui = LogCategory("ui")
    static let network = LogCategory("network")
    static let database = LogCategory("database")
    static let auth = LogCategory("auth")
    static let businessLogic = LogCategory("business-logic")
    static let storage = LogCategory("storage")
    static let analytics = LogCategory("analytics")
    static let coordinator = LogCategory("coordinator")
    static let defaults: [LogCategory] = [.app, .ui, .network, .database, .auth, .businessLogic, .analytics, .storage, .coordinator]
}

extension LogCategory: Identifiable {
    var id: String { rawValue }
}

// MARK: - Log Value Encoding

enum LogValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([LogValue])
    case dictionary([String: LogValue])
    case null

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if let string = try? container.decode(String.self) {
                self = .string(string)
                return
            }
            if let int = try? container.decode(Int.self) {
                self = .int(int)
                return
            }
            if let double = try? container.decode(Double.self) {
                self = .double(double)
                return
            }
            if let bool = try? container.decode(Bool.self) {
                self = .bool(bool)
                return
            }
        }

        if var arrayContainer = try? decoder.unkeyedContainer() {
            var values: [LogValue] = []
            while !arrayContainer.isAtEnd {
                if let value = try? arrayContainer.decode(LogValue.self) {
                    values.append(value)
                } else {
                    #if DEBUG
                        print("LogValue: skipping malformed element")
                    #endif
                    arrayContainer.skip()
                }
            }
            self = .array(values)
            return
        }

        if let dictionaryContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var dictionary: [String: LogValue] = [:]
            for key in dictionaryContainer.allKeys {
                if let value = try? dictionaryContainer.decode(LogValue.self, forKey: key) {
                    dictionary[key.stringValue] = value
                }
            }
            self = .dictionary(dictionary)
            return
        }

        self = .null
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .int(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case let .dictionary(dictionary):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in dictionary {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try container.encode(value, forKey: codingKey)
            }
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

extension LogValue {
    var readableDescription: String {
        switch self {
        case let .string(value): return value
        case let .int(value): return "\(value)"
        case let .double(value): return "\(value)"
        case let .bool(value): return value ? "true" : "false"
        case let .array(values):
            return "[\(values.map { $0.readableDescription }.joined(separator: ", "))]"
        case let .dictionary(dictionary):
            let pairs = dictionary
                .map { "\($0.key): \($0.value.readableDescription)" }
                .sorted()
                .joined(separator: ", ")
            return "{\(pairs)}"
        case .null: return "null"
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - Metadata

protocol LogValueConvertible {
    func asLogValue() -> LogValue
}

extension String: LogValueConvertible {
    func asLogValue() -> LogValue { .string(self) }
}

extension Int: LogValueConvertible {
    func asLogValue() -> LogValue { .int(self) }
}

extension Double: LogValueConvertible {
    func asLogValue() -> LogValue { .double(self) }
}

extension Bool: LogValueConvertible {
    func asLogValue() -> LogValue { .bool(self) }
}

extension Date: LogValueConvertible {
    func asLogValue() -> LogValue {
        .string(Self.iso8601Formatter.string(from: self))
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension Array: LogValueConvertible where Element: LogValueConvertible {
    func asLogValue() -> LogValue {
        .array(map { $0.asLogValue() })
    }
}

extension Dictionary: LogValueConvertible where Key == String, Value: LogValueConvertible {
    func asLogValue() -> LogValue {
        .dictionary(mapValues { $0.asLogValue() })
    }
}

enum LogFieldValue: Sendable {
    case value(LogValue)
    case pii(PIIValue)

    static func `public`(_ value: some LogValueConvertible) -> LogFieldValue {
        .value(value.asLogValue())
    }

    static func sensitive(_ value: PIIValue) -> LogFieldValue {
        .pii(value)
    }
}

typealias LogMetadataFields = [String: LogFieldValue]

// MARK: - PII

struct PIIValue: Sendable, Equatable {
    enum Kind: String, Codable {
        case email
        case phone
        case name
        case token
        case raw
    }

    let kind: Kind
    let value: String

    init(kind: Kind, value: String) {
        self.kind = kind
        self.value = value
    }

    static func email(_ value: String) -> PIIValue {
        PIIValue(kind: .email, value: value)
    }

    static func phone(_ value: String) -> PIIValue {
        PIIValue(kind: .phone, value: value)
    }

    static func name(_ value: String) -> PIIValue {
        PIIValue(kind: .name, value: value)
    }

    static func token(_ value: String) -> PIIValue {
        PIIValue(kind: .token, value: value)
    }

    static func raw(_ value: String) -> PIIValue {
        PIIValue(kind: .raw, value: value)
    }

    var redacted: String {
        switch kind {
        case .email:
            return PIIValue.maskEmail(value)
        case .phone:
            return PIIValue.maskPhone(value)
        case .name:
            return PIIValue.maskName(value)
        case .token:
            return PIIValue.maskToken(value)
        case .raw:
            return PIIValue.maskGeneric(value)
        }
    }

    func representation(includeHash: Bool) -> LogPIIRepresentation {
        let hash = includeHash ? SHA256.hash(data: Data(value.utf8)).hexString : nil
        return LogPIIRepresentation(kind: kind, redacted: redacted, hash: hash)
    }

    // single char emails, e.g. a@email.com will not be masked
    private static func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else {
            return maskGeneric(email)
        }
        let name = email[..<atIndex]
        let domain = email[atIndex...]
        let visiblePrefix = name.prefix(1)
        let masked = String(repeating: "•", count: max(0, name.count - 1))
        return "\(visiblePrefix)\(masked)\(domain)"
    }

    private static func maskPhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count > 4 else { return String(repeating: "•", count: digits.count) }
        let suffix = String(digits.suffix(4))
        return String(repeating: "•", count: digits.count - 4) + suffix
    }

    // single char names, e.g. 'H' will not be masked
    private static func maskName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        if trimmed.count == 1 { return String(first) }
        return "\(first)\(String(repeating: "•", count: max(0, trimmed.count - 1)))"
    }

    private static func maskToken(_ token: String) -> String {
        guard token.count > 8 else { return maskGeneric(token) }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        let masked = String(repeating: "•", count: token.count - 8)
        return "\(prefix)\(masked)\(suffix)"
    }

    private static func maskGeneric(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        if value.count <= 3 { return String(repeating: "•", count: value.count) }
        return "•" + String(repeating: "•", count: max(0, value.count - 2)) + "•"
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

struct LogPIIRepresentation: Codable, Sendable {
    let kind: PIIValue.Kind
    let redacted: String
    let hash: String?
}

// MARK: - Entry & Source

struct LogSource: Codable, Sendable {
    let file: String
    let function: String
    let line: UInt

    static func current(
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) -> LogSource {
        LogSource(file: "\(file)", function: "\(function)", line: line)
    }
}

struct LogEntry: Identifiable, Codable, Sendable {
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

    init(
        id: UUID = UUID(),
        timestamp: Date,
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: LogValue],
        pii: [String: LogPIIRepresentation],
        scope: [String: LogValue],
        source: LogSource,
        threadID: UInt64 = Thread.current.loggingThreadID,
        sequence: UInt64
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.pii = pii
        self.scope = scope
        self.source = source
        self.threadID = threadID
        self.sequence = sequence
    }
}

extension Thread {
    var loggingThreadID: UInt64 {
        var id: __uint64_t = 0
        pthread_threadid_np(nil, &id)
        return id
    }
}

private extension UnkeyedDecodingContainer {
    mutating func skip() {
        _ = try? decode(UnkeyedDiscardable.self)
    }
}

private struct UnkeyedDiscardable: Decodable {}
