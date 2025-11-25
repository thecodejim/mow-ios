import Foundation

enum OnboardingDomain {
    struct State: Equatable, Sendable {
        var steps: [Step] = Step.catalog
        var currentIndex = 0
        var isLoading = false
    }

    struct Environment: @unchecked Sendable {
        let appEnvironment: AppEnvironment
        let analytics: any AnalyticsService
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

        static let catalog: [Step] = [
            Step(id: 0, title: "Plan your day", message: "Line up routes, meals, and reminders in one place.", detail: "We load your territory, favorite recipients, and notes so you can focus on deliveries.", icon: "calendar.badge.clock", accent: .mint),
            Step(id: 1, title: "Stay in sync", message: "Coordinators see your status in real time.", detail: "Push updates to dispatch with a single tap when traffic or weather gets in the way.", icon: "point.3.connected.trianglepath.dotted", accent: .orange),
            Step(id: 2, title: "Deliver with confidence", message: "Meals, dietary notes, and wellness flags travel with you.", detail: "Every household profile highlights what matters most before you knock.", icon: "heart.text.square", accent: .blue)
        ]
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
            return .fireAndForget {
                await environment.analytics.track(
                    event: "onboarding_viewed",
                    metadata: ["environment": environment.appEnvironment.name.rawValue]
                )
            }

        case .advance:
            guard !state.isLoading else { return .none }

            if state.currentIndex < state.steps.count - 1 {
                state.currentIndex += 1
                let stepIndex = state.currentIndex
                return .fireAndForget {
                    await environment.analytics.track(
                        event: "onboarding_step",
                        metadata: ["step": "\(stepIndex)"]
                    )
                }
            } else {
                state.isLoading = true
                return .task {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    return .finished
                }
            }

        case .back:
            guard state.currentIndex > 0 else { return .none }
            state.currentIndex -= 1
            return .none

        case .skip:
            guard !state.isLoading else { return .none }
            state.isLoading = true
            return .task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return .finished
            }

        case let .setIndex(newIndex):
            guard newIndex >= 0, newIndex < state.steps.count else { return .none }
            state.currentIndex = newIndex
            return .none

        case .finished:
            state.isLoading = false
            return .task {
                await environment.analytics.track(event: "onboarding_completed", metadata: [:])
                return .delegate(.finished)
            }

        case .delegate:
            return .none
        }
    }
}

