import AccountKitTestSupport
import ConcurrencyExtras
import CustomDump
import Testing

extension BaseSuite {
    @Suite
    struct RecordingTests {
        @Test
        func eachValueIsRecordedInOrder() async throws {
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            let recording = Recording(stream)
            defer { recording.cancel() }

            continuation.yield(1)
            continuation.yield(2)
            continuation.yield(3)

            try await recording.wait { $0.count == 3 }
            expectNoDifference(recording.values, [1, 2, 3])
        }

        @Test
        func theFailureIsTheErrorTheStreamThrows() async throws {
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            let recording = Recording(stream)
            defer { recording.cancel() }

            continuation.yield(1)
            continuation.finish(throwing: StreamError())

            let failure = try await recording.waitForFailure()
            #expect(failure is StreamError)
            expectNoDifference(recording.values, [1])
        }

        @Test
        func aWaitWithoutTheValueTimesOut() async {
            let (stream, _) = AsyncThrowingStream<Int, any Error>.makeStream()
            let recording = Recording(stream)
            defer { recording.cancel() }

            await withKnownIssue {
                await #expect(throws: TimeoutError.self) {
                    try await recording.wait(timeout: .milliseconds(100)) { !$0.isEmpty }
                }
            }
        }

        @Test
        func aWaitForAFailureWithoutAnErrorTimesOut() async {
            let (stream, _) = AsyncThrowingStream<Int, any Error>.makeStream()
            let recording = Recording(stream)
            defer { recording.cancel() }

            await withKnownIssue {
                await #expect(throws: TimeoutError.self) {
                    _ = try await recording.waitForFailure(timeout: .milliseconds(100))
                }
            }
        }

        @Test
        func cancelingEndsTheStream() async throws {
            let terminated = LockIsolated(false)
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            continuation.onTermination = { _ in terminated.setValue(true) }
            let recording = Recording(stream)

            continuation.yield(1)
            try await recording.wait { $0 == [1] }
            recording.cancel()

            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while !terminated.value, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(terminated.value)
        }
    }
}

private struct StreamError: Error {}
