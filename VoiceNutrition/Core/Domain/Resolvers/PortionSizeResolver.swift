/// Resolves a food item's portion size in grams using a 4-level fallback strategy.
///
/// The resolution order is:
/// 1. Explicit grams (user specified exact weight)
/// 2. Default serving size from the food database
/// 3. Category-based default serving size
/// 4. `nil` (no resolution possible)
///
/// When a base serving size is found (levels 2 or 3), a ``PortionModifier``
/// multiplier is applied to adjust for user-described portion sizes.
public struct PortionSizeResolver: Sendable {

    /// Category-based default serving sizes in grams.
    static let categoryDefaults: [FoodCategory: Int] = [
        .grain: 200,
        .protein: 150,
        .vegetable: 120,
        .fruit: 150,
        .dairy: 200,
        .beverage: 250,
        .fat: 15,
        .other: 150
    ]

    /// Creates a new portion size resolver.
    public init() {}

    /// Resolves the portion size in grams using a 4-level fallback.
    ///
    /// - Parameters:
    ///   - quantityGrams: Explicit gram quantity from user input, if provided.
    ///   - portionModifier: Natural language portion descriptor (e.g. "large", "tiny").
    ///   - defaultServingG: Default serving size from the food database entry.
    ///   - category: Food category for category-based fallback.
    /// - Returns: Resolved portion size in grams, or `nil` if no resolution is possible.
    public func resolve(
        quantityGrams: Int?,
        portionModifier: String?,
        defaultServingG: Int?,
        category: FoodCategory?
    ) -> Int? {
        // Level 1: Explicit grams bypass modifier logic entirely
        if let grams = quantityGrams {
            return grams
        }

        let modifier = PortionModifier(from: portionModifier)

        // Level 2: Default serving from database
        if let serving = defaultServingG {
            return Int(Double(serving) * modifier.multiplier)
        }

        // Level 3: Category-based default
        if let cat = category, let catDefault = Self.categoryDefaults[cat] {
            return Int(Double(catDefault) * modifier.multiplier)
        }

        // Level 4: No resolution
        return nil
    }
}

/// Describes the relative size of a food portion.
///
/// Parsed from natural language descriptions in the user's voice input.
/// Unknown or `nil` modifiers default to ``normal``.
public enum PortionModifier: Sendable {
    case extraLarge
    case large
    case normal
    case small
    case tiny

    /// The multiplier applied to a base serving size.
    public var multiplier: Double {
        switch self {
        case .extraLarge: 1.6
        case .large: 1.3
        case .normal: 1.0
        case .small: 0.7
        case .tiny: 0.5
        }
    }

    /// Creates a modifier from a natural language string.
    ///
    /// Matching is case-insensitive. Unrecognized or `nil` values
    /// default to ``normal``.
    /// - Parameter string: The portion modifier string from user input.
    public init(from string: String?) {
        guard let raw = string?.lowercased() else {
            self = .normal
            return
        }
        switch raw {
        case "extralarge", "extra large", "extra-large", "xl":
            self = .extraLarge
        case "large", "big":
            self = .large
        case "normal", "medium", "regular":
            self = .normal
        case "small", "little":
            self = .small
        case "tiny", "mini":
            self = .tiny
        default:
            self = .normal
        }
    }
}
