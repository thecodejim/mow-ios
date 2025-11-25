import Foundation

enum HomeDomain {
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

    struct State: Equatable, Sendable {
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

        var selectedTab: Tab = .dashboard
        var dashboard = Dashboard()
        var meals = Meals()
        var deliveries = Deliveries()
        var profile = Profile()
        var isRefreshing = false
        var alertMessage: String?
    }

    struct Environment: @unchecked Sendable {
        let api: any APIService
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
            guard state.dashboard.stats.isEmpty else { return .none }
            return .send(.refresh)

        case let .selectTab(tab):
            state.selectedTab = tab
            return .none

        case .refresh:
            guard !state.isRefreshing else { return .none }
            state.isRefreshing = true
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
            state.isRefreshing = false
            switch result {
            case let .success(snapshot):
                state.dashboard.headline = snapshot.headline
                state.dashboard.stats = snapshot.stats.map { .init(label: $0.label, value: $0.value, trend: $0.trend) }
                state.meals.items = snapshot.meals.map { .init(title: $0.title, calories: $0.calories, deliveryTime: $0.deliveryTime) }
                state.deliveries.items = snapshot.deliveries.map { .init(recipient: $0.recipient, address: $0.address, distance: $0.distanceMiles) }
                state.profile.name = snapshot.profile.name
                state.profile.role = snapshot.profile.role
                state.profile.territory = snapshot.profile.territory
            case let .failure(error):
                state.alertMessage = error.description
            }
            return .none

        case .logoutTapped:
            return .send(.delegate(.logout))

        case .clearAlert:
            state.alertMessage = nil
            return .none

        case .delegate:
            return .none
        }
    }
}
