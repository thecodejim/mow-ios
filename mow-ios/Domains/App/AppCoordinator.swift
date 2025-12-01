import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    let store: Store<AppDomain.State, AppDomain.Action, AppDomain.Environment>

    @Published private(set) var route: AppDomain.State.Route

    let onboardingStore: OnboardingScopedStore
    let loginStore: LoginScopedStore
    let homeStore: HomeScopedStore

    private var cancellables: Set<AnyCancellable> = []

    init(dependencies: AppDependencies) {
        let environment = AppDomain.Environment(
            appEnvironment: dependencies.environment,
            onboarding: .init(appEnvironment: dependencies.environment, analytics: dependencies.analytics),
            login: .init(appEnvironment: dependencies.environment, api: dependencies.api, keychain: dependencies.keychain, analytics: dependencies.analytics, deviceInfo: dependencies.deviceInfo),
            home: .init(appEnvironment: dependencies.environment, api: dependencies.api, deviceInfo: dependencies.deviceInfo)
        )
        store = Store(initialState: .init(), environment: environment, reducer: AppDomain.reducer)
        route = store.state.route

        onboardingStore = store.scope(
            state: { $0.onboarding },
            action: AppDomain.Action.onboarding
        )

        loginStore = store.scope(
            state: { $0.login },
            action: AppDomain.Action.login
        )

        homeStore = store.scope(
            state: { $0.home },
            action: AppDomain.Action.home
        )

        store.$state
            .map(\.route)
            .removeDuplicates()
            .sink { [weak self] route in
                self?.route = route
            }
            .store(in: &cancellables)
    }
}
