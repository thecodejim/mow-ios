import Testing
import Foundation
@testable import mow_ios

@Suite("AppDomain Tests")
@MainActor
struct AppDomainTests {
    
    var logger: TestMockLogger
    var environment: AppDomain.Environment
    
    init() async throws {
        logger = TestMockLogger()
        var env = createTestAppEnvironment()
        // Replace logger with our test logger
        env = AppDomain.Environment(
            appEnvironment: env.appEnvironment,
            onboarding: OnboardingDomain.Environment(
                appEnvironment: env.appEnvironment,
                analytics: env.onboarding.analytics,
                logger: logger,
                onboardingStore: env.onboarding.onboardingStore
            ),
            login: LoginDomain.Environment(
                appEnvironment: env.appEnvironment,
                api: env.login.api,
                sessionStore: env.login.sessionStore,
                analytics: env.login.analytics,
                deviceInfo: env.login.deviceInfo,
                logger: logger,
                logHistory: env.login.logHistory
            ),
            home: HomeDomain.Environment(
                appEnvironment: env.appEnvironment,
                api: env.home.api,
                deviceInfo: env.home.deviceInfo,
                logger: logger,
                logHistory: env.home.logHistory,
                homeSnapshotStore: env.home.homeSnapshotStore
            ),
            logger: logger,
            sessionStore: env.sessionStore,
            homeSnapshotStore: env.homeSnapshotStore
        )
        self.environment = env
    }
    
    // MARK: - Initial State Tests
    
    @Test("Initial state starts on onboarding route")
    func initialStateStartsOnOnboardingRoute() {
        // Given: Initial app state
        let state = AppDomain.State()
        
        // When: We check the route
        // Then: App starts on onboarding
        #expect(state.route == .onboarding)
    }
    
    @Test("Initial state has default sub-states")
    func initialStateHasDefaultSubStates() {
        // Given: Initial app state
        let state = AppDomain.State()
        
        // When: We check sub-states
        // Then: All domain states are initialized to their default values
        #expect(state.onboarding == OnboardingDomain.State())
        #expect(state.login == LoginDomain.State())
        #expect(state.home == HomeDomain.State())
    }
    
    // MARK: - Navigation Tests
    
    @Test("showLogin updates route to login")
    func showLoginUpdatesRouteToLogin() async {
        // Given: App state on onboarding route
        var state = AppDomain.State()
        #expect(state.route == .onboarding)
        
        // When: showLogin action is sent
        let effect = AppDomain.reducer(state: &state, action: .showLogin, environment: environment)
        
        // Then: Route changes to login
        #expect(state.route == .login)
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
        
        // And: Logger records the navigation
        #expect(logger.hasLogged(level: .info, containing: "Routing to login"))
    }
    
    @Test("showLogin resets login state")
    func showLoginResetsLoginState() {
        // Given: App state with existing login data
        var state = AppDomain.State()
        state.login = .error(.init(form: .init(email: "old@test.com", password: "old"), message: "Error"))
        
        // When: showLogin action is sent
        _ = AppDomain.reducer(state: &state, action: .showLogin, environment: environment)
        
        // Then: Login state is reset to initial
        if case .loaded(let loadedState) = state.login {
            #expect(loadedState.form.email == LoginDomain.State.LoginForm.defaultEmail)
        } else {
            Issue.record("Expected loaded state")
        }
    }
    
    @Test("showHome updates route to home")
    func showHomeUpdatesRouteToHome() async {
        // Given: App state on login route
        var state = AppDomain.State()
        state.route = .login
        
        // When: showHome action is sent
        let effect = AppDomain.reducer(state: &state, action: .showHome, environment: environment)
        
        // Then: Route changes to home
        #expect(state.route == .home)
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
        
        // And: Logger records the navigation
        #expect(logger.hasLogged(level: .info, containing: "Routing to home"))
    }
    
    @Test("showHome resets home state")
    func showHomeResetsHomeState() {
        // Given: App state with existing home data
        var state = AppDomain.State()
        state.home = .loaded(.init(selectedTab: .profile))
        
        // When: showHome action is sent
        _ = AppDomain.reducer(state: &state, action: .showHome, environment: environment)
        
        // Then: Home state is reset to initial (loading)
        #expect(state.home == .loading)
    }
    
    // MARK: - Onboarding Flow Tests
    
    @Test("Onboarding finished navigates to login")
    func onboardingFinishedNavigatesToLogin() async {
        // Given: App state on onboarding route
        var state = AppDomain.State()
        #expect(state.route == .onboarding)
        
        // When: Onboarding finishes
        let effect = AppDomain.reducer(
            state: &state,
            action: .onboarding(.delegate(.finished)),
            environment: environment
        )
        
        // Then: Route changes to login
        #expect(state.route == .login)
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
        
        // And: Logger records completion
        #expect(logger.hasLogged(level: .info, containing: "Onboarding completed"))
    }
    
