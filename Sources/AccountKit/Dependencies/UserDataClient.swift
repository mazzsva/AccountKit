import Dependencies
import DependenciesMacros
import IssueReporting

@DependencyClient
struct UserDataClient: Sendable {
    var deleteAll: @Sendable (_ uid: String, _ didDeleteSomeData: @Sendable () async -> Void) async throws -> Void
}

extension UserDataClient: DependencyKey {
    static var liveValue: UserDataClient {
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

    static var previewValue: UserDataClient {
        UserDataClient(deleteAll: { _, _ in })
    }

    static var testValue: UserDataClient {
        UserDataClient()
    }
}

extension DependencyValues {
    var userDataClient: UserDataClient {
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
