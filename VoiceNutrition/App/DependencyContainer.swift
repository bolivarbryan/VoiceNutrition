import Foundation

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

    // let healthKit: any HealthKitWriting             // Phase 3
    // let sessionStore: any NutritionSessionStoring   // Phase 3

    /// Creates the container, wiring all concrete dependencies.
    init() {
        self.speechResolver = SpeechRepository()
        self.intentResolver = FoundationModelIntentRepository()
        self.foodDatabase = FoodDatabaseRepository()
        self.logNutritionUseCase = LogNutritionUseCase(
            intentResolver: intentResolver,
            foodDatabase: foodDatabase
        )
    }
}
