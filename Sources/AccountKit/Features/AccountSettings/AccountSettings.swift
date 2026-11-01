import ComposableArchitecture
import Foundation
import os

@Reducer
public struct AccountSettings: Sendable {
    public enum Alert: Equatable, Sendable {
        case confirmAccountDeletion
        case confirmSignOut
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var alert: AlertState<AccountSettings.Alert>?

        public init(alert: AlertState<AccountSettings.Alert>? = nil) {
            self.alert = alert
        }
    }

    public enum Action: Sendable {
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        case deleteAccountButtonTapped
        case signOutButtonTapped
        case signOutFailed(any Error)

        @CasePathable
        public enum Delegate: Sendable {
            case didConfirmAccountDeletion
        }
    }

    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmAccountDeletion)):
                return .send(.delegate(.didConfirmAccountDeletion))

            case .alert(.presented(.confirmSignOut)):
                return .run { _ in
                    try await authClient.signOut()
                } catch: { error, send in
                    await send(.signOutFailed(error))
                }

            case .alert:
                return .none

            case .delegate:
                return .none

            case .deleteAccountButtonTapped:
                state.alert = .confirmAccountDeletion
                return .none

            case .signOutButtonTapped:
                state.alert = .confirmSignOut
                return .none

            case .signOutFailed(let error):
                logger.error("Sign out failed: \(error, privacy: .public)")
                state.alert = .signOutFailed
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == AccountSettings.Alert {
    public static let confirmAccountDeletion = AlertState {
        TextState("Delete Account")
    } actions: {
        ButtonState(role: .destructive, action: .confirmAccountDeletion) {
            TextState("Delete")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Your account and all your data will be permanently deleted. Are you sure?")
    }

    public static let confirmSignOut = AlertState {
        TextState("Sign Out")
    } actions: {
        ButtonState(role: .destructive, action: .confirmSignOut) {
            TextState("Sign Out")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Are you sure you want to sign out?")
    }

    public static let signOutFailed = AlertState {
        TextState("Something Went Wrong")
    } message: {
        TextState("You couldn't be signed out.")
    }
}

private let logger = Logger(category: "Settings")
