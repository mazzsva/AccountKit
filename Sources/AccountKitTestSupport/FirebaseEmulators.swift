import AccountKit
import ConcurrencyExtras
import FirebaseCore
import FirebaseFirestore
import Foundation
import Testing

public enum FirebaseEmulators {
    public static let isAvailable = ProcessInfo.processInfo.environment["FIREBASE_EMULATORS"] == "1"

    private static let configuredProjectID = LockIsolated<String?>(nil)
    private static let settingsLock = NSLock()

    public static func clearLocalData() async throws {
        guard configuredProjectID.value != nil else { throw MissingTraitError() }
        try await AccountStorage.shared.clearLocalData()
        useFirestoreEmulator()
    }

    static func configure(projectID: String) {
        configuredProjectID.withValue { configuredProjectID in
            if let configuredProjectID {
                if configuredProjectID != projectID {
                    Issue.record("The emulators already use the project \(configuredProjectID).")
                }
                return
            }
            let options = FirebaseOptions(
                googleAppID: "1:123456789000:ios:0000000000000000", gcmSenderID: "123456789000")
            options.apiKey = "AIzaDemoKeyForTheLocalEmulatorsOnly0000"
            options.projectID = projectID
            FirebaseApp.configure(options: options)
            useFirestoreEmulator()
            configuredProjectID = projectID
        }
    }

    private static func useFirestoreEmulator() {
        settingsLock.withLock {
            let settings = Firestore.firestore().settings
            settings.host = "127.0.0.1:8080"
            settings.isSSLEnabled = false
            Firestore.firestore().settings = settings
        }
    }
}

private struct MissingTraitError: Error, CustomStringConvertible {
    var description: String {
        "Add the firebaseEmulators(projectID:) trait to the suite."
    }
}
