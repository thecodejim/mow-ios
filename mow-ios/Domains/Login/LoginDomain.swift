import Foundation

enum LoginDomain {
    struct State: Equatable, Sendable {
        struct LoginForm: Equatable, Sendable {
            var email = "volunteer@example.com"
            var password = "password"
            var errorMessage: String?
            var isSecureEntry = true

            var isValid: Bool {
                email.isValidEmail && password.count >= 4
            }
        }

        struct ForgotPassword: Equatable, Sendable {
            enum Status: Equatable, Sendable {
                case idle
                case success(message: String)
                case failure(message: String)
            }

            var email = ""
            var status: Status = .idle
        }

        var form = LoginForm()
        var forgot = ForgotPassword()
        var route: Route?
        var isLoading = false
        var isAuthenticated = false
        var session: AuthSession?
    }

    struct Environment: @unchecked Sendable {
        let appEnvironment: AppEnvironment
        let api: any APIService
        let keychain: any KeychainService
        let analytics: any AnalyticsService
    }

    enum Route: Hashable, Sendable {
        case forgotPassword
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
            return .fireAndForget {
                await environment.analytics.track(event: "login_viewed", metadata: [:])
            }

        case let .emailChanged(email):
            state.form.email = email
            state.form.errorMessage = nil
            return .none

        case let .passwordChanged(password):
            state.form.password = password
            state.form.errorMessage = nil
            return .none

        case .toggleSecureEntry:
            state.form.isSecureEntry.toggle()
            return .none

        case .submit:
            guard !state.isLoading else { return .none }

            guard state.form.email.isValidEmail else {
                state.form.errorMessage = "Please enter a valid email."
                return .none
            }

            guard state.form.password.count >= 4 else {
                state.form.errorMessage = "Your password should be at least 4 characters."
                return .none
            }

            state.isLoading = true
            state.form.errorMessage = nil

            let email = state.form.email
            let password = state.form.password

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
            state.isLoading = false
            switch result {
            case let .success(session):
                state.session = session
                state.isAuthenticated = true
                return .send(.delegate(.authenticated(session)))

            case let .failure(error):
                state.form.errorMessage = error.message
                state.isAuthenticated = false
            }
            return .none

        case .forgotPasswordTapped:
            state.route = .forgotPassword
            return .none

        case let .forgotEmailChanged(email):
            state.forgot.email = email
            state.forgot.status = .idle
            return .none

        case .sendReset:
            guard !state.isLoading else { return .none }

            guard state.forgot.email.isValidEmail else {
                state.forgot.status = .failure(message: "Please enter a valid email address.")
                return .none
            }

            state.isLoading = true
            state.forgot.status = .idle

            let email = state.forgot.email

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
            state.isLoading = false
            switch result {
            case .success:
                state.forgot.status = .success(message: "We sent a magic link to \(state.forgot.email).")
            case let .failure(error):
                state.forgot.status = .failure(message: error.message)
            }
            return .none

        case .dismissForgot:
            state.route = nil
            state.forgot = .init()
            return .none

        case .clearError:
            state.form.errorMessage = nil
            return .none

        case .delegate:
            return .none
        }
    }
}

private extension String {
    var isValidEmail: Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
