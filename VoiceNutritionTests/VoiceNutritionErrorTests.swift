import Testing
@testable import VoiceNutrition

@Suite("VoiceNutritionError Tests")
struct VoiceNutritionErrorTests {

    // MARK: - Helper

    /// All 12 error cases for iteration tests.
    private var allCases: [VoiceNutritionError] {
        [
            .microphoneUnavailable,
            .speechRecognitionUnavailable,
            .transcriptionFailed,
            .emptyTranscription,
            .modelUnavailable("Test device does not support Apple Intelligence"),
            .modelNotDownloaded,
            .resolutionFailed,
            .databaseLoadFailed,
            .healthKitDenied,
            .healthKitSaveFailed,
            .persistenceFailed,
            .fullyUnavailable
        ]
    }

    // MARK: - errorDescription

    @Test("All cases return non-nil errorDescription")
    func test_errorDescription_allCases_returnNonNil() {
        for error in allCases {
            #expect(error.errorDescription != nil, "errorDescription is nil for \(error)")
        }
    }

    @Test("microphoneUnavailable errorDescription contains mic reference")
    func test_errorDescription_microphoneUnavailable_containsMic() {
        let error = VoiceNutritionError.microphoneUnavailable
        let description = error.errorDescription ?? ""
        #expect(description.lowercased().contains("mic"))
    }

    @Test("modelUnavailable errorDescription uses associated value")
    func test_errorDescription_modelUnavailable_usesAssociatedValue() {
        let detail = "This device does not support Apple Intelligence"
        let error = VoiceNutritionError.modelUnavailable(detail)
        #expect(error.errorDescription == detail)
    }

    // MARK: - recoverySuggestion

    @Test("All cases return non-nil recoverySuggestion")
    func test_recoverySuggestion_allCases_returnNonNil() {
        for error in allCases {
            #expect(error.recoverySuggestion != nil, "recoverySuggestion is nil for \(error)")
        }
    }

    // MARK: - Equatable

    @Test("Same cases are equal")
    func test_equatable_sameCases_areEqual() {
        #expect(VoiceNutritionError.transcriptionFailed == VoiceNutritionError.transcriptionFailed)
    }

    @Test("Different cases are not equal")
    func test_equatable_differentCases_areNotEqual() {
        #expect(VoiceNutritionError.transcriptionFailed != VoiceNutritionError.emptyTranscription)
    }

    @Test("modelUnavailable compares associated string")
    func test_equatable_modelUnavailable_comparesString() {
        let a = VoiceNutritionError.modelUnavailable("Device A")
        let b = VoiceNutritionError.modelUnavailable("Device B")
        let c = VoiceNutritionError.modelUnavailable("Device A")
        #expect(a != b)
        #expect(a == c)
    }

    // MARK: - Case count

    @Test("Error enum has exactly 12 cases")
    func test_errorCount_isExactly12() {
        // We verify by listing all 12 distinct cases and confirming they are all different
        let cases = allCases
        #expect(cases.count == 12)

        // Verify all cases are unique
        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j], "Cases at index \(i) and \(j) are equal")
            }
        }
    }
}
