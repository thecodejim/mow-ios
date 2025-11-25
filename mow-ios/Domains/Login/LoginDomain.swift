import Foundation

enum LoginDomain {
    struct Environment: @unchecked Sendable {
        let appEnvironment: AppEnvironment
        let api: any APIService
        let keychain: any KeychainService
        let analytics: any AnalyticsService
    }

    enum State: Equatable, Sendable {
        case loading
        case loaded(LoadedState)
        case submitting(LoadedState)
        case forgotPassword(ForgotPasswordState)
        case authenticated(AuthSession)
        case error(ErrorState)
        
        struct LoadedState: Equatable, Sendable {
            var form: LoginForm

            init(form: LoginForm = .init()) {
                self.form = form
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

        struct ErrorState: Equatable, Sendable {
            var form: LoginForm
            var message: String
        }

        struct LoginForm: Equatable, Sendable {
            var email: String
            var password: String
            var isSecureEntry: Bool

            init(
                email: String = Self.defaultEmail,
                password: String = Self.defaultPassword,
                isSecureEntry: Bool = true
            ) {
                self.email = email
                self.password = password
                self.isSecureEntry = isSecureEntry
            }

            var isValid: Bool {
                email.isValidEmail && password.count >= Self.minPasswordLength
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
        case loginResponse(State.LoginResponse)
        case forgotPasswordTapped
        case forgotEmailChanged(String)
        case sendReset
        case resetResponse(State.ResetResponse)
        case dismissForgot
        case clearError
        case delegate(DelegateAction)
    }

    static func reducer(state: inout State, action: Action, environment: Environment) -> Effect<Action> {
        switch action {
        case .onAppear:
            if case .loading = state {
                state = .loaded(.init())
            }
            return .fireAndForget {
                await environment.analytics.track(event: LoginDomain.AnalyticsEvent.loginViewed, metadata: [:])
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
                state = .error(.init(form: loadedState.form, message: LoginDomain.Copy.invalidEmail))
                return .none
            }

            guard loadedState.form.password.count >= LoginDomain.State.LoginForm.minPasswordLength else {
                state = .error(.init(form: loadedState.form, message: LoginDomain.Copy.passwordTooShort))
                return .none
            }

            state = .submitting(loadedState)
            let email = loadedState.form.email
            let password = loadedState.form.password

            return .task {
                do {
                    let session = try await environment.api.login(email: email, password: password)
                    try await environment.keychain.save(token: session.token)
                    await environment.analytics.track(event: LoginDomain.AnalyticsEvent.loginSuccess, metadata: [:])
                    return .loginResponse(.success(session))
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? LoginDomain.Copy.loginFallbackError
                    await environment.analytics.track(
                        event: LoginDomain.AnalyticsEvent.loginFailure,
                        metadata: ["reason": message]
                    )
                    return .loginResponse(.failure(.service(message)))
                }
            }

        case let .loginResponse(result):
            switch result {
            case let .success(session):
                state = .authenticated(session)
                return .send(.delegate(.authenticated(session)))

            case let .failure(error):
                let loadedState = state.currentLoadedState()
                state = .error(.init(form: loadedState.form, message: error.message))
                return .none
            }

        case .forgotPasswordTapped:
            let resume = state.currentLoadedState()
            var forgotState = State.ForgotPasswordState()
            forgotState.email = resume.form.email
            forgotState.resume = resume
            state = .forgotPassword(forgotState)
            return .none

        case let .forgotEmailChanged(email):
            guard case var .forgotPassword(forgotState) = state else { return .none }
            forgotState.email = email
            forgotState.status = .idle
            state = .forgotPassword(forgotState)
            return .none

        case .sendReset:
            guard case var .forgotPassword(forgotState) = state else { return .none }

            guard forgotState.email.isValidEmail else {
                forgotState.status = .failure(message: LoginDomain.Copy.forgotInvalidEmail)
                state = .forgotPassword(forgotState)
                return .none
            }

            forgotState.status = .sending
            state = .forgotPassword(forgotState)

            let email = forgotState.email

            return .task {
                do {
                    try await environment.api.sendPasswordReset(email: email)
                    await environment.analytics.track(event: LoginDomain.AnalyticsEvent.resetRequested, metadata: [:])
                    return .resetResponse(.success)
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? LoginDomain.Copy.resetFallbackError
                    return .resetResponse(.failure(.service(message)))
                }
            }

        case let .resetResponse(result):
            guard case var .forgotPassword(forgotState) = state else { return .none }

            switch result {
            case .success:
                forgotState.status = .success(message: LoginDomain.Copy.resetSuccessMessage(forEmail: forgotState.email))
            case let .failure(error):
                forgotState.status = .failure(message: error.message)
            }

            state = .forgotPassword(forgotState)
            return .none

        case .dismissForgot:
            guard case let .forgotPassword(forgotState) = state else { return .none }
            state = .loaded(forgotState.resume)
            return .none

        case .clearError:
            guard case let .error(errorState) = state else { return .none }
            state = .loaded(.init(form: errorState.form))
            return .none

        case .delegate:
            return .none
        }
    }
}

private extension LoginDomain.State {
    mutating func updateForm(_ update: (inout LoginDomain.State.LoginForm) -> Void) {
        switch self {
        case var .loaded(loadedState):
            update(&loadedState.form)
            self = .loaded(loadedState)
        case var .submitting(loadedState):
            update(&loadedState.form)
            self = .submitting(loadedState)
        case var .error(errorState):
            update(&errorState.form)
            self = .loaded(.init(form: errorState.form))
        case var .forgotPassword(forgotState):
            update(&forgotState.resume.form)
            self = .forgotPassword(forgotState)
        case .loading:
            var form = LoginDomain.State.LoginForm()
            update(&form)
            self = .loaded(.init(form: form))
        case .authenticated:
            break
        }
    }

    func currentLoadedState() -> LoginDomain.State.LoadedState {
        switch self {
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

extension LoginDomain.State {
    init() {
        self = .loaded(.init())
    }
}
