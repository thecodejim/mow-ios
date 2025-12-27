import Foundation

protocol AnalyticsService: Sendable {
    func track(event: String, metadata: [String: String]) async
}

// MARK: - Mock services

struct MockAnalyticsService: AnalyticsService {
    func track(event: String, metadata: [String: String]) async {
        #if DEBUG
        print("Analytics:", event, metadata)
        #endif
    }
}
