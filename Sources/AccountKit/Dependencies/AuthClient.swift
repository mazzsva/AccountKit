import Dependencies
import DependenciesMacros
import FirebaseAuth

@DependencyClient
public struct AuthClient: Sendable {
    public var appleUserID: @Sendable () -> String? = { nil }
    public var authStateChanges: @Sendable () -> AsyncStream<AccountUser?> = { AsyncStream { _ in } }
    public var currentUser: @Sendable () -> AccountUser? = { nil }
    public var deleteAccount: @Sendable () async throws -> Void
    public var reauthenticate: @Sendable (_ credential: AppleCredential) async throws -> Void
    public var revokeAppleToken: @Sendable (_ authorizationCode: String) async throws -> Void
    public var signIn: @Sendable (_ credential: AppleCredential) async throws -> Void
    public var signOut: @Sendable () async throws -> Void
}

extension AuthClient: DependencyKey {
    public static var liveValue: AuthClient {
        AuthClient(
            appleUserID: {
                Auth.auth().currentUser?.providerData
                    .first { $0.providerID == AuthProviderID.apple.rawValue }?
                    .uid
            },
            authStateChanges: {
                AsyncStream { continuation in
                    nonisolated(unsafe) let handle = Auth.auth()
                        .addStateDidChangeListener { _, user in
                            continuation.yield(user.map { AccountUser(email: $0.email, uid: $0.uid) })
                        }
                    continuation.onTermination = { _ in
                        Auth.auth().removeStateDidChangeListener(handle)
                    }
                }
            },
            currentUser: {
                Auth.auth().currentUser.map { AccountUser(email: $0.email, uid: $0.uid) }
            },
            deleteAccount: {
                try await signedInUser().delete()
            },
            reauthenticate: { credential in
                try await signedInUser().reauthenticate(with: firebaseCredential(from: credential))
            },
            revokeAppleToken: { authorizationCode in
                try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
            },
            signIn: { credential in
                try await Auth.auth().signIn(with: firebaseCredential(from: credential))
            },
            signOut: {
                try Auth.auth().signOut()
            }
        )
    }

    public static var previewValue: AuthClient {
        AuthClient(
            appleUserID: { "mock-apple-user-id" },
            authStateChanges: {
                AsyncStream { continuation in
                    continuation.yield(.mock)
                }
            },
            currentUser: { .mock },
            deleteAccount: {},
            reauthenticate: { _ in },
            revokeAppleToken: { _ in },
            signIn: { _ in },
            signOut: {}
        )
    }

    public static var testValue: AuthClient {
        AuthClient()
    }
}

extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

extension Error {
    var isAuthNetworkError: Bool {
        let error = self as NSError
        return error.domain == AuthErrors.domain && error.code == AuthErrorCode.networkError.rawValue
    }
}

private enum AuthClientError: Error {
    case notSignedIn
}

private func signedInUser() throws -> FirebaseAuth.User {
    guard let user = Auth.auth().currentUser else { throw AuthClientError.notSignedIn }
    return user
}

private func firebaseCredential(from credential: AppleCredential) -> AuthCredential {
    OAuthProvider.appleCredential(
        withIDToken: credential.idToken,
        rawNonce: credential.rawNonce,
        fullName: nil
    )
}
