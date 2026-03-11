import Testing
import Foundation
@testable import VoiceNutrition

@Suite("HealthKitRepository Tests — Mock Behavior")
struct HealthKitRepositoryTests {

    // MARK: - Helpers

    private func makeMock() -> MockHealthKitWriting {
        MockHealthKitWriting()
    }

    private func makeSession(
        totalCalories: Int = 500,
        waterMl: Int? = 250,
        mealContext: String? = "lunch"
    ) -> NutritionSession {
        NutritionSession(
            date: Date(),
            mealContext: mealContext,
            totalCalories: totalCalories,
            waterMl: waterMl
        )
    }

    // MARK: - Tests

    @Test("Mock default state: authorized and not called")
    func test_mock_defaultState_authorizedAndNotCalled() async {
        let mock = makeMock()
        let status = await mock.permissionStatus
        #expect(status == .authorized)
        #expect(mock.saveCalled == false)
        #expect(mock.savedSession == nil)
        #expect(mock.authorizationRequested == false)
    }

    @Test("Mock save records the session")
    func test_mock_save_recordsSession() async throws {
        let mock = makeMock()
        let session = makeSession()
        try await mock.save(session)
        #expect(mock.saveCalled == true)
        #expect(mock.savedSession?.id == session.id)
    }

    @Test("Mock save throws when shouldThrow is true")
    func test_mock_save_throwsWhenConfigured() async {
        let mock = makeMock()
        mock.shouldThrow = true
        let session = makeSession()
        await #expect(throws: VoiceNutritionError.healthKitSaveFailed) {
            try await mock.save(session)
        }
    }

    @Test("Mock denied permission status")
    func test_mock_denied_returnsConfiguredStatus() async {
        let mock = makeMock()
        mock.configuredPermissionStatus = .denied
        let status = await mock.permissionStatus
        #expect(status == .denied)
    }

    @Test("Mock requestAuthorization sets flag")
    func test_mock_requestAuthorization_setsFlag() async throws {
        let mock = makeMock()
        try await mock.requestAuthorization()
        #expect(mock.authorizationRequested == true)
    }
}
