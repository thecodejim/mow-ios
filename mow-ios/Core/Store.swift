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
            Task {
                await work()
            }
            return nil
        }
    }
}

typealias Reducer<State, Action, Environment> = @MainActor (inout State, Action, Environment) -> Effect<Action>

@MainActor
final class Store<State, Action, Environment>: ObservableObject {
    @Published private(set) var state: State
    let environment: Environment
    private let reducer: Reducer<State, Action, Environment>
    private var scopedCancellables: [ObjectIdentifier: AnyCancellable] = [:]

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

    func scope<ChildState, ChildAction>(
            state toChildState: @escaping (State) -> ChildState,
            action fromChildAction: @escaping (ChildAction) -> Action
        ) -> StoreScope<State, Action, Environment, ChildState, ChildAction> {
            let scope = StoreScope(
                parent: self,
                toChildState: toChildState,
                fromChildAction: fromChildAction
            )

            let id = ObjectIdentifier(scope)

            let cancellable = $state
                .map(toChildState)
                .sink { [weak scope] childState in
                    scope?.state = childState
                }

            scopedCancellables[id] = cancellable

            return scope
        }

        func removeScope<ChildState, ChildAction>(
            _ scope: StoreScope<State, Action, Environment, ChildState, ChildAction>
        ) {
            let id = ObjectIdentifier(scope)
            scopedCancellables[id] = nil
        }
}

@MainActor
final class StoreScope<ParentState, ParentAction, ParentEnvironment, ChildState, ChildAction>: ObservableObject {
    @Published fileprivate(set) var state: ChildState
    
    let environment: ParentEnvironment

    private weak var parent: Store<ParentState, ParentAction, ParentEnvironment>?
    private let fromChildAction: (ChildAction) -> ParentAction

    init(
        parent: Store<ParentState, ParentAction, ParentEnvironment>,
        toChildState: @escaping (ParentState) -> ChildState,
        fromChildAction: @escaping (ChildAction) -> ParentAction
    ) {
        self.parent = parent
        self.fromChildAction = fromChildAction
        self.environment = parent.environment
        self.state = toChildState(parent.state)
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
