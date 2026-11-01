import AccountKitTestSupport
import Foundation
import Testing

extension BaseSuite {
    @Suite(.firebaseEmulators(projectID: "demo-accountkit"))
    struct IntegrationSuite {}
}

let lockedUID = "locked"

func newUID() async throws -> String {
    try await FirebaseEmulators.clearLocalData()
    return UUID().uuidString
}
