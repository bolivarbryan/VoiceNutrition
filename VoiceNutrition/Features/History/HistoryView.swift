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
                        sessionRow(session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    toggleExpanded(session.id)
                                }
                            }
                            .accessibilityIdentifier("history.sessionRow.\(session.id)")
                    }
                } header: {
                    HStack {
                        Text(section.title)
                        Spacer()
                        Text("\(section.totalCalories) cal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Session Row

    private func sessionRow(_ session: NutritionSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let context = session.mealContext, !context.isEmpty {
                        Text(context.capitalized)
                            .font(.headline)
                    }
                    Text(timeFormatter.string(from: session.date))
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
                }
            }

            if expandedSessionIDs.contains(session.id) {
                expandedEntries(session.entries)
            }
        }
    }

    // MARK: - Expanded Entries

    private func expandedEntries(_ entries: [FoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.subheadline)
                        Text("\(entry.portionGrams)g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if !entry.isResolved {
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text("\(entry.calories) cal")
                            .font(.subheadline)
                    }
                }
                .accessibilityIdentifier("history.entryRow.\(entry.id)")
            }
        }
        .padding(.top, 4)
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

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
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
