import Foundation

/// Orchestrates the full nutrition logging pipeline from text input to ``ReviewData``.
///
/// The pipeline steps:
/// 1. Intent resolution: text -> ``NutritionLog`` (via ``IntentResolving``)
/// 2. Food lookup: items -> ``FoodLookupResult`` (via ``FoodDatabaseResolving``)
/// 3. Portion resolution: each item -> grams (via ``PortionSizeResolver``)
/// 4. Confidence scoring: each item -> score (via ``ConfidenceCalculator``)
/// 5. Date resolution: each item -> ``DateResolution`` (via ``DateResolver``)
/// 6. Partitioning: confirmed (>= 0.7) vs needs-review (< 0.7) vs unresolved
///
/// The use case imports only Foundation (for Date). All other dependencies
/// are Domain-layer protocols and value types.
public final class LogNutritionUseCase: Sendable {

    /// The intent resolver for converting text to structured nutrition data.
    private let intentResolver: any IntentResolving

    /// The food database for looking up food items.
    private let foodDatabase: any FoodDatabaseResolving

    /// The portion size resolver (value type, no injection needed).
    private let portionResolver = PortionSizeResolver()

    /// The confidence calculator (value type, no injection needed).
    private let confidenceCalculator = ConfidenceCalculator()

    /// The date resolver (value type, no injection needed).
    private let dateResolver = DateResolver()

    /// Creates a new ``LogNutritionUseCase`` with the given dependencies.
    ///
    /// - Parameters:
    ///   - intentResolver: The intent resolver for text-to-NutritionLog conversion.
    ///   - foodDatabase: The food database for fuzzy food matching.
    public init(intentResolver: any IntentResolving, foodDatabase: any FoodDatabaseResolving) {
        self.intentResolver = intentResolver
        self.foodDatabase = foodDatabase
    }

    /// Processes text input through the full nutrition pipeline.
    ///
    /// This is the single entry point for both voice and text fallback paths.
    /// Voice input is transcribed to text before reaching this method,
    /// ensuring identical processing for both input modes (VOICE-03).
    ///
    /// - Parameter text: The text to process (either transcribed speech or typed input).
    /// - Returns: A ``ReviewData`` containing all resolved and unresolved items.
    /// - Throws: ``VoiceNutritionError/resolutionFailed`` if intent resolution fails.
    public func process(text: String) async throws -> ReviewData {
        // Step 1: Intent resolution
        let nutritionLog = try await intentResolver.resolve(text)

        // Step 2: Food lookup
        let lookupResults = foodDatabase.lookup(nutritionLog.items)

        // Step 3-5: Process each item
        var resolvedItems: [ResolvedFoodItem] = []
        var unresolvedItems: [UnresolvedFoodItem] = []
        var confirmedItems: [ResolvedFoodItem] = []
        var needsDateConfirmation = false

        for lookupResult in lookupResults {
            let item = lookupResult.originalItem

            // Step 3: Portion resolution
            let portionGrams = portionResolver.resolve(
                quantityGrams: item.quantityGrams,
                portionModifier: item.portionModifier,
                defaultServingG: lookupResult.matchedEntry?.defaultServingG,
                category: lookupResult.matchedEntry?.category
            )

            // Step 5: Date resolution
            let dateResolution = dateResolver.resolve(item.consumedAt)

            // Check date ambiguity for ALL items (DATE-03)
            switch dateResolution {
            case .approximated, .unknown:
                needsDateConfirmation = true
            case .exact:
                break
            }

            // If notFound or portion cannot be resolved -> unresolved
            if lookupResult.matchQuality == .notFound || portionGrams == nil {
                let reason: String
                if lookupResult.matchQuality == .notFound {
                    reason = "Not found in food database"
                } else {
                    reason = "Could not determine portion size"
                }
                unresolvedItems.append(UnresolvedFoodItem(name: item.name, reason: reason))
                continue
            }

            guard let grams = portionGrams else { continue }

            // Step 4: Confidence scoring
            let confidence = confidenceCalculator.calculate(
                semanticConfidence: item.semanticConfidence,
                quantityGrams: item.quantityGrams,
                matchQuality: lookupResult.matchQuality,
                hasDefaultServing: lookupResult.matchedEntry?.defaultServingG != nil
            )

            // Calculate calories
            let calPer100g = lookupResult.matchedEntry?.calPer100g ?? 0
            let calories = calPer100g * grams / 100

            // Get consumed date from resolution
            let consumedAt: Date
            switch dateResolution {
            case .exact(let date):
                consumedAt = date
            case .approximated(let date):
                consumedAt = date
            case .unknown:
                consumedAt = Date()
            }

            let resolvedItem = ResolvedFoodItem(
                name: item.name,
                matchedDatabaseEntry: lookupResult.matchedName,
                matchQuality: lookupResult.matchQuality,
                calories: calories,
                portionGrams: grams,
                confidence: confidence,
                consumedAt: consumedAt,
                dateResolution: dateResolution
            )

            // Step 6: Partition by confidence threshold (CONF-05)
            if confidence >= 0.7 {
                confirmedItems.append(resolvedItem)
            } else {
                resolvedItems.append(resolvedItem)
            }
        }

        // Determine overall date resolution
        let overallDateResolution = determineOverallDateResolution(
            confirmed: confirmedItems,
            resolved: resolvedItems
        )

        return ReviewData(
            resolvedItems: resolvedItems,
            unresolvedItems: unresolvedItems,
            confirmedItems: confirmedItems,
            waterMl: nutritionLog.waterMl,
            mealContext: nutritionLog.mealContext,
            needsDateConfirmation: needsDateConfirmation,
            dateResolution: overallDateResolution
        )
    }

