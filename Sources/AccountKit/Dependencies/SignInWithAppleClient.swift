import AuthenticationServices
import CryptoKit
import Dependencies
import DependenciesMacros
import Foundation
import Security
import UIKit
import os

@DependencyClient
public struct SignInWithAppleClient: Sendable {
    public var credentialRevocations: @Sendable () -> AsyncStream<Void> = { AsyncStream { _ in } }
    public var credentialState: @Sendable (_ userID: String) async -> AppleCredentialState = { _ in .authorized }
    public var requestCredential: @Sendable () async throws -> AppleCredential
}

extension SignInWithAppleClient: DependencyKey {
    public static var liveValue: SignInWithAppleClient {
        SignInWithAppleClient(
            credentialRevocations: {
                AsyncStream { continuation in
                    nonisolated(unsafe) let observer = NotificationCenter.default.addObserver(
                        forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
                        object: nil,
                        queue: nil
                    ) { _ in
                        continuation.yield()
                    }
                    continuation.onTermination = { _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            },
            credentialState: { userID in
                await withCheckedContinuation { continuation in
                    ASAuthorizationAppleIDProvider()
                        .getCredentialState(forUserID: userID) { state, error in
                            if let error {
                                logger.error(
                                    "Reading the Apple ID credential state failed: \(error, privacy: .public)")
                            }
                            switch state {
                            case .authorized:
                                continuation.resume(returning: .authorized)
                            case .notFound:
                                continuation.resume(returning: .notFound)
                            case .revoked:
                                continuation.resume(returning: .revoked)
                            case .transferred:
                                continuation.resume(returning: .transferred)
                            @unknown default:
                                continuation.resume(returning: .unknown)
                            }
                        }
                }
            },
            requestCredential: {
                let rawNonce = randomNonce()
                let authorization = try await performAuthorization(hashedNonce: sha256(rawNonce))
                guard
                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = credential.identityToken,
                    let idToken = String(data: tokenData, encoding: .utf8)
                else {
                    throw ASAuthorizationError(.invalidResponse)
                }
                return AppleCredential(
                    authorizationCode: credential.authorizationCode
                        .flatMap { String(data: $0, encoding: .utf8) },
                    idToken: idToken,
                    rawNonce: rawNonce
                )
            }
        )
    }

    public static var previewValue: SignInWithAppleClient {
        SignInWithAppleClient(
            credentialRevocations: { AsyncStream { _ in } },
            credentialState: { _ in .authorized },
            requestCredential: { .mock }
        )
    }

    public static var testValue: SignInWithAppleClient {
        SignInWithAppleClient()
    }
}

extension DependencyValues {
    public var signInWithAppleClient: SignInWithAppleClient {
        get { self[SignInWithAppleClient.self] }
        set { self[SignInWithAppleClient.self] = newValue }
    }
}

extension Error {
    var isSignInWithAppleCancellation: Bool {
        (self as? ASAuthorizationError)?.code == .canceled
    }
}

@MainActor
private func performAuthorization(hashedNonce: String) async throws -> ASAuthorization {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.email]
    request.nonce = hashedNonce
    return try await AuthorizationCoordinator().perform(request)
}

func randomNonce() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    precondition(status == errSecSuccess, "Unable to generate a random nonce.")
    return bytes.map { String(format: "%02x", $0) }.joined()
}

func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
}

@MainActor
private final class AuthorizationCoordinator: NSObject {
    private var continuation: CheckedContinuation<ASAuthorization, any Error>?
    private var controller: ASAuthorizationController?

    func perform(_ request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func resume(with result: Result<ASAuthorization, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }
}

extension AuthorizationCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            resume(with: .success(authorization))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        Task { @MainActor in
            resume(with: .failure(error))
        }
    }
}

extension AuthorizationCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            guard let anchor = windows.first(where: \.isKeyWindow) ?? windows.first else {
                preconditionFailure("No window available to present Sign in with Apple.")
            }
            return anchor
        }
    }
}

private let logger = Logger(category: "SignInWithAppleClient")
