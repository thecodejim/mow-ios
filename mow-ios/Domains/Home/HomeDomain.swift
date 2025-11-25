import Foundation

enum HomeDomain {
    struct Environment: @unchecked Sendable {
        let api: any APIService
    }

    enum Tab: String, CaseIterable, Identifiable, Sendable {
        case dashboard
        case meals
        case deliveries
        case profile

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: "Plan"
            case .meals: "Meals"
            case .deliveries: "Deliveries"
            case .profile: "Profile"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: "rectangle.grid.2x2"
            case .meals: "fork.knife"
            case .deliveries: "map"
            case .profile: "person.crop.circle"
            }
        }
    }

    enum State: Equatable, Sendable {
        case loading
        case loaded(LoadedState)
        case refreshing(LoadedState)
        case error(ErrorState)

        struct LoadedState: Equatable, Sendable {
            var selectedTab: Tab = .dashboard
            var dashboard = Dashboard()
            var meals = Meals()
            var deliveries = Deliveries()
            var profile = Profile()
            var alertMessage: String?
        }

        struct ErrorState: Equatable, Sendable {
            var message: String
            var previousState: LoadedState?
        }

        struct Dashboard: Equatable, Sendable {
            struct Stat: Identifiable, Equatable, Sendable {
                let id = UUID()
                let label: String
                let value: String
                let trend: String
            }

            var headline = "You're ready for today."
            var stats: [Stat] = []
        }

        struct Meals: Equatable, Sendable {
            struct Item: Identifiable, Equatable, Sendable {
                let id = UUID()
                let title: String
                let calories: Int
                let deliveryTime: Date
            }

            var items: [Item] = []
        }

        struct Deliveries: Equatable, Sendable {
            struct Item: Identifiable, Equatable, Sendable {
                let id = UUID()
                let recipient: String
                let address: String
                let distance: Double
            }

            var items: [Item] = []
        }

        struct Profile: Equatable, Sendable {
            var name = ""
            var role = ""
            var territory = ""
        }
    }

    enum DelegateAction: Equatable, Sendable {
        case logout
    }

    enum DomainError: Error, Equatable, Sendable {
        case message(String)

        var description: String {
            switch self {
            case let .message(text): text
            }
        }
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case selectTab(Tab)
        case refresh
        case refreshResponse(Result<HomeSnapshot, DomainError>)
        case logoutTapped
        case clearAlert
        case delegate(DelegateAction)
    }

    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        case .onAppear:
            switch state {
            case .loading:
                return .send(.refresh)
            case let .loaded(loadedState):
                guard loadedState.dashboard.stats.isEmpty else { return .none }
                return .send(.refresh)
            case .refreshing:
                return .none
            case .error:
                return .send(.refresh)
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

        case .refresh:
            switch state {
            case .loading:
                break
            case let .loaded(loadedState):
                state = .refreshing(loadedState)
            case .refreshing:
                return .none
            case let .error(errorState):
                if let previous = errorState.previousState {
                    state = .refreshing(previous)
                } else {
                    state = .loading
                }
            }

            return .task {
                do {
                    let snapshot = try await environment.api.fetchHomeSnapshot()
                    return .refreshResponse(.success(snapshot))
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? "Unable to refresh right now."
                    return .refreshResponse(.failure(.message(message)))
                }
            }

        case let .refreshResponse(result):
            switch result {
            case let .success(snapshot):
                var loadedState: State.LoadedState
                if case let .refreshing(current) = state {
                    loadedState = current
                } else if case let .loaded(current) = state {
                    loadedState = current
                } else if case let .error(errorState) = state, let previous = errorState.previousState {
                    loadedState = previous
                } else {
                    loadedState = .init()
                }

                loadedState.dashboard.headline = snapshot.headline
                loadedState.dashboard.stats = snapshot.stats.map { .init(label: $0.label, value: $0.value, trend: $0.trend) }
                loadedState.meals.items = snapshot.meals.map { .init(title: $0.title, calories: $0.calories, deliveryTime: $0.deliveryTime) }
                loadedState.deliveries.items = snapshot.deliveries.map { .init(recipient: $0.recipient, address: $0.address, distance: $0.distanceMiles) }
                loadedState.profile.name = snapshot.profile.name
                loadedState.profile.role = snapshot.profile.role
                loadedState.profile.territory = snapshot.profile.territory
                loadedState.alertMessage = nil

                state = .loaded(loadedState)

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
            }
            return .none

        case .logoutTapped:
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

        case .delegate:
            return .none
        }
    }
}

extension HomeDomain.State {
    init() {
        self = .loading
    }
}
