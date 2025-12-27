import Foundation

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
