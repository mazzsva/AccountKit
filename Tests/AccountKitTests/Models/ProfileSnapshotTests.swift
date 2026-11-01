import Testing

@testable import AccountKit

extension BaseSuite {
    @Suite
    struct ProfileSnapshotTests {
        @Test
        func aKnownMissingValueIsNotUnknown() {
            #expect(ProfileSnapshot<Int?>.known(nil) != .unknown)
        }

        @Test
        func knownSnapshotsAreEqualOnlyWithTheSameValue() {
            #expect(ProfileSnapshot<Int?>.known(1) == .known(1))
            #expect(ProfileSnapshot<Int?>.known(1) != .known(2))
            #expect(ProfileSnapshot<Int?>.known(1) != .known(nil))
        }
    }
}
