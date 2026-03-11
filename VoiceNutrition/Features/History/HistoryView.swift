import SwiftUI

/// Day-grouped session history view.
///
/// Displays past nutrition sessions grouped by day with section headers
/// (Today, Yesterday, or formatted date). Tapping a session row expands
/// it inline to reveal its food entries.
@MainActor
struct HistoryView: View {

    // MARK: - Dependencies

    /// The session store for loading persisted sessions.
    let sessionStore: any NutritionSessionStoring

    // MARK: - State

    @State private var sessions: [NutritionSession] = []
    @State private var expandedSessionIDs: Set<UUID> = []
    @State private var loadError: String?

    // MARK: - Body

    var body: some View {
        Group {
            if sessions.isEmpty, loadError == nil {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "tray",
                    description: Text("Your logged meals will appear here.")
                )
            } else if let loadError {
                ContentUnavailableView(
                    "Unable to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                sessionList
            }
        }
        .navigationTitle("History")
        .task {
            loadSessions()
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            ForEach(groupedSections, id: \.date) { section in
                Section {
                    ForEach(section.sessions) { session in
                        SessionRow(
                            session: session,
                            isExpanded: expandedSessionIDs.contains(session.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) {
                                toggleExpanded(session.id)
                            }
                        }
                        .accessibilityIdentifier("history.sessionRow.\(session.id)")
                    }
                } header: {
                    DaySectionHeader(
                        title: section.title,
                        totalCalories: section.totalCalories
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    private func loadSessions() {
        do {
            sessions = try sessionStore.fetchAll()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedSessionIDs.contains(id) {
            expandedSessionIDs.remove(id)
        } else {
            expandedSessionIDs.insert(id)
        }
    }

    private var groupedSections: [DaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { date, daySessions in
                DaySection(
                    date: date,
                    title: sectionTitle(for: date),
                    sessions: daySessions.sorted { $0.date > $1.date },
                    totalCalories: daySessions.reduce(0) { $0 + $1.totalCalories }
                )
            }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.month(.wide).day())
        }
    }
}

// MARK: - Day Section Header

@MainActor
private struct DaySectionHeader: View {

    let title: String
    let totalCalories: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(totalCalories) cal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Session Row

@MainActor
private struct SessionRow: View {

    let session: NutritionSession
    let isExpanded: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionTitle)
                        .font(.headline)
                    Text(Self.timeFormatter.string(from: session.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if let waterMl = session.waterMl, waterMl > 0 {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if session.hasUnresolvedItems {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("history.unresolvedBadge.\(session.id)")
                    }

                    Text("\(session.totalCalories) cal")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }

            // Expanded entries
            if isExpanded {
                expandedEntries
            }
        }
    }

    private var sessionTitle: String {
        if let context = session.mealContext, !context.isEmpty, context.lowercased() != "nil" {
            return context.capitalized
        }
        return mealContextFromTime
    }

    private var mealContextFromTime: String {
        let hour = Calendar.current.component(.hour, from: session.date)
        switch hour {
        case 5..<11: return "Breakfast"
        case 11..<14: return "Lunch"
        case 14..<17: return "Snack"
        case 17..<21: return "Dinner"
        default: return "Meal"
        }
    }

    private var expandedEntries: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(session.entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name.capitalized)
                            .font(.subheadline)
                        if entry.portionGrams > 0 {
                            Text("\(entry.portionGrams)g")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if !entry.isResolved {
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text("\(entry.calories) cal")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)
                .accessibilityIdentifier("history.entryRow.\(entry.id)")
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Day Section

extension HistoryView {

    /// A group of sessions for a single day.
    struct DaySection {
        let date: Date
        let title: String
        let sessions: [NutritionSession]
        let totalCalories: Int
    }
}
