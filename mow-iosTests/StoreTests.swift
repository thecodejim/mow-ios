import Testing
import Foundation
@testable import mow_ios

actor ExecutionFlag {
    private var value = false

    func markExecuted() {
        value = true
    }

    func didExecute() -> Bool {
        value
    }
}

// MARK: - Effect Tests

@Suite("Effect Tests")
@MainActor
struct EffectTests {
    
    @Test("Effect.none returns nil")
    func noneReturnsNil() async {
        // Given: A none effect
        let effect = Effect<String>.none
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: It returns nil
        #expect(result == nil)
    }
    
    @Test("Effect.send returns action")
    func sendReturnsAction() async {
        // Given: A send effect with an action
        let expectedAction = "TestAction"
        let effect = Effect<String>.send(expectedAction)
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: It returns the action
        #expect(result == expectedAction)
    }
    
    @Test("Effect.task executes work and returns result")
    func taskExecutesWorkAndReturnsResult() async {
        // Given: A task effect that performs async work
        let flag = ExecutionFlag()
        let effect = Effect<String>.task {
            await flag.markExecuted()
            return "WorkCompleted"
        }
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: The work is executed and result is returned
        let workExecuted = await flag.didExecute()
        #expect(workExecuted == true)
        #expect(result == "WorkCompleted")
    }
    
    @Test("Effect.fireAndForget executes work and returns nil")
    func fireAndForgetExecutesWorkAndReturnsNil() async {
        // Given: A fire-and-forget effect
        let flag = ExecutionFlag()
        let effect = Effect<String>.fireAndForget {
            await flag.markExecuted()
        }
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: Work is executed but no action is returned
        let workExecuted = await flag.didExecute()
        #expect(workExecuted == true)
        #expect(result == nil)
    }
    
    @Test(
        "Effect.map transforms string length correctly",
        arguments: [
            ("test", 4),
            ("", 0),
            ("hello", 5),
            ("swift", 5)
        ]
    )
    func mapTransformsAction_parametrized(input: String, expectedCount: Int) async {
        // Given: An effect that returns a string
        let effect = Effect<String>.send(input)
        
        // When: The effect is mapped to an integer
        let mappedEffect = effect.map { $0.count }
        let result = await mappedEffect.run()
        
        // Then: The action is transformed
        #expect(result == expectedCount)
    }
    
    @Test("Effect.map with none returns nil")
    func mapWithNoneReturnsNil() async {
        // Given: A none effect
        let effect = Effect<String>.none
        
        // When: The effect is mapped
        let mappedEffect = effect.map { $0.count }
        let result = await mappedEffect.run()
        
        // Then: It still returns nil
        #expect(result == nil)
    }
}

// MARK: - Store Tests

@Suite("Store Tests", .serialized)
@MainActor
struct StoreTests {
    
