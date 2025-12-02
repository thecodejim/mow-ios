import SwiftUI

@main
struct MowApp: App {
    // Static so it’s built once even in previews / multiple app instances
    private static let dependencies = AppDependencies.live(environment: .current)

    @StateObject private var coordinator = AppCoordinator(dependencies: dependencies)

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}
