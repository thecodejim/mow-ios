import Foundation
@testable import mow_ios

// MARK: - Test Mock API Service

actor TestMockAPIService: APIService {
    private(set) var loginCallCount = 0
    private(set) var resetCallCount = 0
    private(set) var fetchHomeCallCount = 0
    
    var loginResult: Result<AuthSession, Error>
    var resetResult: Result<Void, Error>
    var homeSnapshotResult: Result<HomeSnapshot, Error>

    init(
        loginResult: Result<AuthSession, Error>,
        resetResult: Result<Void, Error>,
        homeSnapshotResult: Result<HomeSnapshot, Error>
    ) {
        self.loginResult = loginResult
        self.resetResult = resetResult
        self.homeSnapshotResult = homeSnapshotResult
    }

    @MainActor
    init() {
        self.loginResult = .success(AuthSession(token: "test-token", displayName: "Test User"))
        self.resetResult = .success(())
        self.homeSnapshotResult = .success(Self.makeDefaultSnapshot())
    }

    @MainActor
    private static func makeDefaultSnapshot() -> HomeSnapshot {
        HomeSnapshot(
            headline: "Test headline",
            stats: [
                .init(label: "Stat 1", value: "10", trend: "up"),
                .init(label: "Stat 2", value: "20", trend: "down")
            ],
            meals: [
                .init(title: "Test Meal", calories: 500, deliveryTime: Date())
            ],
            deliveries: [
                .init(recipient: "Test Recipient", address: "123 Test St", distanceMiles: 1.5)
            ],
            profile: .init(name: "Test Name", role: "Test Role", territory: "Test Territory")
        )
    }
    
    func login(email: String, password: String) async throws -> AuthSession {
        loginCallCount += 1
        
        switch loginResult {
        case .success(let session):
            return session
        case .failure(let error):
            throw error
        }
    }
    
    func sendPasswordReset(email: String) async throws {
        resetCallCount += 1
        
        switch resetResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    func fetchHomeSnapshot() async throws -> HomeSnapshot {
        fetchHomeCallCount += 1
        
        switch homeSnapshotResult {
        case .success(let snapshot):
            return snapshot
        case .failure(let error):
            throw error
        }
    }
    
    func reset() {
        loginCallCount = 0
        resetCallCount = 0
        fetchHomeCallCount = 0
    }
}

// MARK: - Test Onboarding Store

final class TestOnboardingStore: OnboardingProgressStoring {
    private(set) var completed = false
    private(set) var markCount = 0

    func hasCompletedOnboarding() -> Bool {
        completed
    }

    func markCompleted() {
        markCount += 1
        completed = true
    }

    func reset() {
        completed = false
        markCount = 0
    }
}

extension TestOnboardingStore: @unchecked Sendable {}

// MARK: - Test Session Store

final class TestSessionStore: SessionStoring {
    private(set) var storedSession: AuthSession?
    private(set) var storeCallCount = 0
    private(set) var clearCallCount = 0

    var storeResult: Result<Void, Error> = .success(())
    var clearResult: Result<Void, Error> = .success(())

    func store(session: AuthSession) throws {
        storeCallCount += 1
        switch storeResult {
        case .success:
            storedSession = session
        case .failure(let error):
            throw error
        }
    }

    func loadSession() throws -> AuthSession? {
        storedSession
    }

    func clearSession() throws {
        clearCallCount += 1
        switch clearResult {
        case .success:
            storedSession = nil
        case .failure(let error):
            throw error
        }
    }

    func reset() {
        storedSession = nil
        storeCallCount = 0
        clearCallCount = 0
        storeResult = .success(())
        clearResult = .success(())
    }
}

extension TestSessionStore: @unchecked Sendable {}

// MARK: - Test Home Snapshot Store

actor TestHomeSnapshotStore: HomeSnapshotStoring {
    private(set) var snapshot: HomeSnapshot?
    private(set) var loadCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var clearCallCount = 0

    func latestSnapshot() async throws -> HomeSnapshot? {
        loadCallCount += 1
        return snapshot
    }

    func save(_ snapshot: HomeSnapshot) async throws {
        saveCallCount += 1
        self.snapshot = snapshot
    }

    func clear() async throws {
        clearCallCount += 1
        snapshot = nil
    }

    func reset() {
        snapshot = nil
        loadCallCount = 0
        saveCallCount = 0
        clearCallCount = 0
    }
}

// MARK: - Test Mock Analytics Service

actor TestMockAnalyticsService: AnalyticsService {
    private(set) var trackedEvents: [(event: String, metadata: [String: String])] = []
    
    func track(event: String, metadata: [String: String]) async {
        trackedEvents.append((event, metadata))
    }
    
    func reset() {
        trackedEvents = []
    }
    
    func hasTracked(event: String) async -> Bool {
        trackedEvents.contains { $0.event == event }
    }
}

// MARK: - Test Mock Logger

@MainActor
struct TestLogCall: Equatable, Sendable {
    let level: LogLevel
    let message: String
    let categoryRawValue: String
    
    init(level: LogLevel, message: String, category: LogCategory) {
        self.level = level
        self.message = message
        self.categoryRawValue = category.rawValue
    }
    
    var category: LogCategory {
        LogCategory(rawValue: categoryRawValue)
    }
}

@MainActor
final class TestMockLogger: Logger {
    private(set) var logs: [TestLogCall] = []
    
    func log(
        level: LogLevel,
        _ message: @autoclosure () -> String,
        category: LogCategory,
        metadata: LogMetadataFields,
        pii: [String: PIIValue],
        file: StaticString,
        function: StaticString,
        line: UInt
    ) {
        logs.append(TestLogCall(level: level, message: message(), category: category))
    }
    
    func scoped(metadata: LogMetadataFields, pii: [String: PIIValue]) -> Logger {
        self
    }
    
    func flush() async {}
    
    func reset() {
        logs = []
    }
    
    func hasLogged(level: LogLevel, containing text: String) -> Bool {
        logs.contains { $0.level == level && $0.message.contains(text) }
    }
}

// MARK: - Test Helpers

extension AppEnvironment {
    @MainActor
    static func makeTestEnvironment() -> AppEnvironment {
        AppEnvironment(
            name: .localDev,
            apiBaseURL: URL(string: "https://api.test.example.com")!,
            docsURL: URL(string: "https://docs.test.example.com")!,
            portalURL: URL(string: "https://portal.test.example.com")!,
            telemetryURL: URL(string: "https://telemetry.test.example.com")!,
            healthCheckToken: "test-token",
            featureFlags: .init(useMockData: true),
            logLevel: .debug,
            appVersion: "1.0.0-test",
            buildNumber: "1",
            bundleIdentifier: "com.test.mow"
        )
    }
}

@MainActor
func createTestAppEnvironment() -> AppDomain.Environment {
    let logger = TestMockLogger()
    let logHistory = MockLogHistoryProvider()
    let api = TestMockAPIService()
    let onboardingStore = TestOnboardingStore()
    let sessionStore = TestSessionStore()
    let homeSnapshotStore = TestHomeSnapshotStore()
    let analytics = TestMockAnalyticsService()
    let deviceInfo = MockDeviceInfoService()
    let appEnv = AppEnvironment.makeTestEnvironment()
    
    return AppDomain.Environment(
        appEnvironment: appEnv,
        onboarding: OnboardingDomain.Environment(
            appEnvironment: appEnv,
            analytics: analytics,
            logger: logger,
            onboardingStore: onboardingStore
        ),
        login: LoginDomain.Environment(
            appEnvironment: appEnv,
            api: api,
            sessionStore: sessionStore,
            analytics: analytics,
            deviceInfo: deviceInfo,
            logger: logger,
            logHistory: logHistory
        ),
        home: HomeDomain.Environment(
            appEnvironment: appEnv,
            api: api,
            deviceInfo: deviceInfo,
            logger: logger,
            logHistory: logHistory,
            homeSnapshotStore: homeSnapshotStore
        ),
        logger: logger,
        sessionStore: sessionStore,
        homeSnapshotStore: homeSnapshotStore
    )
}
