import Testing

public struct FirebaseEmulatorsTrait: SuiteTrait, TestTrait, TestScoping {
    let projectID: String

    public var isRecursive: Bool { true }

    public func prepare(for test: Test) async throws {
        try await ConditionTrait.enabled(if: FirebaseEmulators.isAvailable).prepare(for: test)
    }

    public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        testCase == nil ? nil : self
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @concurrent @Sendable () async throws -> Void
    ) async throws {
        FirebaseEmulators.configure(projectID: projectID)
        try await withTimeLimit(.seconds(60), function)
    }
}

extension Trait where Self == FirebaseEmulatorsTrait {
    public static func firebaseEmulators(projectID: String) -> Self {
        Self(projectID: projectID)
    }
}

func withTimeLimit(_ timeLimit: Duration, _ body: @concurrent @Sendable () async throws -> Void) async throws {
    try await withoutActuallyEscaping(body) { body in
        try await withThrowingTaskGroup { group in
            group.addTask {
                try await Task.sleep(for: timeLimit)
                Issue.record("Time limit was exceeded: \(timeLimit)")
            }
            group.addTask(operation: body)
            defer { group.cancelAll() }
            try await group.next()
        }
    }
}