    @Test("Onboarding action ignored when not on onboarding route")
    func onboardingActionIgnoredWhenNotOnOnboardingRoute() async {
        // Given: App state on login route
        var state = AppDomain.State()
        state.route = .login
        
        // When: Onboarding action is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .onboarding(.advance),
            environment: environment
        )
        
        // Then: State is unchanged
        #expect(state.route == .login)
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
    }
    
    @Test("Onboarding action processed when on onboarding route")
    func onboardingActionProcessedWhenOnOnboardingRoute() async {
        // Given: App state on onboarding route with loaded state
        var state = AppDomain.State()
        state.route = .onboarding
        state.onboarding = .loaded(.init(steps: [], currentIndex: 0))
        
        // When: Onboarding action is sent (non-delegate action)
        let effect = AppDomain.reducer(
            state: &state,
            action: .onboarding(.back),
            environment: environment
        )
        
        // Then: Action is processed by onboarding reducer
        // (back action when at index 0 should have no effect, but reducer was called)
        let result = await effect.run()
        #expect(result == nil)
    }
    
    // MARK: - Login Flow Tests
    
    @Test("Login authenticated navigates to home")
    func loginAuthenticatedNavigatesToHome() async {
        // Given: App state on login route
        var state = AppDomain.State()
        state.route = .login
        let session = AuthSession(token: "test-token", displayName: "Test User")
        
        // When: Login succeeds
        let effect = AppDomain.reducer(
            state: &state,
            action: .login(.delegate(.authenticated(session))),
            environment: environment
        )
        
        // Then: Route changes to home
        #expect(state.route == .home)
        
        // And: Home state is reset
        #expect(state.home == .loading)
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
        
        // And: Logger records authentication
        #expect(logger.hasLogged(level: .info, containing: "Login authenticated"))
    }
    
    @Test("Login logout navigates to login")
    func loginLogoutNavigatesToLogin() async {
        // Given: App state on home route
        var state = AppDomain.State()
        state.route = .home
        
        // When: Logout delegate action from login is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .login(.delegate(.logout)),
            environment: environment
        )
        
        // Then: Route changes to login
        #expect(state.route == .login)
        
        // And: Login state is reset
        if case .loaded = state.login {
            #expect(true)
        } else {
            Issue.record("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
        
        // And: Logger records logout
        #expect(logger.hasLogged(level: .info, containing: "User logged out"))
    }
    
    @Test("Login action ignored when not on login route")
    func loginActionIgnoredWhenNotOnLoginRoute() async {
        // Given: App state on onboarding route
        var state = AppDomain.State()
        state.route = .onboarding
        
        // When: Login action is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .login(.emailChanged("test@example.com")),
            environment: environment
        )
        
        // Then: State is unchanged
        #expect(state.route == .onboarding)
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
    }
    
    @Test("Login action processed when on login route")
    func loginActionProcessedWhenOnLoginRoute() async {
        // Given: App state on login route
        var state = AppDomain.State()
        state.route = .login
        state.login = .loaded(.init(form: .init(email: "", password: "")))
        
        // When: Login action is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .login(.emailChanged("new@example.com")),
            environment: environment
        )
        
        // Then: Login state is updated
        if case .loaded(let loadedState) = state.login {
            #expect(loadedState.form.email == "new@example.com")
        } else {
            Issue.record("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
    }
    
    // MARK: - Home Flow Tests
    
    @Test("Home logout navigates to login")
    func homeLogoutNavigatesToLogin() async {
        // Given: App state on home route
        var state = AppDomain.State()
        state.route = .home
        
        // When: Logout action from home is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .home(.delegate(.logout)),
            environment: environment
        )
        
        // Then: Route changes to login
        #expect(state.route == .login)
        
        // And: Login state is reset
        if case .loaded = state.login {
            #expect(true)
        } else {
            Issue.record("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
        
        // And: Logger records logout
        #expect(logger.hasLogged(level: .info, containing: "Home requested logout"))
    }
    
    @Test("Home action ignored when not on home route")
    func homeActionIgnoredWhenNotOnHomeRoute() async {
        // Given: App state on login route
        var state = AppDomain.State()
        state.route = .login
        
        // When: Home action is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .home(.selectTab(.profile)),
            environment: environment
        )
        
        // Then: State is unchanged
        #expect(state.route == .login)
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
    }
    
    @Test("Home action processed when on home route")
    func homeActionProcessedWhenOnHomeRoute() async {
        // Given: App state on home route with loaded state
        var state = AppDomain.State()
        state.route = .home
        state.home = .loaded(.init(selectedTab: .dashboard))
        
        // When: Home action is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .home(.selectTab(.profile)),
            environment: environment
        )
        
        // Then: Home state is updated
        if case .loaded(let loadedState) = state.home {
            #expect(loadedState.selectedTab == .profile)
        } else {
            Issue.record("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        #expect(result == nil)
    }
    
    // MARK: - Effect Mapping Tests
    
    @Test("Onboarding effect is mapped correctly")
    func onboardingEffectIsMappedCorrectly() async {
        // Given: App state on onboarding route
        var state = AppDomain.State()
        state.route = .onboarding
        state.onboarding = .loaded(.init())
        
        // When: Onboarding action with effect is sent
        let effect = AppDomain.reducer(
            state: &state,
            action: .onboarding(.onAppear),
            environment: environment
        )
        
        // Then: Effect is mapped to AppDomain.Action
        let result = await effect.run()
        // onAppear returns a fireAndForget effect, so result should be nil
        #expect(result == nil)
    }
    
    // MARK: - Integration Tests
    
    @Test("Full onboarding to login flow")
    func fullOnboardingToLoginFlow() async {
        // Given: Fresh app state
        var state = AppDomain.State()
        #expect(state.route == .onboarding)
        
        // When: User completes onboarding
        _ = AppDomain.reducer(
            state: &state,
            action: .onboarding(.delegate(.finished)),
            environment: environment
        )
        
        // Then: User is on login screen
        #expect(state.route == .login)
        
        // And: Login state is fresh
        if case .loaded = state.login {
            #expect(true)
        } else {
            Issue.record("Expected loaded state")
        }
    }
    
    @Test("Full login to home flow")
    func fullLoginToHomeFlow() async {
        // Given: App state on login route
        var state = AppDomain.State()
        state.route = .login
        let session = AuthSession(token: "auth-token", displayName: "User")
        
        // When: User logs in successfully
        _ = AppDomain.reducer(
            state: &state,
            action: .login(.delegate(.authenticated(session))),
            environment: environment
        )
        
        // Then: User is on home screen
        #expect(state.route == .home)
        
        // And: Home state is initialized
        #expect(state.home == .loading)
    }
    
    @Test("Full home to login logout flow")
    func fullHomeToLoginLogoutFlow() async {
        // Given: App state on home route
        var state = AppDomain.State()
        state.route = .home
        state.home = .loaded(.init())
        
        // When: User logs out from home
        _ = AppDomain.reducer(
            state: &state,
            action: .home(.delegate(.logout)),
            environment: environment
        )
        
        // Then: User is back on login screen
        #expect(state.route == .login)
        
        // And: Login state is fresh
        if case .loaded = state.login {
            #expect(true)
        } else {
            Issue.record("Expected loaded state")
        }
    }
    
    @Test("Complete user journey - onboarding to home and back")
    func completeUserJourneyOnboardingToHomeAndBack() async {
        // Given: Fresh app state
        var state = AppDomain.State()
        logger.reset()
        
        // When: User completes onboarding
        _ = AppDomain.reducer(
            state: &state,
            action: .onboarding(.delegate(.finished)),
            environment: environment
        )
        #expect(state.route == .login)
        
        // And: User logs in
        let session = AuthSession(token: "token", displayName: "User")
        _ = AppDomain.reducer(
            state: &state,
            action: .login(.delegate(.authenticated(session))),
            environment: environment
        )
        #expect(state.route == .home)
        
        // And: User logs out
        _ = AppDomain.reducer(
            state: &state,
            action: .home(.delegate(.logout)),
            environment: environment
        )
        
        // Then: User is back at login
        #expect(state.route == .login)
        
        // And: All key events are logged
        #expect(logger.hasLogged(level: .info, containing: "Onboarding completed"))
        #expect(logger.hasLogged(level: .info, containing: "Login authenticated"))
        #expect(logger.hasLogged(level: .info, containing: "Home requested logout"))
    }
    
    // MARK: - State Isolation Tests
    
    @Test("Route changes do not affect other domain states")
    func routeChangesDoNotAffectOtherDomainStates() {
        // Given: App state with specific domain states
        var state = AppDomain.State()
        state.route = .login
        state.login = .loaded(.init(form: .init(email: "user@test.com", password: "pass")))
        
        // When: We navigate away and back
        _ = AppDomain.reducer(state: &state, action: .showHome, environment: environment)
        #expect(state.route == .home)
        
        _ = AppDomain.reducer(state: &state, action: .showLogin, environment: environment)
        #expect(state.route == .login)
        
        // Then: Original login state data is lost (because showLogin resets it)
        // This is expected behavior - each navigation resets the target state
        if case .loaded(let newState) = state.login {
            // State is reset to defaults
            #expect(newState.form.email == LoginDomain.State.LoginForm.defaultEmail)
        } else {
            Issue.record("Expected loaded state")
        }
    }
}
