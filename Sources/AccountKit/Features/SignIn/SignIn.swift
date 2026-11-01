import ComposableArchitecture
import Foundation
import os

@Reducer
public struct SignIn: Sendable {
    public enum Alert: Equatable, Sendable {}

    public enum Step: Equatable, Sendable {
        case awaitingAuthorization
        case signingIn
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var alert: AlertState<SignIn.Alert>?
        public var step: Step?

        public var isAuthenticating: Bool { step != nil }

        public init(alert: AlertState<SignIn.Alert>? = nil, step: Step? = nil) {
            self.alert = alert
            self.step = step
        }
    }

    public enum Action: Sendable {
        case alert(PresentationAction<Alert>)
        case authorizationResponse(Result<AppleCredential, any Error>)
        case signInButtonTapped
        case signInFailed(any Error)
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.signInWithAppleClient) var signInWithAppleClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alert:
                return .none

            case .authorizationResponse(.success(let credential)):
                state.step = .signingIn
                return .run { _ in
                    try await authClient.signIn(credential: credential)
                } catch: { error, send in
                    await send(.signInFailed(error))
                }

            case .authorizationResponse(.failure(let error)):
                state.step = nil
                if !error.isSignInWithAppleCancellation {
                    logger.error("Apple authorization failed: \(error, privacy: .public)")
                    state.alert = .signInFailed
                }
                return .none

            case .signInButtonTapped:
                guard state.step == nil else { return .none }
                state.step = .awaitingAuthorization
                return .run { send in
                    await send(.authorizationResponse(Result { try await signInWithAppleClient.requestCredential() }))
                }

            case .signInFailed(let error):
                state.step = nil
                logger.error("Firebase sign-in failed: \(error, privacy: .public)")
                state.alert = .signInFailed
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == SignIn.Alert {
    public static let signInFailed = AlertState {
        TextState("Something Went Wrong")
    } message: {
        TextState("You couldn't be signed in.")
    }
}

private let logger = Logger(category: "SignIn")