    // MARK: - Review Trigger

    /// Determines whether the review sheet should be presented.
    ///
    /// Returns `false` for the happy path (all items confirmed, none unresolved,
    /// no date ambiguity), allowing the session to be saved immediately.
    ///
    /// - Parameter data: The processed review data from `process(text:)`.
    /// - Returns: `true` if any item needs user review.
    public static func needsReview(_ data: ReviewData) -> Bool {
        !data.resolvedItems.isEmpty || !data.unresolvedItems.isEmpty || data.needsDateConfirmation
    }

    // MARK: - Save Orchestration

    /// Builds a ``NutritionSession`` from selected review items and persists it.
    ///
    /// Save order (PERS-05): SwiftData first, HealthKit second. Local data is
    /// never lost even if HealthKit fails. On successful HealthKit sync, the
    /// `healthKitSynced` flag is updated with a second SwiftData save.
    ///
    /// - Parameters:
    ///   - reviewData: The processed review data with metadata.
    ///   - selectedConfirmed: Confirmed items the user kept.
    ///   - selectedLowConfidence: Low-confidence items the user accepted.
    ///   - selectedUnresolved: Unresolved items the user chose to include.
    ///   - confirmedDate: The final confirmed consumption date.
    ///   - sessionStore: The local persistence store.
    ///   - healthKit: The HealthKit write integration.
    /// - Returns: The persisted ``NutritionSession``.
    /// - Throws: ``VoiceNutritionError/persistenceFailed`` if local save fails.
    @MainActor
    public func finalize(
        reviewData: ReviewData,
        selectedConfirmed: [ResolvedFoodItem],
        selectedLowConfidence: [ResolvedFoodItem],
        selectedUnresolved: [UnresolvedFoodItem],
        confirmedDate: Date,
        sessionStore: any NutritionSessionStoring,
        healthKit: any HealthKitWriting
    ) throws -> NutritionSession {
        // Build entries from selected items
        var entries: [FoodEntry] = []

        for item in selectedConfirmed + selectedLowConfidence {
            entries.append(FoodEntry(
                name: item.name,
                calories: item.calories,
                portionGrams: item.portionGrams,
                confidence: item.confidence,
                matchQuality: matchQualityString(item.matchQuality),
                consumedAt: item.consumedAt,
                isResolved: true
            ))
        }

        for item in selectedUnresolved {
            entries.append(FoodEntry(
                name: item.name,
                calories: 0,
                portionGrams: 0,
                confidence: 0.0,
                matchQuality: "notFound",
                consumedAt: confirmedDate,
                isResolved: false
            ))
        }

        let totalCalories = (selectedConfirmed + selectedLowConfidence)
            .reduce(0) { $0 + $1.calories }

        let session = NutritionSession(
            date: confirmedDate,
            mealContext: reviewData.mealContext,
            totalCalories: totalCalories,
            waterMl: reviewData.waterMl,
            hasUnresolvedItems: !selectedUnresolved.isEmpty,
            entries: entries
        )

        // PERS-05: SwiftData first — local data never lost
        try sessionStore.save(session)

        // HealthKit second — fire-and-forget on @MainActor
        // NutritionSession is @Model (not Sendable), so HealthKit sync
        // runs in a Task on @MainActor to avoid data races.
        Task { @MainActor in
            do {
                try await healthKit.save(session)
                session.healthKitSynced = true
                try sessionStore.save(session)
            } catch {
                // Silently ignore — healthKitSynced stays false
            }
        }

        return session
    }

    // MARK: - Private

    /// Determines the overall date resolution from all resolved items.
    ///
    /// Priority: unknown > approximated > exact. If any item has unknown,
    /// the overall resolution is unknown. If any has approximated, overall
    /// is approximated with the earliest date.
    private func determineOverallDateResolution(
        confirmed: [ResolvedFoodItem],
        resolved: [ResolvedFoodItem]
    ) -> DateResolution {
        let allItems = confirmed + resolved

        guard let first = allItems.first else {
            return .exact(Date())
        }

        var hasUnknown = false
        var hasApproximated = false
        var earliestDate = first.consumedAt

        for item in allItems {
            if item.consumedAt < earliestDate {
                earliestDate = item.consumedAt
            }
            switch item.dateResolution {
            case .unknown:
                hasUnknown = true
            case .approximated:
                hasApproximated = true
            case .exact:
                break
            }
        }

        if hasUnknown {
            return .unknown
        }
        if hasApproximated {
            return .approximated(earliestDate)
        }
        return .exact(earliestDate)
    }

    /// Converts a ``MatchQuality`` enum to its string representation for persistence.
    private func matchQualityString(_ quality: MatchQuality) -> String {
        switch quality {
        case .strong: "strong"
        case .weak: "weak"
        case .notFound: "notFound"
        }
    }
}
