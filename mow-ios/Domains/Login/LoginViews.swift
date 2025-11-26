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
                Text("Welcome back")
                    .font(.largeTitle.bold())
                Text("Sign in to get rolling on today's deliveries.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 18) {
                TextField("Email", text: Binding(
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
                        SecureField("Password", text: Binding(
                            get: { store.state.loginForm.password },
                            set: { store.send(.passwordChanged($0)) }
                        ))
                        .textContentType(.password)
                    } else {
                        TextField("Password", text: Binding(
                            get: { store.state.loginForm.password },
                            set: { store.send(.passwordChanged($0)) }
                        ))
                        .textContentType(.password)
                    }

                    Button(store.state.loginForm.isSecureEntry ? "Show" : "Hide") {
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

            Button("Forgot password?") {
                store.send(.forgotPasswordTapped)
            }
            .font(.footnote.weight(.semibold))

            Button {
                store.send(.submit)
            } label: {
                HStack {
                    Spacer()
                    Text("Sign in")
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
                deviceInfo: store.environment.login.deviceInfo
            )
                .disabled(!store.state.isDebugInfoButtonEnabled)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay {
            if store.state.isSubmitting {
                BusyOverlay(text: "Checking your credentials…")
            }
        }
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
            Section("Email") {
                TextField("name@email.com", text: Binding(
                    get: { forgotState.email },
                    set: { store.send(.forgotEmailChanged($0)) }
                ))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            }

            Section {
                Button("Send reset link") {
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
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.state.isSendingReset {
                BusyOverlay(text: "Sending instructions…")
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
    let dependencies = AppDependencies.live()
    let environment = AppDomain.Environment(
        appEnvironment: dependencies.environment,
        onboarding: .init(appEnvironment: dependencies.environment, analytics: dependencies.analytics),
        login: .init(appEnvironment: dependencies.environment, api: dependencies.api, keychain: dependencies.keychain, analytics: dependencies.analytics, deviceInfo: dependencies.deviceInfo),
        home: .init(appEnvironment: dependencies.environment, api: dependencies.api, deviceInfo: dependencies.deviceInfo)
    )
    let state = AppDomain.State(route: .login(.init()))
    let appStore = Store(
        initialState: state,
        environment: environment,
        reducer: { state, action, environment in
            AppDomain.reducer(state: &state, action: action, environment: environment)
        }
    )
    let scopedStore = appStore.scope(
        state: { state in
            if case let .login(childState) = state.route {
                return childState
            }
            return .init()
        },
        action: AppDomain.Action.login
    )
    LoginRootView(store: scopedStore)
}
