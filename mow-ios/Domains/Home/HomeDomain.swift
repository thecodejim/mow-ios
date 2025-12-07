import Foundation

enum HomeDomain {
    struct Environment {
        let appEnvironment: AppEnvironment
        let api: APIService
        let deviceInfo: DeviceInfoService
        let logger: Logger
        let logHistory: LogHistoryProviding
        let homeSnapshotStore: HomeSnapshotStoring
    }

    enum Tab: String, CaseIterable {
        case dashboard
        case meals
        case deliveries
        case profile
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
        case refreshing(LoadedState)
        case error(ErrorState)

        struct LoadedState: Equatable {
            var selectedTab: Tab = .dashboard
            var dashboard = Dashboard()
            var meals = Meals()
            var deliveries = Deliveries()
            var profile = Profile()
            var alertMessage: String?
            var isShowingDebugInfo = false
        }

        struct ErrorState: Equatable {
            var message: String
            var previousState: LoadedState?
        }

        struct Dashboard: Equatable {
            struct Stat: Identifiable, Equatable {
                let id = UUID()
                let label: String
                let value: String
                let trend: String
            }

            var headline: String
            var stats: [Stat]

            init(
                headline: String = Self.defaultHeadline,
                stats: [Stat] = []
            ) {
                self.headline = headline
                self.stats = stats
            }
        }

        struct Meals: Equatable {
            struct Item: Identifiable, Equatable {
                let id = UUID()
                let title: String
                let calories: Int
                let deliveryTime: Date
            }

            var items: [Item] = []
        }

        struct Deliveries: Equatable {
            struct Item: Identifiable, Equatable {
                let id = UUID()
                let recipient: String
                let address: String
                let distance: Double
            }

            var items: [Item] = []
        }

        struct Profile: Equatable {
            var name = ""
            var role = ""
            var territory = ""
        }
    }

    enum DomainError: Error, Equatable {
        case message(String)

        var description: String {
            switch self {
            case let .message(text): text
            }
        }
    }

    enum DelegateAction: Equatable {
        case logout
    }

    enum Action: Equatable {
        case onAppear
        case selectTab(Tab)
        case refresh
        case refreshResponse(Result<HomeSnapshot, DomainError>)
        case cacheLoaded(HomeSnapshot, shouldRefresh: Bool)
        case logoutTapped
        case clearAlert
        case setDebugInfoPresented(Bool)
        case delegate(DelegateAction)
    }

    @MainActor
    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        case .onAppear:
            let shouldRefresh: Bool
            switch state {
            case .loading:
                shouldRefresh = true
            case let .loaded(loadedState):
                shouldRefresh = loadedState.dashboard.stats.isEmpty
            case .refreshing:
                shouldRefresh = false
            case .error:
                shouldRefresh = true
            }

            return Effect {
                do {
                    if let snapshot = try await environment.homeSnapshotStore.latestSnapshot() {
                        return .cacheLoaded(snapshot, shouldRefresh: shouldRefresh)
                    }
                } catch {
                    environment.logger.error(
                        "Failed to load cached home snapshot",
                        error: error,
                        category: .businessLogic
                    )
                }
                return shouldRefresh ? .refresh : nil
            }

        case let .selectTab(tab):
            if case var .loaded(loadedState) = state {
                loadedState.selectedTab = tab
                state = .loaded(loadedState)
            } else if case var .refreshing(loadedState) = state {
                loadedState.selectedTab = tab
                state = .refreshing(loadedState)
            }
            return .none

        case let .cacheLoaded(snapshot, shouldRefresh):
            var loadedState = state.resolvedLoadedState()
            loadedState.apply(snapshot: snapshot)
            state = .loaded(loadedState)
            environment.logger.info(
                "Hydrated home from cache",
                category: .businessLogic,
                metadata: [
                    "stats": .public(snapshot.stats.count),
                    "meals": .public(snapshot.meals.count),
                    "deliveries": .public(snapshot.deliveries.count)
                ]
            )
            return shouldRefresh ? .send(.refresh) : .none

        case .refresh:
            switch state {
            case .loading:
                break
            case var .loaded(loadedState):
                loadedState.isShowingDebugInfo = false
                state = .refreshing(loadedState)
            case .refreshing:
                return .none
            case let .error(errorState):
                if var previous = errorState.previousState {
                    previous.isShowingDebugInfo = false
                    state = .refreshing(previous)
                } else {
                    state = .loading
                }
            }

            let refreshFallbackError = HomeDomain.Copy.refreshFallbackError
            environment.logger.info(
                "Refreshing home data",
                category: .businessLogic,
                metadata: ["environment": .public(environment.appEnvironment.name.rawValue)]
            )