    @Test("Store initial state is set correctly")
    func initialStateIsSetCorrectly() {
        // Given: A store with initial state
        let initialState = TestState(count: 5)
        let store = Store(
            initialState: initialState,
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        // When: We check the state
        // Then: Initial state is set correctly
        #expect(store.state.count == 5)
    }
    
    @Test("Store sendAction updates state")
    func sendActionUpdatesState() {
        // Given: A store with initial count of 0
        let store = Store(
            initialState: TestState(count: 0),
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        // When: An increment action is sent
        store.send(.increment)
        
        // Then: State is updated immediately
        #expect(store.state.count == 1)
    }
    
    @Test("Store sendAction executes reducer")
    func sendActionExecutesReducer() {
        // Given: A store with tracking environment
        let environment = TestEnvironment()
        let store = Store(
            initialState: TestState(count: 0),
            environment: environment,
            reducer: testReducer
        )
        
        // When: An action is sent
        store.send(.setValue(42))
        
        // Then: Reducer processes the action
        #expect(store.state.count == 42)
    }
    
    @Test("Store sendAction with effect executes follow-up action")
    func sendActionWithEffectExecutesFollowUpAction() async {
        // Given: A store with initial state
        let store = Store(
            initialState: TestState(count: 0),
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        // When: An action that triggers an effect is sent
        store.send(.incrementWithEffect)
        
        // Then: State is updated immediately
        #expect(store.state.count == 1)
        
        // And: After effect completes, follow-up action is processed
        try? await Task.sleep(nanoseconds: 50_000_000) // Brief wait for effect
        #expect(store.state.count == 2) // Effect sends another increment
    }
    
    @Test("Store multiple actions processed sequentially")
    func multipleActionsProcessedSequentially() {
        // Given: A store with initial count of 0
        let store = Store(
            initialState: TestState(count: 0),
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        // When: Multiple actions are sent
        store.send(.increment)
        store.send(.increment)
        store.send(.increment)
        
        // Then: All actions are processed
        #expect(store.state.count == 3)
    }
    
    @Test("Store ObservableObject publishes state changes")
    func observableObjectPublishesStateChanges() async {
        // Given: A store and expectation for state change
        let store = Store(
            initialState: TestState(count: 0),
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        var receivedCount: Int?
        
        let task = Task {
            for await state in store.$state.values {
                receivedCount = state.count
                if state.count == 10 {
                    break
                }
            }
        }
        
        // When: State is changed
        try? await Task.sleep(nanoseconds: 10_000_000)
        store.send(.setValue(10))
        
        // Then: Subscriber receives the update
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        #expect(receivedCount == 10)
    }
}

// MARK: - StoreScope Tests

@Suite("StoreScope Tests")
@MainActor
struct StoreScopeTests {
    
    @Test("StoreScope extracts child state")
    func extractsChildState() {
        // Given: A parent store with nested state
        let parentStore = Store(
            initialState: ParentState(child: ChildState(name: "Test", value: 42)),
            environment: ParentEnvironment(),
            reducer: parentReducer
        )
        
        // When: A scoped store is created
        let childStore = parentStore.scope(
            state: { $0.child },
            environment: { _ in ChildEnvironment() },
            action: ParentAction.child
        )
        
        // Then: Child state is extracted correctly
        #expect(childStore.state.name == "Test")
        #expect(childStore.state.value == 42)
    }
    
    @Test("StoreScope sends action to parent")
    func sendsActionToParent() {
        // Given: A parent store and scoped child store
        let parentStore = Store(
            initialState: ParentState(child: ChildState(name: "Initial", value: 0)),
            environment: ParentEnvironment(),
            reducer: parentReducer
        )
        
        let childStore = parentStore.scope(
            state: { $0.child },
            environment: { _ in ChildEnvironment() },
            action: ParentAction.child
        )
        
        // When: Child sends an action
        childStore.send(.updateName("Updated"))
        
        // Then: Parent state is updated
        #expect(parentStore.state.child.name == "Updated")
        #expect(childStore.state.name == "Updated")
    }
    
    @Test("StoreScope syncs with parent state changes")
    func syncsWithParentStateChanges() {
        // Given: A parent store and scoped child store
        let parentStore = Store(
            initialState: ParentState(child: ChildState(name: "Initial", value: 0)),
            environment: ParentEnvironment(),
            reducer: parentReducer
        )
        
        let childStore = parentStore.scope(
            state: { $0.child },
            environment: { _ in ChildEnvironment() },
            action: ParentAction.child
        )
        
        // When: Parent state changes
        parentStore.send(.child(.incrementValue))
        
        // Then: Child store state is synchronized
        #expect(childStore.state.value == 1)
        #expect(parentStore.state.child.value == 1)
    }
    
    @Test("StoreScope removeDuplicates prevents unnecessary updates")
    func removeDuplicatesPreventsUnnecessaryUpdates() async {
        // Given: A parent store and scoped child store
        let parentStore = Store(
            initialState: ParentState(
                child: ChildState(name: "Test", value: 0),
                unrelatedCounter: 0
            ),
            environment: ParentEnvironment(),
            reducer: parentReducer
        )
        
        let childStore = parentStore.scope(
            state: { $0.child },
            environment: { _ in ChildEnvironment() },
            action: ParentAction.child
        )
        
        var updateCount = 0
        let task = Task {
            for await _ in childStore.$state.values {
                updateCount += 1
            }
        }
        
        try? await Task.sleep(nanoseconds: 10_000_000)
        let initialUpdateCount = updateCount
        
        // When: Unrelated parent state changes (child state stays the same)
        parentStore.send(.incrementUnrelatedCounter)
        parentStore.send(.incrementUnrelatedCounter)
        
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        // Then: Child store doesn't receive unnecessary updates
        // Note: Initial subscription triggers one update
        #expect(updateCount == initialUpdateCount)
        #expect(childStore.state.name == "Test")
        
        task.cancel()
    }
    
    @Test("StoreScope weak parent reference does not retain parent")
    func weakParentReferenceDoesNotRetainParent() {
        // Given: A parent store
        var parentStore: Store<ParentState, ParentAction, ParentEnvironment>? = Store(
            initialState: ParentState(child: ChildState(name: "Test", value: 0)),
            environment: ParentEnvironment(),
            reducer: parentReducer
        )
        
        var childStore: StoreScope<
            ParentState, ParentAction, ParentEnvironment,
            ChildState, ChildEnvironment, ChildAction
        >?
        
        // When: A scoped store is created
        childStore = parentStore?.scope(
            state: { $0.child },
            environment: { _ in ChildEnvironment() },
            action: ParentAction.child
        )
        
        // And: Parent store is deallocated
        #expect(childStore != nil)
        parentStore = nil
        
        // Then: Child store's parent reference is nil (weak reference works)
        // This is tested by the fact that sending an action has no effect
        childStore?.send(.updateName("ShouldNotCrash"))
        #expect(childStore?.state.name == "Test") // State unchanged
    }
}

// MARK: - Test Types

private struct TestState: Equatable {
    var count: Int = 0
}

private enum TestAction: Equatable, Sendable {
    case increment
    case setValue(Int)
    case incrementWithEffect
}

private struct TestEnvironment {}

@MainActor
private func testReducer(
    state: inout TestState,
    action: TestAction,
    environment: TestEnvironment
) -> Effect<TestAction> {
    switch action {
    case .increment:
        state.count += 1
        return .none
        
    case .setValue(let value):
        state.count = value
        return .none
        
    case .incrementWithEffect:
        state.count += 1
        return .task {
            // No sleep - immediate return
            return .increment
        }
    }
}

// MARK: - Parent/Child Test Types

private struct ParentState: Equatable {
    var child: ChildState
    var unrelatedCounter: Int = 0
}

private struct ChildState: Equatable {
    var name: String
    var value: Int
}

private enum ParentAction: Equatable, Sendable {
    case child(ChildAction)
    case incrementUnrelatedCounter
}

private enum ChildAction: Equatable, Sendable {
    case updateName(String)
    case incrementValue
}

private struct ParentEnvironment {}
private struct ChildEnvironment {}

@MainActor
private func parentReducer(
    state: inout ParentState,
    action: ParentAction,
    environment: ParentEnvironment
) -> Effect<ParentAction> {
    switch action {
    case .child(let childAction):
        let effect = childReducer(
            state: &state.child,
            action: childAction,
            environment: ChildEnvironment()
        )
        return effect.map(ParentAction.child)
        
    case .incrementUnrelatedCounter:
        state.unrelatedCounter += 1
        return .none
    }
}

@MainActor
private func childReducer(
    state: inout ChildState,
    action: ChildAction,
    environment: ChildEnvironment
) -> Effect<ChildAction> {
    switch action {
    case .updateName(let name):
        state.name = name
        return .none
        
    case .incrementValue:
        state.value += 1
        return .none
    }
}
