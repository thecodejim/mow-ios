import Foundation

protocol AnalyticsService: Sendable {
    func track(event: String, metadata: [String: String]) async
}

struct AppDependencies {
    let environment: AppEnvironment
    let logger: Logger
    let logHistory: LogHistoryProviding
    let loginAPI: LoginAPIService
    let homeAPI: HomeAPIService
    let analytics: AnalyticsService
    let deviceInfo: DeviceInfoService
    let onboardingStore: OnboardingProgressStoring
    let sessionStore: SessionStoring
    let homeSnapshotStore: HomeSnapshotStoring

    init(
        environment: AppEnvironment,
        logger: Logger,
        logHistory: LogHistoryProviding,
        loginAPI: LoginAPIService,
        homeAPI: HomeAPIService,
        analytics: AnalyticsService,
        deviceInfo: DeviceInfoService,
        onboardingStore: OnboardingProgressStoring,
        sessionStore: SessionStoring,
        homeSnapshotStore: HomeSnapshotStoring
    ) {
        self.environment = environment
        self.logger = logger
        self.logHistory = logHistory
        self.loginAPI = loginAPI
        self.homeAPI = homeAPI
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
        
        var session: URLSession
        #if DEBUG
        let delegate = DebugTrustingSessionDelegate(allowedHosts: ["portal.localhost"])
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        #else
        session = URLSession(configuration: .default)
        #endif

        let httpClient = HTTPClient(session: session)
        let loginAPI = LiveLoginAPIService(baseURL: environment.apiBaseURL, client: httpClient)
        let homeAPI = MockHomeAPIService()

        return AppDependencies(
            environment: environment,
            logger: logging.logger,
            logHistory: logging.history,
            loginAPI: loginAPI,
            homeAPI: homeAPI,
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
            loginAPI: MockLoginAPIService(),
            homeAPI: MockHomeAPIService(),
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

#if DEBUG
final class DebugTrustingSessionDelegate: NSObject, URLSessionDelegate {
    /// Only bypass trust for these hosts (avoid accidentally trusting everything).
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String> = ["portal.localhost"]) {
        self.allowedHosts = allowedHosts
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // We only care about TLS server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()

        // Only bypass for local dev host(s)
        guard allowedHosts.contains(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Accept the presented certificate chain (DEBUG ONLY)
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}
#endif
