import CustomDump
import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct AccountUserTests {
        @Test
        func theMockHasAnEmailAndAUID() {
            expectNoDifference(AccountUser.mock, AccountUser(email: "user@example.com", uid: "mock-uid"))
        }

        @Test
        func aUserWithoutAnEmailIsAnotherUser() {
            #expect(AccountUser(email: nil, uid: "mock-uid") != .mock)
        }
    }
}
