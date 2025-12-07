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
        let initialRoute = AppCoordinator.resolveInitialRoute(using: dependencies)
        let environment = AppDomain.Environment(
            appEnvironment: dependencies.environment,
            onboarding: .init(
                appEnvironment: dependencies.environment,
                analytics: dependencies.analytics,
                logger: dependencies.logger,
                onboardingStore: dependencies.onboardingStore
            ),
            login: .init(
                appEnvironment: dependencies.environment,
                api: dependencies.api,
                sessionStore: dependencies.sessionStore,
                analytics: dependencies.analytics,
                deviceInfo: dependencies.deviceInfo,
                logger: dependencies.logger,
                logHistory: dependencies.logHistory
            ),
            home: .init(
                appEnvironment: dependencies.environment,
                api: dependencies.api,
                deviceInfo: dependencies.deviceInfo,
                logger: dependencies.logger,
                logHistory: dependencies.logHistory,
                homeSnapshotStore: dependencies.homeSnapshotStore
            ),
            logger: dependencies.logger,
            sessionStore: dependencies.sessionStore,
            homeSnapshotStore: dependencies.homeSnapshotStore
        )

        store = Store(initialState: .init(route: initialRoute), environment: environment, reducer: AppDomain.reducer)
        route = store.state.route

        onboardingStore = store.scope(
            state: { $0.onboarding },
            environment: { $0.onboarding },
            action: AppDomain.Action.onboarding
        )

        loginStore = store.scope(
            state: { $0.login },
            environment: { $0.login },
            action: AppDomain.Action.login
        )

        homeStore = store.scope(
            state: { $0.home },
            environment: { $0.home },
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

private extension AppCoordinator {
    static func resolveInitialRoute(using dependencies: AppDependencies) -> AppDomain.State.Route {
        do {
            if try dependencies.sessionStore.loadSession() != nil {
                return .home
            }
        } catch {
            dependencies.logger.error(
                "Failed to load persisted session",
                error: error,
                category: .auth
            )
        }

        if dependencies.onboardingStore.hasCompletedOnboarding() {
            return .login
        }

        return .onboarding
    }
}
