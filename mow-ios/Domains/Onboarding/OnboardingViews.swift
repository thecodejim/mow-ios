import SwiftUI

struct OnboardingRootView: View {
    @ObservedObject var store: OnboardingScopedStore

    var body: some View {
        NavigationStack {
            OnboardingFlowView(store: store)
                .navigationTitle("Meals on Wheels")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct OnboardingFlowView: View {
    @ObservedObject var store: OnboardingScopedStore

    private var selection: Binding<Int> {
        Binding(
            get: { store.state.currentIndex },
            set: { store.send(.setIndex($0)) }
        )
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .overlay {
                if store.state.shouldShowCompletionOverlay {
                    BusyOverlay(text: "Setting things up…")
                }
            }
            .task {
                store.send(.onAppear)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            ProgressView("Loading…")
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
                    store.send(.onAppear)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        VStack(spacing: 24) {
            TabView(selection: selection) {
                ForEach(store.state.steps) { step in
                    OnboardingStepCard(step: step)
                        .tag(step.id)
                        .padding(.top, 12)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.9), value: store.state.currentIndex)
            .tabViewStyle(.page(indexDisplayMode: .never))

            OnboardingPagerIndicator(steps: store.state.steps, current: store.state.currentIndex)

            OnboardingActionBar(
                canGoBack: store.state.currentIndex > 0,
                isFinalStep: store.state.isOnFinalStep,
                isBusy: store.state.shouldShowCompletionOverlay,
                onBack: { store.send(.back) },
                onPrimary: { store.send(.advance) },
                onSkip: { store.send(.skip) }
            )
        }
    }
}

private struct OnboardingStepCard: View {
    let step: OnboardingDomain.State.Step

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: step.icon)
                .font(.system(size: 44))
                .frame(width: 76, height: 76)
                .foregroundStyle(accentColor)
                .background(accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.title2.bold())
                Text(step.message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(step.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 12)
    }

    private var accentColor: Color {
        switch step.accent {
        case .mint: .mint
        case .orange: .orange
        case .blue: .blue
        }
    }
}

private struct OnboardingPagerIndicator: View {
    let steps: [OnboardingDomain.State.Step]
    let current: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, _ in
                Capsule(style: .continuous)
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: index == current ? 36 : 14, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OnboardingActionBar: View {
    let canGoBack: Bool
    let isFinalStep: Bool
    let isBusy: Bool
    let onBack: () -> Void
    let onPrimary: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if !isFinalStep {
                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(.borderless)
                .disabled(isBusy)
            }

            Button("Back") {
                onBack()
            }
            .buttonStyle(.bordered)
            .disabled(!canGoBack || isBusy)

            Button(isFinalStep ? "Let's go" : "Next") {
                onPrimary()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
        }
    }
}

private extension OnboardingDomain.State {
    var loadedState: LoadedState? {
        if case let .loaded(loadedState) = self {
            return loadedState
        }
        return nil
    }

    var steps: [OnboardingDomain.State.Step] {
        loadedState?.steps ?? []
    }

    var currentIndex: Int {
        loadedState?.currentIndex ?? 0
    }

    var shouldShowCompletionOverlay: Bool {
        loadedState?.isCompleting ?? false
    }

    var isOnFinalStep: Bool {
        guard let loadedState else { return false }
        return loadedState.steps.indices.last == loadedState.currentIndex
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
    let appStore = Store(
        initialState: AppDomain.State(route: .onboarding(.init())),
        environment: environment,
        reducer: { state, action, environment in
            AppDomain.reducer(state: &state, action: action, environment: environment)
        }
    )
    let scopedStore = appStore.scope(
        state: { state in
            if case let .onboarding(onboardingState) = state.route {
                return onboardingState
            }
            return .init()
        },
        action: AppDomain.Action.onboarding
    )
    return OnboardingRootView(store: scopedStore)
}
