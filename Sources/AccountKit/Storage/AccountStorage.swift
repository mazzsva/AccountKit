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

    public func deleteAll(
        in collection: String,
        uid: String,
        didDeleteSomeData: @Sendable () async -> Void = {}
    ) async throws {
        await waitForClearing()
        var hasDeletedSomeData = false
        while true {
            try Task.checkCancellation()
            let snapshot = try await Self.collection(collection, uid: uid).limit(to: 500).getDocuments()
            guard !snapshot.documents.isEmpty else {
                if !hasDeletedSomeData {
                    await didDeleteSomeData()
                }
                return
            }
            let batch = Firestore.firestore().batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
            if !hasDeletedSomeData {
                hasDeletedSomeData = true
                await didDeleteSomeData()
            }
        }
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

extension AccountStorage {
    public static func collection(_ name: String, uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection(name)
    }

    public static func profileDocument(uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }
}
