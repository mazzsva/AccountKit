public struct AppleCredential: Equatable, Sendable {
    public let authorizationCode: String?
    public let idToken: String
    public let rawNonce: String

    public init(authorizationCode: String?, idToken: String, rawNonce: String) {
        self.authorizationCode = authorizationCode
        self.idToken = idToken
        self.rawNonce = rawNonce
    }
}

extension AppleCredential {
    public static let mock = AppleCredential(
        authorizationCode: "mock-authorization-code",
        idToken: "mock-id-token",
        rawNonce: "mock-raw-nonce"
    )
}
