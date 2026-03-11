import Foundation

/// Resolves natural language date descriptions into structured ``DateResolution`` values.
///
/// Resolution follows a 3-level hierarchy:
/// 1. **Exact** -- clear, unambiguous time references (today, yesterday morning, etc.)
/// 2. **Approximated** -- vague but parseable references (last Tuesday, last week)
/// 3. **Unknown** -- unrecognized input
///
/// - Note: This resolver imports Foundation for `Date` and `Calendar` only.
///   This is a documented exception to the Domain-layer "no frameworks" rule.
public struct DateResolver: Sendable {

    /// Creates a new date resolver.
    public init() {}

    /// Resolves a natural language date string into a ``DateResolution``.
    ///
    /// - Parameters:
    ///   - consumedAt: The natural language date string from user input.
    ///     `nil` or empty strings resolve to `.exact(referenceDate)`.
    ///   - referenceDate: The current date used as the base for calculations.
    ///     Defaults to `Date()`.
    /// - Returns: A ``DateResolution`` indicating how the date was resolved.
    public func resolve(
        _ consumedAt: String?,
        referenceDate: Date = Date()
    ) -> DateResolution {
        let calendar = Calendar.current

        guard let raw = consumedAt?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return .exact(referenceDate)
        }

        // Exact patterns
        if raw == "today" {
            return .exact(referenceDate)
        }

        if raw == "yesterday morning" {
            return .exact(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -1, hour: 9))
        }

        if raw == "yesterday afternoon" {
            return .exact(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -1, hour: 14))
        }

        if raw == "yesterday evening" {
            return .exact(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -1, hour: 19))
        }

        if raw == "this morning" {
            return .exact(dateWith(calendar: calendar, reference: referenceDate, daysOffset: 0, hour: 9))
        }

        if raw == "last night" {
            return .exact(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -1, hour: 20))
        }

        if raw == "two days ago" || raw == "2 days ago" {
            return .exact(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -2, hour: 12))
        }

        if raw == "three days ago" || raw == "3 days ago" {
            return .exact(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -3, hour: 12))
        }

        // Approximated patterns

        if raw == "last week" {
            return .approximated(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -7, hour: 12))
        }

        if raw == "a few days ago" || raw == "few days ago" {
            return .approximated(dateWith(calendar: calendar, reference: referenceDate, daysOffset: -3, hour: 12))
        }

        // "last {weekday}" pattern
        if let weekday = parseLastWeekday(from: raw) {
            let resolved = previousWeekday(weekday, from: referenceDate, calendar: calendar)
            return .approximated(dateWith(calendar: calendar, reference: resolved, daysOffset: 0, hour: 12))
        }

        // Unknown
        return .unknown
    }

    // MARK: - Private Helpers

    /// Creates a date at a specific hour offset from the reference date.
    private func dateWith(
        calendar: Calendar,
        reference: Date,
        daysOffset: Int,
        hour: Int
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: reference)
        guard let dayShifted = calendar.date(byAdding: .day, value: daysOffset, to: startOfDay) else {
            return reference
        }
        var components = calendar.dateComponents([.year, .month, .day], from: dayShifted)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? reference
    }

    /// Extracts a weekday from "last {weekday}" patterns.
    private func parseLastWeekday(from input: String) -> Weekday? {
        guard input.hasPrefix("last ") else { return nil }
        let dayName = String(input.dropFirst(5))
        return Weekday(name: dayName)
    }

    /// Finds the most recent occurrence of the given weekday before the reference date.
    private func previousWeekday(
        _ target: Weekday,
        from reference: Date,
        calendar: Calendar
    ) -> Date {
        let currentWeekday = calendar.component(.weekday, from: reference)
        let targetValue = target.calendarValue
        var daysBack = currentWeekday - targetValue
        if daysBack <= 0 {
            daysBack += 7
        }
        return calendar.date(byAdding: .day, value: -daysBack, to: reference) ?? reference
    }
}

/// Weekday representation for natural language weekday parsing.
private enum Weekday {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    /// The `Calendar.component(.weekday)` value (Sunday = 1, Saturday = 7).
    var calendarValue: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }

    /// Creates a weekday from a lowercased day name string.
    init?(name: String) {
        switch name {
        case "sunday", "sun": self = .sunday
        case "monday", "mon": self = .monday
        case "tuesday", "tue", "tues": self = .tuesday
        case "wednesday", "wed": self = .wednesday
        case "thursday", "thu", "thurs": self = .thursday
        case "friday", "fri": self = .friday
        case "saturday", "sat": self = .saturday
        default: return nil
        }
    }
}
