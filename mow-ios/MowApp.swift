import SwiftUI

@main
struct MowApp: App {
    @StateObject private var coordinator: AppCoordinator

    // Static so it’s built once even in previews / multiple app instances
    private static let dependencies = AppDependencies.live(environment: .current)
    
    init() {
        _coordinator = StateObject(wrappedValue: AppCoordinator(dependencies: Self.dependencies))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}
