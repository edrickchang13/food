import SwiftUI
import PhotosUI
import UIKit
import HealthKit
import StoreKit
import BulkAIEngine
import WidgetKit

// MARK: - Camera Mode
enum CameraMode {
    case snapFood
    case snapFoodWithContext
    case nutritionLabel
}

private let fudAIAppStoreID = "6758935726"
private let fudAIAppStoreURL = URL(string: "https://apps.apple.com/us/app/fud-ai-calorie-tracker/id6758935726")!

private enum AppUpdateState: Equatable {
    case idle
    case checking
    case upToDate(current: String, latest: String?)
    case available(current: String, latest: String, url: URL)
    case failed(current: String)

    var isUpdateAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var hasStartedCheck: Bool {
        if case .idle = self {
            return false
        }
        return true
    }
}

private struct AppStoreLookupResponse: Decodable {
    let results: [AppStoreLookupResult]
}

private struct AppStoreLookupResult: Decodable {
    let version: String
    let trackViewUrl: String?
}

private enum AppUpdateChecker {
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    static var currentVersionDisplay: String {
        currentVersion
    }

    static func check() async -> AppUpdateState {
        let current = currentVersion

        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(fudAIAppStoreID)&country=us") else {
            return .failed(current: current)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .failed(current: current)
            }

            let lookup = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
            guard let result = lookup.results.first else {
                return .upToDate(current: current, latest: nil)
            }

            let updateURL = result.trackViewUrl.flatMap(URL.init(string:)) ?? fudAIAppStoreURL
            if isVersion(result.version, newerThan: current) {
                return .available(current: current, latest: result.version, url: updateURL)
            }

            return .upToDate(current: current, latest: result.version)
        } catch {
            return .failed(current: current)
        }
    }

    private static func isVersion(_ latest: String, newerThan current: String) -> Bool {
        let latestParts = latest.split(separator: ".").map { Int($0) ?? 0 }
        let currentParts = current.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(latestParts.count, currentParts.count)

        for index in 0..<count {
            let latestValue = index < latestParts.count ? latestParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0

            if latestValue > currentValue {
                return true
            }
            if latestValue < currentValue {
                return false
            }
        }

        return false
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @AppStorage(AppThemeColor.storageKey) private var appThemeColorRaw = AppThemeColor.defaultColor.rawValue
    @State private var appUpdateState: AppUpdateState = .idle
    @State private var selectedTab: CustomTabBar.Tab = .home
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content pane keyed by selectedTab. The .opacity dance keeps each
            // tab's view state alive across switches (no destroy/recreate) so
            // partially-typed forms and scroll positions persist like a real
            // TabView would.
            ZStack {
                DashboardView()
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)
                FoodLogView()
                    .opacity(selectedTab == .progress ? 1 : 0)
                    .allowsHitTesting(selectedTab == .progress)
                ChatView()
                    .opacity(selectedTab == .coach ? 1 : 0)
                    .allowsHitTesting(selectedTab == .coach)
                ProfileView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 56)   // make room for the tab bar without clipping

            CustomTabBar(selection: $selectedTab) {
                showQuickAdd = true
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(AppThemeColor.color(for: appThemeColorRaw).color)
        .task {
            await refreshAppUpdateState()
        }
        .sheet(isPresented: $showQuickAdd) {
            FoodEntrySheet()
        }
    }

    @MainActor
    private func refreshAppUpdateState(force: Bool = false) async {
        if !force && appUpdateState.hasStartedCheck {
            return
        }

        appUpdateState = .checking
        appUpdateState = await AppUpdateChecker.check()
    }
}

// MARK: - About View
private struct AboutView: View {
    @Binding private var updateState: AppUpdateState
    private let refreshUpdateState: () async -> Void

    @State private var showShareSheet = false

    init(updateState: Binding<AppUpdateState>, refreshUpdateState: @escaping () async -> Void) {
        self._updateState = updateState
        self.refreshUpdateState = refreshUpdateState
    }

