import Foundation
import Testing
@testable import VoiceNutrition

@Suite("DateResolver Tests")
struct DateResolverTests {
    let resolver = DateResolver()

    /// Fixed reference date: 2026-03-15 at noon UTC.
    let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        components.hour = 12
        components.minute = 0
        components.second = 0
        let calendar = Calendar.current
        return calendar.date(from: components) ?? Date()
    }()

    // MARK: - Helper

    private func makeDate(
        daysOffset: Int = 0,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        let calendar = Calendar.current
        guard let dayShifted = calendar.date(
            byAdding: .day,
            value: daysOffset,
            to: calendar.startOfDay(for: referenceDate)
        ) else {
            return referenceDate
        }
        var components = calendar.dateComponents([.year, .month, .day], from: dayShifted)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? referenceDate
    }

    // MARK: - Exact Patterns

    @Test
    func test_resolve_nil_returnsExactNow() {
        let result = resolver.resolve(nil, referenceDate: referenceDate)
        #expect(result == .exact(referenceDate))
    }

    @Test
    func test_resolve_emptyString_returnsExactNow() {
        let result = resolver.resolve("", referenceDate: referenceDate)
        #expect(result == .exact(referenceDate))
    }

    @Test
    func test_resolve_today_returnsExactNow() {
        let result = resolver.resolve("today", referenceDate: referenceDate)
        #expect(result == .exact(referenceDate))
    }

    @Test
    func test_resolve_yesterdayMorning_returnsExact9am() {
        let expected = makeDate(daysOffset: -1, hour: 9)
        let result = resolver.resolve("yesterday morning", referenceDate: referenceDate)
        #expect(result == .exact(expected))
    }

    @Test
    func test_resolve_yesterdayAfternoon_returnsExact2pm() {
        let expected = makeDate(daysOffset: -1, hour: 14)
        let result = resolver.resolve("yesterday afternoon", referenceDate: referenceDate)
        #expect(result == .exact(expected))
    }

    @Test
    func test_resolve_yesterdayEvening_returnsExact7pm() {
        let expected = makeDate(daysOffset: -1, hour: 19)
        let result = resolver.resolve("yesterday evening", referenceDate: referenceDate)
        #expect(result == .exact(expected))
    }

    @Test
    func test_resolve_thisMorning_returnsExact9amToday() {
        let expected = makeDate(daysOffset: 0, hour: 9)
        let result = resolver.resolve("this morning", referenceDate: referenceDate)
        #expect(result == .exact(expected))
    }

    @Test
    func test_resolve_lastNight_returnsExact8pmYesterday() {
        let expected = makeDate(daysOffset: -1, hour: 20)
        let result = resolver.resolve("last night", referenceDate: referenceDate)
        #expect(result == .exact(expected))
    }

    @Test
    func test_resolve_twoDaysAgo_returnsExactNoon() {
        let expected = makeDate(daysOffset: -2, hour: 12)
        let result = resolver.resolve("two days ago", referenceDate: referenceDate)
        #expect(result == .exact(expected))
    }

    @Test
    func test_resolve_threeDaysAgo_returnsExactNoon() {
        let expected = makeDate(daysOffset: -3, hour: 12)
        let result = resolver.resolve("three days ago", referenceDate: referenceDate)
        #expect(result == .exact(expected))
    }

    // MARK: - Approximated Patterns

    @Test
    func test_resolve_lastTuesday_returnsApproximated() {
        // Reference is 2026-03-15 (Sunday). Last Tuesday = 2026-03-10.
        let result = resolver.resolve("last tuesday", referenceDate: referenceDate)
        let expected = makeDate(daysOffset: -5, hour: 12) // March 10
        #expect(result == .approximated(expected))
    }

    @Test
    func test_resolve_lastWeek_returnsApproximated() {
        let expected = makeDate(daysOffset: -7, hour: 12)
        let result = resolver.resolve("last week", referenceDate: referenceDate)
        #expect(result == .approximated(expected))
    }

    @Test
    func test_resolve_fewDaysAgo_returnsApproximated() {
        let expected = makeDate(daysOffset: -3, hour: 12)
        let result = resolver.resolve("a few days ago", referenceDate: referenceDate)
        #expect(result == .approximated(expected))
    }

    // MARK: - Unknown

    @Test
    func test_resolve_gibberish_returnsUnknown() {
        let result = resolver.resolve("blargfargle", referenceDate: referenceDate)
        #expect(result == .unknown)
    }

    @Test
    func test_resolve_ambiguous_returnsUnknown() {
        let result = resolver.resolve("sometime", referenceDate: referenceDate)
        #expect(result == .unknown)
    }
}
