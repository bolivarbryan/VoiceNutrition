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

    /// Called when the user taps "Save Confirmed" with the filtered selections
    /// and the confirmed date.
    ///
    /// Parameters:
    /// - `selectedConfirmed`: Confirmed items the user kept toggled ON.
    /// - `selectedLowConfidence`: Low-confidence items the user kept toggled ON.
    /// - `selectedUnresolved`: Unresolved items the user toggled ON.
    /// - `confirmedDate`: The date the user confirmed (or the resolved date).
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

        // Confirmed items: all toggled ON by default
        _confirmedToggles = State(initialValue: Set(reviewData.confirmedItems.map(\.name)))
        // Low-confidence items: all toggled ON by default
        _lowConfidenceToggles = State(initialValue: Set(reviewData.resolvedItems.map(\.name)))
        // Unresolved items: all toggled OFF by default
        _unresolvedToggles = State(initialValue: [])

        // Pre-fill date from resolution; fall back to now for unknown
        let resolvedDate: Date = {
            switch reviewData.dateResolution {
            case .exact(let date): return date
            case .approximated(let date): return date
            case .unknown: return Date()
            }
        }()
        _selectedDate = State(initialValue: resolvedDate)
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            List {
                // 1. Date picker section — conditional
                if reviewData.needsDateConfirmation {
                    dateSectionView
                }

                // 2. Water badge section — conditional
                if let waterMl = reviewData.waterMl, waterMl > 0 {
                    waterSectionView(waterMl: waterMl)
                }

                // 3. Confirmed items
                if !reviewData.confirmedItems.isEmpty {
                    confirmedSectionView
                }

                // 4. Low-confidence items
                if !reviewData.resolvedItems.isEmpty {
                    lowConfidenceSectionView
                }

                // 5. Unresolved items
                if !reviewData.unresolvedItems.isEmpty {
                    unresolvedSectionView
                }

                // 6. Action buttons
                actionButtonsView
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Section Views

    /// Date picker section for confirming when the food was consumed.
    private var dateSectionView: some View {
        Section(header: Text("When did you eat this?")) {
            DatePicker(
                "Date & Time",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .accessibilityIdentifier("review.datePicker")
        }
    }

    /// Water badge section for displaying detected water intake.
    private func waterSectionView(waterMl: Int) -> some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                Text("Water: \(waterMl)ml")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .accessibilityIdentifier("review.waterBadge")
        }
    }

    /// Section for high-confidence confirmed items.
    private var confirmedSectionView: some View {
        Section(
            header: HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("Confirmed")
            }
        ) {
            ForEach(reviewData.confirmedItems, id: \.name) { item in
                ItemToggleRow(
                    name: item.name,
                    calories: item.calories,
                    portionGrams: item.portionGrams,
                    reasonText: nil,
                    tintColor: .green,
                    isOn: Binding(
                        get: { confirmedToggles.contains(item.name) },
                        set: { isOn in
                            if isOn {
                                confirmedToggles.insert(item.name)
                            } else {
                                confirmedToggles.remove(item.name)
                            }
                        }
                    )
                )
                .accessibilityIdentifier("review.confirmedToggle.\(item.name)")
            }
        }
        .tint(.green)
    }

    /// Section for low-confidence items that need user review.
    private var lowConfidenceSectionView: some View {
        Section(
            header: HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Needs Review")
            }
        ) {
            ForEach(reviewData.resolvedItems, id: \.name) { item in
                let reason: String = {
                    switch item.matchQuality {
                    case .weak: return "Weak match"
                    case .strong, .notFound: return "Low confidence (\(Int(item.confidence * 100))%)"
                    }
                }()
                ItemToggleRow(
                    name: item.name,
                    calories: item.calories,
                    portionGrams: item.portionGrams,
                    reasonText: reason,
                    tintColor: .orange,
                    isOn: Binding(
                        get: { lowConfidenceToggles.contains(item.name) },
                        set: { isOn in
                            if isOn {
                                lowConfidenceToggles.insert(item.name)
                            } else {
                                lowConfidenceToggles.remove(item.name)
                            }
                        }
                    )
                )
                .accessibilityIdentifier("review.lowConfidenceToggle.\(item.name)")
            }
        }
        .tint(.orange)
    }

    /// Section for food items that could not be resolved from the database.
    private var unresolvedSectionView: some View {
        Section(
            header: HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.gray)
                    .font(.caption)
                Text("Not Found")
            }
        ) {
            ForEach(reviewData.unresolvedItems, id: \.name) { item in
                UnresolvedToggleRow(
                    name: item.name,
                    reason: item.reason,
                    isOn: Binding(
                        get: { unresolvedToggles.contains(item.name) },
                        set: { isOn in
                            if isOn {
                                unresolvedToggles.insert(item.name)
                            } else {
                                unresolvedToggles.remove(item.name)
                            }
                        }
                    )
                )
                .accessibilityIdentifier("review.unresolvedToggle.\(item.name)")
            }
        }
        .tint(.gray)
    }

    /// Save and cancel action buttons.
    private var actionButtonsView: some View {
        Section {
            Button {
                let selectedConfirmed = reviewData.confirmedItems.filter { confirmedToggles.contains($0.name) }
                let selectedLowConfidence = reviewData.resolvedItems.filter { lowConfidenceToggles.contains($0.name) }
                let selectedUnresolved = reviewData.unresolvedItems.filter { unresolvedToggles.contains($0.name) }
                onSave(selectedConfirmed, selectedLowConfidence, selectedUnresolved, selectedDate)
            } label: {
                HStack {
                    Spacer()
                    Text("Save Confirmed")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("review.saveButton")

            Button(role: .cancel) {
                onCancel()
            } label: {
                HStack {
                    Spacer()
                    Text("Cancel")
                    Spacer()
                }
            }
            .foregroundStyle(.red)
            .accessibilityIdentifier("review.cancelButton")
        }
    }
}

// MARK: - Supporting Row Views

/// A row view for resolved food items with a toggle.
@MainActor
private struct ItemToggleRow: View {

    let name: String
    let calories: Int
    let portionGrams: Int
    let reasonText: String?
    let tintColor: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.body)
                    Spacer()
                    Text("\(calories) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(portionGrams)g")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let reason = reasonText {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(tintColor)
                }
            }
        }
    }
}

/// A row view for unresolved food items with a toggle.
@MainActor
private struct UnresolvedToggleRow: View {

    let name: String
    let reason: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