            return .task {
                do {
                    let snapshot = try await environment.api.fetchHomeSnapshot()
                    return .refreshResponse(.success(snapshot))
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? refreshFallbackError
                    environment.logger.error(
                        "Home refresh failed",
                        error: error,
                        category: .businessLogic,
                        metadata: ["reason": .public(message)]
                    )
                    return .refreshResponse(.failure(.message(message)))
                }
            }

        case let .refreshResponse(result):
            switch result {
            case let .success(snapshot):
                var loadedState = state.resolvedLoadedState()
                loadedState.apply(snapshot: snapshot)
                state = .loaded(loadedState)
                environment.logger.info(
                    "Home refresh succeeded",
                    category: .businessLogic,
                    metadata: [
                        "stats": .public(snapshot.stats.count),
                        "meals": .public(snapshot.meals.count),
                        "deliveries": .public(snapshot.deliveries.count)
                    ]
                )
                return .fireAndForget {
                    do {
                        try await environment.homeSnapshotStore.save(snapshot)
                    } catch {
                        environment.logger.error(
                            "Failed to cache home snapshot",
                            error: error,
                            category: .businessLogic
                        )
                    }
                }

            case let .failure(error):
                switch state {
                case var .refreshing(loadedState):
                    loadedState.alertMessage = error.description
                    state = .loaded(loadedState)
                case var .loaded(loadedState):
                    loadedState.alertMessage = error.description
                    state = .loaded(loadedState)
                case .loading:
                    state = .error(.init(message: error.description, previousState: nil))
                case var .error(errorState):
                    errorState.message = error.description
                    state = .error(errorState)
                }
                environment.logger.info(
                    "Home refresh error shown",
                    category: .businessLogic,
                    metadata: ["message": .public(error.description)]
                )
            }
            return .none

        case .logoutTapped:
            environment.logger.info(
                "Logout tapped on home",
                category: .auth
            )
            return .send(.delegate(.logout))

        case .clearAlert:
            if case var .loaded(loadedState) = state {
                loadedState.alertMessage = nil
                state = .loaded(loadedState)
            } else if case var .refreshing(loadedState) = state {
                loadedState.alertMessage = nil
                state = .refreshing(loadedState)
            }
            return .none

        case let .setDebugInfoPresented(isPresented):
            state.setDebugInfoPresented(isPresented)
            environment.logger.debug(
                "Debug info toggled on home",
                category: .ui,
                metadata: ["isPresented": .public(isPresented)]
            )
            return .none

        case .delegate:
            return .none
        }
    }
}

private extension HomeDomain.State {
    func resolvedLoadedState() -> LoadedState {
        switch self {
        case let .refreshing(current):
            return current
        case let .loaded(current):
            return current
        case let .error(errorState):
            return errorState.previousState ?? .init()
        case .loading:
            return .init()
        }
    }
}

private extension HomeDomain.State.LoadedState {
    mutating func apply(snapshot: HomeSnapshot) {
        dashboard.headline = snapshot.headline
        dashboard.stats = snapshot.stats.map { .init(label: $0.label, value: $0.value, trend: $0.trend) }
        meals.items = snapshot.meals.map { .init(title: $0.title, calories: $0.calories, deliveryTime: $0.deliveryTime) }
        deliveries.items = snapshot.deliveries.map {
            .init(recipient: $0.recipient, address: $0.address, distance: $0.distanceMiles)
        }
        profile.name = snapshot.profile.name
        profile.role = snapshot.profile.role
        profile.territory = snapshot.profile.territory
        alertMessage = nil
    }
}

extension HomeDomain.State {
    init() {
        self = .loading
    }
}

extension HomeDomain.State {
    var isShowingDebugInfo: Bool {
        switch self {
        case let .loaded(state), let .refreshing(state):
            return state.isShowingDebugInfo
        case let .error(errorState):
            return errorState.previousState?.isShowingDebugInfo ?? false
        case .loading:
            return false
        }
    }
}

private extension HomeDomain.State {
    mutating func setDebugInfoPresented(_ isPresented: Bool) {
        switch self {
        case var .loaded(state):
            state.isShowingDebugInfo = isPresented
            self = .loaded(state)
        case var .error(errorState):
            if var previous = errorState.previousState {
                previous.isShowingDebugInfo = isPresented
                errorState.previousState = previous
                self = .error(errorState)
            }
        case .refreshing, .loading:
            break
        }
    }
}

extension HomeDomain.Tab: Identifiable {
    var id: String { rawValue }
}
