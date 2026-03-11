import Testing
@testable import VoiceNutrition

@Suite("ConfidenceCalculator Tests")
struct ConfidenceCalculatorTests {
    let calculator = ConfidenceCalculator()

    @Test
    func test_calculate_explicitGramsAndFound_returnsMin095() {
        let result = calculator.calculate(
            semanticConfidence: 0.9,
            quantityGrams: 100,
            matchQuality: .strong,
            hasDefaultServing: true
        )
        #expect(result == 0.9)
    }

    @Test
    func test_calculate_explicitGramsAndFound_caps095() {
        let result = calculator.calculate(
            semanticConfidence: 0.99,
            quantityGrams: 100,
            matchQuality: .strong,
            hasDefaultServing: true
        )
        #expect(result == 0.95)
    }

    @Test
    func test_calculate_notFoundPenalty_minus020() {
        // semantic 0.9, notFound penalty -0.20, no serving penalty -0.15
        // 0.9 - 0.20 - 0.15 = 0.55
        let result = calculator.calculate(
            semanticConfidence: 0.9,
            quantityGrams: nil,
            matchQuality: .notFound,
            hasDefaultServing: false
        )
        #expect(result == 0.55)
    }

    @Test
    func test_calculate_weakMatchPenalty_minus010() {
        // semantic 0.9, weak penalty -0.10
        // 0.9 - 0.10 = 0.80
        let result = calculator.calculate(
            semanticConfidence: 0.9,
            quantityGrams: nil,
            matchQuality: .weak,
            hasDefaultServing: true
        )
        #expect(result == 0.8)
    }

    @Test
    func test_calculate_noServingPenalty_minus015() {
        // semantic 0.9, no serving penalty -0.15
        // 0.9 - 0.15 = 0.75
        let result = calculator.calculate(
            semanticConfidence: 0.9,
            quantityGrams: nil,
            matchQuality: .strong,
            hasDefaultServing: false
        )
        #expect(result == 0.75)
    }

    @Test
    func test_calculate_semantic00_normalizesTo07() {
        // 0.0 normalizes to 0.7, strong match, has serving -> no penalties
        let result = calculator.calculate(
            semanticConfidence: 0.0,
            quantityGrams: nil,
            matchQuality: .strong,
            hasDefaultServing: true
        )
        #expect(result == 0.7)
    }

    @Test
    func test_calculate_clampMin01() {
        // semantic 0.1, notFound -0.20, no serving -0.15
        // 0.1 - 0.20 - 0.15 = -0.25 -> clamped to 0.1
        let result = calculator.calculate(
            semanticConfidence: 0.1,
            quantityGrams: nil,
            matchQuality: .notFound,
            hasDefaultServing: false
        )
        #expect(result == 0.1)
    }

    @Test
    func test_calculate_clampMax10() {
        // semantic 1.0, no penalties, no explicit grams
        // should stay at 1.0
        let result = calculator.calculate(
            semanticConfidence: 1.0,
            quantityGrams: nil,
            matchQuality: .strong,
            hasDefaultServing: true
        )
        #expect(result == 1.0)
    }
}
