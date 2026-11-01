import AccountKitTestSupport
import ConcurrencyExtras
import CustomDump
import FirebaseFirestore
import Foundation
import Testing

@testable import AccountKit

extension BaseSuite.IntegrationSuite {
    @Suite
    struct CollectionListenerTests {
        @Test
        func eachElementIsTheTransformOfTheQuery() async throws {
            let uid = try await newUID()
            let items = AccountStorage.collection("items", uid: uid)
            try await items.document("a").setData(["rank": 1])
            try await items.document("b").setData(["rank": 3])
            try await items.document("c").setData(["rank": 2])

            let ids = Recording(
                await AccountStorage.shared.collectionSnapshots(
                    "items",
                    uid: uid,
                    subject: "Items",
                    includeMetadataChanges: false,
                    query: { $0.order(by: "rank", descending: true) }
                ) { snapshot in
                    snapshot.documents.map(\.documentID)
                }
            )
            defer { ids.cancel() }

            try await ids.wait { $0.last == ["b", "c", "a"] }
        }

        @Test
        func onlyTheListenerWithMetadataChangesReportsTheServerAcknowledgement() async throws {
            let uid = try await newUID()
            let withMetadata = Recording(await itemStates(uid: uid, includeMetadataChanges: true))
            let withoutMetadata = Recording(await itemStates(uid: uid, includeMetadataChanges: false))
            defer {
                withMetadata.cancel()
                withoutMetadata.cancel()
            }
            try await withMetadata.wait { $0.last == ItemState(count: 0, hasPendingWrites: false) }
            try await withoutMetadata.wait { $0.last == ItemState(count: 0, hasPendingWrites: false) }

            try await AccountStorage.collection("items", uid: uid).document("a").setData(["rank": 1])
            try await withMetadata.wait { $0.last == ItemState(count: 1, hasPendingWrites: false) }
            #expect(withMetadata.values.contains(ItemState(count: 1, hasPendingWrites: true)))

            try await AccountStorage.collection("items", uid: uid).document("b").setData(["rank": 2])
            try await withoutMetadata.wait { $0.last == ItemState(count: 2, hasPendingWrites: true) }
            #expect(withoutMetadata.values.contains(ItemState(count: 1, hasPendingWrites: true)))
            #expect(!withoutMetadata.values.contains(ItemState(count: 1, hasPendingWrites: false)))
        }

        @Test
        func endingTheStreamRemovesTheListener() async throws {
            let uid = try await newUID()
            let transforms = LockIsolated(0)
            let ended = Recording(
                await AccountStorage.shared.collectionSnapshots(
                    "items",
                    uid: uid,
                    subject: "Items",
                    includeMetadataChanges: false
                ) { snapshot in
                    transforms.withValue { $0 += 1 }
                    return snapshot.documents.count
                }
            )
            try await ended.wait { $0.last == 0 }
            ended.cancel()
            try await Task.sleep(for: .milliseconds(100))
            let transformsWhenEnded = transforms.value

            let active = Recording(await itemStates(uid: uid, includeMetadataChanges: false))
            defer { active.cancel() }
            try await active.wait { $0.last?.count == 0 }
            try await AccountStorage.collection("items", uid: uid).document("a").setData(["rank": 1])
            try await active.wait { $0.last?.count == 1 }

            expectNoDifference(transforms.value, transformsWhenEnded)
        }

        @Test
        func aRefusedListenerEndsTheStream() async throws {
            try await FirebaseEmulators.clearLocalData()

            let states = Recording(await itemStates(uid: lockedUID, includeMetadataChanges: true))
            defer { states.cancel() }
            let failure = try await states.waitForFailure() as NSError
            expectNoDifference(failure.code, FirestoreErrorCode.permissionDenied.rawValue)
            expectNoDifference(states.values, [])
        }

        private func itemStates(
            uid: String,
            includeMetadataChanges: Bool
        ) async -> AsyncThrowingStream<ItemState, any Error> {
            await AccountStorage.shared.collectionSnapshots(
                "items",
                uid: uid,
                subject: "Items",
                includeMetadataChanges: includeMetadataChanges
            ) { snapshot in
                ItemState(count: snapshot.documents.count, hasPendingWrites: snapshot.metadata.hasPendingWrites)
            }
        }
    }
}

private struct ItemState: Equatable, Sendable {
    let count: Int
    let hasPendingWrites: Bool
}
