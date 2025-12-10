import SwiftUI
import Foundation

extension LoginDomain {
    enum AnalyticsEvent {
        static let loginViewed = "login_viewed"
        static let loginSuccess = "login_success"
        static let loginFailure = "login_failure"
        static let resetRequested = "login_reset_requested"
    }

    enum Copy {
        fileprivate enum Key {
            static let welcomeTitle = "login.welcome.title"
            static let welcomeSubtitle = "login.welcome.subtitle"
            static let emailFieldPlaceholder = "login.form.email.placeholder"
            static let emailFieldSectionTitle = "login.form.email.section"
            static let emailSamplePlaceholder = "login.form.email.sample"
            static let passwordFieldPlaceholder = "login.form.password.placeholder"
            static let showPassword = "login.form.password.show"
            static let hidePassword = "login.form.password.hide"
            static let forgotPasswordCTA = "login.cta.forgotPassword"
            static let signInCTA = "login.cta.signIn"
            static let submittingOverlay = "login.overlay.submitting"
            static let resetOverlay = "login.overlay.reset"
            static let sendResetButton = "login.reset.button"
            static let forgotPasswordNavTitle = "login.reset.navTitle"

            static let invalidEmail = "login.error.invalidEmail"
            static let passwordTooShort = "login.error.passwordTooShort"
            static let loginFallbackError = "login.error.fallback"
            static let forgotInvalidEmail = "login.forgot.error.invalidEmail"
            static let resetFallbackError = "login.reset.error.fallback"
            static let resetSuccessFormat = "login.reset.success"
        }

        // MARK: - UI Copy (LocalizedStringKey)
        static var welcomeTitle: LocalizedStringKey { .init(Key.welcomeTitle) }
        static var welcomeSubtitle: LocalizedStringKey { .init(Key.welcomeSubtitle) }
        static var emailFieldPlaceholder: LocalizedStringKey { .init(Key.emailFieldPlaceholder) }
        static var emailSectionTitle: LocalizedStringKey { .init(Key.emailFieldSectionTitle) }
        static var emailSamplePlaceholder: LocalizedStringKey { .init(Key.emailSamplePlaceholder) }
        static var passwordFieldPlaceholder: LocalizedStringKey { .init(Key.passwordFieldPlaceholder) }
        static var showPasswordTitle: LocalizedStringKey { .init(Key.showPassword) }
        static var hidePasswordTitle: LocalizedStringKey { .init(Key.hidePassword) }
        static var forgotPasswordButtonTitle: LocalizedStringKey { .init(Key.forgotPasswordCTA) }
        static var signInButtonTitle: LocalizedStringKey { .init(Key.signInCTA) }
        static var submittingOverlayMessage: LocalizedStringKey { .init(Key.submittingOverlay) }
        static var resetOverlayMessage: LocalizedStringKey { .init(Key.resetOverlay) }
        static var sendResetButtonTitle: LocalizedStringKey { .init(Key.sendResetButton) }
        static var forgotPasswordNavigationTitle: LocalizedStringKey { .init(Key.forgotPasswordNavTitle) }

        // MARK: - String Copy (Domain / Error Handling)
        static var invalidEmail: String { string(Key.invalidEmail) }
        static var passwordTooShort: String { string(Key.passwordTooShort) }
        static var loginFallbackError: String { string(Key.loginFallbackError) }
        static var forgotInvalidEmail: String { string(Key.forgotInvalidEmail) }
        static var resetFallbackError: String { string(Key.resetFallbackError) }

        static func resetSuccessMessage(forEmail email: String) -> String {
            let format = string(Key.resetSuccessFormat)
            return String.localizedStringWithFormat(format, email)
        }

        private static func string(_ key: String) -> String {
            NSLocalizedString(key, bundle: .main, comment: "")
        }
    }
}

extension LoginDomain.State.LoginForm {
    static let defaultEmail = "volunteer@example.com"
    static let defaultPassword = "password"
    static let minPasswordLength = 4
}
