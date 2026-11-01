import FirebaseFirestore
import IssueReporting

extension AccountStorage {
    public func collectionSnapshots<Element: Sendable>(
        _ collection: String,
        uid: String,
        subject: String,
        includeMetadataChanges: Bool,
        query: @Sendable (CollectionReference) -> Query = { $0 },
        transform: @escaping @Sendable (QuerySnapshot) -> Element
    ) async -> AsyncThrowingStream<Element, any Error> {
        await waitForClearing()
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let listener = query(Self.collection(collection, uid: uid))
                .addSnapshotListener(includeMetadataChanges: includeMetadataChanges) { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else {
                        reportIssue("\(subject) listener reported neither a snapshot nor an error.")
                        return
                    }
                    continuation.yield(transform(snapshot))
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
