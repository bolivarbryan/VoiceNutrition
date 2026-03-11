import Foundation
@testable import VoiceNutrition

/// Mock implementation of `HealthKitWriting` for use in unit tests.
///
/// Records calls and supports configuring permission status and error conditions.
/// Used by save orchestration tests to verify HealthKit integration without hardware.
final class MockHealthKitWriting: HealthKitWriting, @unchecked Sendable {

    // MARK: - Configuration

    /// The permission status returned by `permissionStatus`.
    var configuredPermissionStatus: HealthKitPermissionStatus = .authorized

    /// When `true`, `save(_:)` throws `VoiceNutritionError.healthKitSaveFailed`.
    var shouldThrow: Bool = false

    // MARK: - Call recording

    /// Whether `save(_:)` was called.
    var saveCalled: Bool = false

    /// The session passed to the most recent `save(_:)` call.
    var savedSession: NutritionSession?

    /// Whether `requestAuthorization()` was called.
    var authorizationRequested: Bool = false

    // MARK: - HealthKitWriting

    /// Returns `configuredPermissionStatus`.
    var permissionStatus: HealthKitPermissionStatus {
        get async {
            configuredPermissionStatus
        }
    }

    /// Records that authorization was requested.
    func requestAuthorization() async throws {
        authorizationRequested = true
    }

    /// Records the session and optionally throws if `shouldThrow` is set.
    func save(_ session: NutritionSession) async throws {
        if shouldThrow { throw VoiceNutritionError.healthKitSaveFailed }
        saveCalled = true
        savedSession = session
    }
}
