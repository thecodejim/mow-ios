import SwiftUI

@main
struct MowApp: App {
    // Static so it’s built once even in previews / multiple app instances
    private static let dependencies = AppDependencies.live(environment: .current)

    @StateObject private var coordinator = AppCoordinator(dependencies: dependencies)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background || phase == .inactive else { return }
            Task {
                await MowApp.dependencies.logger.flush()
            }
        }
    }
}
