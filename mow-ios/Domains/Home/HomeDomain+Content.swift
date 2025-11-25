extension HomeDomain.Tab {
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
