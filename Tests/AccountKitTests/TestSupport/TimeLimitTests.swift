import ConcurrencyExtras
import CustomDump
import Testing

@testable import AccountKitTestSupport

extension BaseSuite {
    @Suite
    struct TimeLimitTests {
        @Test
        func aBodyWithinTheTimeLimitRunsToTheEnd() async throws {
            let finished = LockIsolated(false)

            try await withTimeLimit(.seconds(10)) {
                finished.setValue(true)
            }

            #expect(finished.value)
        }

        @Test
        func aBodyErrorReachesTheCaller() async {
            await #expect(throws: BodyError.self) {
                try await withTimeLimit(.seconds(10)) {
                    throw BodyError()
                }
            }
        }

        @Test
        func aBodyOverTheTimeLimitRecordsAnIssueAndIsCanceled() async throws {
            let wasCanceled = LockIsolated(false)

            try await withKnownIssue {
                try await withTimeLimit(.milliseconds(100)) {
                    do {
                        try await Task.sleep(for: .seconds(10))
                    } catch is CancellationError {
                        wasCanceled.setValue(true)
                    }
                }
            } matching: { issue in
                issue.comments.map(\.rawValue) == ["Time limit was exceeded: 0.1 seconds"]
            }

            #expect(wasCanceled.value)
        }
    }
}

private struct BodyError: Error {}
