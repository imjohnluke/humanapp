import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @AppStorage("hasCompletedOnboarding") private var completed = false
    @AppStorage("profileAge") private var savedAge = 25
    @AppStorage("profileHeightCM") private var savedHeight = 170
    @AppStorage("profileWorkoutsPerWeek") private var savedWorkouts = 0
    @State private var step = 0
    @State private var name = ""
    @State private var age = 25
    @State private var height = 170
    @State private var metricHeight = true
    @State private var workouts = 0
    @State private var goal = 2000.0
    @State private var selectedBottle: String?
    @State private var capacity = 500.0
    @FocusState private var nameFocused: Bool

    private let bottles: [(asset: String, name: String, capacity: Int)] = [
        ("glass", "Glass", 250), ("bottle", "Water bottle", 500),
        ("gatorade", "Sport bottle", 750), ("stanley", "Tumbler", 1000),
        ("big", "Large bottle", 2000), ("gallon", "Gallon jug", 3785)
    ]
    private let titles = ["Your name?", "Your age?", "Your height?",
                          "How often do you work out?", "Your daily goal?",
                          "What do you drink out of?"]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HydrationTheme.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        Spacer(minLength: 24)
                        Text(titles[step])
                            .font(.title2.weight(.medium))
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
                    Button(action: advance) {
                        Text(step == 5 ? "Let’s go" : "Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(step == 0 && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    HStack {
                        if step > 0 {
                            Button("Back") {
                                nameFocused = false
                                step -= 1
                            }
                        }
                        Spacer()
                        Text("\(step + 1) of 6").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .multilineTextAlignment(.center)
        .onAppear {
            name = store.displayName
            age = savedAge
            height = savedHeight
            workouts = savedWorkouts
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
            Picker("Height units", selection: $metricHeight) {
                Text("cm").tag(true)
                Text("ft / in").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            if metricHeight {
                Picker("Height in centimeters", selection: $height) {
                    ForEach(80...240, id: \.self) { Text("\($0) cm").tag($0) }
                }
                .pickerStyle(.wheel).frame(height: 180)
            } else {
                Picker("Height in feet and inches", selection: Binding(
                    get: { Int((Double(height) / 2.54).rounded()) },
                    set: { height = Int((Double($0) * 2.54).rounded()) }
                )) {
                    ForEach(31...95, id: \.self) { inches in
                        Text("\(inches / 12) ft \(inches % 12) in").tag(inches)
                    }
                }
                .pickerStyle(.wheel).frame(height: 180)
            }
        case 3:
            Text("How many days in a typical week?")
                .font(.subheadline).foregroundStyle(.secondary)
            Picker("Workout days per week", selection: $workouts) {
                ForEach(0...7, id: \.self) { Text("\($0) days").tag($0) }
            }
            .pickerStyle(.wheel).frame(height: 180)
        case 4:
            Text(age >= 18 ? "Recommended starting point" : "Choose a goal with a parent or clinician")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("\(Int(goal)) ml")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .monospacedDigit()
            Slider(value: $goal, in: 500...5000, step: 100)
                .tint(.black)
                .accessibilityLabel("Daily hydration goal in milliliters")
            Text(age >= 18
                 ? "A general adult starting point of 2,000 ml of fluids per day. Adjust it to suit you."
                 : "Children’s needs vary. This is an editable tracking goal, not a recommendation.")
                .font(.subheadline).foregroundStyle(.secondary)
            if workouts > 0 {
                Text("On your \(workouts) workout days, drink regularly and replace extra fluids lost through sweat.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Age, height and workout frequency alone don’t determine your fluid needs. Other drinks count too; follow any fluid limit your clinician has given you.")
                .font(.caption).foregroundStyle(.secondary)
            Link("About this recommendation",
                 destination: URL(string: "https://www.kch.nhs.uk/patients-and-visitors/patients/hydration-matters/")!)
                .font(.caption)
        default:
            Text("Pick your everyday go-to.")
                .font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(bottles, id: \.asset) { bottle in
                    Button {
                        selectedBottle = bottle.asset
                        capacity = Double(bottle.capacity)
                    } label: {
                        VStack(spacing: 8) {
                            DrinkIcon(name: bottle.asset).frame(height: 92)
                            Text(bottle.name).font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .stroke(selectedBottle == bottle.asset ? Color.black : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedBottle == bottle.asset ? .isSelected : [])
                }
            }
            if selectedBottle != nil {
                Stepper("Capacity: \(Int(capacity)) ml", value: $capacity, in: 50...7570, step: 50)
                    .font(.subheadline)
                Text("Check your container’s capacity — these are starting sizes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("I use different ones") { selectedBottle = nil }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func advance() {
        guard step != 0 || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        nameFocused = false
        if step < 5 {
            step += 1
            return
        }
        store.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        savedAge = age
        savedHeight = height
        savedWorkouts = workouts
        store.dailyGoalML = Int(goal)
        if let bottle = bottles.first(where: { $0.asset == selectedBottle }) {
            store.bottle = WaterBottle(name: bottle.name, capacityML: Int(capacity),
                                      assetName: bottle.asset,
                                      colorName: ["stanley", "big"].contains(bottle.asset) ? "pink" : "white")
        } else {
            store.bottle = nil
        }
        completed = true
    }
}
