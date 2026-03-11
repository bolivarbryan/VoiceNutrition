import Foundation
import HealthKit

/// Concrete implementation of `HealthKitWriting` for syncing nutrition data to Apple Health.
///
/// Write-only integration that saves aggregate calorie and water samples per session.
/// Uses guard-first pattern: all operations silently no-op when Health data is unavailable
/// or permission is denied, ensuring the app works fully without HealthKit.
public final class HealthKitRepository: HealthKitWriting, @unchecked Sendable {

    private let healthStore = HKHealthStore()

    /// The current HealthKit authorization status for dietary energy.
    public var permissionStatus: HealthKitPermissionStatus {
        get async {
            guard HKHealthStore.isHealthDataAvailable() else { return .denied }
            let calorieType = HKQuantityType(.dietaryEnergyConsumed)
            let status = healthStore.authorizationStatus(for: calorieType)
            switch status {
            case .sharingAuthorized:
                return .authorized
            case .sharingDenied:
                return .denied
            default:
                return .notDetermined
            }
        }
    }

    /// Requests HealthKit authorization for dietary energy and water share types.
    /// - Throws: `VoiceNutritionError.healthKitDenied` if health data is unavailable.
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw VoiceNutritionError.healthKitDenied
        }
        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryWater)
        ]
        try await healthStore.requestAuthorization(toShare: shareTypes, read: [])
    }

    /// Saves a nutrition session's calorie and water data to HealthKit.
    ///
    /// Produces up to two `HKQuantitySample` objects per session:
    /// - One calorie sample (skipped when `totalCalories == 0`)
    /// - One water sample (skipped when `waterMl` is `nil` or `0`)
    ///
    /// Both samples carry `HKMetadataKeyExternalUUID` matching the session ID
    /// plus custom metadata for meal context and unresolved-items flag.
    ///
    /// - Parameter session: The session to save.
    /// - Throws: `VoiceNutritionError.healthKitSaveFailed` if the save fails.
    public func save(_ session: NutritionSession) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard await permissionStatus == .authorized else { return }

        var samples: [HKQuantitySample] = []
        let metadata = buildMetadata(for: session)

        if session.totalCalories > 0 {
            let calorieQuantity = HKQuantity(
                unit: .kilocalorie(),
                doubleValue: Double(session.totalCalories)
            )
            let calorieSample = HKQuantitySample(
                type: HKQuantityType(.dietaryEnergyConsumed),
                quantity: calorieQuantity,
                start: session.date,
                end: session.date,
                metadata: metadata
            )
            samples.append(calorieSample)
        }

        if let waterMl = session.waterMl, waterMl > 0 {
            let waterQuantity = HKQuantity(
                unit: .liter(),
                doubleValue: Double(waterMl) / 1000.0
            )
            let waterSample = HKQuantitySample(
                type: HKQuantityType(.dietaryWater),
                quantity: waterQuantity,
                start: session.date,
                end: session.date,
                metadata: metadata
            )
            samples.append(waterSample)
        }

        guard !samples.isEmpty else { return }

        do {
            try await healthStore.save(samples)
        } catch {
            throw VoiceNutritionError.healthKitSaveFailed
        }
    }

    /// Builds metadata dictionary for HealthKit samples.
    /// - Parameter session: The source session.
    /// - Returns: Metadata including external UUID, meal context, and unresolved flag.
    private func buildMetadata(for session: NutritionSession) -> [String: Any] {
        var metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: session.id.uuidString,
            "com.voicenutrition.hasUnresolvedItems": session.hasUnresolvedItems
        ]
        if let mealContext = session.mealContext {
            metadata["com.voicenutrition.mealContext"] = mealContext
        }
        return metadata
    }
}
