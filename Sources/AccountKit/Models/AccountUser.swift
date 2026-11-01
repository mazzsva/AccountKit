public struct AccountUser: Equatable, Sendable {
    public let email: String?
    public let uid: String

    public init(email: String?, uid: String) {
        self.email = email
        self.uid = uid
    }
}

extension AccountUser {
    public static let mock = AccountUser(email: "user@example.com", uid: "mock-uid")
}
