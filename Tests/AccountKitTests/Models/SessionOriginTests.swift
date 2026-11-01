import CasePaths
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct SessionOriginTests {
        @Test
        func eachOriginMatchesOnlyItsOwnCase() {
            #expect(SessionOrigin.freshSignIn.is(\.freshSignIn))
            #expect(!SessionOrigin.freshSignIn.is(\.restored))
            #expect(SessionOrigin.restored.is(\.restored))
            #expect(!SessionOrigin.restored.is(\.freshSignIn))
        }
    }
}
