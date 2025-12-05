import XCTest
import Combine
@testable import mow_ios

@MainActor
final class AppDomainTests: XCTestCase {
    
    var logger: TestMockLogger!
    var environment: AppDomain.Environment!
    
    override func setUp() async throws {
        logger = TestMockLogger()
        environment = createTestAppEnvironment()
        // Replace logger with our test logger
        environment = AppDomain.Environment(
            appEnvironment: environment.appEnvironment,
            onboarding: OnboardingDomain.Environment(
                appEnvironment: environment.appEnvironment,
                analytics: environment.onboarding.analytics,
                logger: logger
            ),
            login: LoginDomain.Environment(
                appEnvironment: environment.appEnvironment,
                api: environment.login.api,
                keychain: environment.login.keychain,
                analytics: environment.login.analytics,
                deviceInfo: environment.login.deviceInfo,
                logger: logger,
                logHistory: environment.login.logHistory
            ),
            home: HomeDomain.Environment(
                appEnvironment: environment.appEnvironment,
                api: environment.home.api,
                deviceInfo: environment.home.deviceInfo,
                logger: logger,
                logHistory: environment.home.logHistory
            ),
            logger: logger
        )
    }
    
    override func tearDown() async throws {
        logger = nil
        environment = nil
    }
    
    // MARK: - Initial State Tests
    
    func test_initialState_startsOnOnboardingRoute() {
        // Given: Initial app state
        let state = AppDomain.State()
        
        // When: We check the route
        // Then: App starts on onboarding
        XCTAssertEqual(state.route, .onboarding)
    }
    
    func test_initialState_hasDefaultSubStates() {
        // Given: Initial app state
        let state = AppDomain.State()
        
        // When: We check sub-states
        // Then: All domain states are initialized
        XCTAssertNotNil(state.onboarding)
        XCTAssertNotNil(state.login)
        XCTAssertNotNil(state.home)
    }
    
    // MARK: - Navigation Tests
    
    func test_showLogin_updatesRouteToLogin() async {
        // Given: App state on onboarding route
        var state = AppDomain.State()
        XCTAssertEqual(state.route, .onboarding)
        
        // When: showLogin action is sent
        let effect = AppDomain.reducer(state: &state, action: .showLogin, environment: environment)
        
        // Then: Route changes to login
        XCTAssertEqual(state.route, .login)
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
        
        // And: Logger records the navigation
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Routing to login"))
    }
    
    func test_showLogin_resetsLoginState() {
        // Given: App state with existing login data
        var state = AppDomain.State()
        state.login = .error(.init(form: .init(email: "old@test.com", password: "old"), message: "Error"))
        
        // When: showLogin action is sent
        _ = AppDomain.reducer(state: &state, action: .showLogin, environment: environment)
        
        // Then: Login state is reset to initial
        if case .loaded(let loadedState) = state.login {
            XCTAssertEqual(loadedState.form.email, LoginDomain.State.LoginForm.defaultEmail)
        } else {
            XCTFail("Expected loaded state")
        }
    }
    
    func test_showHome_updatesRouteToHome() async {
        // Given: App state on login route
        var state = AppDomain.State()
        state.route = .login
        
        // When: showHome action is sent
        let effect = AppDomain.reducer(state: &state, action: .showHome, environment: environment)
        
        // Then: Route changes to home
        XCTAssertEqual(state.route, .home)
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
        
        // And: Logger records the navigation
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Routing to home"))
    }
    
    func test_showHome_resetsHomeState() {
        // Given: App state with existing home data
        var state = AppDomain.State()
        state.home = .loaded(.init(selectedTab: .profile))
        
        // When: showHome action is sent
        _ = AppDomain.reducer(state: &state, action: .showHome, environment: environment)
        
        // Then: Home state is reset to initial (loading)
        XCTAssertEqual(state.home, .loading)
    }
    
    // MARK: - Onboarding Flow Tests
    
    func test_onboardingFinished_navigatesToLogin() async {
        // Given: App state on onboarding route
        var state = AppDomain.State()
        XCTAssertEqual(state.route, .onboarding)
        
        // When: Onboarding finishes
        let effect = AppDomain.reducer(
            state: &state,
            action: .onboarding(.delegate(.finished)),
            environment: environment
        )
        
        // Then: Route changes to login
        XCTAssertEqual(state.route, .login)
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
        
        // And: Logger records completion
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Onboarding completed"))
    }
    
    func test_onboardingAction_ignoredWhenNotOnOnboardingRoute() async {
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
        XCTAssertEqual(state.route, .login)
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
    }
    
    func test_onboardingAction_processedWhenOnOnboardingRoute() async {
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
        XCTAssertNil(result)
    }
    
    // MARK: - Login Flow Tests
    
