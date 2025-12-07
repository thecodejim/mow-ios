import Foundation

enum AppDomain {
    struct Environment {
        let appEnvironment: AppEnvironment
        let onboarding: OnboardingDomain.Environment
        let login: LoginDomain.Environment
        let home: HomeDomain.Environment
        let logger: Logger
        let sessionStore: SessionStoring
        let homeSnapshotStore: HomeSnapshotStoring
    }

    struct State: Equatable {
        var onboarding: OnboardingDomain.State
        var login: LoginDomain.State
        var home: HomeDomain.State
        var route: Route

        init(
            onboarding: OnboardingDomain.State = .init(),
            login: LoginDomain.State = .init(),
            home: HomeDomain.State = .init(),
            route: Route = .onboarding
        ) {
            self.onboarding = onboarding
            self.login = login
            self.home = home
            self.route = route
        }

        enum Route: Equatable {
            case onboarding
            case login
            case home
        }
    }

    enum Action: Equatable {
        case onboarding(OnboardingDomain.Action)
        case login(LoginDomain.Action)
        case home(HomeDomain.Action)
        case showLogin
        case showHome
    }

    @MainActor
    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        // MARK: - Navigation / top-level

        case .showLogin:
            state.login = .init()
            state.route = .login
            environment.logger.info(
                "Routing to login",
                category: .coordinator,
                metadata: ["previousRoute": .public(state.route.label)]
            )
            return .none

        case .showHome:
            state.home = .init()
            state.route = .home
            environment.logger.info(
                "Routing to home",
                category: .coordinator,
                metadata: ["previousRoute": .public(state.route.label)]
            )
            return .none

        // MARK: - Onboarding

        case .onboarding(.delegate(.finished)):
            state.login = .init()
            state.route = .login
            environment.logger.info(
                "Onboarding completed",
                category: .coordinator,
                metadata: ["targetRoute": .public(state.route.label)]
            )
            return .none

        case let .onboarding(childAction):
            // ignore onboarding actions when not on that route
            guard state.route == .onboarding else { return .none }

            let effect = OnboardingDomain.reducer(
                state: &state.onboarding,
                action: childAction,
                environment: environment.onboarding
            )
            return effect.map(Action.onboarding)

        // MARK: - Login

        case .login(.delegate(.authenticated)):
            state.home = .init()
            state.route = .home
            environment.logger.info(
                "Login authenticated",
                category: .coordinator,
                metadata: ["targetRoute": .public(state.route.label)]
            )
            return .none

        case .login(.delegate(.logout)):
            state.login = .init()
            state.route = .login
            environment.logger.info(
                "User logged out",
                category: .coordinator,
                metadata: ["targetRoute": .public(state.route.label)]
            )
            return .fireAndForget {
                await environment.clearPersistentSession(reason: "login_logout")
            }

        case let .login(childAction):
            guard state.route == .login else { return .none }

            let effect = LoginDomain.reducer(
                state: &state.login,
                action: childAction,
                environment: environment.login
            )
            return effect.map(Action.login)

        // MARK: - Home

        case .home(.delegate(.logout)):
            state.login = .init()
            state.route = .login
            environment.logger.info(
                "Home requested logout",
                category: .coordinator,
                metadata: ["targetRoute": .public(state.route.label)]
            )
            return .fireAndForget {
                await environment.clearPersistentSession(reason: "home_logout")
            }

        case let .home(childAction):
            guard state.route == .home else { return .none }

            let effect = HomeDomain.reducer(
                state: &state.home,
                action: childAction,
                environment: environment.home
            )
            return effect.map(Action.home)
        }
    }
}

private extension AppDomain.Environment {
    func clearPersistentSession(reason: String) async {
        do {
            try sessionStore.clearSession()
        } catch {
            logger.error(
                "Failed to clear session",
                error: error,
                category: .auth,
                metadata: ["reason": .public(reason)]
            )
        }

        do {
            try await homeSnapshotStore.clear()
        } catch {
            logger.error(
                "Failed to clear cached home snapshot",
                error: error,
                category: .businessLogic,
                metadata: ["reason": .public(reason)]
            )
        }
    }
}

private extension AppDomain.State.Route {
    var label: String {
        switch self {
        case .onboarding: return "onboarding"
        case .login: return "login"
        case .home: return "home"
        }
    }
}
