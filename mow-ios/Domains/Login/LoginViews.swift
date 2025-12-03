import SwiftUI

private enum Route: Hashable {
    case forgotPassword
}

struct LoginRootView: View {
    @ObservedObject var store: LoginScopedStore

    private var pathBinding: Binding<[Route]> {
        Binding(
            get: { store.state.isShowingForgot ? [.forgotPassword] : [] },
            set: { newValue in
                if newValue.isEmpty {
                    if store.state.isShowingForgot {
                        store.send(.dismissForgot)
                    }
                } else if let destination = newValue.last, destination == .forgotPassword {
                    if !store.state.isShowingForgot {
                        store.send(.forgotPasswordTapped)
                    }
                }
            }
        )
    }

    var body: some View {
        NavigationStack(path: pathBinding) {
            LoginScreen(store: store)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .forgotPassword:
                        ForgotPasswordView(store: store)
                    }
                }
        }
    }
}

private struct LoginScreen: View {
    @ObservedObject var store: LoginScopedStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LoginDomain.Copy.welcomeTitle)
                    .font(.largeTitle.bold())
                Text(LoginDomain.Copy.welcomeSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 18) {
                TextField(LoginDomain.Copy.emailFieldPlaceholder, text: Binding(
                    get: { store.state.loginForm.email },
                    set: { store.send(.emailChanged($0)) }
                ))
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                ZStack(alignment: .trailing) {
                    if store.state.loginForm.isSecureEntry {
                        SecureField(LoginDomain.Copy.passwordFieldPlaceholder, text: Binding(
                            get: { store.state.loginForm.password },
                            set: { store.send(.passwordChanged($0)) }
                        ))
                        .textContentType(.password)
                    } else {
                        TextField(LoginDomain.Copy.passwordFieldPlaceholder, text: Binding(
                            get: { store.state.loginForm.password },
                            set: { store.send(.passwordChanged($0)) }
                        ))
                        .textContentType(.password)
                    }

                    Button(store.state.loginForm.isSecureEntry ? LoginDomain.Copy.showPasswordTitle : LoginDomain.Copy.hidePasswordTitle) {
                        store.send(.toggleSecureEntry)
                    }
                    .font(.caption.bold())
                    .padding(.trailing, 16)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let error = store.state.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                }
            }

            Button(LoginDomain.Copy.forgotPasswordButtonTitle) {
                store.send(.forgotPasswordTapped)
            }
            .font(.footnote.weight(.semibold))

            Button {
                store.send(.submit)
            } label: {
                HStack {
                    Spacer()
                    Text(LoginDomain.Copy.signInButtonTitle)
                        .font(.headline)
                    Spacer()
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.state.isSubmitting)

            Spacer()

            DebugInfoButton(
                isPresented: debugInfoBinding,
                environment: store.environment.appEnvironment,
                deviceInfo: store.environment.deviceInfo,
                logHistory: store.environment.logHistory
            )
                .disabled(!store.state.isDebugInfoButtonEnabled)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay {
            if store.state.isSubmitting {
                BusyOverlay(text: LoginDomain.Copy.submittingOverlayMessage)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: store.state.isSubmitting)
        .task {
            store.send(.onAppear)
        }
    }
    
    private var debugInfoBinding: Binding<Bool> {
        Binding(
            get: { store.state.isShowingDebugInfo },
            set: { value in
                guard store.state.isDebugInfoButtonEnabled else { return }
                store.send(.setDebugInfoPresented(value))
            }
        )
    }
}

private struct ForgotPasswordView: View {
    @ObservedObject var store: LoginScopedStore

    var body: some View {
        let forgotState = store.state.forgotState
        Form {
            Section(LoginDomain.Copy.emailSectionTitle) {
                TextField(LoginDomain.Copy.emailSamplePlaceholder, text: Binding(
                    get: { forgotState.email },
                    set: { store.send(.forgotEmailChanged($0)) }
                ))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            }

            Section {
                Button(LoginDomain.Copy.sendResetButtonTitle) {
                    store.send(.sendReset)
                }
                .disabled(store.state.isSendingReset)
            }

            if case let .success(message) = forgotState.status {
                Section {
                    Label(message, systemImage: "envelope.badge")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            }

            if case let .failure(message) = forgotState.status {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(LoginDomain.Copy.forgotPasswordNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.state.isSendingReset {
                BusyOverlay(text: LoginDomain.Copy.resetOverlayMessage)
            }
        }
    }
}

private extension LoginDomain.State {
    var loginForm: LoginDomain.State.LoginForm {
        switch self {
        case let .loaded(loadedState), let .submitting(loadedState):
            return loadedState.form
        case let .error(errorState):
            return errorState.form
        case let .forgotPassword(forgotState):
            return forgotState.resume.form
        case .loading, .authenticated:
            return .init()
        }
    }

    var errorMessage: String? {
        if case let .error(errorState) = self {
            return errorState.message
        }
        return nil
    }

    var isSubmitting: Bool {
        if case .submitting = self {
            return true
        }
        return false
    }

    var isShowingForgot: Bool {
        if case .forgotPassword = self {
            return true
        }
        return false
    }

    var forgotState: LoginDomain.State.ForgotPasswordState {
        if case let .forgotPassword(forgotState) = self {
            return forgotState
        }
        return .init()
    }

    var isSendingReset: Bool {
        if case let .forgotPassword(forgotState) = self, forgotState.status == .sending {
            return true
        }
        return false
    }

    var isDebugInfoButtonEnabled: Bool {
        switch self {
        case .loading, .submitting:
            return false
        default:
            return true
        }
    }
}

#Preview {
    @Previewable @StateObject var coordinator: AppCoordinator = {
        let dependencies = AppDependencies.mock(environment: .preview)
        let coordinator = AppCoordinator(dependencies: dependencies)
        // Set the initial route to login
        coordinator.store.send(.showLogin)
        return coordinator
    }()
    
    LoginRootView(store: coordinator.loginStore)
//        .environment(\.locale, .init(identifier: "es"))
}
