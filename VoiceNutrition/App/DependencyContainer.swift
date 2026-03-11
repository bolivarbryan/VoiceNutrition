import Foundation
import SwiftData

/// Composition Root for the application.
///
/// All concrete repository types are instantiated here and only here.
/// Downstream code receives protocol-typed dependencies.
@MainActor
final class DependencyContainer: Sendable {

    /// Speech recognition for voice input.
    let speechResolver: any SpeechResolving

    /// Intent resolution via on-device Foundation Models.
    let intentResolver: any IntentResolving

    /// Food database for fuzzy name matching via NLEmbedding.
    let foodDatabase: any FoodDatabaseResolving

    /// Orchestrates the full nutrition logging pipeline.
    let logNutritionUseCase: LogNutritionUseCase

    /// Local session persistence via SwiftData.
    let sessionStore: any NutritionSessionStoring

    /// HealthKit write-only integration.
    let healthKit: any HealthKitWriting

    /// Creates the container, wiring all concrete dependencies.
    /// - Parameter modelContext: The SwiftData model context for persistence.
    init(modelContext: ModelContext) {
        self.speechResolver = SpeechRepository()
        self.intentResolver = FoundationModelIntentRepository()
        self.foodDatabase = FoodDatabaseRepository()
        self.logNutritionUseCase = LogNutritionUseCase(
            intentResolver: intentResolver,
            foodDatabase: foodDatabase
        )
        self.sessionStore = SwiftDataNutritionSessionRepository(modelContext: modelContext)
        self.healthKit = HealthKitRepository()
    }
}
