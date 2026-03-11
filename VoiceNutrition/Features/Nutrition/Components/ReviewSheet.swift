import SwiftUI

/// Review sheet presented to the user after intent resolution.
///
/// Displays a categorized list of food items for the user to confirm before
/// persistence. Handles date confirmation, water display, and three item
/// categories (confirmed, low-confidence, unresolved) with per-item toggles.
@MainActor
public struct ReviewSheet: View {

    // MARK: - Input

    /// The resolved session data to present for review.
    public let reviewData: ReviewData

    /// Called when the user taps "Save" with the filtered selections
    /// and the confirmed date.
    public let onSave: ([ResolvedFoodItem], [ResolvedFoodItem], [UnresolvedFoodItem], Date) -> Void

    /// Called when the user taps "Cancel" to discard the session.
    public let onCancel: () -> Void

    // MARK: - Local State

    /// Names of confirmed items that are toggled ON. Initialised to all names.
    @State private var confirmedToggles: Set<String>

    /// Names of low-confidence items that are toggled ON. Initialised to all names.
    @State private var lowConfidenceToggles: Set<String>

    /// Names of unresolved items that are toggled ON. Initialised empty (all OFF).
    @State private var unresolvedToggles: Set<String>

    /// The date the user has confirmed or adjusted for this session.
    @State private var selectedDate: Date

    // MARK: - Init

    /// Creates a ReviewSheet with the provided data and callbacks.
    /// - Parameters:
    ///   - reviewData: The resolved session data.
    ///   - onSave: Called with filtered selections and confirmed date.
    ///   - onCancel: Called when the user discards the session.
    public init(
        reviewData: ReviewData,
        onSave: @escaping ([ResolvedFoodItem], [ResolvedFoodItem], [UnresolvedFoodItem], Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.reviewData = reviewData
        self.onSave = onSave
        self.onCancel = onCancel

        _confirmedToggles = State(initialValue: Set(reviewData.confirmedItems.map(\.name)))
        _lowConfidenceToggles = State(initialValue: Set(reviewData.resolvedItems.map(\.name)))
        _unresolvedToggles = State(initialValue: [])

        let resolvedDate: Date = {
            switch reviewData.dateResolution {
            case .exact(let date): return date
            case .approximated(let date): return date
            case .unknown: return Date()
            }
        }()
        _selectedDate = State(initialValue: resolvedDate)
    }

    // MARK: - Computed

    private var totalSelectedCalories: Int {
        let confirmed = reviewData.confirmedItems
            .filter { confirmedToggles.contains($0.name) }
            .reduce(0) { $0 + $1.calories }
        let lowConf = reviewData.resolvedItems
            .filter { lowConfidenceToggles.contains($0.name) }
            .reduce(0) { $0 + $1.calories }
        return confirmed + lowConf
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            List {
                // Total calories header
                calorieHeaderView

                // Date picker — conditional
                if reviewData.needsDateConfirmation {
                    dateSectionView
                }

                // Water badge — conditional
                if let waterMl = reviewData.waterMl, waterMl > 0 {
                    waterSectionView(waterMl: waterMl)
                }

                // Confirmed items
                if !reviewData.confirmedItems.isEmpty {
                    confirmedSectionView
                }

                // Low-confidence items
                if !reviewData.resolvedItems.isEmpty {
                    lowConfidenceSectionView
                }

                // Unresolved items
                if !reviewData.unresolvedItems.isEmpty {
                    unresolvedSectionView
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .accessibilityIdentifier("review.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        performSave()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("review.saveButton")
                }
            }
        }
    }

    // MARK: - Calorie Header

    private var calorieHeaderView: some View {
        Section {
            VStack(spacing: 4) {
                Text("\(totalSelectedCalories)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: totalSelectedCalories)
                Text("calories")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Date Section

    private var dateSectionView: some View {
        Section {
            DatePicker(
                "When did you eat this?",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .accessibilityIdentifier("review.datePicker")
        }
    }

    // MARK: - Water Section

    private func waterSectionView(waterMl: Int) -> some View {
        Section {
            Label {
                Text("\(waterMl) ml")
                    .font(.body.weight(.medium))
            } icon: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
            }
            .accessibilityIdentifier("review.waterBadge")
        } header: {
            Text("Water")
        }
    }

    // MARK: - Confirmed Section

    private var confirmedSectionView: some View {
        Section {
            ForEach(reviewData.confirmedItems, id: \.name) { item in
                FoodItemToggleRow(
                    name: item.name,
                    calories: item.calories,
                    portionGrams: item.portionGrams,
                    subtitle: nil,
                    accentColor: .green,
                    isOn: toggleBinding(for: item.name, in: $confirmedToggles)
                )
                .accessibilityIdentifier("review.confirmedToggle.\(item.name)")
            }
        } header: {
            SectionHeader(title: "Confirmed", color: .green)
        }
        .tint(.green)
    }

    // MARK: - Low-Confidence Section

    private var lowConfidenceSectionView: some View {
        Section {
            ForEach(reviewData.resolvedItems, id: \.name) { item in
                let subtitle: String = {
                    switch item.matchQuality {
                    case .weak: return "Weak match — verify"
                    case .strong, .notFound: return "Low confidence (\(Int(item.confidence * 100))%)"
                    }
                }()
                FoodItemToggleRow(
                    name: item.name,
                    calories: item.calories,
                    portionGrams: item.portionGrams,
                    subtitle: subtitle,
                    accentColor: .orange,
                    isOn: toggleBinding(for: item.name, in: $lowConfidenceToggles)
                )
                .accessibilityIdentifier("review.lowConfidenceToggle.\(item.name)")
            }
        } header: {
            SectionHeader(title: "Needs Review", color: .orange)
        }
        .tint(.orange)
    }

    // MARK: - Unresolved Section

    private var unresolvedSectionView: some View {
        Section {
            ForEach(reviewData.unresolvedItems, id: \.name) { item in
                Toggle(isOn: toggleBinding(for: item.name, in: $unresolvedToggles)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name.capitalized)
                            .font(.body)
                        Text(item.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("review.unresolvedToggle.\(item.name)")
            }
        } header: {
            SectionHeader(title: "Not Found", color: .secondary)
        }
        .tint(.secondary)
    }

    // MARK: - Helpers

    private func toggleBinding(for name: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(name) },
            set: { isOn in
                if isOn {
                    set.wrappedValue.insert(name)
                } else {
                    set.wrappedValue.remove(name)
                }
            }
        )
    }

    private func performSave() {
        let selectedConfirmed = reviewData.confirmedItems.filter { confirmedToggles.contains($0.name) }
        let selectedLowConfidence = reviewData.resolvedItems.filter { lowConfidenceToggles.contains($0.name) }
        let selectedUnresolved = reviewData.unresolvedItems.filter { unresolvedToggles.contains($0.name) }
        onSave(selectedConfirmed, selectedLowConfidence, selectedUnresolved, selectedDate)
    }
}

// MARK: - Section Header

/// Consistent colored section header with a dot indicator.
@MainActor
private struct SectionHeader: View {

    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
    }
}

// MARK: - Food Item Toggle Row

/// A row view for resolved food items with a toggle, calories, and portion.
@MainActor
private struct FoodItemToggleRow: View {

    let name: String
    let calories: Int
    let portionGrams: Int
    let subtitle: String?
    let accentColor: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name.capitalized)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(calories) kcal")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                HStack {
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(accentColor)
                    }
                    Spacer()
                    Text("\(portionGrams)g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
