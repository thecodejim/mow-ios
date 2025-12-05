import SwiftUI

@main
struct MowApp: App {
    // Static so it’s built once even in previews / multiple app instances
    private static let dependencies = AppDependencies.live(environment: .current)

    private static let isRunningUnitTests = AppEnvironment.isRunningUnitTests

    @StateObject private var coordinator = AppCoordinator(dependencies: dependencies)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootView
        }
        .onChange(of: scenePhase) { _, phase in
            guard !MowApp.isRunningUnitTests else { return }
            guard phase == .background || phase == .inactive else { return }
            Task {
                await MowApp.dependencies.logger.flush()
            }
        }
    }
}

private extension MowApp {
    @ViewBuilder
    var rootView: some View {
        if MowApp.isRunningUnitTests {
            UnitTestPlaceholderView()
        } else {
            AppRootView(coordinator: coordinator)
        }
    }
}
