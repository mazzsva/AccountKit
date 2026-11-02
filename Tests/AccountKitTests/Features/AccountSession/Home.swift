import AccountKit
import ComposableArchitecture

@Reducer
struct Home: SignedInFeature {
    @ObservableState
    struct State: Equatable, SignedInState {
        @Presents var accountDeletion: AccountDeletion.State?
        var isLoadingFirstContent = true
        var settings = AccountSettings.State()
        let sessionOrigin: SessionOrigin
        let user: AccountUser

        init(user: AccountUser, sessionOrigin: SessionOrigin = .restored) {
            self.sessionOrigin = sessionOrigin
            self.user = user
        }

        var isDeletingAccount: Bool { accountDeletion != nil }

        var isReauthenticating: Bool { accountDeletion?.step == .reauthenticating }
    }

    enum Action {
        case accountDeletion(PresentationAction<AccountDeletion.Action>)
        case saveButtonTapped
        case saveFailed(any Error)
        case settings(AccountSettings.Action)
    }

    @Dependency(\.homeClient) var homeClient

    var body: some Reducer<State, Action> {
        Scope(state: \.settings, action: \.settings) {
            AccountSettings()
        }
        Reduce { state, action in
            switch action {
            case .accountDeletion(.presented(.delegate(.didCancel))):
                state.accountDeletion = nil
                return .none

            case .accountDeletion(.presented(.delegate(.didFail(let failure)))):
                state.accountDeletion = nil
                state.settings.alert = .accountDeletionFailed(failure)
                return .none

            case .accountDeletion:
                return .none

            case .saveButtonTapped:
                return .run { _ in
                    try await homeClient.save()
                } catch: { error, send in
                    await send(.saveFailed(error))
                }

            case .saveFailed:
                return .none

            case .settings(.delegate(.didConfirmAccountDeletion)):
                state.accountDeletion = AccountDeletion.State(uid: state.user.uid)
                return .send(.accountDeletion(.presented(.deletionConfirmed)))

            case .settings:
                return .none
            }
        }
        .ifLet(\.$accountDeletion, action: \.accountDeletion) {
            AccountDeletion()
        }
    }

    static func clearLocalData() async throws {
        @Dependency(\.homeClient) var homeClient
        try await homeClient.clearLocalData()
    }

    static func deleteUserData(uid: String, didDeleteSomeData: @Sendable () async -> Void) async throws {
        @Dependency(\.homeClient) var homeClient
        try await homeClient.deleteAll(uid: uid, didDeleteSomeData: didDeleteSomeData)
    }
}

@DependencyClient
struct HomeClient: Sendable {
    var clearLocalData: @Sendable () async throws -> Void
    var deleteAll: @Sendable (_ uid: String, _ didDeleteSomeData: @Sendable () async -> Void) async throws -> Void
    var save: @Sendable () async throws -> Void
}

extension HomeClient: TestDependencyKey {
    static var testValue: HomeClient {
        HomeClient()
    }
}

extension DependencyValues {
    var homeClient: HomeClient {
        get { self[HomeClient.self] }
        set { self[HomeClient.self] = newValue }
    }
}
