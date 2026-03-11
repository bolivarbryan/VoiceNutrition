import SwiftUI
import SwiftData

/// The main entry point for VoiceNutrition.
@main
struct VoiceNutritionApp: App {
    private let modelContainer: ModelContainer
    @State private var container: DependencyContainer

    init() {
        let modelContainer = try! ModelContainer(for: NutritionSession.self, FoodEntry.self)
        self.modelContainer = modelContainer
        self._container = State(initialValue: DependencyContainer(modelContext: modelContainer.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

/// Placeholder root view for the app.
struct ContentView: View {
    var body: some View {
        Text("VoiceNutrition")
            .accessibilityIdentifier("content.title")
    }
}
