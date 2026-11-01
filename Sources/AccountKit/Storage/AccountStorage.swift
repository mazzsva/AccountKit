import FirebaseFirestore

public actor AccountStorage {
    public static let shared = AccountStorage {
        let firestore = Firestore.firestore()
        try await firestore.terminate()
        try await firestore.clearPersistence()
    }

    private let clear: @Sendable () async throws -> Void
    private var clearing: Task<Void, any Error>?

    init(clear: @escaping @Sendable () async throws -> Void) {
        self.clear = clear
    }

    public func clearLocalData() async throws {
        if let clearing {
            return try await clearing.value
        }
        let clearing = Task { [clear] in
            try await clear()
        }
        self.clearing = clearing
        defer { self.clearing = nil }
        try await clearing.value
    }

    public func perform<Result: Sendable>(
        _ operation: @Sendable (isolated AccountStorage) async throws -> Result
    ) async rethrows -> Result {
        await waitForClearing()
        return try await operation(self)
    }

    public func waitForClearing() async {
        _ = try? await clearing?.value
    }
}
