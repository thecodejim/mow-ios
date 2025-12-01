import Foundation

enum AppDomain {
    struct Environment {
        let appEnvironment: AppEnvironment
        let onboarding: OnboardingDomain.Environment
        let login: LoginDomain.Environment
        let home: HomeDomain.Environment
    }

    struct State: Equatable {
        var onboarding: OnboardingDomain.State = .init()
        var login: LoginDomain.State = .init()
        var home: HomeDomain.State = .init()
        var route: Route = .onboarding

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
        case logout
    }

    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        // MARK: - Navigation / top-level

        case .showLogin, .logout:
            state.login = .init()
            state.route = .login
            return .none

        case .showHome:
            state.home = .init()
            state.route = .home
            return .none

        // MARK: - Onboarding

        case .onboarding(.delegate(.finished)):
            state.login = .init()
            state.route = .login
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
            return .none

        case .login(.delegate(.logout)):
            state.login = .init()
            state.route = .login
            return .none

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
            return .none

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
