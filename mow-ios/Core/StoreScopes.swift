import Foundation

typealias OnboardingScopedStore = StoreScope<
    AppDomain.State,
    AppDomain.Action,
    AppDomain.Environment,
    OnboardingDomain.State,
    OnboardingDomain.Action
>

typealias LoginScopedStore = StoreScope<
    AppDomain.State,
    AppDomain.Action,
    AppDomain.Environment,
    LoginDomain.State,
    LoginDomain.Action
>

typealias HomeScopedStore = StoreScope<
    AppDomain.State,
    AppDomain.Action,
    AppDomain.Environment,
    HomeDomain.State,
    HomeDomain.Action
>

