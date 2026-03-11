/// Protocol for writing nutrition data to HealthKit.
///
/// Write-only integration for dietary energy and water intake.
/// HealthKit denial is non-blocking -- the app works fully without it.
public protocol HealthKitWriting: Sendable {
    /// The current HealthKit authorization status.
    var permissionStatus: HealthKitPermissionStatus { get async }

    /// Requests HealthKit authorization from the user.
    /// - Throws: If the authorization request fails.
    func requestAuthorization() async throws

    /// Saves a nutrition session to HealthKit.
    /// - Parameter session: The session to save.
    /// - Throws: `VoiceNutritionError.healthKitSaveFailed` if the save fails.
    func save(_ session: NutritionSession) async throws
}
