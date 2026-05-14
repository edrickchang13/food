import SwiftUI
import PhotosUI

/// Sheet presented by the center + button on the custom tab bar. Surfaces the
/// nine fastest paths to log food in a MacroFactor-style grid: camera, camera
/// with note, nutrition label, photos, photos with note, voice, manual entry,
/// and saved meals — plus the original text input + AI parse + database search
/// rendered below the grid.
struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FoodStore.self) private var foodStore
    @Environment(FoodDatabaseService.self) private var foodDatabase

    @AppStorage("aiAnalysisConsentGiven") private var aiConsentGiven: Bool = false

    // Text input + DB search state (unchanged behavior)
    @State private var description: String = ""
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var selectedItem: FoodDatabaseItem?
    @State private var loggedFeedback: String?
    @FocusState private var inputFocused: Bool

    // Entry-method flow state
    @State private var activeFlow: EntryFlow?
    @State private var showCamera: Bool = false
    @State private var pendingPhotoItem: PhotosPickerItem?
    @State private var photoPickerMode: CameraFlowMode = .auto
    @State private var showPhotoPicker: Bool = false
    @State private var capturedImage: UIImage?
    @State private var pendingCameraMode: CameraFlowMode = .auto
    @State private var pendingContextImage: UIImage?
    @State private var contextDescription: String = ""
    @State private var pendingLabelImage: UIImage?
    @State private var pendingLabelAnalysis: GeminiService.NutritionLabelAnalysis?
    @State private var foodResult: GeminiService.FoodAnalysis?
    @State private var foodResultImage: UIImage?
    @State private var foodResultEmoji: String?
    @State private var foodResultSource: FoodSource = .textInput
    @State private var showAIConsent: Bool = false
    @State private var pendingConsentAction: (() -> Void)?

    /// Sheet content that can present from inside QuickAddSheet. Camera is
    /// presented via a separate `fullScreenCover` flag so dismissing the camera
    /// and presenting the next sheet don't collide in the same run loop.
    private enum EntryFlow: String, Identifiable {
        case contextSheet
        case voice
        case manual
        case savedMeals
        case analyzing
        case servingSize
        case foodResult
        var id: String { rawValue }
    }

    private enum CameraFlowMode {
        case auto              // Camera → autoAnalyze
        case withContext       // Camera → ContextDescriptionSheet → analyzeFood(image:description:)
        case nutritionLabel    // Camera → analyzeNutritionLabel → ServingSizeInputView
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCopy
                    methodGrid
                    textInputCard
                    if isAnalyzing { analyzingRow }
                    if let errorMessage { errorBanner(errorMessage) }
                    if let loggedFeedback { successBanner(loggedFeedback) }
                    searchResultsSection
                }
                .padding(20)
            }
            .background(AppColors.appBackground)
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedItem) { item in
                QuickAddPortionSheet(item: item) { entry in
                    foodStore.addEntry(entry)
                    loggedFeedback = "Logged \(entry.name)."
                    description = ""
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { _, newValue in
                guard let image = newValue else { return }
                capturedImage = nil
                handleCapturedImage(image, mode: pendingCameraMode)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pendingPhotoItem, matching: .images)
            .onChange(of: pendingPhotoItem) { _, newValue in
                guard let item = newValue else { return }
                pendingPhotoItem = nil
                Task { await loadPhoto(item, mode: photoPickerMode) }
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
            .interactiveDismissDisabled(activeFlow == .analyzing)
        }
    }

    // MARK: - Flow content

    @ViewBuilder
    private func flowContent(for flow: EntryFlow) -> some View {
        switch flow {
        case .contextSheet:
            ContextDescriptionSheet(
                image: pendingContextImage,
                description: $contextDescription,
                onAnalyze: {
                    let desc = contextDescription
                    let image = pendingContextImage
                    activeFlow = nil
                    pendingContextImage = nil
                    if let image {
                        runWithConsent {
                            Task {
                                // Brief pause so the context sheet fully dismisses
                                // before we present the analyzing sheet. Mirrors
                                // the existing HomeView text/voice pattern.
                                try? await Task.sleep(for: .milliseconds(300))
                                await analyzeWithContext(image: image, description: desc)
                            }
                        }
                    }
                },
                onCancel: {
                    activeFlow = nil
                    pendingContextImage = nil
                }
            )
        case .voice:
            VoiceInputView(
                onCancel: { activeFlow = nil },
                onSubmit: { description in
                    activeFlow = nil
                    runWithConsent {
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            await analyzeText(description: description)
                        }
                    }
                }
            )
        case .manual:
            ManualEntryView(
                logDate: .now,
                onCancel: { activeFlow = nil },
                onSave: { entry in
                    activeFlow = nil
                    foodStore.addEntry(entry)
                    loggedFeedback = "Logged \(entry.name)."
                }
            )
        case .savedMeals:
            RecentsView(logDate: .now, onReview: { entry in
                // RecentsView.onReview hands us the entry already prepared with
                // today's timestamp + current meal type; just persist it.
                foodStore.addEntry(entry)
                loggedFeedback = "Logged \(entry.name)."
                activeFlow = nil
            })
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
                    logDate: .now,
                    onLog: { entry in
                        foodStore.addEntry(entry)
                        loggedFeedback = "Logged \(entry.name)."
                        activeFlow = nil
                    }
                )
            }
        }
    }

    // MARK: - Sections

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Log a meal")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Pick any input — photo, voice, text, or pull from your saved meals. Free-text falls back to AI parsing.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var methodGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return LazyVGrid(columns: columns, spacing: 10) {
            methodButton(icon: "camera.fill", label: "Camera") {
                pendingCameraMode = .auto
                showCamera = true
            }
            methodButton(icon: "camera.badge.ellipsis", label: "Camera + Note") {
                pendingCameraMode = .withContext
                showCamera = true
            }
            methodButton(icon: "text.viewfinder", label: "Nutrition Label") {
                pendingCameraMode = .nutritionLabel
                showCamera = true
            }
            methodButton(icon: "photo.on.rectangle", label: "From Photos") {
                photoPickerMode = .auto
                showPhotoPicker = true
            }
            methodButton(icon: "photo.badge.plus", label: "From Photos + Note") {
                photoPickerMode = .withContext
                showPhotoPicker = true
            }
            methodButton(icon: "mic.fill", label: "Voice") {
                activeFlow = .voice
            }
            methodButton(icon: "square.and.pencil", label: "Manual Entry") {
                activeFlow = .manual
            }
            methodButton(icon: "bookmark.fill", label: "Saved Meals") {
                activeFlow = .savedMeals
            }
        }
    }

    @ViewBuilder
    private func methodButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppColors.calorie)
                    .frame(height: 28)
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(AppColors.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var textInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or type what you ate")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField("e.g. 150g chicken breast", text: $description, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .focused($inputFocused)
                .padding(14)
                .background(AppColors.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .autocorrectionDisabled(false)

            Button {
                runWithConsent {
                    Task { await aiAnalyze() }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Parse with AI")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.calorie)
            .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)
        }
    }

    private var analyzingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Calling Gemini…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.system(.subheadline, design: .rounded))
        }
    }

    private var searchResultsSection: some View {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let local = trimmed.isEmpty ? [] : foodDatabase.search(trimmed, limit: 15)
        return Group {
            if !local.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Matches in database")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    VStack(spacing: 0) {
                        ForEach(local) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                row(for: item)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                            }
                            .buttonStyle(.plain)
                            if item.id != local.last?.id {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                    .background(AppColors.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: FoodDatabaseItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            sourceBadge(for: item.source)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(Int(item.caloriesPer100g)) kcal · P \(Int(item.proteinPer100g)) / C \(Int(item.carbsPer100g)) / F \(Int(item.fatPer100g)) per 100g")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func sourceBadge(for source: FoodDatabaseSource) -> some View {
        switch source {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))
        case .aiEstimated:
            Image(systemName: "sparkle")
                .foregroundStyle(.tint)
                .font(.system(size: 14))
        }
    }

    // MARK: - Camera / photo handlers

    private func handleCapturedImage(_ image: UIImage, mode: CameraFlowMode) {
        // The fullScreenCover is dismissing concurrently. A short delay before
        // presenting the next sheet avoids the "tried to present while another
        // is dismissing" warning and keeps the transition feeling smooth.
        switch mode {
        case .auto:
            runWithConsent {
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await analyzeAuto(image: image)
                }
            }
        case .withContext:
            pendingContextImage = image
            contextDescription = ""
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                activeFlow = .contextSheet
            }
        case .nutritionLabel:
            runWithConsent {
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await analyzeLabel(image: image)
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem, mode: CameraFlowMode) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }
        await MainActor.run {
            switch mode {
            case .auto:
                runWithConsent {
                    Task { await analyzeAuto(image: image) }
                }
            case .withContext:
                pendingContextImage = image
                contextDescription = ""
                activeFlow = .contextSheet
            case .nutritionLabel:
                // Photo-library route never selects nutritionLabel today, but
                // treat it as auto if it ever does.
                runWithConsent {
                    Task { await analyzeAuto(image: image) }
                }
            }
        }
    }

    // MARK: - Analysis paths

    private func analyzeAuto(image: UIImage) async {
        errorMessage = nil
        loggedFeedback = nil
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

    private func analyzeWithContext(image: UIImage, description: String) async {
        errorMessage = nil
        loggedFeedback = nil
        foodResultImage = image
        foodResultEmoji = nil
        foodResultSource = .snapFood
        activeFlow = .analyzing
        do {
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = try await GeminiService.analyzeFood(
                image: image,
                description: trimmed.isEmpty ? nil : trimmed
            )
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
        loggedFeedback = nil
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
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        loggedFeedback = nil
        foodResultImage = nil
        foodResultEmoji = nil
        foodResultSource = .textInput
        activeFlow = .analyzing
        do {
            let result = try await GeminiService.analyzeTextInput(
                description: trimmed,
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

    // MARK: - Text input AI parse (preserves original behavior)

    private func aiAnalyze() async {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        loggedFeedback = nil
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await GeminiService.analyzeTextInput(
                description: trimmed,
                foodDatabase: foodDatabase
            )
            let entry = FoodEntry(
                name: result.name,
                calories: result.calories,
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                timestamp: .now,
                source: .textInput,
                mealType: MealType.currentMeal,
                sugar: result.sugar,
                addedSugar: result.addedSugar,
                fiber: result.fiber,
                saturatedFat: result.saturatedFat,
                monounsaturatedFat: result.monounsaturatedFat,
                polyunsaturatedFat: result.polyunsaturatedFat,
                cholesterol: result.cholesterol,
                sodium: result.sodium,
                potassium: result.potassium,
                servingSizeGrams: result.servingSizeGrams
            )
            foodStore.addEntry(entry)
            loggedFeedback = "Logged \(result.calories) kcal — \(result.name)."
            description = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Consent gate

    /// Run `action` immediately if the user has already consented to AI analysis,
    /// otherwise stash it and present `AIConsentSheetView`. Mirrors HomeView's
    /// pattern so every AI surface in the app behaves the same way.
    private func runWithConsent(_ action: @escaping () -> Void) {
        if aiConsentGiven {
            action()
        } else {
            pendingConsentAction = action
            showAIConsent = true
        }
    }
}

/// Picks portion size for a database item, then constructs a FoodEntry.
struct QuickAddPortionSheet: View {
    let item: FoodDatabaseItem
    let onLog: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var grams: Double = 100
    @State private var mealType: MealType = .currentMeal

    var body: some View {
        NavigationStack {
            Form {
                Section(item.name) {
                    Stepper(value: $grams, in: 5...2000, step: 5) {
                        HStack {
                            Text("Portion")
                            Spacer()
                            Text("\(Int(grams)) g").monospacedDigit()
                        }
                    }
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }
                Section("Will log") {
                    let multiplier = grams / 100
                    statRow("Calories", "\(Int((item.caloriesPer100g * multiplier).rounded())) kcal")
                    statRow("Protein", "\(Int((item.proteinPer100g * multiplier).rounded())) g")
                    statRow("Carbs", "\(Int((item.carbsPer100g * multiplier).rounded())) g")
                    statRow("Fat", "\(Int((item.fatPer100g * multiplier).rounded())) g")
                }
            }
            .navigationTitle("Log portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log") {
                        let multiplier = grams / 100
                        // Scale every per-100g micronutrient the seed exposes
                        // by the chosen serving so the Food Detail view sees
                        // the right values for the custom amount the user
                        // picked (e.g. logging 200 g of a 373 mg-sodium chain
                        // item should produce a 746 mg row in the detail).
                        let entry = FoodEntry(
                            name: "\(Int(grams))g \(item.name.lowercased())",
                            calories: Int((item.caloriesPer100g * multiplier).rounded()),
                            protein: Int((item.proteinPer100g * multiplier).rounded()),
                            carbs: Int((item.carbsPer100g * multiplier).rounded()),
                            fat: Int((item.fatPer100g * multiplier).rounded()),
                            timestamp: .now,
                            source: .manual,
                            mealType: mealType,
                            sugar: item.sugarPer100g.map { $0 * multiplier },
                            fiber: item.fiberPer100g.map { $0 * multiplier },
                            saturatedFat: item.saturatedFatPer100g.map { $0 * multiplier },
                            sodium: item.sodiumPer100g.map { $0 * multiplier },
                            servingSizeGrams: grams
                        )
                        onLog(entry)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
