import Combine

struct Effect<Action: Sendable>: Sendable {
    private let operation: @Sendable () async -> Action?

    init(operation: @escaping @Sendable () async -> Action?) {
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

    static func task(_ work: @escaping @Sendable () async -> Action) -> Effect {
        Effect {
            await work()
        }
    }

    static func fireAndForget(_ work: @escaping @Sendable () async -> Void) -> Effect {
        Effect {
            _ = Task.detached(priority: nil) {
                await work()
            }
            return nil
        }
    }
}

typealias Reducer<State, Action: Sendable, Environment> = @MainActor @Sendable (inout State, Action, Environment) -> Effect<Action>

@MainActor
final class Store<State, Action: Sendable, Environment>: ObservableObject {
    @Published private(set) var state: State
    let environment: Environment
    private let reducer: Reducer<State, Action, Environment>

    init(initialState: State, environment: Environment, reducer: @escaping Reducer<State, Action, Environment>) {
        self.state = initialState
        self.environment = environment
        self.reducer = reducer
    }

    func send(_ action: Action) {
        Task {
            await reduce(action)
        }
    }

    private func reduce(_ action: Action) async {
        let effect = reducer(&state, action, environment)
        if let nextAction = await effect.run() {
            await reduce(nextAction)
        }
    }

    func scope<ChildState, ChildAction: Sendable>(
        state toChildState: @escaping (State) -> ChildState,
        action fromChildAction: @escaping (ChildAction) -> Action
    ) -> StoreScope<State, Action, Environment, ChildState, ChildAction> {
        StoreScope(parent: self, toChildState: toChildState, fromChildAction: fromChildAction)
    }
}

@MainActor
final class StoreScope<ParentState, ParentAction: Sendable, ParentEnvironment, ChildState, ChildAction: Sendable>: ObservableObject {
    @Published private(set) var state: ChildState

    private let parent: Store<ParentState, ParentAction, ParentEnvironment>
    private let fromChildAction: (ChildAction) -> ParentAction
    private var cancellables: Set<AnyCancellable> = []
    
    var environment: ParentEnvironment {
        parent.environment
    }

    init(
        parent: Store<ParentState, ParentAction, ParentEnvironment>,
        toChildState: @escaping (ParentState) -> ChildState,
        fromChildAction: @escaping (ChildAction) -> ParentAction
    ) {
        self.parent = parent
        self.fromChildAction = fromChildAction
        self.state = toChildState(parent.state)

        parent.$state
            .map(toChildState)
            .sink { [weak self] childState in
                self?.state = childState
            }
            .store(in: &cancellables)
    }

    func send(_ action: ChildAction) {
        parent.send(fromChildAction(action))
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
