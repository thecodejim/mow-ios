extension LoginDomain {
    enum AnalyticsEvent {
        static let loginViewed = "login_viewed"
        static let loginSuccess = "login_success"
        static let loginFailure = "login_failure"
        static let resetRequested = "login_reset_requested"
    }

    enum Copy {
        static let invalidEmail = "Please enter a valid email."
        static let passwordTooShort = "Your password should be at least 4 characters."
        static let loginFallbackError = "We hit a snag signing you in."
        static let forgotInvalidEmail = "Please enter a valid email address."
        static let resetFallbackError = "We could not send that reset."

        static func resetSuccessMessage(forEmail email: String) -> String {
            "We sent a magic link to \(email)."
        }
    }
}

extension LoginDomain.State.LoginForm {
    static let defaultEmail = "volunteer@example.com"
    static let defaultPassword = "password"
    static let minPasswordLength = 4
}

