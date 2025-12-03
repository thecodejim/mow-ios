import Foundation
import SwiftUI

enum OnboardingDomain {
    struct Environment {
        let appEnvironment: AppEnvironment
        let analytics: AnalyticsService
        let logger: Logger
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
        case error(ErrorState)

        struct LoadedState: Equatable {
            var steps: [Step] = Step.catalog
            var currentIndex = 0
            var isCompleting = false
        }

        struct ErrorState: Equatable {
            var message: String
        }
        
        struct Step: Identifiable, Equatable {
            enum Accent: String, Equatable, CaseIterable {
                case mint
                case orange
                case blue
            }

            let id: Int
            let title: LocalizedStringKey
            let message: LocalizedStringKey
            let detail: LocalizedStringKey
            let icon: String
            let accent: Accent
        }
    }

    enum DelegateAction: Equatable {
        case finished
    }

    enum Action: Equatable {
        case onAppear
        case advance
        case back
        case skip
        case setIndex(Int)
        case finished
        case delegate(DelegateAction)
    }

    @MainActor
    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        case .onAppear:
            if case .loading = state {
                state = .loaded(.init())
            }
            environment.logger.info(
                "Onboarding appeared",
                category: .ui,
                metadata: ["environment": .public(environment.appEnvironment.name.rawValue)]
            )
            return .fireAndForget {
                await environment.analytics.track(
                    event: OnboardingDomain.AnalyticsEvent.viewed,
                    metadata: [
                        OnboardingDomain.AnalyticsMetadataKey.environment: environment.appEnvironment.name.rawValue
                    ]
                )
            }

        case .advance:
            guard case var .loaded(loadedState) = state, !loadedState.isCompleting else { return .none }

            if loadedState.currentIndex < loadedState.steps.count - 1 {
                loadedState.currentIndex += 1
                state = .loaded(loadedState)
                environment.logger.debug(
                    "Advanced onboarding step",
                    category: .ui,
                    metadata: ["currentIndex": .public(loadedState.currentIndex)]
                )
                let stepIndex = loadedState.currentIndex
                return .fireAndForget {
                    await environment.analytics.track(
                        event: OnboardingDomain.AnalyticsEvent.step,
                        metadata: [OnboardingDomain.AnalyticsMetadataKey.step: "\(stepIndex)"]
                    )
                }
            } else {
                loadedState.isCompleting = true
                state = .loaded(loadedState)
                environment.logger.info(
                    "Completing onboarding",
                    category: .ui,
                    metadata: ["totalSteps": .public(loadedState.steps.count)]
                )
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
            environment.logger.info(
                "Onboarding skipped",
                category: .ui,
                metadata: ["currentIndex": .public(loadedState.currentIndex)]
            )
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
            environment.logger.info(
                "Onboarding finished",
                category: .ui,
                metadata: ["stepsCompleted": .public(loadedState.steps.count)]
            )
            return .task {
                await environment.analytics.track(event: OnboardingDomain.AnalyticsEvent.completed, metadata: [:])
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
