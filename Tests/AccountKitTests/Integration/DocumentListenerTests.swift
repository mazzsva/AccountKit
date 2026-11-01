import AccountKitTestSupport
import CustomDump
import FirebaseFirestore
import Foundation
import Testing

@testable import AccountKit

extension BaseSuite.IntegrationSuite {
    @Suite
    struct DocumentListenerTests {
        @Test
        func aMissingProfileArrivesAsKnownNil() async throws {
            let uid = try await newUID()
            let values = Recording(await profileValues(uid: uid))
            defer { values.cancel() }

            try await values.wait { $0 == [.known(nil)] }
        }

        @Test
        func aMissingProfileIsUnknownWhileOfflineBeforeAnySync() async throws {
            let uid = try await newUID()
            try await Firestore.firestore().disableNetwork()
            let values = Recording(await profileValues(uid: uid))
            defer { values.cancel() }

            try await values.wait { $0 == [.unknown] }

            try await Firestore.firestore().enableNetwork()
            try await values.wait { $0.last == .known(nil) }
        }

        @Test
        func aSyncedMissingProfileIsKnownWhileOffline() async throws {
            let uid = try await newUID()
            let synced = Recording(await profileValues(uid: uid))
            try await synced.wait { $0.last == .known(nil) }
            synced.cancel()

            try await Firestore.firestore().disableNetwork()
            let values = Recording(await profileValues(uid: uid))
            defer { values.cancel() }

            try await values.wait { $0 == [.known(nil)] }
            try await Firestore.firestore().enableNetwork()
        }

        @Test
        func eachDecodedValueArrivesOnce() async throws {
            let uid = try await newUID()
            let values = Recording(await profileValues(uid: uid))
            defer { values.cancel() }
            try await values.wait { $0 == [.known(nil)] }

            try await AccountStorage.profileDocument(uid: uid).setData(["value": 1], merge: true)
            try await values.wait { $0 == [.known(nil), .known(1)] }

            try await AccountStorage.profileDocument(uid: uid).setData(["other": 2], merge: true)
            try await AccountStorage.profileDocument(uid: uid).updateData(["value": FieldValue.delete()])
            try await values.wait { $0 == [.known(nil), .known(1), .known(nil)] }

            try await AccountStorage.profileDocument(uid: uid).setData(["value": 3], merge: true)
            try await values.wait { $0.last == .known(3) }
            expectNoDifference(values.values, [.known(nil), .known(1), .known(nil), .known(3)])
        }

        @Test
        func aValueRemovedOfflineBecomesNilAtOnce() async throws {
            let uid = try await newUID()
            try await AccountStorage.profileDocument(uid: uid).setData(["value": 1])
            let values = Recording(await profileValues(uid: uid))
            defer { values.cancel() }
            try await values.wait { $0.last == .known(1) }

            try await Firestore.firestore().disableNetwork()
            let deletion = Task {
                try await AccountStorage.profileDocument(uid: uid).updateData(["value": FieldValue.delete()])
            }

            try await values.wait { $0.last == .known(nil) }
            try await Firestore.firestore().enableNetwork()
            try await deletion.value
        }

        @Test
        func aRefusedListenerEndsTheStream() async throws {
            try await FirebaseEmulators.clearLocalData()

            let values = Recording(await profileValues(uid: lockedUID))
            defer { values.cancel() }
            let failure = try await values.waitForFailure() as NSError
            expectNoDifference(failure.code, FirestoreErrorCode.permissionDenied.rawValue)
            expectNoDifference(values.values, [])
        }

        private func profileValues(uid: String) async -> AsyncThrowingStream<ProfileSnapshot<Int?>, any Error> {
            await AccountStorage.shared.profileSnapshots(uid: uid) { $0?["value"] as? Int }
        }
    }
}
