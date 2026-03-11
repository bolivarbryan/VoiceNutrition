import SwiftUI

/// The main entry point for VoiceNutrition.
@main
struct VoiceNutritionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Placeholder root view for the app.
struct ContentView: View {
    var body: some View {
        Text("VoiceNutrition")
            .accessibilityIdentifier("content.title")
    }
}
