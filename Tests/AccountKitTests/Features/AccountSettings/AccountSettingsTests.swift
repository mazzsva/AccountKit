import ComposableArchitecture
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    @MainActor
    struct AccountSettingsTests {
        // A sign out clears the local data
        @Test
        func theSignOutButtonAsksForConfirmation() async {
            let store = TestStore(initialState: AccountSettings.State()) {
                AccountSettings()
            }

            await store.send(.signOutButtonTapped) {
                $0.alert = .confirmSignOut
            }
        }

        // The app feature listens to Firebase, so the settings only start the sign out
        @Test
        func confirmingTheSignOutSignsTheUserOut() async {
            await confirmation("Signs the user out") { signsOut in
                let store = TestStore(initialState: AccountSettings.State(alert: .confirmSignOut)) {
                    AccountSettings()
                } withDependencies: {
                    $0.authClient.signOut = { signsOut() }
                }

                await store.send(.alert(.presented(.confirmSignOut))) {
                    $0.alert = nil
                }
                await store.finish()
            }
        }

        // The settings stay on screen because the user is still signed in
        @Test
        func aFailedSignOutShowsAnAlert() async {
            let store = TestStore(initialState: AccountSettings.State(alert: .confirmSignOut)) {
                AccountSettings()
            } withDependencies: {
                $0.authClient.signOut = { throw SignOutFailure() }
            }

            await store.send(.alert(.presented(.confirmSignOut))) {
                $0.alert = nil
            }
            await store.receive(\.signOutFailed) {
                $0.alert = .signOutFailed
            }
        }

        // A dismissed confirmation must not sign the user out
        @Test
        func dismissingTheAlertClearsIt() async {
            let store = TestStore(initialState: AccountSettings.State(alert: .confirmSignOut)) {
                AccountSettings()
            }

            await store.send(.alert(.dismiss)) {
                $0.alert = nil
            }
        }

        // The deletion removes the user data from every device
        @Test
        func theDeleteAccountButtonAsksForConfirmation() async {
            let store = TestStore(initialState: AccountSettings.State()) {
                AccountSettings()
            }

            await store.send(.deleteAccountButtonTapped) {
                $0.alert = .confirmAccountDeletion
            }
        }

        @Test
        func confirmingTheAccountDeletionAsksTheParentToDeleteTheAccount() async {
            let store = TestStore(initialState: AccountSettings.State(alert: .confirmAccountDeletion)) {
                AccountSettings()
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
            }
            await store.receive(\.delegate.didConfirmAccountDeletion)
        }

        private struct SignOutFailure: Error {}
    }
}
