public enum ProfileSnapshot<Value: Equatable & Sendable>: Equatable, Sendable {
    case known(Value)
    case unknown
}
