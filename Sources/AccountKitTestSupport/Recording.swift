import ConcurrencyExtras
import CustomDump
import Testing

public final class Recording<Element: Sendable>: Sendable {
    private let failure = LockIsolated<(any Error)?>(nil)
    private let recorded = LockIsolated<[Element]>([])
    private let task = LockIsolated<Task<Void, Never>?>(nil)

    public init(_ stream: AsyncThrowingStream<Element, any Error>) {
        task.setValue(
            Task { [failure, recorded] in
                do {
                    for try await value in stream {
                        recorded.withValue { $0.append(value) }
                    }
                } catch {
                    failure.setValue(error)
                }
            }
        )
    }

    public var values: [Element] { recorded.value }

    public func cancel() {
        task.value?.cancel()
    }

    public func wait(
        timeout: Duration = .seconds(10),
        sourceLocation: SourceLocation = #_sourceLocation,
        until condition: ([Element]) -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition(recorded.value) {
            guard ContinuousClock.now < deadline else {
                Issue.record(
                    "Timed out. Recorded: \(String(customDumping: recorded.value))", sourceLocation: sourceLocation)
                throw TimeoutError()
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    public func waitForFailure(
        timeout: Duration = .seconds(10),
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> any Error {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while true {
            if let failure = failure.value { return failure }
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for a failure.", sourceLocation: sourceLocation)
                throw TimeoutError()
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

public struct TimeoutError: Error {}
