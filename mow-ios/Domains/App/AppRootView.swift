import SwiftUI

struct AppRootView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.route {
            case .onboarding:
                OnboardingRootView(store: coordinator.onboardingStore)
            case .login:
                LoginRootView(store: coordinator.loginStore)
            case .home:
                HomeRootView(store: coordinator.homeStore)
            }
        }
        .animation(.easeInOut, value: coordinator.route)
    }
}
