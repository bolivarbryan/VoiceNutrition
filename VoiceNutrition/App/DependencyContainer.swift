import Foundation

/// Composition Root for the application.
///
/// All concrete repository types are instantiated here and only here.
/// Downstream code receives protocol-typed dependencies.
@MainActor
final class DependencyContainer {
    /// Shared container instance.
    static let shared = DependencyContainer()

    private init() {}
}
