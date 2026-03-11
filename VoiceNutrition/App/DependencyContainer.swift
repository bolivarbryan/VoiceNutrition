import Foundation

/// Composition Root for the application.
///
/// All concrete repository types are instantiated here and only here.
/// Downstream code receives protocol-typed dependencies.
@MainActor
final class DependencyContainer: Sendable {

    /// Intent resolution — uses mock in Phase 1, real implementation in Phase 2.
    let intentResolver: any IntentResolving

    // let speechResolver: any SpeechResolving        // Phase 2
    // let foodDatabase: any FoodDatabaseResolving     // Phase 2
    // let healthKit: any HealthKitWriting             // Phase 3
    // let sessionStore: any NutritionSessionStoring   // Phase 3

    /// Creates the container, wiring all concrete dependencies.
    init() {
        self.intentResolver = MockIntentRepository()
    }
}
