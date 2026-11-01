import AccountKitTestSupport
import ConcurrencyExtras
import CustomDump
import FirebaseFirestore
import Foundation
import Testing

@testable import AccountKit

extension BaseSuite.IntegrationSuite {
    @Suite
    struct CollectionDeleteTests {
        @Test
        func theProfileAndItsCollectionsAreUnderTheUser() {
            expectNoDifference(AccountStorage.profileDocument(uid: "mock-uid").path, "users/mock-uid")
            expectNoDifference(AccountStorage.collection("items", uid: "mock-uid").path, "users/mock-uid/items")
        }

        @Test
        func deletingAllRemovesEveryPageAndKeepsTheRest() async throws {
            let uid = try await newUID()
            try await add(501, to: "items", uid: uid)
            try await add(1, to: "others", uid: uid)
            try await AccountStorage.profileDocument(uid: uid).setData(["value": 1])

            try await AccountStorage.shared.deleteAll(in: "items", uid: uid)

            let items = try await count("items", uid: uid)
            let others = try await count("others", uid: uid)
            expectNoDifference(items, 0)
            expectNoDifference(others, 1)
            let profile = try await AccountStorage.profileDocument(uid: uid).getDocument(source: .server)
            #expect(profile.exists)
        }

        @Test
        func deletingAllInAnEmptyCollectionReturns() async throws {
            let uid = try await newUID()

            try await AccountStorage.shared.deleteAll(in: "items", uid: uid)

            let items = try await count("items", uid: uid)
            expectNoDifference(items, 0)
        }

        @Test
        func deletingAllReportsTheFirstPageOnceBeforeTheLastPage() async throws {
            let uid = try await newUID()
            try await add(501, to: "items", uid: uid)
            let remainingAtReports = LockIsolated<[Int?]>([])

            try await AccountStorage.shared.deleteAll(in: "items", uid: uid) {
                let remaining = try? await count("items", uid: uid)
                remainingAtReports.withValue { $0.append(remaining) }
            }

            let items = try await count("items", uid: uid)
            expectNoDifference(remainingAtReports.value, [1])
            expectNoDifference(items, 0)
        }

        @Test
        func deletingAllInAnEmptyCollectionReportsOnceAtTheEnd() async throws {
            let uid = try await newUID()
            let reports = LockIsolated(0)

            try await AccountStorage.shared.deleteAll(in: "items", uid: uid) {
                reports.withValue { $0 += 1 }
            }

            expectNoDifference(reports.value, 1)
        }

        @Test
        func aFailureAfterTheFirstPageHasAlreadyReportedIt() async throws {
            let uid = try await newUID()
            try await add(501, to: "items", uid: uid)
            let reports = LockIsolated(0)

            let deletion = Task {
                try await AccountStorage.shared.deleteAll(in: "items", uid: uid) {
                    reports.withValue { $0 += 1 }
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }

            await #expect(throws: CancellationError.self) { try await deletion.value }
            let items = try await count("items", uid: uid)
            expectNoDifference(reports.value, 1)
            expectNoDifference(items, 1)
        }

        @Test
        func aCanceledDeleteKeepsTheDocuments() async throws {
            let uid = try await newUID()
            try await add(2, to: "items", uid: uid)

            let deletion = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                try await AccountStorage.shared.deleteAll(in: "items", uid: uid)
            }

            await #expect(throws: CancellationError.self) { try await deletion.value }
            let items = try await count("items", uid: uid)
            expectNoDifference(items, 2)
        }

        @Test
        func aRefusedReadEndsTheDelete() async throws {
            try await FirebaseEmulators.clearLocalData()

            let error = await #expect(throws: NSError.self) {
                try await AccountStorage.shared.deleteAll(in: "items", uid: lockedUID)
            }
            expectNoDifference(error?.code, FirestoreErrorCode.permissionDenied.rawValue)
        }

        @Test
        func aRefusedReadReportsNothing() async throws {
            try await FirebaseEmulators.clearLocalData()
            let reports = LockIsolated(0)

            await #expect(throws: NSError.self) {
                try await AccountStorage.shared.deleteAll(in: "items", uid: lockedUID) {
                    reports.withValue { $0 += 1 }
                }
            }
            expectNoDifference(reports.value, 0)
        }

        private func add(_ count: Int, to collection: String, uid: String) async throws {
            var remaining = count
            while remaining > 0 {
                let batch = Firestore.firestore().batch()
                let reference = AccountStorage.collection(collection, uid: uid)
                for index in 0 ..< min(remaining, 500) {
                    batch.setData(["index": index], forDocument: reference.document())
                }
                try await batch.commit()
                remaining -= 500
            }
        }

        private func count(_ collection: String, uid: String) async throws -> Int {
            try await AccountStorage.collection(collection, uid: uid).getDocuments(source: .server).documents.count
        }
    }
}
