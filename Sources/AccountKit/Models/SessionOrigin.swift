import CasePaths

@CasePathable
public enum SessionOrigin: Equatable, Sendable {
    case freshSignIn
    case restored
}
