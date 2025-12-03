import SwiftUI
import Foundation

extension OnboardingDomain {
    enum AnalyticsEvent {
        static let viewed = "onboarding_viewed"
        static let step = "onboarding_step"
        static let completed = "onboarding_completed"
    }

    enum AnalyticsMetadataKey {
        static let environment = "environment"
        static let step = "step"
    }

    enum Copy {
        fileprivate enum Key {
            static let loadingTitle = "onboarding.loading.title"
            static let completionOverlay = "onboarding.completion.overlay"
            static let retryButton = "onboarding.error.retry"
            static let skipButton = "onboarding.actions.skip"
            static let backButton = "onboarding.actions.back"
            static let nextButton = "onboarding.actions.next"
            static let launchButton = "onboarding.actions.launch"

            static let stepPlanTitle = "onboarding.steps.plan.title"
            static let stepPlanMessage = "onboarding.steps.plan.message"
            static let stepPlanDetail = "onboarding.steps.plan.detail"

            static let stepSyncTitle = "onboarding.steps.sync.title"
            static let stepSyncMessage = "onboarding.steps.sync.message"
            static let stepSyncDetail = "onboarding.steps.sync.detail"

            static let stepConfidenceTitle = "onboarding.steps.confidence.title"
            static let stepConfidenceMessage = "onboarding.steps.confidence.message"
            static let stepConfidenceDetail = "onboarding.steps.confidence.detail"
        }

        static var loadingTitle: LocalizedStringKey { .init(Key.loadingTitle) }
        static var completionOverlayMessage: LocalizedStringKey { .init(Key.completionOverlay) }
        static var retryButtonTitle: LocalizedStringKey { .init(Key.retryButton) }
        static var skipButtonTitle: LocalizedStringKey { .init(Key.skipButton) }
        static var backButtonTitle: LocalizedStringKey { .init(Key.backButton) }
        static var nextButtonTitle: LocalizedStringKey { .init(Key.nextButton) }
        static var launchButtonTitle: LocalizedStringKey { .init(Key.launchButton) }

        static var stepPlanTitle: LocalizedStringKey { .init(Key.stepPlanTitle) }
        static var stepPlanMessage: LocalizedStringKey { .init(Key.stepPlanMessage) }
        static var stepPlanDetail: LocalizedStringKey { .init(Key.stepPlanDetail) }

        static var stepSyncTitle: LocalizedStringKey { .init(Key.stepSyncTitle) }
        static var stepSyncMessage: LocalizedStringKey { .init(Key.stepSyncMessage) }
        static var stepSyncDetail: LocalizedStringKey { .init(Key.stepSyncDetail) }

        static var stepConfidenceTitle: LocalizedStringKey { .init(Key.stepConfidenceTitle) }
        static var stepConfidenceMessage: LocalizedStringKey { .init(Key.stepConfidenceMessage) }
        static var stepConfidenceDetail: LocalizedStringKey { .init(Key.stepConfidenceDetail) }

        static func string(_ key: String) -> String {
            NSLocalizedString(key, bundle: .main, comment: "")
        }
    }
}

extension OnboardingDomain.State.Step {
    static let catalog: [Self] = [
        .init(
            id: 0,
            title: OnboardingDomain.Copy.stepPlanTitle,
            message: OnboardingDomain.Copy.stepPlanMessage,
            detail: OnboardingDomain.Copy.stepPlanDetail,
            icon: "calendar.badge.clock",
            accent: .mint
        ),
        .init(
            id: 1,
            title: OnboardingDomain.Copy.stepSyncTitle,
            message: OnboardingDomain.Copy.stepSyncMessage,
            detail: OnboardingDomain.Copy.stepSyncDetail,
            icon: "point.3.connected.trianglepath.dotted",
            accent: .orange
        ),
        .init(
            id: 2,
            title: OnboardingDomain.Copy.stepConfidenceTitle,
            message: OnboardingDomain.Copy.stepConfidenceMessage,
            detail: OnboardingDomain.Copy.stepConfidenceDetail,
            icon: "heart.text.square",
            accent: .blue
        )
    ]
}
