import ComposableArchitecture

public protocol SignedInFeature: Reducer, SendableMetatype where State: SignedInState {
    init()

    static func clearLocalData() async throws

    static func deleteUserData(uid: String, didDeleteSomeData: @Sendable () async -> Void) async throws
}

public protocol SignedInState {
    var isDeletingAccount: Bool { get }
    var isLoadingFirstContent: Bool { get }
    var isReauthenticating: Bool { get }
    var sessionOrigin: SessionOrigin { get }
    var user: AccountUser { get }

    init(user: AccountUser, sessionOrigin: SessionOrigin)
}
