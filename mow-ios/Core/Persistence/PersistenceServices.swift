import Foundation
import Security

// MARK: - Low-level data stores

protocol DataStoring {
    func load(key: String) throws -> Data?
    func save(_ data: Data, key: String) throws
    func delete(key: String) throws
}

final class UserDefaultsDataStore: DataStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(key: String) throws -> Data? {
        defaults.data(forKey: key)
    }

    func save(_ data: Data, key: String) throws {
        defaults.set(data, forKey: key)
    }

    func delete(key: String) throws {
        defaults.removeObject(forKey: key)
    }
}

enum KeychainStoreError: Error {
    case keychain(OSStatus)
}

extension KeychainStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .keychain(status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error (\(status)): \(message)"
            }
            return "Keychain error (\(status))"
        }
    }
}

final class KeychainDataStore: DataStoring {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func load(key: String) throws -> Data? {
        var query = baseQuery(account: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.keychain(status)
        }
    }

    func save(_ data: Data, key: String) throws {
        var query = baseQuery(account: key)
        let currentStatus = SecItemCopyMatching(query as CFDictionary, nil)

        switch currentStatus {
        case errSecSuccess:
            let attributes: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainStoreError.keychain(status)
            }
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainStoreError.keychain(status)
            }
        default:
            throw KeychainStoreError.keychain(currentStatus)
        }
    }

    func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(account: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.keychain(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

// MARK: - Codable store

enum CodableStoreError: Error {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case underlying(Error)
}

extension CodableStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .encodingFailed(error):
            return "Failed to encode value: \(error.localizedDescription)"
        case let .decodingFailed(error):
            return "Failed to decode value: \(error.localizedDescription)"
        case let .underlying(error):
            return error.localizedDescription
        }
    }
}

final class CodableStore<Value: Codable> {
    private let dataStore: DataStoring
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        dataStore: DataStoring,
        key: String,
        configureEncoder: (JSONEncoder) -> Void = { _ in },
        configureDecoder: (JSONDecoder) -> Void = { _ in }
    ) {
        self.dataStore = dataStore
        self.key = key

        let encoder = JSONEncoder()
        configureEncoder(encoder)
        self.encoder = encoder

        let decoder = JSONDecoder()
        configureDecoder(decoder)
        self.decoder = decoder
    }

    func load() throws -> Value? {
        let data: Data
        do {
            guard let loaded = try dataStore.load(key: key) else { return nil }
            data = loaded
        } catch let error as CodableStoreError {
            throw error
        } catch {
            throw CodableStoreError.underlying(error)
        }

        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw CodableStoreError.decodingFailed(error)
        }
    }

    func save(_ value: Value) throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw CodableStoreError.encodingFailed(error)
        }

        do {
            try dataStore.save(data, key: key)
        } catch let error as CodableStoreError {
            throw error
        } catch {
            throw CodableStoreError.underlying(error)
        }
    }

    func clear() throws {
        do {
            try dataStore.delete(key: key)
        } catch let error as CodableStoreError {
            throw error
        } catch {
            throw CodableStoreError.underlying(error)
        }
    }
}

// MARK: - Domain-facing stores

protocol OnboardingProgressStoring: AnyObject {
    func hasCompletedOnboarding() -> Bool
    func markCompleted()
    func reset()
}

final class UserDefaultsOnboardingStore: OnboardingProgressStoring {
    private let store: CodableStore<Bool>

    init(defaults: UserDefaults = .standard, key: String = "onboarding.completed") {
        let dataStore = UserDefaultsDataStore(defaults: defaults)
        self.store = CodableStore(dataStore: dataStore, key: key)
    }

    func hasCompletedOnboarding() -> Bool {
        (try? store.load()) ?? false
    }

    func markCompleted() {
        try? store.save(true)
    }

    func reset() {
        try? store.clear()
    }
}

protocol SessionStoring: AnyObject {
    func store(session: AuthSession) throws
    func loadSession() throws -> AuthSession?
    func clearSession() throws
}

enum SessionStoreError: Error {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case keychain(OSStatus)
    case unknown(Error)

    static func from(_ error: Error) -> SessionStoreError {
        if let sessionError = error as? SessionStoreError {
            return sessionError
        }

        if let codableError = error as? CodableStoreError {
            switch codableError {
            case let .encodingFailed(underlying):
                return .encodingFailed(underlying)
            case let .decodingFailed(underlying):
                return .decodingFailed(underlying)
            case let .underlying(underlying):
                return .from(underlying)
            }
        }

        if let keychainError = error as? KeychainStoreError {
            switch keychainError {
            case let .keychain(status):
                return .keychain(status)
            }
        }

        return .unknown(error)
    }
}

extension SessionStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .encodingFailed(error):
            return "Failed to encode auth session: \(error.localizedDescription)"
        case let .decodingFailed(error):
            return "Failed to decode auth session: \(error.localizedDescription)"
        case let .keychain(status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error (\(status)): \(message)"
            }
            return "Keychain error (\(status))"
        case let .unknown(error):
            return error.localizedDescription
        }
    }
}

final class KeychainSessionStore: SessionStoring {
    private let store: CodableStore<AuthSession>

    init(service: String, account: String = "auth.session") {
        let dataStore = KeychainDataStore(service: service)
        self.store = CodableStore(
            dataStore: dataStore,
            key: account,
            configureEncoder: { $0.dateEncodingStrategy = .iso8601 },
            configureDecoder: { $0.dateDecodingStrategy = .iso8601 }
        )
    }

    func store(session: AuthSession) throws {
        do {
            try store.save(session)
        } catch {
            throw SessionStoreError.from(error)
        }
    }

    func loadSession() throws -> AuthSession? {
        do {
            return try store.load()
        } catch {
            throw SessionStoreError.from(error)
        }
    }

    func clearSession() throws {
        do {
            try store.clear()
        } catch {
            throw SessionStoreError.from(error)
        }
    }
}

