import AccountKitTestSupport
import CustomDump
import FirebaseFirestore
import Foundation
import Testing

@testable import AccountKit

extension BaseSuite.IntegrationSuite {
    @Suite
    struct CacheClearTests {
        @Test
        func clearingRemovesTheCachedDocuments() async throws {
            let uid = try await newUID()
            try await AccountStorage.profileDocument(uid: uid).setData(["value": 1])
            _ = try await AccountStorage.profileDocument(uid: uid).getDocument(source: .cache)

            try await FirebaseEmulators.clearLocalData()

            let error = await #expect(throws: NSError.self) {
                _ = try await AccountStorage.profileDocument(uid: uid).getDocument(source: .cache)
            }
            expectNoDifference(error?.code, FirestoreErrorCode.unavailable.rawValue)
        }

        @Test
        func clearsAtTheSameTimeBothSucceed() async throws {
            let uid = try await newUID()
            try await AccountStorage.profileDocument(uid: uid).setData(["value": 1])

            async let first: Void = FirebaseEmulators.clearLocalData()
            async let second: Void = FirebaseEmulators.clearLocalData()
            _ = try await (first, second)

            let error = await #expect(throws: NSError.self) {
                _ = try await AccountStorage.profileDocument(uid: uid).getDocument(source: .cache)
            }
            expectNoDifference(error?.code, FirestoreErrorCode.unavailable.rawValue)
        }

        @Test
        func theStorageWorksAfterAClear() async throws {
            let uid = try await newUID()

            try await FirebaseEmulators.clearLocalData()

            try await AccountStorage.profileDocument(uid: uid).setData(["value": 1])
            let document = try await AccountStorage.profileDocument(uid: uid).getDocument(source: .server)
            expectNoDifference(document.data()?["value"] as? Int, 1)
        }
    }
}
