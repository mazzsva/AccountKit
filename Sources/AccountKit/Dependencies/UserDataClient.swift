import Dependencies
import DependenciesMacros
import IssueReporting

@DependencyClient
public struct UserDataClient: Sendable {
    public var deleteAll:
        @Sendable (_ uid: String, _ didDeleteSomeData: @Sendable () async -> Void) async throws -> Void
}

extension UserDataClient: DependencyKey {
    public static var liveValue: UserDataClient {
        UserDataClient(
            deleteAll: { _, _ in
                let description = "UserDataClient has no live value. Set it with prepareDependencies at launch."
                reportIssue(description)
                throw UnimplementedFailure(description: description)
            }
        )
    }

    public static var previewValue: UserDataClient {
        UserDataClient(deleteAll: { _, _ in })
    }

    public static var testValue: UserDataClient {
        UserDataClient()
    }
}

extension DependencyValues {
    public var userDataClient: UserDataClient {
        get { self[UserDataClient.self] }
        set { self[UserDataClient.self] = newValue }
    }
}
