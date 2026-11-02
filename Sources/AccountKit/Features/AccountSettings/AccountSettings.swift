import ComposableArchitecture
import Foundation
import SwiftUI
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
    public static func accountDeletionFailed(_ failure: AccountDeletion.Failure) -> AlertState {
        AlertState {
            TextState("Something Went Wrong", bundle: .module)
        } message: {
            switch failure {
            case .connectionFailed:
                TextState("Your account couldn't be deleted. Check your connection and try again.", bundle: .module)
            case .notDeleted:
                TextState("Your account couldn't be deleted.", bundle: .module)
            case .notFullyDeleted:
                TextState("Your account couldn't be fully deleted.", bundle: .module)
            case .notSignedOut:
                TextState("You couldn't be signed out.", bundle: .module)
            }
        }
    }

    public static let confirmAccountDeletion = AlertState {
        TextState("Delete Account", bundle: .module)
    } actions: {
        ButtonState(role: .destructive, action: .confirmAccountDeletion) {
            TextState("Delete", bundle: .module)
        }
        ButtonState(role: .cancel) {
            TextState("Cancel", bundle: .module)
        }
    } message: {
        TextState("Your account and all your data will be permanently deleted. Are you sure?", bundle: .module)
    }

    public static let confirmSignOut = AlertState {
        TextState("Sign Out", bundle: .module)
    } actions: {
        ButtonState(role: .destructive, action: .confirmSignOut) {
            TextState("Sign Out", bundle: .module)
        }
        ButtonState(role: .cancel) {
            TextState("Cancel", bundle: .module)
        }
    } message: {
        TextState("Are you sure you want to sign out?", bundle: .module)
    }

    public static let signOutFailed = AlertState {
        TextState("Something Went Wrong", bundle: .module)
    } message: {
        TextState("You couldn't be signed out.", bundle: .module)
    }
}

private let logger = Logger(category: "Settings")
