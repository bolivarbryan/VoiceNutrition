import Foundation
import SwiftData

/// Composition Root for the application.
///
/// All concrete repository types are instantiated here and only here.
/// Downstream code receives protocol-typed dependencies.
@MainActor
final class DependencyContainer: Sendable {

    let speechResolver: any SpeechResolving
    let intentResolver: any IntentResolving
    let foodDatabase: any FoodDatabaseResolving
    let logNutritionUseCase: LogNutritionUseCase
    let sessionStore: any NutritionSessionStoring
    let healthKit: any HealthKitWriting
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
