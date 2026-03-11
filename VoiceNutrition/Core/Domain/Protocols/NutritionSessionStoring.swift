/// Protocol for persisting nutrition sessions to local storage.
///
/// Implementations use SwiftData for persistence with cascade
/// delete relationships between sessions and entries.
/// Marked `@MainActor` because `NutritionSession` is an `@Model` class
/// whose mutation and persistence must occur on the main actor.
@MainActor
public protocol NutritionSessionStoring {
    /// Saves a nutrition session.
    /// - Parameter session: The session to save.
    /// - Throws: `VoiceNutritionError.persistenceFailed` if the save fails.
    func save(_ session: NutritionSession) throws

    /// Fetches all stored nutrition sessions.
    /// - Returns: All sessions, typically sorted by date descending.
    /// - Throws: `VoiceNutritionError.persistenceFailed` if the fetch fails.
    func fetchAll() throws -> [NutritionSession]

    /// Deletes a nutrition session and its entries.
    /// - Parameter session: The session to delete.
    /// - Throws: `VoiceNutritionError.persistenceFailed` if the delete fails.
    func delete(_ session: NutritionSession) throws
}
