    import Foundation
import SwiftData

/// Concrete implementation of `NutritionSessionStoring` backed by SwiftData.
///
/// Uses an in-process `ModelContext` for all operations. All methods are
/// `@MainActor` to match the main context's actor isolation requirement.
@MainActor
public final class SwiftDataNutritionSessionRepository: NutritionSessionStoring {

    private let modelContext: ModelContext

    /// Creates a new repository with the given model context.
    /// - Parameter modelContext: The SwiftData `ModelContext` to use for persistence.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Inserts or updates a session and persists changes.
    /// - Parameter session: The session to save.
    /// - Throws: `VoiceNutritionError.persistenceFailed` if saving fails.
    public func save(_ session: NutritionSession) throws {
        do {
            modelContext.insert(session)
            try modelContext.save()
        } catch {
            throw VoiceNutritionError.persistenceFailed
        }
    }

    /// Fetches all sessions sorted by date, newest first.
    /// - Returns: All persisted sessions in descending date order.
    /// - Throws: `VoiceNutritionError.persistenceFailed` if fetching fails.
    public func fetchAll() throws -> [NutritionSession] {
        do {
            let descriptor = FetchDescriptor<NutritionSession>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            throw VoiceNutritionError.persistenceFailed
        }
    }

    /// Deletes a session and cascade-deletes its associated `FoodEntry` children.
    /// - Parameter session: The session to delete.
    /// - Throws: `VoiceNutritionError.persistenceFailed` if deleting fails.
    public func delete(_ session: NutritionSession) throws {
        do {
            modelContext.delete(session)
            try modelContext.save()
        } catch {
            throw VoiceNutritionError.persistenceFailed
        }
    }
}
