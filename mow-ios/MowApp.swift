import SwiftUI

@main
struct MowApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        let dependencies = AppDependencies.live()
        _coordinator = StateObject(wrappedValue: AppCoordinator(dependencies: dependencies))
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator)
        }
    }
}
