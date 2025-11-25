import SwiftUI

struct AppCoordinatorView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.route {
            case .onboarding:
                OnboardingCoordinatorView(store: coordinator.onboardingStore)
            case .login:
                LoginCoordinatorView(store: coordinator.loginStore)
            case .home:
                HomeCoordinatorView(store: coordinator.homeStore)
            }
        }
        .animation(.easeInOut, value: coordinator.route)
    }
}
