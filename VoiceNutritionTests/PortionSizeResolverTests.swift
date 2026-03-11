import Testing
@testable import VoiceNutrition

@Suite("PortionSizeResolver Tests")
struct PortionSizeResolverTests {
    let resolver = PortionSizeResolver()

    @Test
    func test_resolve_explicitGrams_returnsGramsIgnoringModifier() {
        let result = resolver.resolve(
            quantityGrams: 200,
            portionModifier: "large",
            defaultServingG: 100,
            category: .grain
        )
        #expect(result == 200)
    }

    @Test
    func test_resolve_defaultServingWithModifier_appliesMultiplier() {
        let result = resolver.resolve(
            quantityGrams: nil,
            portionModifier: "large",
            defaultServingG: 100,
            category: nil
        )
        #expect(result == 130)
    }

    @Test
    func test_resolve_categoryDefaultWithModifier_appliesMultiplier() {
        let result = resolver.resolve(
            quantityGrams: nil,
            portionModifier: "small",
            defaultServingG: nil,
            category: .protein
        )
        // protein category default is 150g, small = 0.7x -> 105
        #expect(result == 105)
    }

    @Test
    func test_resolve_noResolution_returnsNil() {
        let result = resolver.resolve(
            quantityGrams: nil,
            portionModifier: nil,
            defaultServingG: nil,
            category: nil
        )
        #expect(result == nil)
    }

    @Test
    func test_resolve_allModifiers_correctMultipliers() {
        let base = 100
        let cases: [(String, Int)] = [
            ("extraLarge", 160),
            ("large", 130),
            ("normal", 100),
            ("small", 70),
            ("tiny", 50)
        ]
        for (modifier, expected) in cases {
            let result = resolver.resolve(
                quantityGrams: nil,
                portionModifier: modifier,
                defaultServingG: base,
                category: nil
            )
            #expect(result == expected, "Modifier '\(modifier)' should produce \(expected), got \(String(describing: result))")
        }
    }

    @Test
    func test_resolve_unknownModifier_defaultsToNormal() {
        let result = resolver.resolve(
            quantityGrams: nil,
            portionModifier: "gigantic",
            defaultServingG: 100,
            category: nil
        )
        #expect(result == 100)
    }

    @Test
    func test_resolve_nilModifier_defaultsToNormal() {
        let result = resolver.resolve(
            quantityGrams: nil,
            portionModifier: nil,
            defaultServingG: 100,
            category: nil
        )
        #expect(result == 100)
    }

    @Test
    func test_resolve_caseInsensitiveModifier() {
        let result1 = resolver.resolve(
            quantityGrams: nil,
            portionModifier: "Large",
            defaultServingG: 100,
            category: nil
        )
        let result2 = resolver.resolve(
            quantityGrams: nil,
            portionModifier: "LARGE",
            defaultServingG: 100,
            category: nil
        )
        #expect(result1 == 130)
        #expect(result2 == 130)
    }
}
