import SwiftUI

struct LoginCoordinatorView: View {
    @ObservedObject var store: LoginScopedStore

    private var pathBinding: Binding<[LoginDomain.Route]> {
        Binding(
            get: {
                guard let route = store.state.route else { return [] }
                return [route]
            },
            set: { newValue in
                if newValue.isEmpty {
                    if store.state.route != nil {
                        store.send(.dismissForgot)
                    }
                } else if let destination = newValue.last {
                    switch destination {
                    case .forgotPassword:
                        if store.state.route == nil {
                            store.send(.forgotPasswordTapped)
                        }
                    }
                }
            }
        )
    }

    var body: some View {
        NavigationStack(path: pathBinding) {
            LoginScreen(store: store)
                .navigationDestination(for: LoginDomain.Route.self) { route in
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
                    get: { store.state.form.email },
                    set: { store.send(.emailChanged($0)) }
                ))
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                ZStack(alignment: .trailing) {
                    if store.state.form.isSecureEntry {
                        SecureField("Password", text: Binding(
                            get: { store.state.form.password },
                            set: { store.send(.passwordChanged($0)) }
                        ))
                        .textContentType(.password)
                    } else {
                        TextField("Password", text: Binding(
                            get: { store.state.form.password },
                            set: { store.send(.passwordChanged($0)) }
                        ))
                        .textContentType(.password)
                    }

                    Button(store.state.form.isSecureEntry ? "Show" : "Hide") {
                        store.send(.toggleSecureEntry)
                    }
                    .font(.caption.bold())
                    .padding(.trailing, 16)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let error = store.state.form.errorMessage {
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
            .disabled(store.state.isLoading)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay {
            if store.state.isLoading {
                BusyOverlay(text: "Checking your credentials…")
            }
        }
        .task {
            store.send(.onAppear)
        }
    }
}

private struct ForgotPasswordView: View {
    @ObservedObject var store: LoginScopedStore

    var body: some View {
        Form {
            Section("Email") {
                TextField("name@email.com", text: Binding(
                    get: { store.state.forgot.email },
                    set: { store.send(.forgotEmailChanged($0)) }
                ))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            }

            Section {
                Button("Send reset link") {
                    store.send(.sendReset)
                }
                .disabled(store.state.isLoading)
            }

            if case let .success(message) = store.state.forgot.status {
                Section {
                    Label(message, systemImage: "envelope.badge")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            }

            if case let .failure(message) = store.state.forgot.status {
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
            if store.state.isLoading {
                BusyOverlay(text: "Sending instructions…")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    store.send(.dismissForgot)
                }
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.live()
    let environment = AppDomain.Environment(
        appEnvironment: dependencies.environment,
        onboarding: .init(appEnvironment: dependencies.environment, analytics: dependencies.analytics),
        login: .init(appEnvironment: dependencies.environment, api: dependencies.api, keychain: dependencies.keychain, analytics: dependencies.analytics),
        home: .init(api: dependencies.api)
    )
    let state = AppDomain.State(route: .login(.init()))
    let appStore = Store(initialState: state, environment: environment, reducer: AppDomain.reducer)
    let scopedStore = appStore.scope(
        state: { state in
            if case let .login(childState) = state.route {
                return childState
            }
            return .init()
        },
        action: AppDomain.Action.login
    )
    return LoginCoordinatorView(store: scopedStore)
}
