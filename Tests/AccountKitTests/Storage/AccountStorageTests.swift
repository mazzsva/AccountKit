import ConcurrencyExtras
import CustomDump
import Foundation
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct AccountStorageTests {
        @Test
        func aClearDuringAClearJoinsIt() async throws {
            let gate = Gate()
            let clears = LockIsolated(0)
            let storage = AccountStorage {
                clears.withValue { $0 += 1 }
                await gate.wait()
            }

            let first = Task { try await storage.clearLocalData() }
            try await waitUntil { clears.value == 1 }
            let second = Task { try await storage.clearLocalData() }
            try await Task.sleep(for: .milliseconds(100))
            gate.open()

            try await first.value
            try await second.value
            expectNoDifference(clears.value, 1)
        }

        @Test
        func aClearDuringAClearThrowsTheSameError() async throws {
            let gate = Gate()
            let clears = LockIsolated(0)
            let storage = AccountStorage {
                clears.withValue { $0 += 1 }
                await gate.wait()
                throw ClearError()
            }

            let first = Task { try await storage.clearLocalData() }
            try await waitUntil { clears.value == 1 }
            let second = Task { try await storage.clearLocalData() }
            try await Task.sleep(for: .milliseconds(100))
            gate.open()

            await #expect(throws: ClearError.self) { try await first.value }
            await #expect(throws: ClearError.self) { try await second.value }
            expectNoDifference(clears.value, 1)
        }

        @Test
        func aClearAfterAFailedClearStartsAgain() async throws {
            let clears = LockIsolated(0)
            let storage = AccountStorage {
                let clear = clears.withValue {
                    $0 += 1
                    return $0
                }
                if clear == 1 {
                    throw ClearError()
                }
            }

            await #expect(throws: ClearError.self) { try await storage.clearLocalData() }
            try await storage.clearLocalData()

            expectNoDifference(clears.value, 2)
        }

        @Test
        func aClearDuringAnOperationStartsAfterItsSynchronousPart() async throws {
            let events = LockIsolated<[String]>([])
            let storage = AccountStorage {
                events.withValue { $0.append("cleared") }
            }

            let clear = await storage.runSynchronousOperation {
                let clear = Task { try await storage.clearLocalData() }
                usleep(100_000)
                events.withValue { $0.append("operation") }
                return clear
            }

            try await clear.value
            expectNoDifference(events.value, ["operation", "cleared"])
        }

        @Test
        func waitingDuringAClearReturnsAfterTheClear() async throws {
            let gate = Gate()
            let events = LockIsolated<[String]>([])
            let storage = AccountStorage {
                events.withValue { $0.append("started") }
                await gate.wait()
                events.withValue { $0.append("cleared") }
            }

            let clear = Task { try await storage.clearLocalData() }
            try await waitUntil { events.value == ["started"] }
            let wait = Task {
                await storage.waitForClearing()
                events.withValue { $0.append("waited") }
            }
            try await Task.sleep(for: .milliseconds(100))
            expectNoDifference(events.value, ["started"])
            gate.open()

            try await clear.value
            await wait.value
            expectNoDifference(events.value, ["started", "cleared", "waited"])
        }

        @Test
        func waitingDuringAFailedClearReturnsWithoutAnError() async throws {
            let gate = Gate()
            let clears = LockIsolated(0)
            let storage = AccountStorage {
                clears.withValue { $0 += 1 }
                await gate.wait()
                throw ClearError()
            }

            let clear = Task { try await storage.clearLocalData() }
            try await waitUntil { clears.value == 1 }
            let wait = Task { await storage.waitForClearing() }
            try await Task.sleep(for: .milliseconds(100))
            gate.open()

            await #expect(throws: ClearError.self) { try await clear.value }
            await wait.value
        }

        @Test
        func waitingWithoutAClearReturnsAtOnce() async {
            let storage = AccountStorage {
                Issue.record("The storage cleared without a request.")
            }

            await storage.waitForClearing()
        }
    }
}

private struct ClearError: Error {}

extension AccountStorage {
    fileprivate func runSynchronousOperation<Result: Sendable>(_ operation: () -> Result) -> Result {
        operation()
    }
}

private struct TimeoutError: Error {}

private final class Gate: Sendable {
    private let continuation: AsyncStream<Void>.Continuation
    private let opening: Task<Void, Never>

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.continuation = continuation
        opening = Task {
            for await _ in stream {}
        }
    }

    func open() {
        continuation.finish()
    }

    func wait() async {
        await opening.value
    }
}

private func waitUntil(
    timeout: Duration = .seconds(10),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out.", sourceLocation: sourceLocation)
            throw TimeoutError()
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}
