import Foundation
import Security

protocol OnboardingProgressStoring: AnyObject {
    func hasCompletedOnboarding() -> Bool
    func markCompleted()
    func reset()
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
        }
    }
}

final class UserDefaultsOnboardingStore: OnboardingProgressStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "onboarding.completed") {
        self.defaults = defaults
        self.key = key
    }

    func hasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: key)
    }

    func markCompleted() {
        defaults.set(true, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}

final class KeychainSessionStore: SessionStoring {
    private let service: String
    private let account: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(service: String, account: String = "auth.session") {
        self.service = service
        self.account = account
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func store(session: AuthSession) throws {
        let payload: Data
        do {
            payload = try encoder.encode(session)
        } catch {
            throw SessionStoreError.encodingFailed(error)
        }

        var query = baseQuery()
        let currentStatus = SecItemCopyMatching(query as CFDictionary, nil)

        switch currentStatus {
        case errSecSuccess:
            let attributes: [String: Any] = [kSecValueData as String: payload]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw SessionStoreError.keychain(status)
            }

        case errSecItemNotFound:
            query[kSecValueData as String] = payload
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw SessionStoreError.keychain(status)
            }

        default:
            throw SessionStoreError.keychain(currentStatus)
        }
    }

    func loadSession() throws -> AuthSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            do {
                return try decoder.decode(AuthSession.self, from: data)
            } catch {
                throw SessionStoreError.decodingFailed(error)
            }

        case errSecItemNotFound:
            return nil

        default:
            throw SessionStoreError.keychain(status)
        }
    }

    func clearSession() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionStoreError.keychain(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

