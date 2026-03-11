import Foundation
@testable import VoiceNutrition

/// Mock implementation of `NutritionSessionStoring` for use in unit tests.
///
/// Records calls made to its methods and supports configuring return values
/// and error conditions. Use `shouldThrow = true` to verify error-handling paths.
@MainActor
final class MockNutritionSessionStoring: NutritionSessionStoring {

    // MARK: - Call recording

    /// Sessions passed to `save(_:)`.
    var savedSessions: [NutritionSession] = []

    /// Sessions passed to `delete(_:)`.
    var deletedSessions: [NutritionSession] = []

    // MARK: - Configuration

    /// Sessions returned by `fetchAll()`.
    var sessionsToReturn: [NutritionSession] = []

    /// When `true`, every mutating call throws `VoiceNutritionError.persistenceFailed`.
    var shouldThrow: Bool = false

    // MARK: - NutritionSessionStoring

    /// Records the session and optionally throws if `shouldThrow` is set.
    func save(_ session: NutritionSession) throws {
        if shouldThrow { throw VoiceNutritionError.persistenceFailed }
        savedSessions.append(session)
    }

    /// Returns `sessionsToReturn`, or throws if `shouldThrow` is set.
    func fetchAll() throws -> [NutritionSession] {
        if shouldThrow { throw VoiceNutritionError.persistenceFailed }
        return sessionsToReturn
    }

    /// Records the session for deletion and optionally throws if `shouldThrow` is set.
    func delete(_ session: NutritionSession) throws {
        if shouldThrow { throw VoiceNutritionError.persistenceFailed }
        deletedSessions.append(session)
    }
}
