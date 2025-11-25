import SwiftUI

struct HomeCoordinatorView: View {
    @ObservedObject var store: HomeScopedStore

    var body: some View {
        HomeTabView(store: store)
    }
}

private struct HomeTabView: View {
    @ObservedObject var store: HomeScopedStore

    private var selection: Binding<HomeDomain.Tab> {
        Binding(
            get: { store.state.currentTab },
            set: { store.send(.selectTab($0)) }
        )
    }

    var body: some View {
        content
            .task {
                store.send(.onAppear)
            }
            .alert(
                "Heads up",
                isPresented: Binding(
                    get: { store.state.alertMessage != nil },
                    set: { if !$0 { store.send(.clearAlert) } }
                ),
                actions: {},
                message: {
                    Text(store.state.alertMessage ?? "")
                }
            )
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            ProgressView("Loading your day…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .error(errorState):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(errorState.message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    store.send(.refresh)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .loaded(loadedState):
            loadedContent(for: loadedState, isRefreshing: false)
        case let .refreshing(loadedState):
            loadedContent(for: loadedState, isRefreshing: true)
        }
    }

    private func loadedContent(for state: HomeDomain.State.LoadedState, isRefreshing: Bool) -> some View {
        TabView(selection: selection) {
            DashboardView(
                state: state.dashboard,
                isRefreshing: isRefreshing,
                onRefresh: { store.send(.refresh) }
            )
            .tabItem { Label(HomeDomain.Tab.dashboard.title, systemImage: HomeDomain.Tab.dashboard.icon) }
            .tag(HomeDomain.Tab.dashboard)

            MealsView(meals: state.meals)
                .tabItem { Label(HomeDomain.Tab.meals.title, systemImage: HomeDomain.Tab.meals.icon) }
                .tag(HomeDomain.Tab.meals)

            DeliveriesView(deliveries: state.deliveries)
                .tabItem { Label(HomeDomain.Tab.deliveries.title, systemImage: HomeDomain.Tab.deliveries.icon) }
                .tag(HomeDomain.Tab.deliveries)

            ProfileView(profile: state.profile, onLogout: { store.send(.logoutTapped) })
                .tabItem { Label(HomeDomain.Tab.profile.title, systemImage: HomeDomain.Tab.profile.icon) }
                .tag(HomeDomain.Tab.profile)
        }
        .overlay {
            if isRefreshing {
                BusyOverlay(text: "Syncing your routes…")
            }
        }
    }
}

private struct DashboardView: View {
    let state: HomeDomain.State.Dashboard
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(state.headline)
                        .font(.title2.bold())

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                        ForEach(state.stats) { stat in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stat.label.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(stat.value)
                                    .font(.title3.weight(.semibold))
                                Text(stat.trend)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onRefresh()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }
}

private struct MealsView: View {
    let meals: HomeDomain.State.Meals

    var body: some View {
        NavigationStack {
            List(meals.items) { meal in
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title)
                        .font(.headline)
                    Text("\(meal.calories) calories • \(meal.deliveryTime.formatted(date: .omitted, time: .shortened)) delivery")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Meals")
        }
    }
}

private struct DeliveriesView: View {
    let deliveries: HomeDomain.State.Deliveries

    var body: some View {
        NavigationStack {
            List(deliveries.items) { stop in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stop.recipient)
                            .font(.headline)
                        Text(stop.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(stop.distance, format: .number.precision(.fractionLength(1))) mi")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Deliveries")
        }
    }
}

private struct ProfileView: View {
    let profile: HomeDomain.State.Profile
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Volunteer") {
                    LabeledContent("Name", value: profile.name)
                    LabeledContent("Role", value: profile.role)
                    LabeledContent("Territory", value: profile.territory)
                }

                Section {
                    Button(role: .destructive) {
                        onLogout()
                    } label: {
                        Text("Log out")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } footer: {
                    Text("Logging out clears cached credentials stored in the secure enclave.")
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    let dependencies = AppDependencies.live()
    let environment = AppDomain.Environment(
        appEnvironment: dependencies.environment,
        onboarding: .init(appEnvironment: dependencies.environment, analytics: dependencies.analytics),
        login: .init(appEnvironment: dependencies.environment, api: dependencies.api, keychain: dependencies.keychain, analytics: dependencies.analytics),
        home: .init(api: dependencies.api)
    )
    let state = AppDomain.State(route: .home(.init()))
    let appStore = Store(
        initialState: state,
        environment: environment,
        reducer: { state, action, environment in
            AppDomain.reducer(state: &state, action: action, environment: environment)
        }
    )
    let scopedStore = appStore.scope(
        state: { state in
            if case let .home(childState) = state.route {
                return childState
            }
            return .init()
        },
        action: AppDomain.Action.home
    )
    return HomeCoordinatorView(store: scopedStore)
}

private extension HomeDomain.State {
    var currentTab: HomeDomain.Tab {
        switch self {
        case let .loaded(state), let .refreshing(state):
            return state.selectedTab
        case let .error(errorState):
            return errorState.previousState?.selectedTab ?? .dashboard
        case .loading:
            return .dashboard
        }
    }

    var alertMessage: String? {
        switch self {
        case let .loaded(state), let .refreshing(state):
            return state.alertMessage
        default:
            return nil
        }
    }
}
