import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var showingPro = false
    @State private var showingIntro = true
    @AppStorage("hasCompletedOnboarding") private var completed = false
    @AppStorage("profileAge") private var savedAge = 25
    @AppStorage("profileHeightCM") private var savedHeight = 170
    @AppStorage("profileWeightPounds") private var savedWeight = 170
    @AppStorage("profileWorkoutsPerWeek") private var savedWorkouts = 0
    @AppStorage("profileWorkoutMinutes") private var savedWorkoutMinutes = 45
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var planProgress = 0.0
    @State private var step = 0
    @State private var name = ""
    @State private var age = 25
    @State private var height = 170
    @State private var weight = 170
    @State private var workouts = 0
    @State private var workoutMinutes = 45
    @State private var goal = Double(HydrationGoalCalculator.gallonML)
    @State private var drinkCapacity = WaterVolume.input(250)
    @State private var selectedBottle: String? = "glass"
    @State private var bottlePage = 0
    @FocusState private var nameFocused: Bool

    private let bottles: [(asset: String, name: String, capacity: Int)] = BottleCatalog.options.map { ($0.0, $0.1, $0.2) }
    private let titles = ["Your name?", "Your age?", "Your height?",
                          "How often do you work out?", "Your everyday glass or bottle",
                          "Connect Apple Health", "Creating your personal hydration plan", "Your hydration plan"]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HydrationTheme.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        Spacer(minLength: 24)
                        Text(titles[step])
                            .font(.title2.weight(.regular))
                        stepContent
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: 460)
                    .frame(minHeight: max(0, geometry.size.height - 150))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if step != 6 {
                    Button(action: advance) {
                        Text(step == 7 ? "Start my plan" : step == 5 ? "Create my plan" : step == 4 ? "Use this as my usual drink" : "Continue")
                            .font(.headline.weight(.regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(health.busy || (step == 0 && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || (step == 4 && selectedBottle != nil && WaterVolume.milliliters(drinkCapacity, minimum: 40) == nil))
                    }
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay {
            if showingIntro {
                OnboardingIntroView { withAnimation(.easeInOut(duration: 0.35)) { showingIntro = false } }
            }
        }
        .task(id: step) {
            guard step == 6 else { return }
            planProgress = 0
            do {
                for stage in 1...3 {
                    try await Task.sleep(for: .milliseconds(650))
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                        planProgress = Double(stage) / 3
                    }
                }
                try await Task.sleep(for: .milliseconds(350))
                withAnimation(reduceMotion ? nil : .easeInOut) { step = 7 }
            } catch { }
        }
        .fullScreenCover(isPresented: $showingPro, onDismiss: { completed = true }) {
            ProSubscriptionSheet(isOnboarding: true)
        }
        .multilineTextAlignment(.center)
        .onAppear {
            name = store.displayName
            age = savedAge
            height = savedHeight
            weight = savedWeight
            workouts = savedWorkouts
            workoutMinutes = savedWorkoutMinutes
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            Text("What should we call you?")
                .font(.subheadline).foregroundStyle(.secondary)
            TextField("Your name", text: $name)
                .textContentType(.name)
                .focused($nameFocused)
                .submitLabel(.continue)
                .onSubmit(advance)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .modifier(LiquidGlassSurface(shape: .rounded(20)))
        case 1:
            Picker("Age in years", selection: $age) {
                ForEach(1...120, id: \.self) { Text("\($0) years").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)
        case 2:
            HStack {
                Picker("Height in feet and inches", selection: Binding(
                    get: { Int((Double(height) / 2.54).rounded()) },
                    set: { height = Int((Double($0) * 2.54).rounded()) }
                )) {
                    ForEach(48...95, id: \.self) { inches in
                        Text("\(inches / 12) ft \(inches % 12) in").tag(inches)
                    }
                }
                Picker("Weight in pounds", selection: $weight) {
                    ForEach(70...500, id: \.self) { Text("\($0) lb").tag($0) }
                }
            }
            .pickerStyle(.wheel).frame(height: 180)
        case 3:
            Text("How many days in a typical week?")
                .font(.subheadline).foregroundStyle(.secondary)
            Picker("Workout days per week", selection: $workouts) {
                ForEach(0...7, id: \.self) { Text("\($0) days").tag($0) }
            }
            .pickerStyle(.wheel).frame(height: 180)
            if workouts > 0 {
                Stepper("About \(workoutMinutes) minutes each", value: $workoutMinutes, in: 15...180, step: 15)
            }
        case 4:
            Text("Choose what you drink water from most often.")
                .font(.headline.weight(.regular))
            Text("We’ll use it for quick logging on Home. You can change it anytime.")
                .font(.subheadline).foregroundStyle(.secondary)
            TabView(selection: $bottlePage) {
                ForEach(bottles.indices, id: \.self) { index in
                    let bottle = bottles[index]
                    VStack(spacing: 12) {
                        BottleFinishIcon(asset: bottle.asset, finish: "clear")
                            .frame(height: 230)
                            .padding(.horizontal, 48)
                            .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
                        Text(bottle.name).font(.title3.weight(.regular))
                        Text(BottleCatalog.sizeLabel(capacityML: bottle.capacity))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)
            .overlay(alignment: .top) {
                HStack {
                    Button { withAnimation { bottlePage -= 1 } } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.disabled(bottlePage == 0).accessibilityLabel("Previous bottle")
                    Spacer()
                    Button { withAnimation { bottlePage += 1 } } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }.disabled(bottlePage == bottles.count - 1).accessibilityLabel("Next bottle")
                }.foregroundStyle(.primary).frame(height: 230).padding(.top, 15)
            }
            .onChange(of: bottlePage) { _, index in
                selectedBottle = bottles[index].asset
                drinkCapacity = WaterVolume.input(bottles[index].capacity)
            }
            Text("Swipe to choose · \(bottlePage + 1) of \(bottles.count)")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Full capacity")
                TextField("fl oz", text: $drinkCapacity).keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("fl oz")
            }.padding(14).modifier(LiquidGlassSurface(shape: .rounded(16)))
            Text("Check your glass or bottle’s size and adjust if needed. This will be your usual drink.")
                .font(.caption).foregroundStyle(.secondary)
        case 5:
            HealthConnectionCard()
                .padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
            Text("You can skip this and connect later in Settings.")
                .font(.caption).foregroundStyle(.secondary)
        case 6:
            ZStack {
                Circle().stroke(.blue.opacity(0.1), lineWidth: 12)
                Circle().trim(from: 0, to: planProgress)
                    .stroke(LinearGradient(colors: [.cyan.opacity(0.4), .blue], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "drop.fill").font(.system(size: 48)).foregroundStyle(.blue)
            }.frame(width: 160, height: 160).padding(.vertical, 24)
                .accessibilityLabel("Creating hydration plan")
            Text(planProgress < 0.34 ? "Adding your daily goal" : planProgress < 0.67 ? "Building around your routine" : "Getting your plan ready")
                .font(.subheadline).foregroundStyle(.secondary)
                .accessibilityAddTraits(.updatesFrequently)
        default:
            VStack(alignment: .leading, spacing: 18) {
                Text("\(name.trimmingCharacters(in: .whitespacesAndNewlines)), let’s make it a habit.")
                    .font(.title3.weight(.regular))
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WaterVolume.label(store.dailyGoalML)).font(.title.weight(.regular))
                        Text("Your daily tracking goal").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "drop.fill").font(.largeTitle).foregroundStyle(.blue)
                }.padding(20).modifier(LiquidGlassSurface(shape: .rounded(22)))
                if let drink = store.selectedDrink {
                    Label("Ready to log: \(drink.name) · \(BottleCatalog.sizeLabel(capacityML: drink.capacityML))", systemImage: "checkmark.circle")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if health.enabled { HealthRoutineCard() }
                Text("Good moments to check in").font(.headline.weight(.regular))
                planMoment("Start your morning", "Pair a water check-in with breakfast or your morning routine.", icon: "sunrise.fill", color: .orange)
                planMoment("With your meals", "Use lunch and dinner as reminders to pause for a drink and log it.", icon: "fork.knife", color: .blue)
                if workouts > 0 {
                    planMoment("After a workout", "On your \(workouts) workout days each week, check in after exercising: did you hydrate?", icon: "figure.run", color: .purple)
                } else {
                    planMoment("During an afternoon break", "Keep your usual glass or bottle nearby so it’s easy to remember.", icon: "sun.max.fill", color: .purple)
                }
                Text("These are flexible habit cues, not fixed drinking times. Adjust your goal to your needs and follow any fluid limits from your clinician.")
                    .font(.caption).foregroundStyle(.secondary)
                if age < 18 {
                    Text("Review your goal and routine with a parent or clinician.").font(.caption).foregroundStyle(.secondary)
                }
                Link("About healthy hydration", destination: URL(string: "https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/water-drinks-nutrition/")!)
                    .font(.caption)
            }.multilineTextAlignment(.leading)

        }
    }

    private func planMoment(_ title: String, _ detail: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).modifier(LiquidGlassSurface(shape: .rounded(20)))
    }

    private func advance() {
        if step == 7 {
            if subscriptions.isPro { completed = true } else { showingPro = true }
            return
        }
        guard step != 6 else { return }
        if step == 5 { withAnimation(reduceMotion ? nil : .easeInOut) { step = 6 }; return }
        guard step != 0 || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        nameFocused = false
        if step < 4 {
            if step == 3 {
                goal = Double(HydrationGoalCalculator.dailyGoalML(weightPounds: Double(weight), workoutsPerWeek: workouts, workoutMinutes: workoutMinutes))
            }
            step += 1
            return
        }
        store.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        savedAge = age
        savedHeight = height
        savedWeight = weight
        savedWorkouts = workouts
        savedWorkoutMinutes = workoutMinutes
        store.dailyGoalML = Int(goal)
        if let bottle = bottles.first(where: { $0.asset == selectedBottle }) {
            store.selectBottle(WaterBottle(name: bottle.name, capacityML: WaterVolume.milliliters(drinkCapacity, minimum: 40) ?? bottle.capacity,
                                      assetName: bottle.asset,
                                      colorName: BottleCatalog.startingColor(bottle.asset)))
        } else {
            store.bottle = nil
        }
        step = 5
    }
}

private struct OnboardingIntroView: View {
    let begin: () -> Void
    @State private var textVisible = false
    @State private var detailVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            HydrationTheme.canvas.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "drop.fill")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.blue)
                    .scaleEffect(textVisible ? 1 : 0.72)
                    .opacity(textVisible ? 1 : 0)
                Text("Answer a few questions to get your personalized hydration plan.")
                    .font(.largeTitle.weight(.regular))
                    .multilineTextAlignment(.center)
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : 14)
                Text("It only takes a minute.")
                    .font(.headline.weight(.regular))
                    .foregroundStyle(.secondary)
                    .opacity(detailVisible ? 1 : 0)
                Spacer()
                Button("Let’s begin") { begin() }
                    .font(.headline.weight(.regular))
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .opacity(detailVisible ? 1 : 0)
            }
            .frame(maxWidth: 460)
            .padding(28)
        }
        .task {
            if reduceMotion {
                textVisible = true
                detailVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.7)) { textVisible = true }
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeOut(duration: 0.5)) { detailVisible = true }
            }
        }
    }
}
