import ConcurrencyExtras
import CustomDump
import Dependencies
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct UserDataClientTests {
        @Test
        func theTestValueFailsWhenTheDeletionIsNotImplemented() async {
            @Dependency(\.userDataClient) var userDataClient

            await withKnownIssue {
                try await userDataClient.deleteAll(uid: "mock-uid") {}
            }
        }

        @Test
        func theLiveValueFailsOutsideAnAccountSession() async {
            let deletions = LockIsolated(0)

            await withKnownIssue {
                try await UserDataClient.liveValue.deleteAll("mock-uid") {
                    deletions.withValue { $0 += 1 }
                }
            }

            expectNoDifference(deletions.value, 0)
        }

        @Test
        func thePreviewValueDeletesNothing() async throws {
            let deletions = LockIsolated(0)

            try await UserDataClient.previewValue.deleteAll("mock-uid") {
                deletions.withValue { $0 += 1 }
            }

            expectNoDifference(deletions.value, 0)
        }
    }
}
