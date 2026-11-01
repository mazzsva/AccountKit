public enum AppleCredentialState: Sendable {
    case authorized
    case notFound
    case revoked
    case transferred
    case unknown
}

extension AppleCredentialState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .authorized: "authorized"
        case .notFound: "not found"
        case .revoked: "revoked"
        case .transferred: "transferred to another team"
        case .unknown: "in an unknown state"
        }
    }
}
