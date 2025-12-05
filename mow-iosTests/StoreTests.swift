import XCTest
import Combine
@testable import mow_ios

@MainActor
final class StoreTests: XCTestCase {
    
    // MARK: - Effect Tests
    
    func test_Effect_none_returnsNil() async {
        // Given: A none effect
        let effect = Effect<String>.none
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: It returns nil
        XCTAssertNil(result)
    }
    
    func test_Effect_send_returnsAction() async {
        // Given: A send effect with an action
        let expectedAction = "TestAction"
        let effect = Effect<String>.send(expectedAction)
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: It returns the action
        XCTAssertEqual(result, expectedAction)
    }
    
    func test_Effect_task_executesWorkAndReturnsResult() async {
        // Given: A task effect that performs async work
        var workExecuted = false
        let effect = Effect<String>.task {
            workExecuted = true
            return "WorkCompleted"
        }
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: The work is executed and result is returned
        XCTAssertTrue(workExecuted)
        XCTAssertEqual(result, "WorkCompleted")
    }
    
    func test_Effect_fireAndForget_executesWorkAndReturnsNil() async {
        // Given: A fire-and-forget effect
        var workExecuted = false
        let effect = Effect<String>.fireAndForget {
            workExecuted = true
        }
        
        // When: The effect is run
        let result = await effect.run()
        
        // Then: Work is executed but no action is returned
        XCTAssertTrue(workExecuted)
        XCTAssertNil(result)
    }
    
    func test_Effect_map_transformsAction() async {
        // Given: An effect that returns a string
        let effect = Effect<String>.send("test")
        
        // When: The effect is mapped to an integer
        let mappedEffect = effect.map { $0.count }
        let result = await mappedEffect.run()
        
        // Then: The action is transformed
        XCTAssertEqual(result, 4)
    }
    
    func test_Effect_map_withNone_returnsNil() async {
        // Given: A none effect
        let effect = Effect<String>.none
        
        // When: The effect is mapped
        let mappedEffect = effect.map { $0.count }
        let result = await mappedEffect.run()
        
        // Then: It still returns nil
        XCTAssertNil(result)
    }
    
    // MARK: - Store Tests
    
    func test_Store_initialState_isSetCorrectly() {
        // Given: A store with initial state
        let initialState = TestState(count: 5)
        let store = Store(
            initialState: initialState,
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        // When: We check the state
        // Then: Initial state is set correctly
        XCTAssertEqual(store.state.count, 5)
    }
    
    func test_Store_sendAction_updatesState() {
        // Given: A store with initial count of 0
        let store = Store(
            initialState: TestState(count: 0),
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        // When: An increment action is sent
        store.send(.increment)
        
        // Then: State is updated immediately
        XCTAssertEqual(store.state.count, 1)
    }
    
    func test_Store_sendAction_executesReducer() {
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
        XCTAssertEqual(store.state.count, 42)
    }
    
    func test_Store_sendAction_withEffect_executesFollowUpAction() async {
        // Given: A store with initial state
        let store = Store(
            initialState: TestState(count: 0),
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        // When: An action that triggers an effect is sent
        store.send(.incrementWithEffect)
        
        // Then: State is updated immediately
        XCTAssertEqual(store.state.count, 1)
        
        // And: After effect completes, follow-up action is processed
        try? await Task.sleep(nanoseconds: 50_000_000) // Brief wait for effect
        XCTAssertEqual(store.state.count, 2) // Effect sends another increment
    }
    
    func test_Store_multipleActions_processedSequentially() {
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
        XCTAssertEqual(store.state.count, 3)
    }
    
    func test_Store_observableObject_publishesStateChanges() {
        // Given: A store and expectation for state change
        let store = Store(
            initialState: TestState(count: 0),
            environment: TestEnvironment(),
            reducer: testReducer
        )
        
        let expectation = XCTestExpectation(description: "State change published")
        var receivedCount: Int?
        
        let cancellable = store.$state.sink { state in
            receivedCount = state.count
            if state.count == 10 {
                expectation.fulfill()
            }
        }
        
        // When: State is changed
        store.send(.setValue(10))
        
        // Then: Subscriber receives the update
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedCount, 10)
        
        cancellable.cancel()
    }
    
    // MARK: - StoreScope Tests
    
    func test_StoreScope_extractsChildState() {
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
        XCTAssertEqual(childStore.state.name, "Test")
        XCTAssertEqual(childStore.state.value, 42)
    }
    
    func test_StoreScope_sendsActionToParent() {
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
        XCTAssertEqual(parentStore.state.child.name, "Updated")
        XCTAssertEqual(childStore.state.name, "Updated")
    }
    
    func test_StoreScope_syncsWithParentStateChanges() {
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
        XCTAssertEqual(childStore.state.value, 1)
        XCTAssertEqual(parentStore.state.child.value, 1)
    }
    
    func test_StoreScope_removeDuplicates_preventsUnnecessaryUpdates() {
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
        let cancellable = childStore.$state.sink { _ in
            updateCount += 1
        }
        
        let initialUpdateCount = updateCount
        
        // When: Unrelated parent state changes (child state stays the same)
        parentStore.send(.incrementUnrelatedCounter)
        parentStore.send(.incrementUnrelatedCounter)
        
        // Then: Child store doesn't receive unnecessary updates
        // Note: Initial subscription triggers one update
        XCTAssertEqual(updateCount, initialUpdateCount)
        XCTAssertEqual(childStore.state.name, "Test")
        
        cancellable.cancel()
    }
    
    func test_StoreScope_weakParentReference_doesNotRetainParent() {
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
        XCTAssertNotNil(childStore)
        parentStore = nil
        
        // Then: Child store's parent reference is nil (weak reference works)
        // This is tested by the fact that sending an action has no effect
        childStore?.send(.updateName("ShouldNotCrash"))
        XCTAssertEqual(childStore?.state.name, "Test") // State unchanged
    }
}

// MARK: - Test Types

private struct TestState: Equatable {
    var count: Int = 0
}

private enum TestAction: Equatable {
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

private enum ParentAction: Equatable {
    case child(ChildAction)
    case incrementUnrelatedCounter
}

private enum ChildAction: Equatable {
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
