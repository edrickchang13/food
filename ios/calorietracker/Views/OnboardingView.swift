import SwiftUI
import HealthKit
import StoreKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(FoodStore.self) private var foodStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(StoreManager.self) private var storeManager

    @State private var step = 0
    @State private var selectedAccessMode: AIAccessMode = .fudAIPlus
    @State private var showPaywall = false
    @State private var shouldAdvanceAfterPlusPurchase = false
    @State private var gender: Gender = .male
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @AppStorage("useMetric") private var useMetric = false
    @State private var isMetric = false
    @State private var heightFeet = 5
    @State private var heightInches = 9
    @State private var heightCm = 175
    // Weights are split into whole + tenth so the SwiftUI wheel picker can stay
    // Int-tagged (fractional tags don't pair cleanly with Picker) while users
    // still get 0.1-precision selection. Combine via `Double(whole) + Double(tenth) / 10.0`.
    @State private var weightLbsWhole = 154
    @State private var weightLbsTenth = 0
    @State private var weightKgWhole = 70
    @State private var weightKgTenth = 0
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var goal: WeightGoal = .maintain
    @State private var targetWeightLbsWhole = 154
    @State private var targetWeightLbsTenth = 0
    @State private var targetWeightKgWhole = 70
    @State private var targetWeightKgTenth = 0
    @State private var goalSpeed = 1
    @State private var knowsBodyFat = false
    @State private var bodyFatPercentage = 20
    /// Optional target body-fat % (whole number, 3–60). Nil means "skip" — the
    /// user opted out, or hasn't entered a current body fat (the goal field
    /// only appears when knowsBodyFat is true).
    @State private var goalBodyFatPercentInt: Int? = nil
    @State private var editedCalories: Int?
    @State private var editedProtein: Int?
    @State private var editedFat: Int?
    @State private var editedCarbs: Int?
    @State private var editingField: EditableField?
    @State private var showCalculationSources = false

    private enum EditableField: String, Identifiable {
        case calories, protein, fat, carbs
        var id: String { rawValue }
    }

    private let totalSteps = 15 // 0-14

    /// Combine the whole + tenth wheel selections into a single Double.
    private func combine(_ whole: Int, _ tenth: Int) -> Double { Double(whole) + Double(tenth) / 10.0 }

    private var weightKg: Double { combine(weightKgWhole, weightKgTenth) }
    private var weightLbs: Double { combine(weightLbsWhole, weightLbsTenth) }
    private var targetWeightKg: Double { combine(targetWeightKgWhole, targetWeightKgTenth) }
    private var targetWeightLbs: Double { combine(targetWeightLbsWhole, targetWeightLbsTenth) }

    private var profile: UserProfile {
        let cm: Double
        let kg: Double
        if isMetric {
            cm = Double(heightCm)
            kg = weightKg
        } else {
            cm = Double(heightFeet) * 30.48 + Double(heightInches) * 2.54
            kg = weightLbs * 0.453592
        }
        let targetKg: Double? = goal == .maintain ? nil : (isMetric ? targetWeightKg : targetWeightLbs * 0.453592)
        return UserProfile(
            gender: gender,
            birthday: birthday,
            heightCm: cm,
            weightKg: kg,
            activityLevel: activityLevel,
            goal: goal,
            bodyFatPercentage: knowsBodyFat ? Double(bodyFatPercentage) / 100.0 : nil,
            goalBodyFatPercentage: knowsBodyFat ? goalBodyFatPercentInt.map { Double($0) / 100.0 } : nil,
            weeklyChangeKg: goal == .maintain ? nil : weeklyChangeKg,
            goalWeightKg: targetKg
        )
    }

    var body: some View {
        VStack(spacing: 0) {
                if step > 0 && step < totalSteps - 1 {
                    HStack(spacing: BulkAITheme.Spacing.md) {
                        Button {
                            withAnimation(.snappy) { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(BulkAITheme.Typography.headline)
                                .foregroundStyle(.primary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(Color.primary)
                                    .frame(width: geo.size.width * CGFloat(step) / CGFloat(totalSteps - 1))
                                    .animation(.snappy, value: step)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, BulkAITheme.Spacing.xl)
                    .padding(.top, BulkAITheme.Spacing.sm)
                    .padding(.bottom, BulkAITheme.Spacing.xs)
                }

                ZStack {
                    switch step {
                    case 0: welcomeStep
                    case 1: genderStep
                    case 2: birthdayStep
                    case 3: heightWeightStep
                    case 4: bodyFatStep
                    case 5: activityStep
                    case 6: goalStep
                    case 7: desiredWeightStep
                    case 8: aiProviderStep
                    case 9: goalSpeedStep
                    case 10: notificationsStep
                    case 11: appleHealthStep
                    case 12: buildingPlanStep
                    case 13: planReadyStep
                    case 14: reviewStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.snappy, value: step)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView {
                    advanceAfterPlusPurchaseIfNeeded()
                }
            }
            .onChange(of: storeManager.isSubscribed) { _, isSubscribed in
                if isSubscribed {
                    advanceAfterPlusPurchaseIfNeeded()
                }
            }
    }

    // MARK: - Continue Button

    private func continueButton(_ title: String = "Continue", action: @escaping () -> Void = {}) -> some View {
        Button {
            action()
            withAnimation(.snappy) { step += 1 }
        } label: {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.primary, in: Capsule())
        }
        .padding(.horizontal, BulkAITheme.Spacing.xl)
        .padding(.bottom, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xxs)
    }

    private func advanceAfterPlusPurchaseIfNeeded() {
        guard shouldAdvanceAfterPlusPurchase, step == 8 else { return }
        shouldAdvanceAfterPlusPurchase = false
        showPaywall = false
        AIAccessSettings.mode = .fudAIPlus
        withAnimation(.snappy) { step += 1 }
    }

    // MARK: - 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: BulkAITheme.Spacing.lg) {
                Image("onboardingLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                VStack(spacing: BulkAITheme.Spacing.xs) {
                    Text("Eat Smart,")
                        .font(BulkAITheme.Typography.title)
                    Text("Live Better")
                        .font(BulkAITheme.Typography.title)
                        .foregroundStyle(
                            LinearGradient(colors: [BulkAITheme.Color.accent], startPoint: .leading, endPoint: .trailing)
                        )
                }
                Text("Just snap, track, and thrive.\nYour nutrition, simplified.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()

            Button {
                withAnimation(.snappy) { step += 1 }
            } label: {
                Text("Get Started")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BulkAITheme.Spacing.md)
                    .background(
                        LinearGradient(colors: [BulkAITheme.Color.accent], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md))
            }
            .padding(.horizontal, BulkAITheme.Spacing.xl)
            .padding(.bottom, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xxs)
        }
    }

    // MARK: - 1: Gender

    private var genderStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What's your gender?", subtitle: "This helps us calculate your metabolism")
            Spacer()
            VStack(spacing: BulkAITheme.Spacing.sm) {
                ForEach(Gender.allCases, id: \.self) { g in
                    selectionCard(icon: g.icon, title: g.displayName, isSelected: gender == g) {
                        withAnimation(.spring(response: 0.3)) { gender = g }
                    }
                }
            }
            .padding(.horizontal, BulkAITheme.Spacing.xl)
            Spacer()
            continueButton()
        }
    }

    // MARK: - 2: Birthday

    private var birthdayStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "When's your birthday?", subtitle: "Used to calculate your daily needs")
            Spacer()
            DatePicker("Birthday", selection: $birthday, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, BulkAITheme.Spacing.xl)
            Spacer()
            continueButton()
        }
    }

    // MARK: - 3: Height & Weight

    private var heightWeightStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Height & Weight", subtitle: "We'll keep this private")
            Picker("Unit", selection: $isMetric) {
                Text("Imperial").tag(false)
                Text("Metric").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, BulkAITheme.Spacing.xl)
            .padding(.top, BulkAITheme.Spacing.md)
            .onChange(of: isMetric) { _, newValue in useMetric = newValue }
            Spacer()
            // Stack height + weight as two rows so the weight picker (whole +
            // "." + tenth + unit = 4 sub-cells) gets the full screen width
            // instead of competing with feet/inches for one-third of it. The
            // 3-column imperial layout used to render the lbs whole-number
            // wheel as "..." because there wasn't enough width for 3-digit
            // values like 152 alongside the decimal column.
            if isMetric {
                VStack(spacing: BulkAITheme.Spacing.xs) {
                    VStack(spacing: BulkAITheme.Spacing.xxs) {
                        Text("Height").font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
                        Picker("cm", selection: $heightCm) {
                            ForEach(100...250, id: \.self) { cm in Text("\(cm) cm").tag(cm) }
                        }.pickerStyle(.wheel).frame(height: 130)
                    }
                    VStack(spacing: BulkAITheme.Spacing.xxs) {
                        Text("Weight").font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
                        decimalWeightWheel(whole: $weightKgWhole, tenth: $weightKgTenth, range: 30...250, unit: "kg")
                            .frame(height: 130)
                    }
                }.padding(.horizontal, BulkAITheme.Spacing.xl)
            } else {
                VStack(spacing: BulkAITheme.Spacing.xs) {
                    HStack(spacing: BulkAITheme.Spacing.xs) {
                        VStack(spacing: BulkAITheme.Spacing.xxs) {
                            Text("Feet").font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
                            Picker("ft", selection: $heightFeet) {
                                ForEach(3...8, id: \.self) { ft in Text("\(ft) ft").tag(ft) }
                            }.pickerStyle(.wheel).frame(height: 130)
                        }
                        VStack(spacing: BulkAITheme.Spacing.xxs) {
                            Text("Inches").font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
                            Picker("in", selection: $heightInches) {
                                ForEach(0...11, id: \.self) { inch in Text("\(inch) in").tag(inch) }
                            }.pickerStyle(.wheel).frame(height: 130)
                        }
                    }
                    VStack(spacing: BulkAITheme.Spacing.xxs) {
                        Text("Weight").font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
                        decimalWeightWheel(whole: $weightLbsWhole, tenth: $weightLbsTenth, range: 60...500, unit: "lbs")
                            .frame(height: 130)
                    }
                }.padding(.horizontal, BulkAITheme.Spacing.xl)
            }
            Spacer()
            continueButton()
        }
    }

    // MARK: - 4: Body Fat

    private var bodyFatStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Do you know your\nbody fat %?", subtitle: "Helps us calculate your metabolism more accurately")
            Spacer()
            VStack(spacing: BulkAITheme.Spacing.sm) {
                selectionCard(icon: "checkmark.circle", title: "Yes", isSelected: knowsBodyFat) {
                    withAnimation(.spring(response: 0.3)) { knowsBodyFat = true }
                }
                selectionCard(icon: "xmark.circle", title: "No", isSelected: !knowsBodyFat) {
                    withAnimation(.spring(response: 0.3)) { knowsBodyFat = false }
                }
            }
            .padding(.horizontal, BulkAITheme.Spacing.xl)
            if knowsBodyFat {
                ScrollView {
                    VStack(spacing: BulkAITheme.Spacing.md) {
                        VStack(spacing: BulkAITheme.Spacing.xxs) {
                            Text("Current")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, BulkAITheme.Spacing.xl)
                            Picker("Body Fat %", selection: $bodyFatPercentage) {
                                ForEach(3...60, id: \.self) { pct in Text("\(pct)%").tag(pct) }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 130)
                            .padding(.horizontal, BulkAITheme.Spacing.xl)
                            Text("Common ranges: Men 10–25%, Women 18–35%")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }

                        // Optional goal sub-section. Skip is the default — keeping it
                        // off-by-default avoids surprising users who don't have a
                        // body-recomp goal in mind. Goal body fat % is display-only
                        // (drives the Progress tab chart line) — it does NOT
                        // participate in BMR / TDEE / macro math.
                        VStack(spacing: BulkAITheme.Spacing.xxs) {
                            HStack {
                                Text("Goal (optional)")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { goalBodyFatPercentInt != nil },
                                    set: { isOn in
                                        // Default the goal to the current value
                                        // when toggled on — gives the user a sane
                                        // starting point to scroll up/down from.
                                        goalBodyFatPercentInt = isOn ? bodyFatPercentage : nil
                                    }
                                ))
                                .labelsHidden()
                                .tint(BulkAITheme.Color.accent)
                            }
                            .padding(.horizontal, BulkAITheme.Spacing.xl)

                            if let _ = goalBodyFatPercentInt {
                                Picker("Goal Body Fat %", selection: Binding(
                                    get: { goalBodyFatPercentInt ?? bodyFatPercentage },
                                    set: { goalBodyFatPercentInt = $0 }
                                )) {
                                    ForEach(3...60, id: \.self) { pct in Text("\(pct)%").tag(pct) }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 110)
                                .padding(.horizontal, BulkAITheme.Spacing.xl)
                            } else {
                                Text("You can set this later in Settings.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, BulkAITheme.Spacing.xl)
                                    .padding(.top, BulkAITheme.Spacing.xxs)
                            }
                        }
                    }
                    .padding(.vertical, BulkAITheme.Spacing.xs)
                }
            } else {
                VStack(spacing: BulkAITheme.Spacing.xs) {
                    Image(systemName: "function")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No worries! We'll use a standard formula\nbased on your height, weight, and age.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, BulkAITheme.Spacing.xl)
                .frame(maxWidth: .infinity)
            }
            Spacer()
            continueButton()
        }
    }

    // MARK: - 5: Activity Level

    private var activityStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "How active are you?", subtitle: "Your typical week")
            ScrollView {
                VStack(spacing: BulkAITheme.Spacing.sm) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        selectionCard(icon: level.icon, title: level.displayName, subtitle: level.subtitle, isSelected: activityLevel == level) {
                            withAnimation(.spring(response: 0.3)) { activityLevel = level }
                        }
                    }
                }
                .padding(.horizontal, BulkAITheme.Spacing.xl)
                .padding(.vertical, BulkAITheme.Spacing.md)
            }
            continueButton()
        }
    }

    // MARK: - 6: Goal

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What's your goal?", subtitle: "You can change this anytime")
            Spacer()
            VStack(spacing: BulkAITheme.Spacing.sm) {
                ForEach(WeightGoal.allCases, id: \.self) { g in
                    selectionCard(icon: g.icon, title: g.displayName, isSelected: goal == g) {
                        withAnimation(.spring(response: 0.3)) { goal = g }
                    }
                }
            }
            .padding(.horizontal, BulkAITheme.Spacing.xl)
            Spacer()
            continueButton {
                // Seed the desired-weight wheels from the current weight + a
                // direction-appropriate offset. Whole-number offsets (5/10) are
                // fine — the user can fine-tune the tenth wheel in the next step.
                let lbsDelta = goal == .lose ? -10 : (goal == .gain ? 10 : 0)
                let kgDelta  = goal == .lose ? -5  : (goal == .gain ? 5  : 0)
                let newLbsWhole = max(60, weightLbsWhole + lbsDelta)
                let newKgWhole  = max(30, weightKgWhole + kgDelta)
                targetWeightLbsWhole = newLbsWhole
                targetWeightLbsTenth = weightLbsTenth
                targetWeightKgWhole  = newKgWhole
                targetWeightKgTenth  = weightKgTenth
            }
        }
    }

    // MARK: - 7: Desired Weight

    private var weightUnit: String { isMetric ? "kg" : "lbs" }

    private var weightDiffKg: Double {
        let currentKg = isMetric ? weightKg : weightLbs * 0.453592
        let targetKg = isMetric ? targetWeightKg : targetWeightLbs * 0.453592
        return abs(targetKg - currentKg)
    }

    private var desiredWeightStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What's your\ndesired weight?", subtitle: goal.displayName)
            Spacer()
            if isMetric {
                decimalWeightWheel(whole: $targetWeightKgWhole, tenth: $targetWeightKgTenth, range: 30...250, unit: "kg")
                    .frame(height: 150).padding(.horizontal, BulkAITheme.Spacing.xl)
            } else {
                decimalWeightWheel(whole: $targetWeightLbsWhole, tenth: $targetWeightLbsTenth, range: 60...500, unit: "lbs")
                    .frame(height: 150).padding(.horizontal, BulkAITheme.Spacing.xl)
            }
            Spacer()
            continueButton()
        }
    }

    /// Reusable iOS-26-style two-wheel decimal picker for body weight (whole +
    /// tenth + unit suffix). Keeps the wheel selections Int-tagged — Picker
    /// doesn't pair cleanly with Double tags — and the parent computes the
    /// combined Double via `combine(_:_:)`.
    private func decimalWeightWheel(whole: Binding<Int>, tenth: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 0) {
            Picker("whole", selection: whole) {
                ForEach(range, id: \.self) { n in Text("\(n)").tag(n) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Text(".")
                .font(BulkAITheme.Typography.title3)
                .offset(y: -1)
                .foregroundStyle(.secondary)

            Picker("tenth", selection: tenth) {
                ForEach(0...9, id: \.self) { n in Text("\(n)").tag(n) }
            }
            .pickerStyle(.wheel)
            .frame(width: 56)
            .clipped()

            Text(unit)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - 8: Goal Speed

    private var weeklyChangeKg: Double {
        switch goalSpeed { case 0: 0.25; case 2: 1.0; default: 0.5 }
    }

    private var estimatedDays: Int {
        guard weightDiffKg > 0 else { return 0 }
        return Int(weightDiffKg / weeklyChangeKg * 7)
    }

    private var goalSpeedStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: goal == .maintain ? "Your pace" : "How fast do you want\nto reach your goal?",
                subtitle: goal == .maintain ? "We'll set a balanced plan" : "\(goal == .lose ? "Weight loss" : "Weight gain") speed per week"
            )
            if goal == .maintain {
                Spacer()
                VStack(spacing: BulkAITheme.Spacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48)).foregroundStyle(BulkAITheme.Color.macroProtein)
                    Text("Balanced pace set")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("We'll keep your calories steady\nto maintain your current weight.")
                        .font(.system(.callout, design: .rounded)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
                Spacer()
            } else {
                Spacer()
                VStack(spacing: BulkAITheme.Spacing.xl) {
                    VStack(spacing: BulkAITheme.Spacing.xxs) {
                        Text(String(format: "%.1f %@", weeklyChangeKg * (isMetric ? 1 : 2.205), weightUnit))
                            .font(BulkAITheme.Typography.display)
                            .contentTransition(.numericText()).animation(.snappy, value: goalSpeed)
                        Text("per week").font(.system(.callout, design: .rounded)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 0) {
                        VStack(spacing: BulkAITheme.Spacing.xxs + BulkAITheme.Spacing.xxs) {
                            Image(systemName: "tortoise.fill").font(.system(size: 24))
                                .foregroundStyle(goalSpeed == 0 ? BulkAITheme.Color.accent : Color.secondary.opacity(0.4))
                            Text("Slow").font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(goalSpeed == 0 ? BulkAITheme.Color.accent : .secondary)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: BulkAITheme.Spacing.xxs + BulkAITheme.Spacing.xxs) {
                            Image(systemName: "hare.fill").font(.system(size: 24))
                                .foregroundStyle(goalSpeed == 1 ? BulkAITheme.Color.accent : Color.secondary.opacity(0.4))
                            Text("Recommended").font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(goalSpeed == 1 ? BulkAITheme.Color.accent : .secondary)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: BulkAITheme.Spacing.xxs + BulkAITheme.Spacing.xxs) {
                            Image(systemName: "bolt.fill").font(.system(size: 24))
                                .foregroundStyle(goalSpeed == 2 ? BulkAITheme.Color.accent : Color.secondary.opacity(0.4))
                            Text("Fast").font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(goalSpeed == 2 ? BulkAITheme.Color.accent : .secondary)
                        }.frame(maxWidth: .infinity)
                    }.padding(.horizontal, BulkAITheme.Spacing.xl)
                    Slider(value: Binding(
                        get: { Double(goalSpeed) },
                        set: { goalSpeed = Int($0.rounded()) }
                    ), in: 0...2, step: 1).tint(BulkAITheme.Color.accent).padding(.horizontal, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xs)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 0) {
                            Text("You'll reach your goal in ")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                            Text("\(estimatedDays) days")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(BulkAITheme.Color.accent)
                        }
                        Text(goalSpeed == 1 ? "The most balanced pace, motivating and sustainable."
                             : goalSpeed == 0 ? "Gentle and sustainable. Great for long-term habits."
                             : "Aggressive but doable. Requires strong discipline.")
                            .font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
                    }
                    .padding(BulkAITheme.Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
                    .background(BulkAITheme.Color.surface, in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.md))
                    .padding(.horizontal, BulkAITheme.Spacing.xl)
                }
                Spacer()
            }
            continueButton { profile.save() }
        }
    }

    // MARK: - 9: Notifications

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    private var notificationsStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BulkAITheme.Spacing.xl) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BulkAITheme.Color.accent)

                Text("Be reminded to\nlog meals")
                    .font(BulkAITheme.Typography.title)
                    .multilineTextAlignment(.center)

                Text("Get gentle reminders at meal times\nso you never forget to track.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: BulkAITheme.Spacing.sm) {
                    Text("Bulk AI would like to send you Notifications")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .multilineTextAlignment(.center)
                    Divider()
                    HStack {
                        Button {
                            notificationsEnabled = false
                            withAnimation(.snappy) { step += 1 }
                        } label: {
                            Text("Don't Allow")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        Divider().frame(height: 30)
                        Button {
                            Task {
                                let granted = await notificationManager.requestAuthorization()
                                notificationsEnabled = granted
                                if granted {
                                    notificationManager.scheduleMealReminders(
                                        breakfastEnabled: true, breakfastHour: 8, breakfastMinute: 0,
                                        lunchEnabled: true, lunchHour: 12, lunchMinute: 0,
                                        dinnerEnabled: true, dinnerHour: 19, dinnerMinute: 0
                                    )
                                }
                                withAnimation(.snappy) { step += 1 }
                            }
                        } label: {
                            Text("Allow")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(BulkAITheme.Spacing.md)
                .background(BulkAITheme.Color.surface, in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg - 2))
                .padding(.horizontal, BulkAITheme.Spacing.xl)
            }

            Spacer()

            Button {
                notificationsEnabled = false
                withAnimation(.snappy) { step += 1 }
            } label: {
                Text("Skip")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xxs)
        }
    }

    // MARK: - 10: Apple Health

    private var appleHealthStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BulkAITheme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.06))
                        .frame(width: 120, height: 120)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                VStack(spacing: BulkAITheme.Spacing.xs) {
                    Text("Connect to\nApple Health")
                        .font(BulkAITheme.Typography.title)
                        .multilineTextAlignment(.center)

                    Text("Keep your nutrition and body\nmeasurements in sync automatically.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Feature list
                VStack(alignment: .leading, spacing: 12) {
                    healthFeatureRow(icon: "fork.knife", label: "Nutrition Data")
                    healthFeatureRow(icon: "scalemass.fill", label: "Weight Sync")
                    healthFeatureRow(icon: "figure.stand", label: "Body Measurements")
                }
                .padding(.horizontal, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xs)
            }

            Spacer()

            VStack(spacing: BulkAITheme.Spacing.sm) {
                Button {
                    Task {
                        let authorized = await healthKitManager.requestAuthorization()
                        if authorized {
                            UserDefaults.standard.set(true, forKey: "healthKitEnabled")

                            // Write current profile data to Health
                            let p = profile
                            healthKitManager.writeWeight(kg: p.weightKg, date: .now)
                            healthKitManager.writeHeight(cm: p.heightCm)
                            if let bf = p.bodyFatPercentage {
                                healthKitManager.writeBodyFat(fraction: bf)
                            }

                            // Read Health data back into profile
                            let measurements = await healthKitManager.fetchLatestBodyMeasurements()
                            if let dob = measurements.dob {
                                birthday = dob
                            }
                            if let sex = measurements.sex {
                                switch sex {
                                case .male: gender = .male
                                case .female: gender = .female
                                default: break
                                }
                            }
                        }
                        withAnimation(.snappy) { step += 1 }
                    }
                } label: {
                    Text("Continue")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(BulkAITheme.Color.accent, in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg - 2))
                }
                .padding(.horizontal, BulkAITheme.Spacing.xl)
                .padding(.bottom, BulkAITheme.Spacing.lg)
            }
        }
    }

    // MARK: - 11: AI Provider Setup

    private var aiProviderStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BulkAITheme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)

                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [BulkAITheme.Color.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                VStack(spacing: BulkAITheme.Spacing.xs) {
                    Text("Connect Gemini")
                        .font(BulkAITheme.Typography.title)
                        .multilineTextAlignment(.center)

                    Text("Bulk AI uses Google Gemini for food parsing. A free API key from aistudio.google.com/apikey unlocks photo, voice, and text logging.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: BulkAITheme.Spacing.sm) {
                    aiAccessCard(
                        mode: .bringYourOwnKey,
                        title: "Bring Your Own Key",
                        subtitle: "Free. Paste your Gemini API key now or later from Settings → AI. You can still log meals manually without one.",
                        badge: "Free"
                    )
                }
                .padding(.horizontal, BulkAITheme.Spacing.xl)

                Text("Your key is stored encrypted on this device only. It never leaves the phone.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BulkAITheme.Spacing.xl)
            }

            Spacer()

            Button {
                AIAccessSettings.mode = .bringYourOwnKey
                withAnimation(.snappy) { step += 1 }
            } label: {
                Text("Continue")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(colors: [BulkAITheme.Color.accent], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg - 2)
                    )
                    .shadow(color: BulkAITheme.Color.accent.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, BulkAITheme.Spacing.xl)
            .padding(.bottom, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xxs)
        }
    }

    private func aiSetupRow(number: String, text: String) -> some View {
        HStack(spacing: BulkAITheme.Spacing.sm) {
            Text(number)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(BulkAITheme.Color.accent, in: Circle())
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private func aiAccessCard(mode: AIAccessMode, title: String, subtitle: String, badge: String) -> some View {
        Button {
            selectedAccessMode = mode
            AIAccessSettings.mode = mode
        } label: {
            HStack(spacing: BulkAITheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    Image(systemName: mode.icon)
                        .font(BulkAITheme.Typography.headline)
                        .foregroundStyle(BulkAITheme.Color.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: BulkAITheme.Spacing.xs) {
                        Text(title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(badge)
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(BulkAITheme.Color.accent, in: Capsule())
                    }
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: selectedAccessMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selectedAccessMode == mode ? BulkAITheme.Color.accent : .secondary.opacity(0.35))
            }
            .padding(BulkAITheme.Spacing.sm + BulkAITheme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selectedAccessMode == mode ? BulkAITheme.Color.accent.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 14: Review

    private var reviewStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BulkAITheme.Spacing.xl) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color.pink.opacity(0.1), Color.yellow.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 160, height: 160)
                    Image(systemName: "star.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(BulkAITheme.Color.accent)
                }

                VStack(spacing: BulkAITheme.Spacing.xs) {
                    Text("Enjoying Bulk AI so far?")
                        .font(BulkAITheme.Typography.title)
                        .multilineTextAlignment(.center)
                    Text("A quick rating helps us grow\nand build more features for you!")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            Button {
                requestNativeReview()
                hasCompletedOnboarding = true
            } label: {
                Text("Rate Bulk AI")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(colors: [BulkAITheme.Color.accent], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg - 2)
                    )
                    .shadow(color: BulkAITheme.Color.accent.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, BulkAITheme.Spacing.xl)

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Maybe Later")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, BulkAITheme.Spacing.sm)
            .padding(.bottom, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xxs)
        }
    }

    // MARK: - 12: Building Plan

    private var buildingPlanStep: some View {
        BuildingPlanStepView(profile: profile) {
            withAnimation(.snappy) { step += 1 }
        }
    }

    // MARK: - 13: Plan Ready

    private var planCalories: Int { editedCalories ?? profile.dailyCalories }
    private var planProtein: Int { editedProtein ?? profile.proteinGoal }
    private var planFat: Int { editedFat ?? profile.fatGoal }
    private var planCarbs: Int { editedCarbs ?? profile.carbsGoal }

    private func initPlanValues() {
        if editedCalories == nil && editedProtein == nil && editedFat == nil && editedCarbs == nil {
            editedCalories = profile.dailyCalories
            editedProtein = profile.proteinGoal
            editedFat = profile.fatGoal
            editedCarbs = profile.carbsGoal
        }
    }

    private var planReadyStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "Your Plan", subtitle: "Tap any value to adjust")

            ScrollView {
                VStack(spacing: BulkAITheme.Spacing.lg) {
                    // Calorie display - tappable
                    Button {
                        withAnimation(.snappy) {
                            editingField = editingField == .calories ? nil : .calories
                        }
                    } label: {
                        VStack(spacing: BulkAITheme.Spacing.xxs) {
                            Text("\(planCalories)")
                                .font(.system(size: 64, weight: .bold, design: .rounded)) // TODO: BulkAITheme token
                                .foregroundStyle(
                                    LinearGradient(colors: [BulkAITheme.Color.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .contentTransition(.numericText())
                                .animation(.snappy, value: planCalories)
                            HStack(spacing: BulkAITheme.Spacing.xxs) {
                                Text("daily calories")
                                    .font(.system(.callout, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if editingField == .calories {
                        Picker("Calories", selection: Binding(
                            get: { planCalories },
                            set: { newCal in
                                editedCalories = newCal
                                editedCarbs = max(0, (newCal - planProtein * 4 - planFat * 9) / 4)
                            }
                        )) {
                            ForEach(Array(stride(from: 800, through: 5000, by: 10)), id: \.self) { cal in
                                Text("\(cal) cal").tag(cal)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(.horizontal, BulkAITheme.Spacing.xl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Macro cards - tappable
                    HStack(spacing: BulkAITheme.Spacing.sm) {
                        editableMacroCard(label: "Protein", value: planProtein, unit: "g", gradientColors: [BulkAITheme.Color.macroProtein], field: .protein)
                        editableMacroCard(label: "Carbs", value: planCarbs, unit: "g", gradientColors: [BulkAITheme.Color.macroCarbs], field: .carbs)
                        editableMacroCard(label: "Fat", value: planFat, unit: "g", gradientColors: [BulkAITheme.Color.macroFat], field: .fat)
                    }
                    .padding(.horizontal, BulkAITheme.Spacing.xl)

                    if editingField == .protein {
                        Picker("Protein", selection: Binding(
                            get: { planProtein },
                            set: { newProtein in
                                editedProtein = newProtein
                                editedCarbs = max(0, (planCalories - newProtein * 4 - planFat * 9) / 4)
                            }
                        )) {
                            ForEach(20...300, id: \.self) { g in Text("\(g) g").tag(g) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(.horizontal, BulkAITheme.Spacing.xl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if editingField == .carbs {
                        Picker("Carbs", selection: Binding(
                            get: { planCarbs },
                            set: { newCarbs in
                                editedCarbs = newCarbs
                                editedCalories = newCarbs * 4 + planProtein * 4 + planFat * 9
                            }
                        )) {
                            ForEach(0...500, id: \.self) { g in Text("\(g) g").tag(g) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(.horizontal, BulkAITheme.Spacing.xl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if editingField == .fat {
                        Picker("Fat", selection: Binding(
                            get: { planFat },
                            set: { newFat in
                                editedFat = newFat
                                editedCarbs = max(0, (planCalories - planProtein * 4 - newFat * 9) / 4)
                            }
                        )) {
                            ForEach(10...200, id: \.self) { g in Text("\(g) g").tag(g) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(.horizontal, BulkAITheme.Spacing.xl)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if planCalories < 1200 {
                        HStack(spacing: BulkAITheme.Spacing.xs + BulkAITheme.Spacing.xxs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Please consult with a doctor")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                Text("The minimum recommendation is 1,200 calories per day.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(BulkAITheme.Spacing.sm + BulkAITheme.Spacing.xxs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm + BulkAITheme.Spacing.xxs))
                        .padding(.horizontal, BulkAITheme.Spacing.xl)
                    }
                    // Citations link (Apple Guideline 1.4.1 — medical info needs sources)
                    Button {
                        showCalculationSources = true
                    } label: {
                        HStack(spacing: BulkAITheme.Spacing.xxs + BulkAITheme.Spacing.xxs) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 11))
                            Text("How is this calculated?")
                                .font(.system(.footnote, design: .rounded, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(BulkAITheme.Color.accent)
                    }
                    .padding(.top, BulkAITheme.Spacing.xs)
                    .padding(.horizontal, BulkAITheme.Spacing.xl)
                }
                .padding(.top, BulkAITheme.Spacing.md)
                .padding(.bottom, 100)
            }

            continueButton("Let's get started!") {
                var editedProfile = profile
                editedProfile.customCalories = editedCalories
                editedProfile.customProtein = editedProtein
                editedProfile.customFat = editedFat
                editedProfile.customCarbs = editedCarbs
                editedProfile.autoBalanceMacro = .carbs
                editedProfile.save()
            }
        }
        .onAppear { initPlanValues() }
        .sheet(isPresented: $showCalculationSources) {
            CalculationMethodsView()
        }
    }

    private func editableMacroCard(label: String, value: Int, unit: String, gradientColors: [Color], field: EditableField) -> some View {
        Button {
            withAnimation(.snappy) {
                editingField = editingField == field ? nil : field
            }
        } label: {
            VStack(spacing: BulkAITheme.Spacing.xxs + BulkAITheme.Spacing.xxs) {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: BulkAITheme.Spacing.xxs / 2) {
                    Text("\(value)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .contentTransition(.numericText())
                        .animation(.snappy, value: value)
                    Text(unit)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BulkAITheme.Spacing.sm)
            .background(BulkAITheme.Color.surface, in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.md)
                    .strokeBorder(editingField == field ? gradientColors.first ?? .clear : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(BulkAITheme.Typography.title)
            if !subtitle.isEmpty {
                Text(subtitle).font(.system(.callout, design: .rounded)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BulkAITheme.Spacing.xl).padding(.top, BulkAITheme.Spacing.xl)
    }

    private func selectionCard(icon: String, title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BulkAITheme.Spacing.md) {
                Image(systemName: icon).font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.primary : .secondary).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(.body, design: .rounded, weight: .semibold)).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle).font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.3))
            }
            .padding(BulkAITheme.Spacing.md)
            .background(BulkAITheme.Color.surface, in: RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg - 2))
            .overlay(RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg - 2).strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2))
        }.buttonStyle(.plain)
    }

    private func healthFeatureRow(icon: String, label: String) -> some View {
        HStack(spacing: BulkAITheme.Spacing.sm + BulkAITheme.Spacing.xxs) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(.secondary).frame(width: 28)
            Text(label).font(.system(.body, design: .rounded)).foregroundStyle(.primary)
        }
    }

    private func requestNativeReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}

// MARK: - Building Plan Step (enhanced with percentage + checklist)

struct BuildingPlanStepView: View {
    let profile: UserProfile
    let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var percent = 0
    @State private var checkItem = 0

    private let items = [
        ("Calories", "flame.fill"),
        ("Carbs", "leaf.fill"),
        ("Protein", "fish.fill"),
        ("Fats", "drop.fill"),
        ("Health Score", "heart.fill")
    ]

    var body: some View {
        VStack(spacing: BulkAITheme.Spacing.xxl) {
            Spacer()

            VStack(spacing: BulkAITheme.Spacing.xs) {
                Text("\(percent)%")
                    .font(.system(size: 56, weight: .bold, design: .rounded)) // TODO: BulkAITheme token
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: percent)

                Text("We're setting everything\nup for you")
                    .font(BulkAITheme.Typography.title3)
                    .multilineTextAlignment(.center)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            // Mono-pink to match the rest of the brand surface
                            // (macro rings, home + button, PlanReady calorie
                            // number) — earlier 3-stop gradient ended in blue
                            // and read as off-brand against the otherwise
                            // pink-only palette.
                            LinearGradient(colors: [BulkAITheme.Color.accent], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 10)
            .padding(.horizontal, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xs)

            Text("Finalizing results...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            // Checklist
            VStack(alignment: .leading, spacing: 14) {
                Text("Daily recommendation for")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                ForEach(0..<items.count, id: \.self) { index in
                    HStack(spacing: BulkAITheme.Spacing.xs + BulkAITheme.Spacing.xxs) {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        Text(items[index].0)
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        if index < checkItem {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.primary)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.4), value: checkItem)
                }
            }
            .padding(.horizontal, BulkAITheme.Spacing.xxl + BulkAITheme.Spacing.xs)

            Spacer()
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // 5 items over ~4 seconds
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7) {
                withAnimation { checkItem = i + 1 }
                percent = [20, 40, 60, 80, 100][i]
                progress = Double(i + 1) / 5.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            onComplete()
        }
    }
}
