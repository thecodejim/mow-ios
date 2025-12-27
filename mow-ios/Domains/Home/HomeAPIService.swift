import Foundation

// MARK: - Home API Service Protocol

protocol HomeAPIService: Sendable {
    func fetchHomeSnapshot() async throws -> HomeSnapshot
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
