import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var health: HealthKitService
    @AppStorage("profileWeightPounds") private var weight = 170
    @AppStorage("profileWorkoutsPerWeek") private var workouts = 0
    @AppStorage("profileWorkoutMinutes") private var workoutMinutes = 45

    private var extraML: Int { max(store.dailyGoalML - HydrationGoalCalculator.gallonML, 0) }
    private var daysHit: Int {
        store.statistics.dailyTotals.values.filter { $0 >= store.dailyGoalML }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your plan").font(.system(size: 38, weight: .regular))
                    summaryCards
                    dailyRhythm
                    coachCard
                    goalBreakdown
                    if health.enabled { HealthRoutineCard() }
                }.padding().padding(.bottom, 80)
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(HydrationTheme.canvas.ignoresSafeArea())
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Daily goal", value: WaterVolume.label(store.dailyGoalML), icon: "drop.fill", color: .blue)
            summaryCard(title: "Days hit", value: "\(daysHit)", icon: "checkmark.circle.fill", color: .green)
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.weight(.regular)).minimumScaleFactor(0.75).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .modifier(LiquidGlassSurface(shape: .rounded(22)))
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Hydration coach", systemImage: "sparkles").font(.title3)
            Text(coachTitle).font(.headline.weight(.regular))
            Text(coachMessage).font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: store.todayProgress).tint(.blue)
            HStack {
                Text("\(WaterVolume.label(store.todayAmountML)) logged")
                Spacer()
                Text("\(Int(store.todayProgress * 100))%")
            }.font(.caption).foregroundStyle(.secondary)
            if let drink = store.selectedDrink, store.todayProgress < 1 {
                Button("Log \(BottleCatalog.displayName(drink.name).lowercased()) · \(BottleCatalog.sizeLabel(capacityML: drink.capacityML))") {
                    store.addWater(drink.capacityML)
                }.buttonStyle(.borderedProminent).tint(.blue)
            }
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }

    private var goalBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How your goal is built").font(.title3)
            planRow("Daily baseline", HydrationGoalCalculator.gallonML, "1 gallon every day", "drop.fill")
            if extraML > 0 {
                Divider()
                planRow("Personal adjustment", extraML,
                        "Based on \(weight) lb and \(workouts) × \(workoutMinutes)-minute workouts per week",
                        "figure.run")
            }
            Divider()
            HStack {
                Text("Daily target").font(.headline)
                Spacer()
                Text(WaterVolume.label(store.dailyGoalML)).font(.headline)
            }
            Text("Workout needs vary with sweat rate, intensity, and weather. Treat this as a practical tracking plan and follow any clinician-set fluid limit.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }

    private var dailyRhythm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stay on track").font(.title3)
            Text("Four flexible checkpoints—not deadlines.").font(.subheadline).foregroundStyle(.secondary)
            checkpoint("Morning", fraction: 0.25, icon: "sunrise.fill")
            checkpoint("By lunch", fraction: 0.50, icon: "fork.knife")
            checkpoint("Late afternoon", fraction: 0.75, icon: "sun.max.fill")
            checkpoint("Evening", fraction: 1.0, icon: "moon.stars.fill")
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }

    private func planRow(_ title: String, _ amount: Int, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.blue).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(title).font(.headline.weight(.regular)); Spacer(); Text(WaterVolume.label(amount)) }
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func checkpoint(_ title: String, fraction: Double, icon: String) -> some View {
        let amount = Int((Double(store.dailyGoalML) * fraction).rounded())
        let reached = store.todayAmountML >= amount
        return HStack(spacing: 12) {
            Image(systemName: reached ? "checkmark.circle.fill" : icon)
                .foregroundStyle(reached ? .green : .blue).frame(width: 26)
            Text(title)
            Spacer()
            Text(WaterVolume.label(amount)).foregroundStyle(.secondary)
        }.font(.subheadline).accessibilityLabel("\(title), \(WaterVolume.label(amount))\(reached ? ", reached" : "")")
    }

    private var expectedFraction: Double {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<11: return 0.25
        case 11..<15: return 0.50
        case 15..<19: return 0.75
        default: return 1.0
        }
    }

    private var coachTitle: String {
        if store.todayProgress >= 1 { return "Today’s goal is complete" }
        if store.todayProgress >= expectedFraction { return "You’re on track" }
        return "Let’s catch up gently"
    }

    private var coachMessage: String {
        if store.todayProgress >= 1 { return "Nice work. Keep listening to thirst—there’s no need to force extra water." }
        let checkpointML = Int((Double(store.dailyGoalML) * expectedFraction).rounded())
        let gap = max(checkpointML - store.todayAmountML, 0)
        if gap == 0 { return "Keep your usual drink nearby and check in again at the next part of your day." }
        return "You’re \(WaterVolume.label(gap)) from the current checkpoint. Sip at a comfortable pace and log it from Home or here."
    }
}
