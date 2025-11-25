import Foundation

enum LoginDomain {
    struct State: Equatable, Sendable {
        var view: ViewState

        init(view: ViewState = .loaded(.init())) {
            self.view = view
        }
    }

    enum ViewState: Equatable, Sendable {
        case loading
        case loaded(LoadedState)
        case submitting(LoadedState)
        case forgotPassword(ForgotPasswordState)
        case authenticated(AuthSession)
        case error(ErrorState)
    }

    struct LoadedState: Equatable, Sendable {
        var form: LoginForm

        init(form: LoginForm = .init()) {
            self.form = form
        }
    }

    struct ErrorState: Equatable, Sendable {
        var form: LoginForm
        var message: String
    }

    struct LoginForm: Equatable, Sendable {
        var email = "volunteer@example.com"
        var password = "password"
        var isSecureEntry = true

        var isValid: Bool {
            email.isValidEmail && password.count >= 4
        }
    }

    struct ForgotPasswordState: Equatable, Sendable {
        enum Status: Equatable, Sendable {
            case idle
            case sending
            case success(message: String)
            case failure(message: String)
        }

        var email = ""
        var status: Status = .idle
        var resume: LoadedState = .init()
    }

    struct Environment: @unchecked Sendable {
        let appEnvironment: AppEnvironment
        let api: any APIService
        let keychain: any KeychainService
        let analytics: any AnalyticsService
    }

    enum DomainError: Error, Equatable, Sendable {
        case validation(String)
        case service(String)

        var message: String {
            switch self {
            case let .validation(message): message
            case let .service(message): message
            }
        }
    }

    enum LoginResponse: Equatable, Sendable {
        case success(AuthSession)
        case failure(DomainError)
    }

    enum ResetResponse: Equatable, Sendable {
        case success
        case failure(DomainError)
    }

    enum DelegateAction: Equatable, Sendable {
        case authenticated(AuthSession)
        case logout
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case emailChanged(String)
        case passwordChanged(String)
        case toggleSecureEntry
        case submit
        case loginResponse(LoginResponse)
        case forgotPasswordTapped
        case forgotEmailChanged(String)
        case sendReset
        case resetResponse(ResetResponse)
        case dismissForgot
        case clearError
        case delegate(DelegateAction)
    }

    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        case .onAppear:
            if case .loading = state.view {
                state.view = .loaded(.init())
            }
            return .fireAndForget {
                await environment.analytics.track(event: "login_viewed", metadata: [:])
            }

        case let .emailChanged(email):
            state.updateForm { form in
                form.email = email
            }
            return .none

        case let .passwordChanged(password):
            state.updateForm { form in
                form.password = password
            }
            return .none

        case .toggleSecureEntry:
            state.updateForm { form in
                form.isSecureEntry.toggle()
            }
            return .none

        case .submit:
            let loadedState = state.currentLoadedState()

            guard loadedState.form.email.isValidEmail else {
                state.view = .error(.init(form: loadedState.form, message: "Please enter a valid email."))
                return .none
            }

            guard loadedState.form.password.count >= 4 else {
                state.view = .error(.init(form: loadedState.form, message: "Your password should be at least 4 characters."))
                return .none
            }

            state.view = .submitting(loadedState)
            let email = loadedState.form.email
            let password = loadedState.form.password

            return .task {
                do {
                    let session = try await environment.api.login(email: email, password: password)
                    try await environment.keychain.save(token: session.token)
                    await environment.analytics.track(event: "login_success", metadata: [:])
                    return .loginResponse(.success(session))
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? "We hit a snag signing you in."
                    await environment.analytics.track(event: "login_failure", metadata: ["reason": message])
                    return .loginResponse(.failure(.service(message)))
                }
            }

        case let .loginResponse(result):
            switch result {
            case let .success(session):
                state.view = .authenticated(session)
                return .send(.delegate(.authenticated(session)))

            case let .failure(error):
                let loadedState = state.currentLoadedState()
                state.view = .error(.init(form: loadedState.form, message: error.message))
                return .none
            }

        case .forgotPasswordTapped:
            let resume = state.currentLoadedState()
            var forgotState = ForgotPasswordState()
            forgotState.email = resume.form.email
            forgotState.resume = resume
            state.view = .forgotPassword(forgotState)
            return .none

        case let .forgotEmailChanged(email):
            guard case var .forgotPassword(forgotState) = state.view else { return .none }
            forgotState.email = email
            forgotState.status = .idle
            state.view = .forgotPassword(forgotState)
            return .none

        case .sendReset:
            guard case var .forgotPassword(forgotState) = state.view else { return .none }

            guard forgotState.email.isValidEmail else {
                forgotState.status = .failure(message: "Please enter a valid email address.")
                state.view = .forgotPassword(forgotState)
                return .none
            }

            forgotState.status = .sending
            state.view = .forgotPassword(forgotState)

            let email = forgotState.email

            return .task {
                do {
                    try await environment.api.sendPasswordReset(email: email)
                    await environment.analytics.track(event: "login_reset_requested", metadata: [:])
                    return .resetResponse(.success)
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? "We could not send that reset."
                    return .resetResponse(.failure(.service(message)))
                }
            }

        case let .resetResponse(result):
            guard case var .forgotPassword(forgotState) = state.view else { return .none }

            switch result {
            case .success:
                forgotState.status = .success(message: "We sent a magic link to \(forgotState.email).")
            case let .failure(error):
                forgotState.status = .failure(message: error.message)
            }

            state.view = .forgotPassword(forgotState)
            return .none

        case .dismissForgot:
            guard case let .forgotPassword(forgotState) = state.view else { return .none }
            state.view = .loaded(forgotState.resume)
            return .none

        case .clearError:
            guard case let .error(errorState) = state.view else { return .none }
            state.view = .loaded(.init(form: errorState.form))
            return .none

        case .delegate:
            return .none
        }
    }
}

private extension LoginDomain.State {
    mutating func updateForm(_ update: (inout LoginDomain.LoginForm) -> Void) {
        switch view {
        case var .loaded(loadedState):
            update(&loadedState.form)
            view = .loaded(loadedState)
        case var .submitting(loadedState):
            update(&loadedState.form)
            view = .submitting(loadedState)
        case var .error(errorState):
            update(&errorState.form)
            view = .loaded(.init(form: errorState.form))
        case var .forgotPassword(forgotState):
            update(&forgotState.resume.form)
            view = .forgotPassword(forgotState)
        case .loading:
            var form = LoginDomain.LoginForm()
            update(&form)
            view = .loaded(.init(form: form))
        case .authenticated:
            break
        }
    }

    func currentLoadedState() -> LoginDomain.LoadedState {
        switch view {
        case let .loaded(loadedState), let .submitting(loadedState):
            return loadedState
        case let .error(errorState):
            return .init(form: errorState.form)
        case let .forgotPassword(forgotState):
            return forgotState.resume
        case .authenticated, .loading:
            return .init()
        }
    }
}

private extension String {
    var isValidEmail: Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
