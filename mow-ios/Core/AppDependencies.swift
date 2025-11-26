import Foundation

protocol APIService {
    func login(email: String, password: String) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func fetchHomeSnapshot() async throws -> HomeSnapshot
}

protocol KeychainService {
    func save(token: String) async throws
    func clear() async throws
}

protocol AnalyticsService {
    func track(event: String, metadata: [String: String]) async
}

struct AppDependencies {
    let environment: AppEnvironment
    let api: any APIService
    let keychain: any KeychainService
    let analytics: any AnalyticsService
    let deviceInfo: any DeviceInfoService

    init(
        environment: AppEnvironment,
        api: some APIService,
        keychain: some KeychainService,
        analytics: some AnalyticsService,
        deviceInfo: some DeviceInfoService
    ) {
        self.environment = environment
        self.api = api
        self.keychain = keychain
        self.analytics = analytics
        self.deviceInfo = deviceInfo
    }

    static func live(environment: AppEnvironment = .current) -> AppDependencies {
        AppDependencies(
            environment: environment,
            api: MockAPIService(),
            keychain: MockKeychainService(),
            analytics: MockAnalyticsService(),
            deviceInfo: LiveDeviceInfoService()
        )
    }
}

// MARK: - DTOs

struct AuthSession: Equatable, Sendable {
    let token: String
    let displayName: String
}

struct HomeSnapshot: Equatable, Sendable {
    struct DashboardStat: Identifiable, Equatable, Sendable {
        let id = UUID()
        let label: String
        let value: String
        let trend: String
    }

    struct Meal: Identifiable, Equatable, Sendable {
        let id = UUID()
        let title: String
        let calories: Int
        let deliveryTime: Date
    }

    struct Delivery: Identifiable, Equatable, Sendable {
        let id = UUID()
        let recipient: String
        let address: String
        let distanceMiles: Double
    }

    struct Profile: Equatable, Sendable {
        let name: String
        let role: String
        let territory: String
    }

    let headline: String
    let stats: [DashboardStat]
    let meals: [Meal]
    let deliveries: [Delivery]
    let profile: Profile
}

// MARK: - Mock services

enum MockAPIError: Error, LocalizedError, Equatable, Sendable {
    case invalidCredentials
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "That email and password combo does not look right."
        case .offline:
            "We could not reach the server. Please try again."
        }
    }
}

struct MockAPIService: APIService {
    func login(email: String, password: String) async throws -> AuthSession {
        try await Task.sleep(nanoseconds: 1_000_000_000)

        guard password.lowercased() == "password" else {
            throw MockAPIError.invalidCredentials
        }

        return AuthSession(token: UUID().uuidString, displayName: email.components(separatedBy: "@").first ?? "Volunteer")
    }

    func sendPasswordReset(email: String) async throws {
        try await Task.sleep(nanoseconds: 600_000_000)

        if email.isEmpty {
            throw MockAPIError.invalidCredentials
        }
    }

    func fetchHomeSnapshot() async throws -> HomeSnapshot {
        try await Task.sleep(nanoseconds: 800_000_000)

        return HomeSnapshot(
            headline: "You have 12 meals and 4 routes today.",
            stats: [
                .init(label: "Families Served", value: "32", trend: "+4 vs yesterday"),
                .init(label: "Miles", value: "18.4", trend: "On track"),
                .init(label: "Volunteer Hours", value: "6h 15m", trend: "Ahead of plan")
            ],
            meals: [
                .init(title: "Low-sodium chicken bowl", calories: 540, deliveryTime: .now.addingTimeInterval(1_800)),
                .init(title: "Gluten-free pasta", calories: 610, deliveryTime: .now.addingTimeInterval(3_600)),
                .init(title: "Fresh salad kit", calories: 320, deliveryTime: .now.addingTimeInterval(7_200))
            ],
            deliveries: [
                .init(recipient: "The Johnson Family", address: "18 W 34th St", distanceMiles: 1.3),
                .init(recipient: "Ms. Chen", address: "44 Spring Ave", distanceMiles: 2.1),
                .init(recipient: "The Rivera Household", address: "220 Beacon Rd", distanceMiles: 4.8)
            ],
            profile: .init(name: "Taylor West", role: "Lead Volunteer", territory: "North Austin")
        )
    }
}

actor MockKeychainService: KeychainService {
    private var token: String?

    func save(token: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        self.token = token
    }

    func clear() async throws {
        token = nil
    }
}

struct MockAnalyticsService: AnalyticsService {
    func track(event: String, metadata: [String: String]) async {
        #if DEBUG
        print("Analytics:", event, metadata)
        #endif
    }
}
