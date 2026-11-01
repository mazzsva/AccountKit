import CustomDump
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct AppleCredentialStateTests {
        @Test(
            arguments: [
                (AppleCredentialState.authorized, "authorized"),
                (.notFound, "not found"),
                (.revoked, "revoked"),
                (.transferred, "transferred to another team"),
                (.unknown, "in an unknown state"),
            ]
        )
        func eachStateHasADescription(state: AppleCredentialState, description: String) {
            expectNoDifference(state.description, description)
        }

        @Test
        func theDescriptionIsUsedInAString() {
            expectNoDifference("The credential is \(AppleCredentialState.revoked).", "The credential is revoked.")
        }
    }
}
