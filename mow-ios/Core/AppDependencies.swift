import Foundation

protocol APIService: Sendable {
    func login(email: String, password: String) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func fetchHomeSnapshot() async throws -> HomeSnapshot
}

protocol AnalyticsService: Sendable {
    func track(event: String, metadata: [String: String]) async
}

struct AppDependencies {
    let environment: AppEnvironment
    let logger: Logger
    let logHistory: LogHistoryProviding
    let api: APIService
    let analytics: AnalyticsService
    let deviceInfo: DeviceInfoService
    let onboardingStore: OnboardingProgressStoring
    let sessionStore: SessionStoring
    let homeSnapshotStore: HomeSnapshotStoring

    init(
        environment: AppEnvironment,
        logger: Logger,
        logHistory: LogHistoryProviding,
        api: APIService,
        analytics: AnalyticsService,
        deviceInfo: DeviceInfoService,
        onboardingStore: OnboardingProgressStoring,
        sessionStore: SessionStoring,
        homeSnapshotStore: HomeSnapshotStoring
    ) {
        self.environment = environment
        self.logger = logger
        self.logHistory = logHistory
        self.api = api
        self.analytics = analytics
        self.deviceInfo = deviceInfo
        self.onboardingStore = onboardingStore
        self.sessionStore = sessionStore
        self.homeSnapshotStore = homeSnapshotStore
    }

    static func live(environment: AppEnvironment) -> AppDependencies {
        let logging = LoggingSystem.bootstrap(environment: environment)
        let onboardingStore = UserDefaultsOnboardingStore(
            defaults: .standard,
            key: "\(environment.bundleIdentifier).onboarding.completed"
        )
        let sessionStore = KeychainSessionStore(service: environment.bundleIdentifier)
        let homeSnapshotStore = SwiftDataHomeSnapshotStore.makeDefault(for: environment)

        return AppDependencies(
            environment: environment,
            logger: logging.logger,
            logHistory: logging.history,
            api: MockAPIService(),
//            api: LiveAPIService(baseURL: environment.apiBaseURL), // TODO: use live api service once backend is up
            analytics: MockAnalyticsService(),
            deviceInfo: LiveDeviceInfoService(),
            onboardingStore: onboardingStore,
            sessionStore: sessionStore,
            homeSnapshotStore: homeSnapshotStore
        )
    }
    
    static func mock(environment: AppEnvironment) -> AppDependencies {
        AppDependencies(
            environment: environment,
            logger: MockLogger(),
            logHistory: MockLogHistoryProvider(),
            api: MockAPIService(),
            analytics: MockAnalyticsService(),
            deviceInfo: MockDeviceInfoService(),
            onboardingStore: InMemoryOnboardingStore(),
            sessionStore: InMemorySessionStore(),
            homeSnapshotStore: InMemoryHomeSnapshotStore()
        )
    }
}

// MARK: - DTOs

struct AuthSession: Equatable, Codable {
    let token: String
    let displayName: String

    init(token: String, displayName: String) {
        self.token = token
        self.displayName = displayName
    }
}

struct HomeSnapshot: Equatable, Codable {
    struct DashboardStat: Identifiable, Equatable, Codable {
        let id: UUID
        let label: String
        let value: String
        let trend: String

        init(id: UUID = UUID(), label: String, value: String, trend: String) {
            self.id = id
            self.label = label
            self.value = value
            self.trend = trend
        }
    }

    struct Meal: Identifiable, Equatable, Codable {
        let id: UUID
        let title: String
        let calories: Int
        let deliveryTime: Date

        init(id: UUID = UUID(), title: String, calories: Int, deliveryTime: Date) {
            self.id = id
            self.title = title
            self.calories = calories
            self.deliveryTime = deliveryTime
        }
    }

    struct Delivery: Identifiable, Equatable, Codable {
        let id: UUID
        let recipient: String
        let address: String
        let distanceMiles: Double

        init(id: UUID = UUID(), recipient: String, address: String, distanceMiles: Double) {
            self.id = id
            self.recipient = recipient
            self.address = address
            self.distanceMiles = distanceMiles
        }
    }

    struct Profile: Equatable, Codable {
        let name: String
        let role: String
        let territory: String

        init(name: String, role: String, territory: String) {
            self.name = name
            self.role = role
            self.territory = territory
        }
    }

    let headline: String
    let stats: [DashboardStat]
    let meals: [Meal]
    let deliveries: [Delivery]
    let profile: Profile

    init(
        headline: String,
        stats: [DashboardStat],
        meals: [Meal],
        deliveries: [Delivery],
        profile: Profile
    ) {
        self.headline = headline
        self.stats = stats
        self.meals = meals
        self.deliveries = deliveries
        self.profile = profile
    }
}

// MARK: - Mock services

enum MockAPIError: Error, LocalizedError, Equatable {
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

struct MockAnalyticsService: AnalyticsService {
    func track(event: String, metadata: [String: String]) async {
        #if DEBUG
        print("Analytics:", event, metadata)
        #endif
    }
}

final class InMemoryOnboardingStore: OnboardingProgressStoring {
    private var completed = false

    func hasCompletedOnboarding() -> Bool { completed }

    func markCompleted() {
        completed = true
    }

    func reset() {
        completed = false
    }
}

final class InMemorySessionStore: SessionStoring {
    private var session: AuthSession?

    func store(session: AuthSession) throws {
        self.session = session
    }

    func loadSession() throws -> AuthSession? {
        session
    }

    func clearSession() throws {
        session = nil
    }
}

actor InMemoryHomeSnapshotStore: HomeSnapshotStoring {
    private var snapshot: HomeSnapshot?

    func latestSnapshot() async throws -> HomeSnapshot? {
        snapshot
    }

    func save(_ snapshot: HomeSnapshot) async throws {
        self.snapshot = snapshot
    }

    func clear() async throws {
        snapshot = nil
    }
}
