import SwiftUI

/// MacroFactor-style Food Entry sheet. Replaces the old `QuickAddSheet` grid
/// with a five-tab interface (Search, AI, Scan, Quick Add, Library) sitting
/// between a header-pill row and a floating bottom bar.
///
/// Reference screens live under `~/Downloads/macrofactor-screens/`:
/// - IMG_6466.PNG — Search tab + header pills
/// - IMG_6467.PNG — Scan tab
/// - IMG_6468.PNG — AI tab
/// - IMG_6469.PNG — Quick Add tab
/// - IMG_6470.PNG — Library tab + floating bottom bar
///
/// Behavior:
/// - Each row's trailing "+" stages a default-portion entry into `stagedEntries`.
/// - Tapping a row opens a portion picker that stages the result on confirm.
/// - AI/Scan paths run through `AnalyzingView` → `FoodResultView`; the result
///   sheet's `onLog` stages the entry rather than persisting it directly.
/// - Quick Add's `Quick Add` button stages; its `Log Foods` button stages and
///   immediately commits the queue.
/// - The floating bottom bar's `Log N Foods` CTA commits all staged entries
///   into `FoodStore` and dismisses the sheet.
struct FoodEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FoodStore.self) private var foodStore
    @Environment(FoodDatabaseService.self) private var foodDatabase
    @Environment(ProfileStore.self) private var profileStore
    @Environment(FavoritesStore.self) private var favoritesStore

    @AppStorage("aiAnalysisConsentGiven") private var aiConsentGiven: Bool = false

    /// Optional caller-provided initial time. Used by the Food Log per-hour
    /// "+" affordance to drop the header into the slot the user tapped.
    let initialTime: Date?

    /// Initial tab. Used by Dashboard search-bar affordances to deep-link the
    /// sheet into Scan (barcode) or AI without making the user pick the tab
    /// first. Indices match the `tabs` array: 0 Search / 1 Voice / 2 AI /
    /// 3 Scan / 4 Quick Add / 5 Library.
    let initialTab: Int

    init(initialTime: Date? = nil, initialTab: Int = 0) {
        self.initialTime = initialTime
        self.initialTab = initialTab
        _time = State(initialValue: initialTime ?? .now)
        _selectedTab = State(initialValue: initialTab)
    }

    // Header state
    @State private var time: Date
    @State private var mealType: MealType? = nil

    // Tab + bottom bar state
    @State private var selectedTab: Int
    @State private var filterQuery: String = ""
    @State private var libraryMode: Int = 1   // 0 = Recipes, 1 = Foods

    // Staged entries — committed by the bottom-bar "Log Foods" CTA.
    @State private var stagedEntries: [FoodEntry] = []
    @State private var portionItem: FoodDatabaseItem?

    // Memoized search results — recomputed only when filterQuery or the tab
    // changes, not on every body call. Each body call would otherwise execute
    // up to 3 full-corpus scans over 6,900+ items (seed + USDA + AI cache).
    @State private var cachedFavorites: [FoodDatabaseItem] = []
    @State private var cachedSuggestions: [FoodDatabaseItem] = []
    @State private var cachedLibrary: [FoodDatabaseItem] = []

    // Cached formatter — avoid re-allocating DateFormatter on every body call.
    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h a"
        return f
    }()

    // AI flow state — mirrors QuickAddSheet's analyze pipeline.
    @State private var activeFlow: EntryFlow?
    @State private var pendingLabelImage: UIImage?
    @State private var pendingLabelAnalysis: GeminiService.NutritionLabelAnalysis?
    @State private var foodResult: GeminiService.FoodAnalysis?
    @State private var foodResultImage: UIImage?
    @State private var foodResultEmoji: String?
    @State private var foodResultSource: FoodSource = .textInput
    @State private var showAIConsent: Bool = false
    @State private var pendingConsentAction: (() -> Void)?

    // Scan tab state — scanMode is hoisted here so BarcodeUnavailableSheet's
    // "Try label scan" CTA can reset the segment without ScanView needing a
    // callback that mutates its own private @State (structs can't do that).
    @State private var scanMode: ScanMode = .barcode
    @State private var showBarcodeUnavailable: Bool = false

    @State private var errorMessage: String?

    private enum EntryFlow: String, Identifiable {
        case analyzing
        case servingSize
        case foodResult
        var id: String { rawValue }
    }

    private let tabs = ["Search", "Voice", "AI", "Scan", "Quick Add", "Library"]
    private let tabIcons = [
        "magnifyingglass",
        "mic.fill",
        "sparkles",
        "barcode.viewfinder",
        "plus.square",
        "books.vertical"
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HeaderPillRow(
                    time: $time,
                    consumed: foodStore.todayCalories,
                    target: profileStore.profile.effectiveCalories,
                    stagedKcal: stagedKcal,
                    stagedEmojis: stagedEmojis,
                    mealType: $mealType,
                    onClose: { dismiss() },
                    onCollapse: { dismiss() }
                )

                PillTabBar(tabs: tabs, selection: $selectedTab, tabIcons: tabIcons)
                    .padding(.horizontal, BulkAITheme.Spacing.md)
                    .padding(.bottom, BulkAITheme.Spacing.sm)

                tabBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let errorMessage {
                    errorBanner(errorMessage)
                        .padding(.horizontal, BulkAITheme.Spacing.md)
                        .padding(.bottom, BulkAITheme.Spacing.sm)
                }
            }
            .padding(.bottom, 72) // room for the floating bottom bar

            FloatingBottomBar(
                filterQuery: $filterQuery,
                logCount: stagedEntries.count,
                onLog: commitStaged,
                placeholder: bottomBarPlaceholder
            )
            .padding(.bottom, BulkAITheme.Spacing.sm)
        }
        .background(BulkAITheme.Color.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $portionItem) { item in
            QuickAddPortionSheet(item: item) { entry in
                stage(entry)
            }
        }
        .sheet(item: $activeFlow) { flow in
            flowContent(for: flow)
        }
        .sheet(isPresented: $showAIConsent) {
            AIConsentSheetView(
                onAllow: {
                    aiConsentGiven = true
                    showAIConsent = false
                    let pending = pendingConsentAction
                    pendingConsentAction = nil
                    pending?()
                },
                onCancel: {
                    showAIConsent = false
                    pendingConsentAction = nil
                }
            )
        }
        .sheet(isPresented: $showBarcodeUnavailable) {
            BarcodeUnavailableSheet(
                onSearchManually: {
                    showBarcodeUnavailable = false
                    selectedTab = 0
                },
                onTryLabel: {
                    showBarcodeUnavailable = false
                    scanMode = .label
                },
                onClose: {
                    showBarcodeUnavailable = false
                }
            )
        }
        .interactiveDismissDisabled(activeFlow == .analyzing)
        .onAppear { recomputeSearchResults() }
        .onChange(of: filterQuery) { recomputeSearchResults() }
        .onChange(of: selectedTab) { recomputeSearchResults() }
        // Refresh when the user toggles a favorite OR adds/removes a food
        // log entry. The favorites strip + per-slot picks both depend on
        // these stores; without this, hearts and time-of-day suggestions
        // would stale-out until the user changed tabs or queries.
        .onChange(of: favoritesStore.sortedIDs.count) { recomputeSearchResults() }
        .onChange(of: foodStore.entries.count) { recomputeSearchResults() }
        .onChange(of: time) { recomputeSearchResults() }
    }

    // MARK: - Search result recompute

    private func recomputeSearchResults() {
        cachedFavorites = computedFilteredFavorites()
        cachedSuggestions = computedFilteredSuggestions()
        cachedLibrary = computedFilteredLibrary()
    }

    // MARK: - Tab body

    @ViewBuilder
    private var tabBody: some View {
        switch selectedTab {
        case 0:
            SearchView(
                timeLabel: Self.hourFormatter.string(from: time),
                favorites: cachedFavorites,
                suggestions: cachedSuggestions,
                onTapItem: { portionItem = $0 },
                onAddItem: { stageDefaultPortion(of: $0) },
                isFavorite: { favoritesStore.contains($0.id) },
                onToggleFavorite: { favoritesStore.toggle($0.id) }
            )
        case 1:
            VoiceView(onTranscript: { transcript in
                runWithConsent {
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        await analyzeText(description: transcript)
                    }
                }
            })
        case 2:
            AIView(
                onSnap: { image in
                    runWithConsent {
                        Task {
                            try? await Task.sleep(for: .milliseconds(150))
                            await analyzeAuto(image: image)
                        }
                    }
                },
                onDescribe: { description in
                    // Mirrors the Voice tab path: gate the network call on
                    // AI consent, then run analyzeText. analyzeText sets
                    // activeFlow = .analyzing immediately, which presents
                    // AnalyzingView as a sheet — that is the loading UI
                    // the user sees while Gemini is processing.
                    runWithConsent {
                        Task {
                            try? await Task.sleep(for: .milliseconds(150))
                            await analyzeText(description: description)
                        }
                    }
                }
            )
        case 3:
            ScanView(scanMode: $scanMode) { result in
                switch result {
                case .barcodeUnavailable:
                    showBarcodeUnavailable = true
                case .label(let image):
                    runWithConsent {
                        Task {
                            try? await Task.sleep(for: .milliseconds(150))
                            await analyzeLabel(image: image)
                        }
                    }
                }
            }
        case 4:
            QuickAddView(
                onQuickAdd: { entry in stage(applyHeader(to: entry)) },
                onLogFoods: { entry in
                    stage(applyHeader(to: entry))
                    commitStaged()
                }
            )
        case 5:
            LibraryView(
                mode: $libraryMode,
                items: cachedLibrary,
                onTapItem: { portionItem = $0 },
                onAddItem: { stageDefaultPortion(of: $0) },
                isFavorite: { favoritesStore.contains($0.id) },
                onToggleFavorite: { favoritesStore.toggle($0.id) }
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Flow content (Analyze / FoodResult / ServingSize)

    @ViewBuilder
    private func flowContent(for flow: EntryFlow) -> some View {
        switch flow {
        case .analyzing:
            AnalyzingView(
                image: foodResultImage,
                message: foodResultImage == nil ? "Looking up nutrition..." : "Analyzing your food..."
            )
        case .servingSize:
            if let image = pendingLabelImage, let label = pendingLabelAnalysis {
                ServingSizeInputView(image: image, labelAnalysis: label) { analysis in
                    foodResult = analysis
                    foodResultImage = image
                    foodResultEmoji = nil
                    foodResultSource = .nutritionLabel
                    activeFlow = .foodResult
                }
            }
        case .foodResult:
            if let result = foodResult {
                FoodResultView(
                    image: foodResultImage,
                    emoji: foodResultEmoji,
                    source: foodResultSource,
                    name: result.name,
                    calories: result.calories,
                    protein: result.protein,
                    carbs: result.carbs,
                    fat: result.fat,
                    servingSizeGrams: result.servingSizeGrams,
                    sugar: result.sugar,
                    addedSugar: result.addedSugar,
                    fiber: result.fiber,
                    saturatedFat: result.saturatedFat,
                    monounsaturatedFat: result.monounsaturatedFat,
                    polyunsaturatedFat: result.polyunsaturatedFat,
                    cholesterol: result.cholesterol,
                    sodium: result.sodium,
                    potassium: result.potassium,
                    servingUnitOptions: result.servingUnitOptions,
                    selectedServingUnit: result.selectedServingUnit,
                    selectedServingQuantity: result.selectedServingQuantity,
                    logDate: time,
                    onLog: { entry in
                        stage(applyHeader(to: entry))
                        activeFlow = nil
                    }
                )
            }
        }
    }

    // MARK: - Analyzer paths

    private func analyzeAuto(image: UIImage) async {
        errorMessage = nil
        foodResultImage = image
        foodResultEmoji = nil
        foodResultSource = .snapFood
        activeFlow = .analyzing
        do {
            let result = try await GeminiService.autoAnalyze(image: image)
            foodResult = result
            foodResultEmoji = result.emoji
            activeFlow = .foodResult
        } catch {
            activeFlow = nil
            errorMessage = error.localizedDescription
        }
    }

    private func analyzeLabel(image: UIImage) async {
        errorMessage = nil
        foodResultImage = image
        foodResultEmoji = nil
        foodResultSource = .nutritionLabel
        activeFlow = .analyzing
        do {
            let label = try await GeminiService.analyzeNutritionLabel(image: image)
            pendingLabelImage = image
            pendingLabelAnalysis = label
            activeFlow = .servingSize
        } catch {
            activeFlow = nil
            errorMessage = error.localizedDescription
        }
    }

    private func analyzeText(description: String) async {
        errorMessage = nil
        foodResultImage = nil
        foodResultEmoji = nil
        foodResultSource = .textInput
        activeFlow = .analyzing
        do {
            let result = try await GeminiService.analyzeTextInput(
                description: description,
                foodDatabase: foodDatabase
            )
            foodResult = result
            foodResultEmoji = result.emoji
            activeFlow = .foodResult
        } catch {
            activeFlow = nil
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Staging-derived header state

    /// Sum of calories across staged entries. Surfaces in the header pill so
    /// the user sees the running total of what they're about to log.
    private var stagedKcal: Int {
        stagedEntries.reduce(0) { $0 + $1.calories }
    }

    /// One emoji per staged entry for the header's icon strip. Entries
    /// without a Gemini-supplied emoji fall back to a meal-type glyph so
    /// the strip never breaks. Order matches insertion order so the most
    /// recently staged item appears last (closest to the chevron-down).
    private var stagedEmojis: [String] {
        stagedEntries.map { entry in
            if let emoji = entry.emoji, !emoji.isEmpty {
                return emoji
            }
            return fallbackEmoji(for: entry)
        }
    }

    /// Heuristic fallback when a staged entry doesn't carry its own emoji:
    /// use the source (snap / nutrition label / text / manual) to pick a
    /// representative glyph so the strip stays expressive even for
    /// Quick-Add or barcode entries.
    private func fallbackEmoji(for entry: FoodEntry) -> String {
        switch entry.source {
        case .snapFood: return "\u{1F4F8}"        // camera
        case .nutritionLabel: return "\u{1F516}"  // bookmark tab (label)
        case .textInput: return "\u{1F4DD}"       // memo
        case .manual: return "\u{1F37D}"          // fork + knife with plate
        }
    }

    // MARK: - Staging + commit

    private func stage(_ entry: FoodEntry) {
        stagedEntries.append(entry)
    }

    private func stageDefaultPortion(of item: FoodDatabaseItem) {
        // Default portion is 100 g, mirroring `QuickAddPortionSheet`'s initial
        // state. Users who need a custom amount tap the row instead of the "+".
        //
        // Pass through every per-100g micronutrient the seed carries so the
        // Food Detail view (which already supports sodium / sugar / saturated
        // fat editing) lights up with real values for branded chain items —
        // e.g. tapping the "+" on an In-N-Out Cheeseburger stages an entry
        // with its published sodium load instead of stripping that detail.
        let grams: Double = 100
        let entry = FoodEntry(
            name: "\(Int(grams))g \(item.name.lowercased())",
            calories: Int(item.caloriesPer100g.rounded()),
            protein: Int(item.proteinPer100g.rounded()),
            carbs: Int(item.carbsPer100g.rounded()),
            fat: Int(item.fatPer100g.rounded()),
            timestamp: time,
            source: .manual,
            mealType: mealType ?? .currentMeal,
            sugar: item.sugarPer100g,
            fiber: item.fiberPer100g,
            saturatedFat: item.saturatedFatPer100g,
            sodium: item.sodiumPer100g,
            servingSizeGrams: grams
        )
        stage(entry)
    }

    /// Re-stamp an entry with the header's chosen time + meal type so every
    /// staged entry consistently lands on the slot the user selected.
    private func applyHeader(to entry: FoodEntry) -> FoodEntry {
        FoodEntry(
            id: entry.id,
            name: entry.name,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            timestamp: time,
            imageData: entry.imageData,
            imageFilename: entry.imageFilename,
            emoji: entry.emoji,
            source: entry.source,
            mealType: mealType ?? entry.mealType,
            sugar: entry.sugar,
            addedSugar: entry.addedSugar,
            fiber: entry.fiber,
            saturatedFat: entry.saturatedFat,
            monounsaturatedFat: entry.monounsaturatedFat,
            polyunsaturatedFat: entry.polyunsaturatedFat,
            cholesterol: entry.cholesterol,
            sodium: entry.sodium,
            potassium: entry.potassium,
            servingSizeGrams: entry.servingSizeGrams,
            servingUnitOptions: entry.servingUnitOptions,
            selectedServingUnit: entry.selectedServingUnit,
            selectedServingQuantity: entry.selectedServingQuantity
        )
    }

    private func commitStaged() {
        guard !stagedEntries.isEmpty else {
            dismiss()
            return
        }
        for entry in stagedEntries {
            foodStore.addEntry(entry)
        }
        Haptics.medium()
        stagedEntries.removeAll()
        dismiss()
    }

    // MARK: - Consent gate

    private func runWithConsent(_ action: @escaping () -> Void) {
        if aiConsentGiven {
            action()
        } else {
            pendingConsentAction = action
            showAIConsent = true
        }
    }

    // MARK: - Filtered data (compute functions — call from recomputeSearchResults only)

    private func computedFilteredFavorites() -> [FoodDatabaseItem] {
        // Pull the user's actually-favorited IDs (P14) and resolve them
        // against the database. When no favorites exist yet, fall back to a
        // small head of the seed DB so the strip isn't empty for new users.
        let favIDs = favoritesStore.sortedIDs
        if favIDs.isEmpty {
            let pool = foodDatabase.search(filterQuery, limit: 8)
            return Array(pool.prefix(6))
        }
        // Resolve each ID against the seed + USDA + AI-cache via the search
        // index. We search by ID prefix; the index returns the exact match
        // first when it exists.
        var resolved: [FoodDatabaseItem] = []
        for id in favIDs.prefix(8) {
            if let item = foodDatabase.search(id, limit: 1).first(where: { $0.id == id }) {
                resolved.append(item)
            }
        }
        return Array(resolved.prefix(6))
    }

    private func computedFilteredSuggestions() -> [FoodDatabaseItem] {
        let trimmed = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return foodDatabase.search(trimmed, limit: 15)
        }
        // No query — pull time-of-day picks from the user's own log history (P14).
        // SlotPicksService aggregates entries logged within a 4-hour window
        // around the sheet's header time and ranks by distinct-day count.
        let picks = SlotPicksService.suggestionsAsDatabaseItems(
            from: foodStore.entries,
            for: time,
            database: foodDatabase
        )
        if !picks.isEmpty {
            return picks
        }
        // Cold-start fallback: user has no log history yet, just surface a
        // curated head of the seed DB so the section isn't empty.
        return Array(foodDatabase.search("", limit: 15))
    }

    private func computedFilteredLibrary() -> [FoodDatabaseItem] {
        let trimmed = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return foodDatabase.search(trimmed, limit: 30)
    }

    private var bottomBarPlaceholder: String {
        switch selectedTab {
        case 0: return "Search foods"
        case 5: return "Filter library"
        default: return "Filter foods"
        }
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.vertical, BulkAITheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm)
                .fill(Color.red.opacity(0.85))
        )
    }
}
