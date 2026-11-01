import CustomDump
import Dependencies
import FirebaseAuth
import Foundation
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct AuthClientTests {
        @Test
        func onlyTheFirebaseNetworkErrorIsANetworkError() {
            let networkError = NSError(domain: AuthErrors.domain, code: AuthErrorCode.networkError.rawValue)
            let otherAuthError = NSError(domain: AuthErrors.domain, code: AuthErrorCode.userNotFound.rawValue)
            let otherDomainError = NSError(domain: NSURLErrorDomain, code: AuthErrorCode.networkError.rawValue)

            #expect(networkError.isAuthNetworkError)
            #expect(!otherAuthError.isAuthNetworkError)
            #expect(!otherDomainError.isAuthNetworkError)
            #expect(!URLError(.notConnectedToInternet).isAuthNetworkError)
        }

        @Test
        func theTestValueFailsWhenTheSignInIsNotImplemented() async {
            @Dependency(\.authClient) var authClient

            await withKnownIssue {
                try await authClient.signIn(credential: .mock)
            }
        }

        @Test
        func thePreviewValueIsSignedInAsTheMockUser() async {
            let client = AuthClient.previewValue

            var changes = client.authStateChanges().makeAsyncIterator()
            let change = await changes.next()

            expectNoDifference(client.appleUserID(), "mock-apple-user-id")
            expectNoDifference(client.currentUser(), .mock)
            expectNoDifference(change, .some(.mock))
        }
    }
}
