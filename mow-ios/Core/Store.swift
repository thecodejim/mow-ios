import Combine

struct Effect<Action> {
    private let operation: () async -> Action?

    init(operation: @escaping () async -> Action?) {
        self.operation = operation
    }

    func run() async -> Action? {
        await operation()
    }

    static var none: Effect {
        Effect { nil }
    }

    static func send(_ action: Action) -> Effect {
        Effect { action }
    }

    static func task(_ work: @escaping () async -> Action) -> Effect {
        Effect {
            await work()
        }
    }

    static func fireAndForget(_ work: @escaping () async -> Void) -> Effect {
        Effect {
            await work()
            return nil
        }
    }
}

typealias Reducer<State, Action, Environment> =
    @MainActor (inout State, Action, Environment) -> Effect<Action>

@MainActor
final class Store<State, Action, Environment>: ObservableObject {
    @Published private(set) var state: State
    let environment: Environment
    private let reducer: Reducer<State, Action, Environment>

    init(
        initialState: State,
        environment: Environment,
        reducer: @escaping Reducer<State, Action, Environment>
    ) {
        self.state = initialState
        self.environment = environment
        self.reducer = reducer
    }

    /// Public entry point for sending actions.
    /// Reducer runs synchronously on the main actor; effects are detached.
    func send(_ action: Action) {
        // 1. Run reducer immediately on the main actor
        let effect = reducer(&state, action, environment)

        // 2. Run the effect asynchronously; it can send follow-up actions
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let next = await effect.run() {
                self.send(next)
            }
        }
    }

    func scope<ChildState, ChildEnvironment, ChildAction>(
        state toChildState: @escaping (State) -> ChildState,
        environment toChildEnvironment: @escaping (Environment) -> ChildEnvironment,
        action fromChildAction: @escaping (ChildAction) -> Action
    ) -> StoreScope<State, Action, Environment, ChildState, ChildEnvironment, ChildAction> {
        StoreScope(
            parent: self,
            toChildState: toChildState,
            toChildEnvironment: toChildEnvironment,
            fromChildAction: fromChildAction
        )
    }
}

@MainActor
final class StoreScope<
    ParentState,
    ParentAction,
    ParentEnvironment,
    ChildState: Equatable,
    ChildEnvironment,
    ChildAction
>: ObservableObject {

    @Published fileprivate(set) var state: ChildState
    let environment: ChildEnvironment

    private weak var parent: Store<ParentState, ParentAction, ParentEnvironment>?
    private let fromChildAction: (ChildAction) -> ParentAction
    private var cancellable: AnyCancellable?

    init(
        parent: Store<ParentState, ParentAction, ParentEnvironment>,
        toChildState: @escaping (ParentState) -> ChildState,
        toChildEnvironment: @escaping (ParentEnvironment) -> ChildEnvironment,
        fromChildAction: @escaping (ChildAction) -> ParentAction
    ) {
        self.parent = parent
        self.fromChildAction = fromChildAction
        self.environment = toChildEnvironment(parent.environment)
        self.state = toChildState(parent.state)

        self.cancellable = parent.$state
            .map(toChildState)
            .removeDuplicates() // prevent unnecessary publishes - ChildState must be Equatable
            .sink { [weak self] childState in
                self?.state = childState
            }
    }

    func send(_ action: ChildAction) {
        parent?.send(fromChildAction(action))
    }
}

extension Effect {
    func map<T>(_ transform: @escaping (Action) -> T) -> Effect<T> {
        Effect<T> {
            if let action = await run() {
                return transform(action)
            }
            return nil
        }
    }
}
