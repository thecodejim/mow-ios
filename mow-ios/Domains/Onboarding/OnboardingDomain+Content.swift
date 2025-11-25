extension OnboardingDomain.State.Step {
    static let catalog: [OnboardingDomain.State.Step] = [
        OnboardingDomain.State.Step(
            id: 0,
            title: "Plan your day",
            message: "Line up routes, meals, and reminders in one place.",
            detail: "We load your territory, favorite recipients, and notes so you can focus on deliveries.",
            icon: "calendar.badge.clock",
            accent: .mint
        ),
        OnboardingDomain.State.Step(
            id: 1,
            title: "Stay in sync",
            message: "Coordinators see your status in real time.",
            detail: "Push updates to dispatch with a single tap when traffic or weather gets in the way.",
            icon: "point.3.connected.trianglepath.dotted",
            accent: .orange
        ),
        OnboardingDomain.State.Step(
            id: 2,
            title: "Deliver with confidence",
            message: "Meals, dietary notes, and wellness flags travel with you.",
            detail: "Every household profile highlights what matters most before you knock.",
            icon: "heart.text.square",
            accent: .blue
        )
    ]
}
