import Foundation

// MARK: - Home API Service Protocol

protocol HomeAPIService: Sendable {
    func fetchHomeSnapshot() async throws -> HomeSnapshot
}

// MARK: - DTOs

struct HomeSnapshot: Equatable, Codable {
    struct DashboardStat: Identifiable, Equatable, Codable {
        let id: UUID
        let label: String
        let value: String
        let trend: String

        init(id: UUID = UUID(), label: String, value: String, trend: String) {
            self.id = id
            self.label = label
            self.value = value
            self.trend = trend
        }
    }

    struct Meal: Identifiable, Equatable, Codable {
        let id: UUID
        let title: String
        let calories: Int
        let deliveryTime: Date

        init(id: UUID = UUID(), title: String, calories: Int, deliveryTime: Date) {
            self.id = id
            self.title = title
            self.calories = calories
            self.deliveryTime = deliveryTime
        }
    }

    struct Delivery: Identifiable, Equatable, Codable {
        let id: UUID
        let recipient: String
        let address: String
        let distanceMiles: Double

        init(id: UUID = UUID(), recipient: String, address: String, distanceMiles: Double) {
            self.id = id
            self.recipient = recipient
            self.address = address
            self.distanceMiles = distanceMiles
        }
    }

    struct Profile: Equatable, Codable {
        let name: String
        let role: String
        let territory: String

        init(name: String, role: String, territory: String) {
            self.name = name
            self.role = role
            self.territory = territory
        }
    }

    let headline: String
    let stats: [DashboardStat]
    let meals: [Meal]
    let deliveries: [Delivery]
    let profile: Profile

    init(
        headline: String,
        stats: [DashboardStat],
        meals: [Meal],
        deliveries: [Delivery],
        profile: Profile
    ) {
        self.headline = headline
        self.stats = stats
        self.meals = meals
        self.deliveries = deliveries
        self.profile = profile
    }
}

// MARK: - Mock Implementation

struct MockHomeAPIService: HomeAPIService {
    func fetchHomeSnapshot() async throws -> HomeSnapshot {
        // TODO: Implement when API endpoint is available
        // For now, use mock implementation
        try await Task.sleep(nanoseconds: 800_000_000)
        
        return HomeSnapshot(
            headline: "You have 12 meals and 4 routes today.",
            stats: [
                .init(label: "Families Served", value: "32", trend: "+4 vs yesterday"),
                .init(label: "Miles", value: "18.4", trend: "On track"),
                .init(label: "Volunteer Hours", value: "6h 15m", trend: "Ahead of plan")
            ],
            meals: [
                .init(title: "Low-sodium chicken bowl", calories: 540, deliveryTime: .now.addingTimeInterval(1_800)),
                .init(title: "Gluten-free pasta", calories: 610, deliveryTime: .now.addingTimeInterval(3_600)),
                .init(title: "Fresh salad kit", calories: 320, deliveryTime: .now.addingTimeInterval(7_200))
            ],
            deliveries: [
                .init(recipient: "The Johnson Family", address: "18 W 34th St", distanceMiles: 1.3),
                .init(recipient: "Ms. Chen", address: "44 Spring Ave", distanceMiles: 2.1),
                .init(recipient: "The Rivera Household", address: "220 Beacon Rd", distanceMiles: 4.8)
            ],
            profile: .init(name: "Taylor West", role: "Lead Volunteer", territory: "North Austin")
        )
    }
}
