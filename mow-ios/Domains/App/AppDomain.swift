import Foundation

enum AppDomain {
    struct Environment: @unchecked Sendable {
        let appEnvironment: AppEnvironment
        let onboarding: OnboardingDomain.Environment
        let login: LoginDomain.Environment
        let home: HomeDomain.Environment
    }

    struct State: Equatable, Sendable {
        var route: Route = .onboarding(.init())
    }

    enum Route: Equatable, Sendable {
        case onboarding(OnboardingDomain.State)
        case login(LoginDomain.State)
        case home(HomeDomain.State)
    }

    enum Action: Equatable, Sendable {
        case onboarding(OnboardingDomain.Action)
        case login(LoginDomain.Action)
        case home(HomeDomain.Action)
        case showLogin
        case showHome
        case logout
    }

    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        case .showLogin, .logout:
            state.route = .login(.init())
            return .none

        case .showHome:
            state.route = .home(.init())
            return .none

        case .onboarding(.delegate(.finished)):
            state.route = .login(.init())
            return .none

        case let .onboarding(childAction):
            guard case var .onboarding(childState) = state.route else {
                return .none
            }
            let effect = OnboardingDomain.reducer(
                state: &childState,
                action: childAction,
                environment: environment.onboarding
            )
            state.route = .onboarding(childState)
            return effect.map(Action.onboarding)

        case .login(.delegate(.authenticated)):
            state.route = .home(.init())
            return .none

        case .login(.delegate(.logout)):
            state.route = .login(.init())
            return .none

        case let .login(childAction):
            guard case var .login(childState) = state.route else {
                return .none
            }
            let effect = LoginDomain.reducer(
                state: &childState,
                action: childAction,
                environment: environment.login
            )
            state.route = .login(childState)
            return effect.map(Action.login)

        case .home(.delegate(.logout)):
            state.route = .login(.init())
            return .none

        case let .home(childAction):
            guard case var .home(childState) = state.route else {
                return .none
            }
            let effect = HomeDomain.reducer(
                state: &childState,
                action: childAction,
                environment: environment.home
            )
            state.route = .home(childState)
            return effect.map(Action.home)
        }
    }
}
