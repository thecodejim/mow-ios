import Combine

struct Effect<Action: Sendable>: Sendable {
    typealias Operation = @Sendable () async -> Action?

    private let priority: TaskPriority
    private let operation: Operation?

    init(priority: TaskPriority = .userInitiated, operation: Operation? = nil) {
        self.priority = priority
        self.operation = operation
    }

    func run() async -> Action? {
        guard let operation else { return nil }
        return await operation()
    }

    func run(send: @MainActor @escaping (Action) -> Void) {
        guard let operation else { return }

        Task.detached(priority: priority) {
            guard let action = await operation() else { return }
            await MainActor.run {
                send(action)
            }
        }
    }

    static var none: Effect {
        Effect(operation: nil)
    }

    static func send(_ action: Action) -> Effect {
        Effect {
            action
        }
    }

    static func task(
        priority: TaskPriority = .userInitiated,
        _ work: @escaping @Sendable () async -> Action
    ) -> Effect {
        Effect(priority: priority) {
            await work()
        }
    }

    static func fireAndForget(
        priority: TaskPriority = .userInitiated,
        _ work: @escaping @Sendable () async -> Void
    ) -> Effect {
        Effect(priority: priority) {
            await work()
            return nil
        }
    }
}

typealias Reducer<State, Action: Sendable, Environment> = (inout State, Action, Environment) -> Effect<Action>

@MainActor
final class Store<State, Action: Sendable, Environment>: ObservableObject {
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
    
    /// Workaround for a Swift Concurrency + AddressSanitizer bug where
    /// deallocating a @MainActor class can crash inside TaskLocal teardown.
    /// Deinit must remain empty / not touch actor-isolated state.
    /// Only happened in StoreTests
    #if DEBUG
    nonisolated deinit { }
    #endif

    /// Public entry point for sending actions.
    /// Reducer runs synchronously on the main actor; effects are detached.
    func send(_ action: Action) {
        let effect = reducer(&state, action, environment)
        effect.run(send: self.send)
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
    ParentAction: Sendable,
    ParentEnvironment,
    ChildState: Equatable,
    ChildEnvironment,
    ChildAction: Sendable
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
    
    /// Workaround for a Swift Concurrency + AddressSanitizer bug where
    /// deallocating a @MainActor class can crash inside TaskLocal teardown.
    /// Deinit must remain empty / not touch actor-isolated state.
    /// Only happened in StoreTests
    #if DEBUG
    nonisolated deinit { }
    #endif

    func send(_ action: ChildAction) {
        parent?.send(fromChildAction(action))
    }
}

extension Effect {
    func map<T: Sendable>(_ transform: @escaping @Sendable (Action) -> T) -> Effect<T> {
        guard let operation else { return .none }

        return Effect<T>(priority: priority) {
            guard let action = await operation() else { return nil }
            return transform(action)
        }
    }
}
