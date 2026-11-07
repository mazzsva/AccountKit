# AccountKit

Sign in with Apple account flow in TCA, Firebase Auth, and Firestore.

AccountKit holds the account code that Lexicon and Overhead share: Sign in with Apple, Firebase Auth, Firestore storage, the session, sign-in, account deletion, and the account settings logic. It has no UI. Each app draws its own screens and supplies its own data through `SignedInFeature`.

## Core technologies

<table>
  <tr><td><b>Platform</b></td><td>iOS 27</td></tr>
  <tr><td><b>Language</b></td><td>Swift 6</td></tr>
  <tr><td><b>Architecture</b></td><td><a href="https://github.com/pointfreeco/swift-composable-architecture">The Composable Architecture</a></td></tr>
  <tr><td><b>Backend</b></td><td>Firebase</td></tr>
  <tr><td><b>Database</b></td><td>Cloud Firestore</td></tr>
  <tr><td><b>Authentication</b></td><td>Sign in with Apple</td></tr>
</table>

## Engineering decisions

**One session for every app.** `AccountSession` decides if the user is signed in, and shows sign-in or the app's home. The app gives it a `SignedInFeature` that knows how to clear and delete the app's own data.

**Apple Account checks.** The session checks the Apple Account credential on launch and each time the app becomes active, and it listens for revocations. Only a revoked credential signs the user out.

**Account deletion.** Deleting an account reauthenticates with Apple, deletes the Firestore data, revokes the token, then deletes the account. It times out after 60 seconds, and a failure after the revoke signs out.

**Safe cache clears.** Sign-out clears the local Firestore cache. Each storage call waits with `waitForClearing()`, so no new read or write starts during a clear.

**Emulator tests stay in each target.** The Firebase emulator helpers in `AccountKitTestSupport` are only for AccountKit's own tests. Linking them into a hosted app test target breaks the Firestore link, so each app keeps its own copy.
