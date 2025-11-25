import Foundation

enum OnboardingDomain {
    struct Environment: @unchecked Sendable {
        let appEnvironment: AppEnvironment
        let analytics: any AnalyticsService
    }

    enum State: Equatable, Sendable {
        case loading
        case loaded(LoadedState)
        case error(ErrorState)

        struct LoadedState: Equatable, Sendable {
            var steps: [Step] = Step.catalog
            var currentIndex = 0
            var isCompleting = false
        }

        struct ErrorState: Equatable, Sendable {
            var message: String
        }
        
        struct Step: Identifiable, Equatable, Sendable {
            enum Accent: String, Equatable, CaseIterable, Sendable {
                case mint
                case orange
                case blue
            }

            let id: Int
            let title: String
            let message: String
            let detail: String
            let icon: String
            let accent: Accent
        }
    }

    enum DelegateAction: Equatable, Sendable {
        case finished
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case advance
        case back
        case skip
        case setIndex(Int)
        case finished
        case delegate(DelegateAction)
    }

    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        case .onAppear:
            if case .loading = state {
                state = .loaded(.init())
            }
            return .fireAndForget {
                await environment.analytics.track(
                    event: "onboarding_viewed",
                    metadata: ["environment": environment.appEnvironment.name.rawValue]
                )
            }

        case .advance:
            guard case var .loaded(loadedState) = state, !loadedState.isCompleting else { return .none }

            if loadedState.currentIndex < loadedState.steps.count - 1 {
                loadedState.currentIndex += 1
                state = .loaded(loadedState)
                let stepIndex = loadedState.currentIndex
                return .fireAndForget {
                    await environment.analytics.track(
                        event: "onboarding_step",
                        metadata: ["step": "\(stepIndex)"]
                    )
                }
            } else {
                loadedState.isCompleting = true
                state = .loaded(loadedState)
                return .task {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    return .finished
                }
            }

        case .back:
            guard case var .loaded(loadedState) = state, loadedState.currentIndex > 0 else { return .none }
            loadedState.currentIndex -= 1
            state = .loaded(loadedState)
            return .none

        case .skip:
            guard case var .loaded(loadedState) = state, !loadedState.isCompleting else { return .none }
            loadedState.isCompleting = true
            state = .loaded(loadedState)
            return .task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return .finished
            }

        case let .setIndex(newIndex):
            guard case var .loaded(loadedState) = state,
                  newIndex >= 0,
                  newIndex < loadedState.steps.count
            else { return .none }
            loadedState.currentIndex = newIndex
            state = .loaded(loadedState)
            return .none

        case .finished:
            guard case var .loaded(loadedState) = state else { return .none }
            loadedState.isCompleting = false
            state = .loaded(loadedState)
            return .task {
                await environment.analytics.track(event: "onboarding_completed", metadata: [:])
                return .delegate(.finished)
            }

        case .delegate:
            return .none
        }
    }
}

extension OnboardingDomain.State {
    init() {
        self = .loaded(.init())
    }
}

extension OnboardingDomain.State.Step {
    static let catalog: [OnboardingDomain.State.Step] = [
        OnboardingDomain.State.Step(
            id: 0,
            title: "Plan your day",
            message: "Line up routes, meals, and reminders in one place.",
            detail: "We load your territory, favorite recipients, and notes so you can focus on deliveries.",
            icon: "calendar.badge.clock",
            accent: .mint
        ),
        OnboardingDomain.State.Step(
            id: 1,
            title: "Stay in sync",
            message: "Coordinators see your status in real time.",
            detail: "Push updates to dispatch with a single tap when traffic or weather gets in the way.",
            icon: "point.3.connected.trianglepath.dotted",
            accent: .orange
        ),
        OnboardingDomain.State.Step(
            id: 2,
            title: "Deliver with confidence",
            message: "Meals, dietary notes, and wellness flags travel with you.",
            detail: "Every household profile highlights what matters most before you knock.",
            icon: "heart.text.square",
            accent: .blue
        )
    ]
}
