extension HomeDomain {
    enum Copy {
        static let dashboardHeadline = "You're ready for today."
        static let refreshFallbackError = "Unable to refresh right now."
    }
}

extension HomeDomain.State.Dashboard {
    static let defaultHeadline = HomeDomain.Copy.dashboardHeadline
}

extension HomeDomain.Tab {
    private var content: (title: String, icon: String) {
        switch self {
        case .dashboard: ("Plan", "rectangle.grid.2x2")
        case .meals: ("Meals", "fork.knife")
        case .deliveries: ("Deliveries", "map")
        case .profile: ("Profile", "person.crop.circle")
        }
    }

    var title: String { content.title }
    var icon: String { content.icon }
}
