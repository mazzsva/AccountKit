import AuthenticationServices
import CustomDump
import Dependencies
import Foundation
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct SignInWithAppleClientTests {
        @Test
        func onlyACanceledAuthorizationIsACancellation() {
            #expect(ASAuthorizationError(.canceled).isSignInWithAppleCancellation)
            #expect(!ASAuthorizationError(.failed).isSignInWithAppleCancellation)
            #expect(!ASAuthorizationError(.unknown).isSignInWithAppleCancellation)
            #expect(!URLError(.cancelled).isSignInWithAppleCancellation)
        }

        @Test(
            arguments: [
                (ASAuthorizationAppleIDProvider.CredentialState.authorized, AppleCredentialState.authorized),
                (.notFound, .notFound),
                (.revoked, .revoked),
                (.transferred, .transferred),
            ]
        )
        func eachCredentialStateWithoutAnErrorKeepsItsCase(
            state: ASAuthorizationAppleIDProvider.CredentialState,
            expected: AppleCredentialState
        ) {
            expectNoDifference(appleCredentialState(from: state, error: nil), expected)
        }

        @Test(
            arguments: [
                ASAuthorizationAppleIDProvider.CredentialState.authorized,
                .notFound,
                .revoked,
                .transferred,
            ]
        )
        func aCredentialStateWithAnErrorIsUnknown(state: ASAuthorizationAppleIDProvider.CredentialState) {
            expectNoDifference(appleCredentialState(from: state, error: ASAuthorizationError(.failed)), .unknown)
        }

        @Test
        func theNonceIs64LowercaseHexadecimalCharacters() {
            let nonce = randomNonce()

            expectNoDifference(nonce.count, 64)
            #expect(nonce.allSatisfy { "0123456789abcdef".contains($0) })
        }

        @Test
        func eachNonceIsDifferent() {
            #expect(randomNonce() != randomNonce())
        }

        @Test
        func theHashIsTheLowercaseHexadecimalSHA256() {
            expectNoDifference(sha256(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            expectNoDifference(sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        }

        @Test
        func theTestValueFailsWhenTheCredentialRequestIsNotImplemented() async {
            @Dependency(\.signInWithAppleClient) var signInWithAppleClient

            await withKnownIssue {
                _ = try await signInWithAppleClient.requestCredential()
            }
        }

        @Test
        func thePreviewValueIsAuthorizedWithTheMockCredential() async throws {
            let client = SignInWithAppleClient.previewValue

            let state = await client.credentialState(userID: "mock-apple-user-id")
            let credential = try await client.requestCredential()

            expectNoDifference(state, .authorized)
            expectNoDifference(credential, .mock)
        }
    }
}