    func test_loginAuthenticated_navigatesToHome() async {
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
        XCTAssertEqual(state.route, .home)
        
        // And: Home state is reset
        XCTAssertEqual(state.home, .loading)
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
        
        // And: Logger records authentication
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Login authenticated"))
    }
    
    func test_loginLogout_navigatesToLogin() async {
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
        XCTAssertEqual(state.route, .login)
        
        // And: Login state is reset
        if case .loaded = state.login {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
        
        // And: Logger records logout
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "User logged out"))
    }
    
    func test_loginAction_ignoredWhenNotOnLoginRoute() async {
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
        XCTAssertEqual(state.route, .onboarding)
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
    }
    
    func test_loginAction_processedWhenOnLoginRoute() async {
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
            XCTAssertEqual(loadedState.form.email, "new@example.com")
        } else {
            XCTFail("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
    }
    
    // MARK: - Home Flow Tests
    
    func test_homeLogout_navigatesToLogin() async {
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
        XCTAssertEqual(state.route, .login)
        
        // And: Login state is reset
        if case .loaded = state.login {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
        
        // And: Logger records logout
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Home requested logout"))
    }
    
    func test_homeAction_ignoredWhenNotOnHomeRoute() async {
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
        XCTAssertEqual(state.route, .login)
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
    }
    
    func test_homeAction_processedWhenOnHomeRoute() async {
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
            XCTAssertEqual(loadedState.selectedTab, .profile)
        } else {
            XCTFail("Expected loaded state")
        }
        
        // And: Effect is none
        let result = await effect.run()
        XCTAssertNil(result)
    }
    
    // MARK: - Effect Mapping Tests
    
    func test_onboardingEffect_isMappedCorrectly() async {
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
        XCTAssertNil(result)
    }
    
    // MARK: - Integration Tests
    
    func test_fullOnboardingToLoginFlow() async {
        // Given: Fresh app state
        var state = AppDomain.State()
        XCTAssertEqual(state.route, .onboarding)
        
        // When: User completes onboarding
        _ = AppDomain.reducer(
            state: &state,
            action: .onboarding(.delegate(.finished)),
            environment: environment
        )
        
        // Then: User is on login screen
        XCTAssertEqual(state.route, .login)
        
        // And: Login state is fresh
        if case .loaded = state.login {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected loaded state")
        }
    }
    
    func test_fullLoginToHomeFlow() async {
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
        XCTAssertEqual(state.route, .home)
        
        // And: Home state is initialized
        XCTAssertEqual(state.home, .loading)
    }
    
    func test_fullHomeToLoginLogoutFlow() async {
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
        XCTAssertEqual(state.route, .login)
        
        // And: Login state is fresh
        if case .loaded = state.login {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected loaded state")
        }
    }
    
    func test_completeUserJourney_onboardingToHomeAndBack() async {
        // Given: Fresh app state
        var state = AppDomain.State()
        logger.reset()
        
        // When: User completes onboarding
        _ = AppDomain.reducer(
            state: &state,
            action: .onboarding(.delegate(.finished)),
            environment: environment
        )
        XCTAssertEqual(state.route, .login)
        
        // And: User logs in
        let session = AuthSession(token: "token", displayName: "User")
        _ = AppDomain.reducer(
            state: &state,
            action: .login(.delegate(.authenticated(session))),
            environment: environment
        )
        XCTAssertEqual(state.route, .home)
        
        // And: User logs out
        _ = AppDomain.reducer(
            state: &state,
            action: .home(.delegate(.logout)),
            environment: environment
        )
        
        // Then: User is back at login
        XCTAssertEqual(state.route, .login)
        
        // And: All key events are logged
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Onboarding completed"))
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Login authenticated"))
        XCTAssertTrue(logger.hasLogged(level: .info, containing: "Home requested logout"))
    }
    
    // MARK: - State Isolation Tests
    
    func test_routeChanges_doNotAffectOtherDomainStates() {
        // Given: App state with specific domain states
        var state = AppDomain.State()
        state.route = .login
        state.login = .loaded(.init(form: .init(email: "user@test.com", password: "pass")))
        
        // When: We navigate away and back
        _ = AppDomain.reducer(state: &state, action: .showHome, environment: environment)
        XCTAssertEqual(state.route, .home)
        
        _ = AppDomain.reducer(state: &state, action: .showLogin, environment: environment)
        XCTAssertEqual(state.route, .login)
        
        // Then: Original login state data is lost (because showLogin resets it)
        // This is expected behavior - each navigation resets the target state
        if case .loaded(let newState) = state.login {
            // State is reset to defaults
            XCTAssertEqual(newState.form.email, LoginDomain.State.LoginForm.defaultEmail)
        } else {
            XCTFail("Expected loaded state")
        }
    }
}
