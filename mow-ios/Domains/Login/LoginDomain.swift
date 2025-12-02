import Foundation

enum LoginDomain {
    struct Environment {
        let appEnvironment: AppEnvironment
        let api: APIService
        let keychain: KeychainService
        let analytics: AnalyticsService
        let deviceInfo: DeviceInfoService
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
        case submitting(LoadedState)
        case forgotPassword(ForgotPasswordState)
        case authenticated(AuthSession)
        case error(ErrorState)
        
        struct LoadedState: Equatable {
            var form: LoginForm
            var isShowingDebugInfo: Bool

            init(form: LoginForm = .init(), isShowingDebugInfo: Bool = false) {
                self.form = form
                self.isShowingDebugInfo = isShowingDebugInfo
            }
        }
        
        struct ForgotPasswordState: Equatable {
            enum Status: Equatable {
                case idle
                case sending
                case success(message: String)
                case failure(message: String)
            }

            var email = ""
            var status: Status = .idle
            var resume: LoadedState = .init()
        }

        struct ErrorState: Equatable {
            var form: LoginForm
            var message: String
            var isShowingDebugInfo: Bool = false
        }

        struct LoginForm: Equatable {
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
        
        enum LoginResponse: Equatable {
            case success(AuthSession)
            case failure(DomainError)
        }

        enum ResetResponse: Equatable {
            case success
            case failure(DomainError)
        }
    }

    enum DomainError: Error, Equatable {
        case validation(String)
        case service(String)

        var message: String {
            switch self {
            case let .validation(message): message
            case let .service(message): message
            }
        }
    }

    enum DelegateAction: Equatable {
        case authenticated(AuthSession)
        case logout
    }

    enum Action: Equatable {
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
        case setDebugInfoPresented(Bool)
        case delegate(DelegateAction)
    }

    @MainActor
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
            var loadedState = state.currentLoadedState()

            guard loadedState.form.email.isValidEmail else {
                state = .error(.init(
                    form: loadedState.form,
                    message: LoginDomain.Copy.invalidEmail,
                    isShowingDebugInfo: loadedState.isShowingDebugInfo
                ))
                return .none
            }

            guard loadedState.form.password.count >= LoginDomain.State.LoginForm.minPasswordLength else {
                state = .error(.init(
                    form: loadedState.form,
                    message: LoginDomain.Copy.passwordTooShort,
                    isShowingDebugInfo: loadedState.isShowingDebugInfo
                ))
                return .none
            }

            loadedState.isShowingDebugInfo = false
            state = .submitting(loadedState)
            let email = loadedState.form.email
            let password = loadedState.form.password
            let loginFallbackError = LoginDomain.Copy.loginFallbackError

            return .task {
                do {
                    let session = try await environment.api.login(email: email, password: password)
                    try await environment.keychain.save(token: session.token)
                    await environment.analytics.track(event: LoginDomain.AnalyticsEvent.loginSuccess, metadata: [:])
                    return .loginResponse(.success(session))
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? loginFallbackError
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
                state = .error(.init(
                    form: loadedState.form,
                    message: error.message,
                    isShowingDebugInfo: loadedState.isShowingDebugInfo
                ))
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
            let resetFallbackError = LoginDomain.Copy.resetFallbackError

            return .task {
                do {
                    try await environment.api.sendPasswordReset(email: email)
                    await environment.analytics.track(event: LoginDomain.AnalyticsEvent.resetRequested, metadata: [:])
                    return .resetResponse(.success)
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? resetFallbackError
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
            state = .loaded(.init(form: errorState.form, isShowingDebugInfo: errorState.isShowingDebugInfo))
            return .none

        case let .setDebugInfoPresented(isPresented):
            state.setDebugInfoPresented(isPresented)
            return .none

        case .delegate:
            return .none
        }
    }
}

extension LoginDomain.State {
    var isShowingDebugInfo: Bool {
        switch self {
        case let .loaded(loadedState), let .submitting(loadedState):
            return loadedState.isShowingDebugInfo
        case let .error(errorState):
            return errorState.isShowingDebugInfo
        case let .forgotPassword(forgotState):
            return forgotState.resume.isShowingDebugInfo
        case .loading, .authenticated:
            return false
        }
    }
}

private extension LoginDomain.State {
    mutating func setDebugInfoPresented(_ isPresented: Bool) {
        switch self {
        case var .loaded(loadedState):
            loadedState.isShowingDebugInfo = isPresented
            self = .loaded(loadedState)
        case var .error(errorState):
            errorState.isShowingDebugInfo = isPresented
            self = .error(errorState)
        case var .forgotPassword(forgotState):
            var resume = forgotState.resume
            resume.isShowingDebugInfo = isPresented
            forgotState.resume = resume
            self = .forgotPassword(forgotState)
        case .submitting, .loading, .authenticated:
            break
        }
    }

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
            self = .loaded(.init(form: errorState.form, isShowingDebugInfo: errorState.isShowingDebugInfo))
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
            return .init(form: errorState.form, isShowingDebugInfo: errorState.isShowingDebugInfo)
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