    private var shareMessage: String {
        String(localized: "I've been tracking my meals with Bulk AI — snap a photo, speak it, or type it, and the AI logs the calories. It's free, open source, and your data stays on your device.\n\nDownload: https://fud-ai.app")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    updateRow

                    // Rate the App
                    Button {
                        requestNativeReview()
                    } label: {
                        Label {
                            Text("Rate the App")
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Share the App — uses UIActivityViewController so both
                    // the personalized message AND the App Store URL get
                    // forwarded to every share target (SwiftUI ShareLink
                    // drops the message arg for most targets).
                    Button {
                        showShareSheet = true
                    } label: {
                        Label {
                            Text("Share the App")
                        } icon: {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Support
                    Link(destination: URL(string: "https://ko-fi.com/apoorvdarshan")!) {
                        Label {
                            Text("Support on Ko-fi")
                        } icon: {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Open Source
                    Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai")!) {
                        Label {
                            Text("Open Source (MIT)")
                        } icon: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Star the Repo
                    Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai")!) {
                        Label {
                            Text("Star on GitHub")
                        } icon: {
                            Image(systemName: "star.circle.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Vote on Product Hunt
                    Link(destination: URL(string: "https://www.producthunt.com/products/fud-ai-calorie-tracker")!) {
                        Label {
                            Text("Vote on Product Hunt")
                        } icon: {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Report an Issue
                    Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai/issues/new?labels=bug&title=Bug:%20")!) {
                        Label {
                            Text("Report an Issue")
                        } icon: {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Request a Feature
                    Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai/issues/new?labels=enhancement&title=Feature:%20")!) {
                        Label {
                            Text("Request a Feature")
                        } icon: {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Contact
                    Link(destination: URL(string: "mailto:apoorv@fud-ai.app")!) {
                        Label {
                            Text("Contact Us")
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Follow on X
                    Link(destination: URL(string: "https://x.com/apoorvdarshan")!) {
                        Label {
                            Text("Follow on X")
                        } icon: {
                            Image(systemName: "at")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Instagram
                    Link(destination: URL(string: "https://www.instagram.com/fudai.app/")!) {
                        Label {
                            Text("Follow on Instagram")
                        } icon: {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // LinkedIn
                    Link(destination: URL(string: "https://www.linkedin.com/company/fud-ai-app")!) {
                        Label {
                            Text("Follow on LinkedIn")
                        } icon: {
                            Image(systemName: "briefcase.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)
                }
                .listRowBackground(AppColors.appCard)

                Section {
                    // Privacy Policy
                    Link(destination: URL(string: "https://fud-ai.app/privacy.html")!) {
                        Label {
                            Text("Privacy Policy")
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    // Terms of Service
                    Link(destination: URL(string: "https://fud-ai.app/terms.html")!) {
                        Label {
                            Text("Terms of Service")
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)
                }
                .listRowBackground(AppColors.appCard)

                Section {
                    VStack(spacing: 4) {
                        Text("Made by Apoorv Darshan")
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("with care, for everyone")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $showShareSheet) {
                ActivityShareSheet(activityItems: [shareMessage, fudAIAppStoreURL])
            }
        }
    }

    @ViewBuilder
    private var updateRow: some View {
        switch updateState {
        case .checking:
            HStack {
                Label {
                    Text("Checking for Updates")
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(AppColors.calorie)
                }

                Spacer()

                ProgressView()
                    .tint(AppColors.calorie)
            }

        case .available(let current, let latest, let url):
            Button {
                UIApplication.shared.open(url)
            } label: {
                HStack(spacing: 12) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Update Available")
                            Text("Current \(current) -> Latest \(latest)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(AppColors.calorie)

                            Circle()
                                .fill(AppColors.calorie)
                                .frame(width: 8, height: 8)
                                .offset(x: 3, y: -3)
                        }
                    }

                    Spacer()

                    Text("Update")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.calorie)
                }
            }
            .tint(.primary)

        case .failed:
            Button {
                Task {
                    await refreshUpdateState()
                }
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for Updates")
                            Text("Version \(AppUpdateChecker.currentVersionDisplay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(AppColors.calorie)
                    }

                    Spacer()
                }
            }
            .tint(.primary)

        case .idle, .upToDate:
            Button {
                Task {
                    await refreshUpdateState()
                }
            } label: {
                HStack {
                    Label {
                        Text("App Version")
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(AppColors.calorie)
                    }

                    Spacer()

                    Text(AppUpdateChecker.currentVersionDisplay)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
        }
    }

    private func requestNativeReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}

// MARK: - Share Sheet wrapper (UIActivityViewController)
// Used by AboutView so the personalized message AND the App Store URL
// both reach every share target. SwiftUI's ShareLink message arg is
// dropped by most targets; UIActivityViewController forwards every item.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Home View (Main Dashboard)
struct HomeView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(FoodDatabaseService.self) private var foodDatabase
    @State private var selectedDate: Date = .now

    enum ActiveSheet: String, Identifiable {
        case editFood
        var id: String { rawValue }
    }
    @State private var activeSheet: ActiveSheet?
    @State private var editingEntry: FoodEntry?

    @AppStorage(FoodLogSortOrder.storageKey) private var foodLogSortOrderRaw = FoodLogSortOrder.defaultOrder.rawValue
    @AppStorage(HomeTopNutrient.storageKey) private var homeTopNutrientsRaw = HomeTopNutrient.storageValue(for: HomeTopNutrient.defaultSelection)
    @AppStorage(OptionalNutrientGoals.storageKey) private var optionalNutrientGoalsData = Data()
    @Environment(ProfileStore.self) private var profileStore

    /// Force a body re-evaluation whenever profileStore.profile changes by reading it
    /// at the top of body. SwiftUI's @Observable tracking sometimes misses the access
    /// when the read is buried in a computed property; explicit access guarantees it.
    private var userProfile: UserProfile { profileStore.profile }
    private var calorieGoal: Int { userProfile.effectiveCalories }
    private var proteinGoal: Int { userProfile.effectiveProtein }
    private var carbsGoal: Int { userProfile.effectiveCarbs }
    private var fatGoal: Int { userProfile.effectiveFat }
    private var selectedCalories: Int { foodStore.calories(for: selectedDate) }
    private var caloriesRemaining: Int { max(calorieGoal - selectedCalories, 0) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    private var foodLogSortOrder: FoodLogSortOrder { FoodLogSortOrder.order(for: foodLogSortOrderRaw) }
    private var homeTopNutrients: [HomeTopNutrient] { HomeTopNutrient.selection(from: homeTopNutrientsRaw) }
    private var optionalNutrientGoals: OptionalNutrientGoals { OptionalNutrientGoals.decoded(from: optionalNutrientGoalsData) }
    private var logDateForSelectedDay: Date { logDate(on: selectedDate) }

    private var navigationTitle: String {
        if isToday { return "Today" }
        return selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func logDate(on day: Date, now: Date = .now) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return now }

        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond
        return calendar.date(from: components) ?? day
    }

    var body: some View {
        // Explicit observation tracking — reads profileStore.profile at body root
        // so SwiftUI invalidates this view on every profile mutation.
        let _ = profileStore.profile
        return NavigationStack {
            List {
                // Week-energy date strip — drives `selectedDate`, which the food
                // log query below reads. Without this strip the user has no way
                // to navigate to past days (orphaned-state regression caught by
                // the home-screen audit).
                Section {
                    WeekEnergyStrip(
                        selectedDate: $selectedDate,
                        caloriesForDate: { foodStore.calories(for: $0) },
                        calorieGoal: calorieGoal
                    )
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                // MacroFactor-style dashboard: header + calorie ring + macro bars
                // + insights row + habit heatmaps. Replaces the legacy Fud AI
                // hero (week strip + giant calorie number + nutrient trio cards)
                // with the layout from the design reference.
                Section {
                    MacroFactorDashboard(selectedDate: selectedDate)
                        .padding(.horizontal, -16)   // counter the List's inset
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Food list
                let mealGroups = foodStore.entriesByMeal(for: selectedDate, order: foodLogSortOrder)
                if mealGroups.isEmpty {
                    Section(isToday ? "Today's Food" : "Food Log") {
                        Text("No foods logged")
                            .foregroundStyle(.secondary)
                            .listRowBackground(AppColors.appCard)
                    }
                } else {
                    ForEach(mealGroups) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                FoodRow(entry: entry)
                                    .listRowBackground(AppColors.appCard)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingEntry = entry
                                        activeSheet = .editFood
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            foodStore.deleteEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                        Button {
                                            foodStore.toggleFavorite(entry)
                                        } label: {
                                            Label(foodStore.isFavorite(entry) ? "Unfavorite" : "Favorite", systemImage: foodStore.isFavorite(entry) ? "heart.slash.fill" : "heart.fill")
                                        }
                                        .tint(AppColors.calorie)
                                    }
                            }
                        } header: {
                            HStack(alignment: .center) {
                                Label(group.meal.displayName, systemImage: group.meal.icon)
                                Spacer()
                                if group.id == mealGroups.first?.id {
                                    Menu {
                                        Picker("Food Log Order", selection: $foodLogSortOrderRaw) {
                                            ForEach(FoodLogSortOrder.allCases) { order in
                                                Text(order.displayName).tag(order.rawValue)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                            Text("Sort")
                                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        }
                                    }
                                    .tint(AppColors.calorie)
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .animation(.snappy, value: selectedDate)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .editFood:
                    if let editingEntry {
                        EditFoodEntryView(entry: editingEntry)
                    }
                }
            }
        }
    }

}


// MARK: - Nutrition Detail View
struct NutritionDetailView: View {
    let date: Date
    @Binding var homeTopNutrientsRaw: String
    @Environment(FoodStore.self) private var foodStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OptionalNutrientGoals.storageKey) private var optionalNutrientGoalsData = Data()
    @State private var showHomeNutrientPicker = false

    private var userProfile: UserProfile { profileStore.profile }
    private var optionalNutrientGoals: OptionalNutrientGoals { OptionalNutrientGoals.decoded(from: optionalNutrientGoalsData) }
    private var homeTopNutrients: [HomeTopNutrient] { HomeTopNutrient.selection(from: homeTopNutrientsRaw) }
    private var homeTopNutrientNames: String {
        homeTopNutrients
            .map(\.displayName)
            .joined(separator: ", ")
    }

    var body: some View {
        let _ = profileStore.profile
        return NavigationStack {
            List {
                Section {
                    Button {
                        showHomeNutrientPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Label("Home Nutrient Cards", systemImage: "square.grid.3x1.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(homeTopNutrientNames)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppColors.appCard)

                Section("Macros") {
                    NutritionDetailRow(icon: "flame.fill", label: "Calories", value: "\(foodStore.calories(for: date))", unit: "kcal", goal: "\(userProfile.effectiveCalories)")
                    NutritionDetailRow(icon: "p.circle.fill", label: "Protein", value: "\(foodStore.protein(for: date))", unit: "g", goal: "\(userProfile.effectiveProtein)")
                    NutritionDetailRow(icon: "c.circle.fill", label: "Carbs", value: "\(foodStore.carbs(for: date))", unit: "g", goal: "\(userProfile.effectiveCarbs)")
                    NutritionDetailRow(icon: "f.circle.fill", label: "Fat", value: "\(foodStore.fat(for: date))", unit: "g", goal: "\(userProfile.effectiveFat)")
                }
                .listRowBackground(AppColors.appCard)

                Section("Detailed Nutrition") {
                    optionalNutritionRow(.sugar, value: foodStore.sugar(for: date))
                    optionalNutritionRow(.addedSugar, value: foodStore.addedSugar(for: date))
                    optionalNutritionRow(.fiber, value: foodStore.fiber(for: date))
                    optionalNutritionRow(.saturatedFat, value: foodStore.saturatedFat(for: date))
                    NutritionDetailRow(icon: "drop", label: "Mono Unsat. Fat", value: formatMicro(foodStore.monounsaturatedFat(for: date)), unit: "g")
                    NutritionDetailRow(icon: "drop.halffull", label: "Poly Unsat. Fat", value: formatMicro(foodStore.polyunsaturatedFat(for: date)), unit: "g")
                    optionalNutritionRow(.cholesterol, value: foodStore.cholesterol(for: date))
                    optionalNutritionRow(.sodium, value: foodStore.sodium(for: date))
                    optionalNutritionRow(.potassium, value: foodStore.potassium(for: date))
                }
                .listRowBackground(AppColors.appCard)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .navigationTitle("Nutrition Details")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showHomeNutrientPicker) {
                HomeNutrientPickerSheet(selectionRawValue: $homeTopNutrientsRaw)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(AppColors.calorie)
                }
            }
        }
    }

    private func formatMicro(_ value: Double) -> String {
        value == 0 ? "—" : String(format: "%.1f", value)
    }

    private func optionalNutritionRow(_ nutrient: OptionalNutrient, value: Double) -> some View {
        NutritionDetailRow(
            icon: nutrient.iconName,
            label: nutrient.displayName,
            value: formatMicro(value),
            unit: nutrient.unit,
            goal: "\(optionalNutrientGoals.goal(for: nutrient))"
        )
    }
}

struct NutritionDetailRow: View {
    var icon: String? = nil
    let label: String
    let value: String
    let unit: String
    var goal: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: AppColors.calorieGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 24)
            }
            Text(label)
                .font(.system(.body, design: .rounded))
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.calorie)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            if let goal {
                Text("/ \(goal)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Context Description Sheet
struct ContextDescriptionSheet: View {
    let image: UIImage?
    @Binding var description: String
    let onAnalyze: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(AppColors.calorie.opacity(0.15), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add context (optional)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("e.g. \"This is a half portion\" or \"Cooked in olive oil\"")
                                    .foregroundStyle(.tertiary)
                                    .font(.body)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 10)
                                    .allowsHitTesting(false)
                            }
                            TextField("", text: $description, axis: .vertical)
                                .font(.body)
                                .lineLimit(3...6)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 10)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }

                    Button {
                        onAnalyze()
                    } label: {
                        Text("Analyze")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.calorie)
                    .controlSize(.large)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Camera View (UIKit wrapper)
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        picker.edgesForExtendedLayout = .all
        picker.showsCameraControls = false

        // Custom overlay with shutter + cancel buttons
        let overlay = UIView(frame: UIScreen.main.bounds)
        overlay.isUserInteractionEnabled = true
        overlay.backgroundColor = .clear

        let bottomBar = UIView()
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(bottomBar)

        let shutterOuter = UIView()
        shutterOuter.backgroundColor = .white
        shutterOuter.layer.cornerRadius = 37
        shutterOuter.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(shutterOuter)

        let shutterInner = UIView()
        shutterInner.backgroundColor = .white
        shutterInner.layer.cornerRadius = 32
        shutterInner.layer.borderWidth = 2
        shutterInner.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        shutterInner.translatesAutoresizingMaskIntoConstraints = false
        shutterOuter.addSubview(shutterInner)

        let shutterButton = UIButton(type: .system)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addTarget(context.coordinator, action: #selector(Coordinator.capture), for: .touchUpInside)
        shutterOuter.addSubview(shutterButton)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(context.coordinator, action: #selector(Coordinator.cancel), for: .touchUpInside)
        bottomBar.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 140),

            shutterOuter.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            shutterOuter.centerYAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 50),
            shutterOuter.widthAnchor.constraint(equalToConstant: 74),
            shutterOuter.heightAnchor.constraint(equalToConstant: 74),

            shutterInner.centerXAnchor.constraint(equalTo: shutterOuter.centerXAnchor),
            shutterInner.centerYAnchor.constraint(equalTo: shutterOuter.centerYAnchor),
            shutterInner.widthAnchor.constraint(equalToConstant: 64),
            shutterInner.heightAnchor.constraint(equalToConstant: 64),

            shutterButton.leadingAnchor.constraint(equalTo: shutterOuter.leadingAnchor),
            shutterButton.trailingAnchor.constraint(equalTo: shutterOuter.trailingAnchor),
            shutterButton.topAnchor.constraint(equalTo: shutterOuter.topAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: shutterOuter.bottomAnchor),

            cancelButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: shutterOuter.centerYAnchor),
        ])

        picker.cameraOverlayView = overlay
        context.coordinator.picker = picker

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        weak var picker: UIImagePickerController?

        init(_ parent: CameraView) {
            self.parent = parent
        }

        @objc func capture() {
            picker?.takePicture()
        }

        @objc func cancel() {
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Food Row
struct FoodRow: View {
    let entry: FoodEntry
    @Environment(FoodStore.self) private var foodStore

    private var servingText: String? {
        guard let grams = entry.servingSizeGrams else { return nil }
        let formatted = grams == grams.rounded() ? "\(Int(grams))" : String(format: "%.1f", grams)
        if let selectedUnit = entry.selectedServingUnit,
           let quantity = entry.selectedServingQuantity,
           quantity > 0 {
            let option = ServingUnitOption.option(matching: selectedUnit, in: entry.servingUnitOptions)
            if !option.isGramUnit {
                let quantityText = ServingUnitEditor.formatQuantity(quantity)
                return "\(quantityText) \(option.displayUnit(for: quantity)) (~\(formatted)g)"
            }
        }
        return "\(formatted)g"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppColors.calorie.opacity(0.15), lineWidth: 1)
                    )
            } else if let emoji = entry.emoji {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(AppColors.calorie)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    HStack(spacing: 4) {
                        Text(entry.name)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                        if foodStore.isFavorite(entry) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    Spacer()
                    Text(entry.timeString)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 6) {
                    Text("\(entry.calories) kcal")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppColors.calorie)

                    if let serving = servingText {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(serving)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    MacroPill(label: "P", value: entry.protein)
                    MacroPill(label: "C", value: entry.carbs)
                    MacroPill(label: "F", value: entry.fat)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacroPill: View {
    let label: String
    let value: Int

    var body: some View {
        Text("\(label) \(value)g")
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.calorie.opacity(0.08), in: Capsule())
    }
}

// MARK: - Progress Tab
struct ProgressTabView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(BodyFatStore.self) private var bodyFatStore
    @Environment(ProfileStore.self) private var profileStore
    @AppStorage("useMetric") private var useMetric = false
    @State private var timeRange: TimeRange = .week
    @State private var showLogWeight = false
    @State private var showLogBodyFat = false
    @State private var showGoalReached = false
    @State private var showAllWeights = false

    private var userProfile: UserProfile { profileStore.profile }

    private var dateRange: ClosedRange<Date> { timeRange.dateRange() }

    private var filteredWeightEntries: [WeightEntry] {
        weightStore.entries(in: dateRange)
    }

    private var filteredBodyFatEntries: [BodyFatEntry] {
        bodyFatStore.entries(in: dateRange)
    }

    /// Show the Body Fat section to anyone who has either logged a reading,
    /// set a current value (legacy users from before BodyFatStore existed —
    /// they won't have any entries yet but we still want to show the tracker
    /// + Log button so they can start), or set a goal. Hidden entirely for
    /// users who skipped the body-fat track in onboarding.
    private var showsBodyFatSection: Bool {
        !bodyFatStore.entries.isEmpty
            || userProfile.bodyFatPercentage != nil
            || userProfile.goalBodyFatPercentage != nil
    }

    private var dailyCalories: [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        let days = timeRange.days
        let today = calendar.startOfDay(for: .now)
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let cals = foodStore.calories(for: date)
            if cals == 0 { return nil }
            return (date: date, calories: cals)
        }.reversed()
    }

    private var macroAverages: (protein: Int, carbs: Int, fat: Int) {
        let calendar = Calendar.current
        let days = timeRange.days
        let today = calendar.startOfDay(for: .now)
        var totalP = 0, totalC = 0, totalF = 0, count = 0
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayEntries = foodStore.entries(for: date)
            if dayEntries.isEmpty { continue }
            totalP += dayEntries.reduce(0) { $0 + $1.protein }
            totalC += dayEntries.reduce(0) { $0 + $1.carbs }
            totalF += dayEntries.reduce(0) { $0 + $1.fat }
            count += 1
        }
        guard count > 0 else { return (0, 0, 0) }
        return (totalP / count, totalC / count, totalF / count)
    }

    var body: some View {
        let _ = profileStore.profile
        return NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segmented Picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Weight / Body Fat Trend — single card with a segmented
                    // toggle (when the user has opted into body-fat tracking)
                    // or just the bare Weight chart (when they haven't, so the
                    // layout stays identical to v3.1 for those users).
                    BodyMetricsSection(
                        weightEntries: filteredWeightEntries,
                        goalWeightKg: userProfile.goalWeightKg,
                        currentWeightKg: weightStore.latestEntry?.weightKg,
                        onLogWeight: { showLogWeight = true },
                        bodyFatEntries: filteredBodyFatEntries,
                        goalBodyFatFraction: userProfile.goalBodyFatPercentage,
                        currentBodyFatFraction: bodyFatStore.latestEntry?.bodyFatFraction ?? userProfile.bodyFatPercentage,
                        onLogBodyFat: { showLogBodyFat = true },
                        bodyFatAvailable: showsBodyFatSection
                    )
                    .padding(.horizontal)

                    // Weight History — tap to view/delete entries
                    if !weightStore.entries.isEmpty {
                        WeightHistoryLink(
                            totalCount: weightStore.entries.count,
                            onTap: { showAllWeights = true }
                        )
                        .padding(.horizontal)
                    }

                    // Calorie Trend
                    CalorieChartSection(
                        dailyCalories: dailyCalories,
                        calorieGoal: userProfile.effectiveCalories
                    )
                    .padding(.horizontal)

                    // Macro Averages
                    MacroAveragesSection(
                        avgProtein: macroAverages.protein,
                        avgCarbs: macroAverages.carbs,
                        avgFat: macroAverages.fat,
                        proteinGoal: userProfile.effectiveProtein,
                        carbsGoal: userProfile.effectiveCarbs,
                        fatGoal: userProfile.effectiveFat
                    )
                    .padding(.horizontal)


                }
                .padding(.vertical)
            }
            .background(AppColors.appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $showLogWeight) {
                LogWeightSheet(
                    currentWeightKg: weightStore.latestEntry?.weightKg ?? userProfile.weightKg
                ) { weightKg in
                    weightStore.addEntry(WeightEntry(weightKg: weightKg))
                }
            }
            .sheet(isPresented: $showLogBodyFat) {
                // Seed from latest entry → profile current → sane default,
                // mirroring the LogWeightSheet seeding chain.
                let seed = bodyFatStore.latestEntry?.bodyFatFraction
                    ?? userProfile.bodyFatPercentage
                    ?? 0.20
                LogBodyFatSheet(currentFraction: seed) { fraction in
                    bodyFatStore.addEntry(BodyFatEntry(bodyFatFraction: fraction))
                }
            }
            .alert("Congratulations!", isPresented: $showGoalReached) {
                Button("Keep Going", role: .cancel) { }
            } message: {
                Text("You've reached your goal weight! Head to Settings to switch your goal (Maintain, Lose, or Gain) and tap Recalculate Goals to refresh your targets.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .weightGoalReached)) { _ in
                showGoalReached = true
            }
            .sheet(isPresented: $showAllWeights) {
                AllWeightHistoryView(
                    entries: weightStore.entries.sorted { $0.date > $1.date },
                    useMetric: useMetric,
                    onDelete: { entry in weightStore.deleteEntry(entry) }
                )
            }
        }
    }

}


struct ProfileView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ChatStore.self) private var chatStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(FoodStore.self) private var foodStore
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(StoreManager.self) private var storeManager
    @Environment(EngineState.self) private var engineState
    private var profile: UserProfile {
        // Read passes through; writes route through ProfileStore.save(_:)
        // because the underlying store made `profile` private(set) in P22.
        get { profileStore.profile }
        nonmutating set { profileStore.save(newValue) }
    }
    private var profileBinding: Binding<UserProfile> {
        // Same routing for the binding — every form-driven mutation lands
        // in SwiftData via ProfileStore.save(_:) and republishes.
        Binding(
            get: { profileStore.profile },
            set: { profileStore.save($0) }
        )
    }
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("useMetric") private var useMetric = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false
    @AppStorage(AppThemeColor.storageKey) private var appThemeColorRaw = AppThemeColor.defaultColor.rawValue

    enum ActiveSheet: String, Identifiable {
        case editBirthday, editHeight, editWeight, editBodyFat, editGoalBodyFat, editGoalWeight, editCalories, editProtein, editCarbs, editFat
        var id: String { rawValue }
    }
    @State private var activeSheet: ActiveSheet?
    @State private var showDeleteConfirmation = false
    @State private var showClearFoodLogConfirmation = false
    @State private var showRecalculateConfirm = false
    @State private var showCalculationMethods = false
    @State private var showEngineDebug = false
    @State private var showManualCheckIn = false
    @State private var showTDEEExplainer = false
    @State private var showFreeSigningStatus = false
    @State private var showCSVImporter = false
    @State private var pendingImport: [FoodEntry] = []
    @State private var showImportConfirm = false
    @State private var importErrorMessage: String?
    @State private var showImportError = false
    @State private var importSuccessCount: Int?
    @State private var showImportSuccess = false
    @State private var showAutoMacroEditAlert = false
    @State private var showMaxPinnedAlert = false
    @State private var showInvalidGoalWeightAlert = false
    @State private var invalidGoalWeightMessage = ""
    @State private var selectedProvider: AIProvider = AIProviderSettings.selectedProvider
    @State private var selectedModel: String = AIProviderSettings.selectedModel
    @State private var apiKeyText: String = AIProviderSettings.apiKey(for: AIProviderSettings.selectedProvider) ?? ""
    @State private var customBaseURL: String = AIProviderSettings.customBaseURL(for: AIProviderSettings.selectedProvider) ?? ""
    @State private var showAPIKey = false
    @State private var customAIInstructions: String = AIProviderSettings.userContext
    @State private var savedAIInstructions: String = AIProviderSettings.userContext
    @FocusState private var customInstructionsFocused: Bool
    @State private var selectedSpeechProvider: SpeechProvider = SpeechSettings.selectedProvider
    @State private var selectedSpeechLanguage: SpeechLanguage = SpeechSettings.selectedLanguage(for: SpeechSettings.selectedProvider)
    @State private var speechApiKeyText: String = SpeechSettings.apiKey(for: SpeechSettings.selectedProvider) ?? ""
    @State private var showSpeechAPIKey = false

    // Height formatting
    private var heightDisplay: String {
        if useMetric {
            return "\(Int(profile.heightCm)) cm"
        }
        let totalInches = profile.heightCm / 2.54
        let feet = Int(totalInches) / 12
        let inches = Int(totalInches) % 12
        return "\(feet)'\(inches)\""
    }

    // Weight formatting
    private var weightDisplay: String {
        if useMetric {
            return String(format: "%.1f kg", profile.weightKg)
        }
        return String(format: "%.1f lbs", profile.weightKg * 2.20462)
    }

    // Birthday formatting
    private var birthdayDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: profile.birthday)) (age \(profile.age))"
    }

    // Goal weight display
    private var goalWeightDisplay: String {
        guard let gw = profile.goalWeightKg else { return "Not set" }
        if useMetric {
            return String(format: "%.1f kg", gw)
        }
        return String(format: "%.1f lbs", gw * 2.20462)
    }

    // Weekly change display
    private var weeklyChangeDisplay: String {
        let rate = profile.weeklyChangeKg ?? 0.5
        if useMetric {
            return String(format: "%.2f kg/week", rate)
        }
        return String(format: "%.1f lbs/week", rate * 2.20462)
    }

    private var selectedThemeColor: AppThemeColor {
        AppThemeColor.color(for: appThemeColorRaw)
    }

    /// Shown in the Settings "Build" row. Reads the values stamped into Info.plist
    /// by the CI workflow before .ipa packaging, so each AltStore update bumps
    /// this string visibly.
    private var buildVersionString: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info["CFBundleVersion"] as? String ?? "0"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Personal Info
                Section("Personal Info") {
                    Picker(selection: profileBinding.gender) {
                        Text("Male").tag(Gender.male)
                        Text("Female").tag(Gender.female)
                        Text("Other").tag(Gender.other)
                    } label: {
                        Label {
                            Text("Gender")
                        } icon: {
                            Image(systemName: profile.gender.icon)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: profile.gender) { _, _ in resetCustomGoalsAndSave() }

                    ProfileInfoRow(icon: "birthday.cake", label: "Birthday", value: birthdayDisplay) {
                        activeSheet = .editBirthday
                    }

                    ProfileInfoRow(icon: "ruler", label: "Height", value: heightDisplay) {
                        activeSheet = .editHeight
                    }

                    ProfileInfoRow(icon: "scalemass", label: "Weight", value: weightDisplay) {
                        activeSheet = .editWeight
                    }

                    ProfileInfoRow(
                        icon: "percent",
                        label: "Body Fat",
                        value: profile.bodyFatPercentage != nil ? "\(Int(profile.bodyFatPercentage! * 100))%" : "Not set"
                    ) {
                        activeSheet = .editBodyFat
                    }

                    // Only surface the goal row to users who have a current
                    // body-fat value — feature was scoped to "skippable, no
                    // math impact, only visible if the user opted in to the
                    // body-fat track in onboarding (or set one later here)."
                    if profile.bodyFatPercentage != nil {
                        ProfileInfoRow(
                            icon: "target",
                            label: "Goal Body Fat",
                            value: profile.goalBodyFatPercentage != nil ? "\(Int(profile.goalBodyFatPercentage! * 100))%" : "Not set"
                        ) {
                            activeSheet = .editGoalBodyFat
                        }

                        // Toggle to disable Katch-McArdle without wiping the
                        // body-fat value — escape hatch for users whose
                        // reading is stale (weight shifted but they haven't
                        // re-measured). When off, BMR/TDEE/macros recompute
                        // from Mifflin-St Jeor (height/weight/age only).
                        Toggle(isOn: Binding(
                            get: { profile.useBodyFatInBMR ?? true },
                            set: { newValue in
                                profile.useBodyFatInBMR = newValue
                                resetCustomGoalsAndSave()
                            }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use Body Fat for BMR")
                                    Text("On = Katch-McArdle (uses lean mass for a more accurate BMR). Off = Mifflin-St Jeor (height/weight/age only). Turn off if your body-fat reading is outdated.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "function")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .tint(AppColors.calorie)
                    }
                }
                .listRowBackground(AppColors.appCard)

                // Section 2: Goals & Nutrition
                Section("Goals & Nutrition") {
                    Picker(selection: profileBinding.goal) {
                        ForEach(WeightGoal.allCases, id: \.self) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    } label: {
                        Label {
                            Text("Weight Goal")
                        } icon: {
                            Image(systemName: profile.goal.icon)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: profile.goal) { _, newValue in
                        if newValue == .maintain {
                            profile.weeklyChangeKg = nil
                            profile.goalWeightKg = nil
                        } else {
                            if profile.weeklyChangeKg == nil {
                                profile.weeklyChangeKg = 0.5
                            }
                            // Clear goal weight if it no longer matches the new direction
                            // (e.g., switching from Lose to Gain with an old target below current weight).
                            if let gw = profile.goalWeightKg {
                                let losingPastTarget = newValue == WeightGoal.lose && gw >= profile.weightKg
                                let gainingPastTarget = newValue == WeightGoal.gain && gw <= profile.weightKg
                                if losingPastTarget || gainingPastTarget {
                                    profile.goalWeightKg = nil
                                }
                            }
                        }
                        resetCustomGoalsAndSave()
                    }

                    Picker(selection: profileBinding.activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    } label: {
                        Label {
                            Text("Activity Level")
                        } icon: {
                            Image(systemName: profile.activityLevel.icon)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: profile.activityLevel) { _, _ in resetCustomGoalsAndSave() }

                    if profile.goal != .maintain {
                        Picker(selection: Binding(
                            get: { profile.weeklyChangeKg ?? 0.5 },
                            set: { profile.weeklyChangeKg = $0; resetCustomGoalsAndSave() }
                        )) {
                            Text("Slow (0.25 kg/wk)").tag(0.25)
                            Text("Moderate (0.5 kg/wk)").tag(0.5)
                            Text("Fast (1.0 kg/wk)").tag(1.0)
                        } label: {
                            Label {
                                Text("Weekly Change")
                            } icon: {
                                Image(systemName: "gauge.with.dots.needle.33percent")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)

                        ProfileInfoRow(
                            icon: "flag.checkered",
                            label: "Goal Weight",
                            value: goalWeightDisplay
                        ) {
                            activeSheet = .editGoalWeight
                        }
                    }

                    ProfileInfoRow(icon: "flame", label: "Calories", value: "\(profile.effectiveCalories) kcal") {
                        activeSheet = .editCalories
                    }

                    macroRow(label: "Protein", icon: "p.circle", macro: .protein, value: profile.effectiveProtein, sheet: .editProtein)
                    macroRow(label: "Carbs", icon: "c.circle", macro: .carbs, value: profile.effectiveCarbs, sheet: .editCarbs)
                    macroRow(label: "Fat", icon: "f.circle", macro: .fat, value: profile.effectiveFat, sheet: .editFat)

                    NavigationLink {
                        OptionalNutrientGoalsSettingsView(profile: profile, useMetric: useMetric)
                    } label: {
                        Label {
                            HStack {
                                Text("Other Nutrients")
                                Spacer()
                                Text("Sugar, Fiber, Sodium")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    Button {
                        showRecalculateConfirm = true
                    } label: {
                        Label {
                            Text("Recalculate Goals")
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    Button {
                        showCalculationMethods = true
                    } label: {
                        Label {
                            Text("Calculation Methods")
                        } icon: {
                            Image(systemName: "book")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    Button {
                        showEngineDebug = true
                    } label: {
                        Label {
                            Text("Engine (debug)")
                        } icon: {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    Button {
                        showTDEEExplainer = true
                    } label: {
                        Label {
                            Text("Energy balance")
                        } icon: {
                            Image(systemName: "function")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    Picker(selection: Binding(
                        get: { engineState.programMode },
                        set: { engineState.programMode = $0 }
                    )) {
                        Text("Coached").tag(ProgramMode.coached)
                        Text("Collaborative").tag(ProgramMode.collaborative)
                        Text("Manual").tag(ProgramMode.manual)
                    } label: {
                        Label {
                            Text("Coaching mode")
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)

                    Button {
                        showManualCheckIn = true
                    } label: {
                        Label {
                            Text("Run check-in now")
                        } icon: {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)
                }
                .listRowBackground(AppColors.appCard)

                Section("Body") {
                    NavigationLink {
                        BodyMeasurementsView()
                    } label: {
                        Label {
                            Text("Body measurements")
                        } icon: {
                            Image(systemName: "ruler")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    NavigationLink {
                        PeriodTrackingView()
                    } label: {
                        Label {
                            Text("Period tracking")
                        } icon: {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    NavigationLink {
                        ProgressPhotosView()
                    } label: {
                        Label {
                            Text("Progress photos")
                        } icon: {
                            Image(systemName: "photo.stack")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    NavigationLink {
                        RecipesView()
                    } label: {
                        Label {
                            Text("Recipes")
                        } icon: {
                            Image(systemName: "book.closed")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    NavigationLink {
                        FoodDatabaseView()
                    } label: {
                        Label {
                            Text("Food database")
                        } icon: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                }
                .listRowBackground(AppColors.appCard)

                Section("Data") {
                    Button {
                        showCSVImporter = true
                    } label: {
                        Label {
                            Text("Import from MacroFactor (CSV)")
                        } icon: {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)
                }
                .listRowBackground(AppColors.appCard)

                // Section 3: App Settings
                Section("App Settings") {
                    Picker(selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    } label: {
                        Label {
                            Text("Appearance")
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)

                    NavigationLink {
                        ThemeColorSettingsView(selectedColorRaw: $appThemeColorRaw)
                    } label: {
                        Label {
                            HStack {
                                Text("Theme Color")
                                Spacer()
                                HStack(spacing: 8) {
                                    ThemeColorSwatch(themeColor: selectedThemeColor, size: 22)
                                    Text(selectedThemeColor.displayName)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    Toggle(isOn: $useMetric) {
                        Label {
                            Text("Metric Units")
                        } icon: {
                            Image(systemName: "ruler")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(AppColors.calorie)

                    Picker(selection: $weekStartsOnMonday) {
                        Text("Sunday").tag(false)
                        Text("Monday").tag(true)
                    } label: {
                        Label {
                            Text("Week Starts On")
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label {
                            Text("Notifications")
                        } icon: {
                            Image(systemName: "bell")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    Button {
                        showFreeSigningStatus = true
                    } label: {
                        Label {
                            Text("Free Signing")
                        } icon: {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)
                }
                .listRowBackground(AppColors.appCard)

                // Section 4: AI. Bulk AI is Gemini-only — users supply a free key
                // from aistudio.google.com/apikey. Stored in iOS Keychain.
                Section("AI") {
                    if selectedProvider.supportsCustomModelName {
                        // Free-form TextField for any model ID, with optional preset suggestions menu
                        // (e.g., OpenRouter has presets but lets user type any of openrouter.ai/models).
                        HStack {
                            Label {
                                Text("Model")
                            } icon: {
                                Image(systemName: "brain")
                                    .foregroundStyle(AppColors.calorie)
                            }
                            Spacer()
                            TextField(
                                selectedProvider == .openrouter
                                    ? "e.g. anthropic/claude-sonnet-4"
                                    : "e.g. gpt-4o-mini",
                                text: $selectedModel
                            )
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: selectedModel) { _, newModel in
                                    AIProviderSettings.selectedModel = newModel
                                }
                            if !selectedProvider.models.isEmpty {
                                Menu {
                                    ForEach(selectedProvider.models, id: \.self) { model in
                                        Button(model) {
                                            selectedModel = model
                                            AIProviderSettings.selectedModel = model
                                        }
                                    }
                                } label: {
                                    Image(systemName: "list.bullet.circle")
                                        .foregroundStyle(AppColors.calorie)
                                }
                            }
                        }
                    } else {
                        Picker(selection: $selectedModel) {
                            ForEach(selectedProvider.models, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        } label: {
                            Label {
                                Text("Model")
                            } icon: {
                                Image(systemName: "brain")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .onAppear {
                            if !selectedProvider.models.contains(selectedModel) {
                                selectedModel = selectedProvider.defaultModel
                                AIProviderSettings.selectedModel = selectedModel
                            }
                        }
                        .onChange(of: selectedModel) { _, newModel in
                            AIProviderSettings.selectedModel = newModel
                        }
                    }

                    if selectedProvider.requiresAPIKey {
                        HStack {
                            Label {
                                Text("API Key")
                            } icon: {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(AppColors.calorie)
                            }
                            Spacer()
                            Group {
                                if showAPIKey {
                                    TextField(selectedProvider.apiKeyPlaceholder, text: $apiKeyText)
                                } else {
                                    SecureField(selectedProvider.apiKeyPlaceholder, text: $apiKeyText)
                                }
                            }
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: apiKeyText) { _, newValue in
                                AIProviderSettings.setAPIKey(newValue.isEmpty ? nil : newValue, for: selectedProvider)
                            }
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.fill" : "eye.slash.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if selectedProvider == .ollama || selectedProvider.requiresCustomEndpoint {
                        HStack {
                            Label {
                                Text(selectedProvider.requiresCustomEndpoint ? "Base URL" : "Server URL")
                            } icon: {
                                Image(systemName: "link")
                                    .foregroundStyle(AppColors.calorie)
                            }
                            Spacer()
                            TextField(
                                selectedProvider.requiresCustomEndpoint
                                    ? "https://your-endpoint.com/v1"
                                    : selectedProvider.baseURL,
                                text: $customBaseURL
                            )
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .onChange(of: customBaseURL) { _, newValue in
                                    AIProviderSettings.setCustomBaseURL(newValue.isEmpty ? nil : newValue, for: selectedProvider)
                                }
                        }
                    }
                }
                .listRowBackground(AppColors.appCard)

                // Custom AI Instructions (User Context) — prepended to every AI request when non-empty
                Section {
                    TextField(
                        "I live in Germany, assume European portion sizes. I'm on a bodybuilding cut.",
                        text: $customAIInstructions,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .autocorrectionDisabled(false)
                    .focused($customInstructionsFocused)

                    Button {
                        AIProviderSettings.userContext = customAIInstructions
                        let canonical = AIProviderSettings.userContext
                        customAIInstructions = canonical
                        savedAIInstructions = canonical
                        customInstructionsFocused = false
                    } label: {
                        HStack {
                            Spacer()
                            Label("Save", systemImage: "checkmark.circle.fill")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(customAIInstructions == savedAIInstructions ? .secondary : AppColors.calorie)
                            Spacer()
                        }
                    }
                    .disabled(customAIInstructions == savedAIInstructions)
                } header: {
                    Text("Custom AI Instructions")
                } footer: {
                    Text("Optional context sent with every AI request — region, diet, athletic goals, anything you'd otherwise repeat each time. Leave empty to disable.")
                }
                .listRowBackground(AppColors.appCard)


                    // Speech-to-Text Provider — Bulk AI only exposes the free options.
                    Section {
                    Picker(selection: $selectedSpeechProvider) {
                        ForEach([SpeechProvider.nativeIOS, .gemini], id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    } label: {
                        Label {
                            Text("Provider")
                        } icon: {
                            Image(systemName: selectedSpeechProvider.icon)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: selectedSpeechProvider) { _, newProvider in
                        SpeechSettings.selectedProvider = newProvider
                        speechApiKeyText = SpeechSettings.apiKey(for: newProvider) ?? ""
                        selectedSpeechLanguage = SpeechSettings.selectedLanguage(for: newProvider)
                    }

                    Text(selectedSpeechProvider.description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker(selection: $selectedSpeechLanguage) {
                        ForEach(SpeechLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    } label: {
                        Label {
                            Text("Language")
                        } icon: {
                            Image(systemName: "globe")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: selectedSpeechLanguage) { _, newLanguage in
                        SpeechSettings.setLanguage(newLanguage, for: selectedSpeechProvider)
                    }

                    if selectedSpeechProvider.requiresAPIKey {
                        HStack {
                            Label {
                                Text("API Key")
                            } icon: {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(AppColors.calorie)
                            }
                            Spacer()
                            Group {
                                if showSpeechAPIKey {
                                    TextField(selectedSpeechProvider.apiKeyPlaceholder, text: $speechApiKeyText)
                                } else {
                                    SecureField(selectedSpeechProvider.apiKeyPlaceholder, text: $speechApiKeyText)
                                }
                            }
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: speechApiKeyText) { _, newValue in
                                SpeechSettings.setAPIKey(newValue.isEmpty ? nil : newValue, for: selectedSpeechProvider)
                            }
                            Button {
                                showSpeechAPIKey.toggle()
                            } label: {
                                Image(systemName: showSpeechAPIKey ? "eye.fill" : "eye.slash.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Speech-to-Text")
                } footer: {
                    Text("Used when you tap the voice icon to log a meal. Each provider remembers its own language. Provider Auto keeps the provider default; Use iPhone Language sends your current iPhone language when supported.")
                }
                    .listRowBackground(AppColors.appCard)

                // Section 5: Health & Data
                Section("Health & Data") {
                    // Apple Health
                    HStack {
                        Label {
                            Text("Apple Health")
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                        }
                        Spacer()
                        Toggle("", isOn: $healthKitEnabled)
                            .labelsHidden()
                            .onChange(of: healthKitEnabled) { _, enabled in
                                handleHealthKitToggle(enabled)
                            }
                    }

                    // Clear Food Log
                    Button(role: .destructive) {
                        showClearFoodLogConfirmation = true
                    } label: {
                        Label {
                            Text("Clear Food Log")
                        } icon: {
                            Image(systemName: "fork.knife")
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)

                    // Delete All Data — always visible
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label {
                            Text("Delete All Data")
                        } icon: {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppColors.appCard)

                // Build info — version + run number get stamped by the CI
                // workflow before .ipa packaging. Bumps on every push to main.
                Section {
                    HStack {
                        Label {
                            Text("Build")
                        } icon: {
                            Image(systemName: "hammer")
                                .foregroundStyle(AppColors.calorie)
                        }
                        Spacer()
                        Text(buildVersionString)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .listRowBackground(AppColors.appCard)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .navigationBarHidden(true)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .editBirthday:
                    NavigationStack {
                        VStack(spacing: 20) {
                            Text("Birthday")
                                .font(.system(.title2, design: .rounded, weight: .bold))

                            DatePicker(
                                "Birthday",
                                selection: profileBinding.birthday,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()

                            Button {
                                saveProfile()
                                activeSheet = nil
                            } label: {
                                Text("Save")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(colors: AppColors.calorieGradient, startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 24)

                            Spacer()
                        }
                        .padding(.top, 24)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { activeSheet = nil }
                            }
                        }
                    }
                    .presentationDetents([.medium])

                case .editHeight:
                    HeightPickerSheet(
                        useMetric: useMetric,
                        currentHeightCm: profile.heightCm
                    ) { newHeight in
                        profile.heightCm = newHeight
                        resetCustomGoalsAndSave()
                    }

                case .editWeight:
                    WeightPickerSheet(
                        useMetric: useMetric,
                        currentWeightKg: profile.weightKg
                    ) { newWeight in
                        profile.weightKg = newWeight
                        // Invalidate goal weight if the new current weight makes the direction impossible.
                        if let gw = profile.goalWeightKg {
                            let mismatch = (profile.goal == .lose && gw >= newWeight)
                                        || (profile.goal == .gain && gw <= newWeight)
                            if mismatch { profile.goalWeightKg = nil }
                        }
                        resetCustomGoalsAndSave()
                        weightStore.addEntry(WeightEntry(weightKg: newWeight))
                    }

                case .editBodyFat:
                    BodyFatPickerSheet(
                        currentPercentage: profile.bodyFatPercentage
                    ) { newValue in
                        profile.bodyFatPercentage = newValue
                        // Goal body fat only makes sense alongside a current
                        // value — clear it whenever the current is cleared so
                        // a stale goal doesn't linger on a user who's opted out.
                        if newValue == nil { profile.goalBodyFatPercentage = nil }
                        resetCustomGoalsAndSave()
                    }

                case .editGoalBodyFat:
                    // Goal body fat is purely cosmetic — does NOT participate
                    // in BMR / TDEE / macro math. Use a plain saveProfile()
                    // path (not resetCustomGoalsAndSave) so editing the goal
                    // never silently wipes a user's pinned macros.
                    GoalBodyFatPickerSheet(
                        currentGoal: profile.goalBodyFatPercentage,
                        currentBodyFat: profile.bodyFatPercentage
                    ) { newValue in
                        profile.goalBodyFatPercentage = newValue
                        saveProfile()
                    }

                case .editGoalWeight:
                    WeightPickerSheet(
                        useMetric: useMetric,
                        currentWeightKg: profile.goalWeightKg ?? profile.weightKg
                    ) { newGoalWeight in
                        // Validate against current goal direction.
                        let invalid = (profile.goal == .lose && newGoalWeight >= profile.weightKg)
                                   || (profile.goal == .gain && newGoalWeight <= profile.weightKg)
                        if invalid {
                            invalidGoalWeightMessage = profile.goal == .lose
                                ? "A Lose goal needs a target below your current weight."
                                : "A Gain goal needs a target above your current weight."
                            showInvalidGoalWeightAlert = true
                            return
                        }
                        profile.goalWeightKg = newGoalWeight
                        saveProfile()
                    }

                case .editCalories:
                    NutritionPickerSheet(label: "Calories", unit: "kcal", currentValue: profile.effectiveCalories, range: 800...6000, step: 50) { value in
                        profile.customCalories = value
                        saveProfile()
                    }

                case .editProtein:
                    NutritionPickerSheet(
                        label: "Protein", unit: "g",
                        currentValue: profile.effectiveProtein,
                        range: 10...500, step: 5,
                        onSave: { setMacro(.protein, to: $0) },
                        onResetToAuto: profile.isPinned(.protein) ? { setMacro(.protein, to: nil) } : nil
                    )

                case .editCarbs:
                    NutritionPickerSheet(
                        label: "Carbs", unit: "g",
                        currentValue: profile.effectiveCarbs,
                        range: 0...800, step: 5,
                        onSave: { setMacro(.carbs, to: $0) },
                        onResetToAuto: profile.isPinned(.carbs) ? { setMacro(.carbs, to: nil) } : nil
                    )

                case .editFat:
                    NutritionPickerSheet(
                        label: "Fat", unit: "g",
                        currentValue: profile.effectiveFat,
                        range: 10...300, step: 5,
                        onSave: { setMacro(.fat, to: $0) },
                        onResetToAuto: profile.isPinned(.fat) ? { setMacro(.fat, to: nil) } : nil
                    )

                }
            }
            .alert("Clear Food Log", isPresented: $showClearFoodLogConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All Logs", role: .destructive) {
                    foodStore.replaceAllEntries([])
                }
            } message: {
                Text("This will permanently delete all your logged food entries. Your profile, weight entries, and favorites will be kept. This action cannot be undone.")
            }
            .alert("Recalculate Goals", isPresented: $showRecalculateConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Recalculate") { recalculateGoalsNow() }
            } message: {
                Text("Recompute calories, protein, carbs, and fat from your current weight, activity, and goal? Your custom values will be replaced and Auto-balance will reset to Carbs.")
            }
            .sheet(isPresented: $showCalculationMethods) {
                CalculationMethodsView()
            }
            .sheet(isPresented: $showEngineDebug) {
                NavigationStack {
                    EngineDebugView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showEngineDebug = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showManualCheckIn) {
                CheckInReviewView()
            }
            .sheet(isPresented: $showTDEEExplainer) {
                DynamicTDEEExplainer()
            }
            .sheet(isPresented: $showFreeSigningStatus) {
                FreeSigningStatusView()
            }
            .fileImporter(
                isPresented: $showCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .data]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let entries = try MacroFactorCSVImporter.parse(url: url)
                        pendingImport = entries
                        showImportConfirm = true
                    } catch {
                        importErrorMessage = error.localizedDescription
                        showImportError = true
                    }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                    showImportError = true
                }
            }
            .alert("Import \(pendingImport.count) entries?", isPresented: $showImportConfirm) {
                Button("Import") {
                    let count = pendingImport.count
                    foodStore.addEntries(pendingImport)
                    pendingImport = []
                    importSuccessCount = count
                    showImportSuccess = true
                }
                Button("Cancel", role: .cancel) {
                    pendingImport = []
                }
            } message: {
                Text("This adds \(pendingImport.count) food log entries from your MacroFactor CSV. Existing entries are not touched and duplicates aren't detected — only import once.")
            }
            .alert("Imported \(importSuccessCount ?? 0) entries", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your MacroFactor history is now in Bulk AI's food log. The engine will start factoring it in on the next refresh.")
            }
            .alert("Import failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "Unknown error.")
            }
            .alert("Auto-balanced", isPresented: $showAutoMacroEditAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This macro is auto-balanced from the others. Tap the lock icon to pin it, then tap the row to set a custom value.")
            }
            .alert("Max 2 Pinned", isPresented: $showMaxPinnedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("At most 2 macros can be pinned at a time. Unpin another macro first (tap its lock icon).")
            }
            .alert("Invalid Goal Weight", isPresented: $showInvalidGoalWeightAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(invalidGoalWeightMessage)
            }
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    // Delete All Data is local-only. We intentionally do NOT touch Apple
                    // Health samples — that data is personal and belongs to the user, not
                    // this app's storage. If they want HK cleaned up they can do it from
                    // the Health app's Sources → Bulk AI screen.
                    foodStore.replaceAllEntries([])
                    weightStore.replaceAllEntries([])
                    // Wipe the food-image folder defensively — replaceAllEntries
                    // already cleans per-entry files, but a belt-and-braces
                    // deleteAll catches any orphans from earlier crash recovery.
                    FoodImageStore.shared.deleteAll()
                    // Cancel all notifications
                    notificationManager.cancelAllNotifications()
                    // Wipe all persisted data
                    let domain = Bundle.main.bundleIdentifier ?? ""
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    // Wipe Keychain API keys
                    AIProviderSettings.deleteAllData()
                    SpeechSettings.deleteAllData()
                    AIAccessSettings.resetForDeleteAllData()
                    chatStore.reset()
                    // Wipe the widget snapshot out of the App Group container —
                    // it lives outside UserDefaults.standard and would otherwise
                    // keep showing the previous profile's numbers on the widget.
                    WidgetSnapshot.clear()
                    WidgetCenter.shared.reloadAllTimelines()
                    hasCompletedOnboarding = false
                }
            } message: {
                Text("This will permanently delete all your data including food logs, weight entries, and profile. This action cannot be undone.")
            }
        }
    }

    private func saveProfile() {
        profileStore.save(profile)
    }

    /// Clear all custom goal overrides so calories + macros recompute from the current
    /// weight / activity / goal formulas. Triggered automatically when those underlying
    /// inputs change (gender, activity, weight, etc.) and via the Recalculate button.
    private func resetCustomGoalsAndSave() {
        profile.recalculateGoalsFromFormulas()
        saveProfile()
    }

    /// Macro row. Tap to open the picker (which lets the user enter a value to pin, or reset to auto).
    /// "(auto)" suffix when the macro is unpinned. Lock icon shows current pin state.
    @ViewBuilder
    private func macroRow(label: String, icon: String, macro: AutoBalanceMacro, value: Int, sheet: ActiveSheet) -> some View {
        let pinned = profile.isPinned(macro)
        Button {
            // Enforce max-2 only at the moment of trying to pin a NEW macro.
            // Opening the picker on an already-pinned macro is fine; opening on an auto macro
            // is also fine since user might just want to view + tap "Reset to Auto" to no-op.
            if !pinned && profile.pinnedCount >= 2 {
                showMaxPinnedAlert = true
            } else {
                activeSheet = sheet
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.calorie)
                    .frame(width: 22)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Text(pinned ? "\(value)g" : "\(value)g · auto")
                    .foregroundStyle(.secondary)
                Image(systemName: pinned ? "lock.fill" : "lock.open")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(pinned ? AppColors.calorie : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func setMacro(_ macro: AutoBalanceMacro, to value: Int?) {
        switch macro {
        case .protein: profile.customProtein = value
        case .carbs:   profile.customCarbs   = value
        case .fat:     profile.customFat     = value
        }
        saveProfile()
    }

    private func recalculateGoalsNow() {
        profile.recalculateGoalsFromFormulas()
        saveProfile()
    }

    private func handleHealthKitToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let authorized = await healthKitManager.requestAuthorization()
                if authorized {
                    healthKitManager.writeWeight(kg: profile.weightKg, date: .now)
                    healthKitManager.writeHeight(cm: profile.heightCm)
                    if let bf = profile.bodyFatPercentage {
                        healthKitManager.writeBodyFat(fraction: bf)
                    }
                    let measurements = await healthKitManager.fetchLatestBodyMeasurements()
                    if let kg = measurements.weight, abs(profile.weightKg - kg) > 0.01 {
                        profile.weightKg = kg
                    }
                    if let cm = measurements.height, abs(profile.heightCm - cm) > 0.1 {
                        profile.heightCm = cm
                    }
                    if let bf = measurements.bodyFat {
                        profile.bodyFatPercentage = bf
                    }
                    if let dob = measurements.dob {
                        profile.birthday = dob
                    }
                    if let sex = measurements.sex {
                        switch sex {
                        case .male: profile.gender = .male
                        case .female: profile.gender = .female
                        default: break
                        }
                    }
                    saveProfile()
                    healthKitManager.startBodyMeasurementObserver()
                    healthKitManager.backfillNutritionIfNeeded(
                        entries: foodStore.entries,
                        currentEntryIDs: { Set(foodStore.entries.map(\.id)) }
                    )
                } else {
                    healthKitEnabled = false
                }
            }
        } else {
            healthKitManager.stopObserver()
        }
    }
}

private struct ThemeColorSettingsView: View {
    @Binding var selectedColorRaw: String

    private var selectedColor: AppThemeColor {
        AppThemeColor.color(for: selectedColorRaw)
    }

    var body: some View {
        List {
            Section {
                ForEach(AppThemeColor.allCases) { themeColor in
                    Button {
                        selectedColorRaw = themeColor.rawValue
                    } label: {
                        HStack(spacing: 14) {
                            ThemeColorSwatch(themeColor: themeColor, size: 30)
                            Text(themeColor.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedColor == themeColor {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                    }
                    .tint(.primary)
                }
            } footer: {
                Text("Changes the main app color and home screen icon used for tabs, buttons, icons, charts, and progress rings.")
            }
            .listRowBackground(AppColors.appCard)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.appBackground)
        .navigationTitle("Theme Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemeColorSwatch: View {
    let themeColor: AppThemeColor
    var size: CGFloat = 24

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: themeColor.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: themeColor.color.opacity(0.28), radius: 4, y: 2)
    }
}

// MARK: - AI Consent Sheet (Apple Guideline 5.1.1(i) + 5.1.2(i))
/// Disclosed-and-explicit consent before any user data is sent to a third-party
/// AI provider. Apple App Review (April 2026) rejected v3.2 (5) for not having
/// in-app consent — privacy policy alone is not sufficient. The sheet names the
/// currently selected provider, lists what data gets sent, and requires an
/// explicit Allow tap before any food analysis call can fire.
struct AIConsentSheetView: View {
    let onAllow: () -> Void
    let onCancel: () -> Void

    private var providerName: String {
        AIAccessSettings.isUsingFudAIPlus ? "Bulk AI Plus (Google Gemini)" : AIProviderSettings.selectedProvider.rawValue
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 88, height: 88)
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(colors: AppColors.calorieGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                    .padding(.top, 28)

                    VStack(spacing: 8) {
                        Text("AI Analysis Notice")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("Before Bulk AI sends data to a third-party AI provider, we need your permission.")
                            .font(.system(.callout, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        consentRow(icon: "photo.fill", title: "What is sent",
                                   text: "When you log a meal, the photo, voice transcript, or text description is sent to your selected AI provider. Profile data (age, weight, goals) is sent only for Coach chat.")
                        consentRow(icon: "network", title: "Who receives it",
                                   text: "Your current AI access: \(providerName). You can change this anytime in Settings → AI Access. BYOK requests go directly to your provider; Plus requests go through Bulk AI's Gemini proxy.")
                        consentRow(icon: "lock.shield.fill", title: "What stays local",
                                   text: AIAccessSettings.isUsingFudAIPlus ? "Your saved food log, weight history, and body fat history stay on this device. Only the active AI request is sent for processing." : "Your API key, weight history, body fat history, and food log all stay on this device. Requests go directly from your device to the provider.")
                    }
                    .padding(.horizontal, 20)

                    Text("Tap Allow to enable AI food analysis. Manual entry is always available without sending data anywhere. You can revoke consent later by deleting the app or via Settings → Delete All Data.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    Link("View privacy policy", destination: URL(string: "https://fud-ai.app/privacy.html")!)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(AppColors.calorie)
                }
                .padding(.bottom, 24)
            }

            VStack(spacing: 10) {
                Button(action: onAllow) {
                    Text("Allow")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(colors: AppColors.calorieGradient, startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                Button(action: onCancel) {
                    Text("Not Now")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(.ultraThinMaterial)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private func consentRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.calorie)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(text)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(FoodStore())
        .environment(WeightStore())
}
