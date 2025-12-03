import SwiftUI
import Foundation

extension HomeDomain {
    enum Copy {
        fileprivate enum Key {
            static let dashboardHeadline = "home.dashboard.headline.default"
            static let refreshFallbackError = "home.refresh.error"

            static let alertTitle = "home.alert.title"
            static let loadingTitle = "home.loading.title"
            static let retryButton = "home.error.retry"
            static let refreshOverlay = "home.refresh.overlay"

            static let tabDashboard = "home.tab.dashboard"
            static let tabMeals = "home.tab.meals"
            static let tabDeliveries = "home.tab.deliveries"
            static let tabProfile = "home.tab.profile"

            static let volunteerSection = "home.profile.section.volunteer"
            static let nameLabel = "home.profile.label.name"
            static let roleLabel = "home.profile.label.role"
            static let territoryLabel = "home.profile.label.territory"
            static let logoutButton = "home.profile.logout"
            static let logoutFooter = "home.profile.logout.footer"

            static let mealsMetadata = "home.meals.metadata"
            static let deliveriesDistance = "home.deliveries.distance"
        }

        // MARK: - UI Copy
        static var alertTitle: LocalizedStringKey { .init(Key.alertTitle) }
        static var loadingTitle: LocalizedStringKey { .init(Key.loadingTitle) }
        static var retryButtonTitle: LocalizedStringKey { .init(Key.retryButton) }
        static var refreshOverlayMessage: LocalizedStringKey { .init(Key.refreshOverlay) }

        static var tabDashboardTitle: LocalizedStringKey { .init(Key.tabDashboard) }
        static var tabMealsTitle: LocalizedStringKey { .init(Key.tabMeals) }
        static var tabDeliveriesTitle: LocalizedStringKey { .init(Key.tabDeliveries) }
        static var tabProfileTitle: LocalizedStringKey { .init(Key.tabProfile) }

        static var volunteerSectionTitle: LocalizedStringKey { .init(Key.volunteerSection) }
        static var nameLabel: LocalizedStringKey { .init(Key.nameLabel) }
        static var roleLabel: LocalizedStringKey { .init(Key.roleLabel) }
        static var territoryLabel: LocalizedStringKey { .init(Key.territoryLabel) }
        static var logoutButtonTitle: LocalizedStringKey { .init(Key.logoutButton) }
        static var logoutFooterText: LocalizedStringKey { .init(Key.logoutFooter) }

        static func mealMetadata(calories: Int, deliveryTime: Date) -> LocalizedStringKey {
            "home.meals.metadata \(calories) \(deliveryTime, format: .dateTime.hour().minute())"
        }

        static func deliveryDistance(_ miles: Double) -> LocalizedStringKey {
            "home.deliveries.distance \(miles, format: .number.precision(.fractionLength(1)))"
        }

        // MARK: - Domain Copy
        static var dashboardHeadline: String { string(Key.dashboardHeadline) }
        static var refreshFallbackError: String { string(Key.refreshFallbackError) }

        private static func string(_ key: String) -> String {
            NSLocalizedString(key, bundle: .main, comment: "")
        }
    }
}

extension HomeDomain.State.Dashboard {
    static let defaultHeadline = HomeDomain.Copy.dashboardHeadline
}

extension HomeDomain.Tab {
    private var content: (title: LocalizedStringKey, icon: String) {
        switch self {
        case .dashboard: (HomeDomain.Copy.tabDashboardTitle, "rectangle.grid.2x2")
        case .meals: (HomeDomain.Copy.tabMealsTitle, "fork.knife")
        case .deliveries: (HomeDomain.Copy.tabDeliveriesTitle, "map")
        case .profile: (HomeDomain.Copy.tabProfileTitle, "person.crop.circle")
        }
    }

    var title: LocalizedStringKey { content.title }
    var icon: String { content.icon }
}
