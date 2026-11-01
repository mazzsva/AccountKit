import ConcurrencyExtras
import FirebaseFirestore
import Foundation
import IssueReporting

extension AccountStorage {
    public func profileSnapshots<Value: Equatable & Sendable>(
        uid: String,
        decode: @escaping @Sendable ([String: Any]?) -> Value
    ) async -> AsyncThrowingStream<ProfileSnapshot<Value>, any Error> {
        await waitForClearing()
        let isCached = await isProfileCached(uid: uid)
        await waitForClearing()
        return AsyncThrowingStream { continuation in
            let delivered = LockIsolated<(data: NSDictionary?, snapshot: ProfileSnapshot<Value>)?>(nil)
            let registration = ListenerRegistrationBox()
            let listener = Self.profileDocument(uid: uid)
                .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                    if let error {
                        registration.remove()
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else {
                        reportIssue("Profile listener reported neither a snapshot nor an error.")
                        return
                    }
                    nonisolated(unsafe) let data = snapshot.data()
                    let isConfirmed = isCached || snapshot.exists || !snapshot.metadata.isFromCache
                    nonisolated(unsafe) let current = data.map(NSDictionary.init(dictionary:))
                    let next = delivered.withValue { delivered -> ProfileSnapshot<Value>? in
                        let isKnown = isConfirmed || delivered.map { $0.snapshot != .unknown } == true
                        if let delivered, delivered.data == current, (delivered.snapshot != .unknown) == isKnown {
                            return nil
                        }
                        let previous = delivered?.snapshot
                        let next: ProfileSnapshot<Value> = isKnown ? .known(decode(data)) : .unknown
                        delivered = (current, next)
                        return next == previous ? nil : next
                    }
                    guard let next else { return }
                    continuation.yield(next)
                }
            registration.set(listener)
            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }

    private func isProfileCached(uid: String) async -> Bool {
        do {
            _ = try await Self.profileDocument(uid: uid).getDocument(source: .cache)
            return true
        } catch let error as NSError
            where error.domain == FirestoreErrorDomain && error.code == FirestoreErrorCode.unavailable.rawValue
        {
            return false
        } catch {
            reportIssue(error, "Reading the cached profile failed.")
            return false
        }
    }
}

private final class ListenerRegistrationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var registration: (any ListenerRegistration)?

    func remove() {
        lock.withLock { registration }?.remove()
    }

    func set(_ registration: any ListenerRegistration) {
        lock.withLock { self.registration = registration }
    }
}
