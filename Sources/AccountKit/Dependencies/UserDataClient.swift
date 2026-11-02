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
            deleteAll: { uid, didDeleteSomeData in
                @Dependency(\.signedInUserDataClient) var signedInUserDataClient
                guard let signedInUserDataClient else {
                    let description = "UserDataClient has no live value outside an AccountSession."
                    reportIssue(description)
                    throw UnimplementedFailure(description: description)
                }
                try await signedInUserDataClient.deleteAll(uid, didDeleteSomeData)
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

    var signedInUserDataClient: UserDataClient? {
        get { self[SignedInUserDataClientKey.self] }
        set { self[SignedInUserDataClientKey.self] = newValue }
    }
}

private enum SignedInUserDataClientKey: DependencyKey {
    static let liveValue: UserDataClient? = nil
    static let testValue: UserDataClient? = nil
}
