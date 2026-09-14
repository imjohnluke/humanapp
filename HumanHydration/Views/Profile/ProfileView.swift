import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: HydrationStore
    @State private var showingSettings = false
    @State private var showingCollection = false
    @State private var historyMetric: HydrationHistoryMetric?

    var body: some View {
        ZStack {
            HydrationTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    HStack(spacing: 16) {
                        Circle().fill(HydrationTheme.surface).frame(width: 72, height: 72)
                            .overlay(Image(systemName: "person.fill").font(.system(size: 30, weight: .light)).foregroundStyle(.secondary))
                            .overlay(Circle().stroke(HydrationTheme.border, lineWidth: 1))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(store.displayName.isEmpty ? "Your name" : store.displayName)
                                .font(.title2.weight(.regular))
                                .fixedSize(horizontal: false, vertical: true)
                            memberSinceLabel
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.headline.weight(.regular))
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 18).padding(.bottom, 8)

                    ProfileGoalCard(amount: store.todayAmountML, goal: store.dailyGoalML)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("My bottle collection").font(.headline.weight(.regular))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(BottleCatalog.finishes) { finish in
                                let unlocked = store.isFinishUnlocked(finish.id)
                                Button { showingCollection = true } label: {
                                    VStack(spacing: 6) {
                                        BottleFinishIcon(asset: store.bottle?.assetName ?? "bottle", finish: finish.id)
                                            .frame(height: 64)
                                            .opacity(unlocked ? 1 : 0.45)
                                            .overlay {
                                                if !unlocked { Image(systemName: "lock.fill").font(.caption) }
                                            }
                                        Text(finish.name).font(.caption)
                                        Text(finish.milestone).font(.caption2).foregroundStyle(.secondary)
                                        Text(unlocked ? "Unlocked" : "\(finish.days) day streak")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(unlocked ? HydrationTheme.surface : HydrationTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(.plain)
                                    .accessibilityLabel("\(finish.name), \(unlocked ? "unlocked" : "requires a \(finish.days) day streak")")
                            }
                        }
                        Text("Hit your daily goal to earn finishes for every style. Earned finishes stay unlocked.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Month milestones: 30, 90, 180 and 365 consecutive days.")
                            .font(.caption2).foregroundStyle(.secondary)

                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).modifier(LiquidGlassSurface(shape: .rounded(24)))

                    HStack(spacing: 12) {
                        Button { historyMetric = .streak } label: {
                            ProfileStat(value: "\(store.currentStreak)", label: "Day streak", icon: "flame.fill")
                        }.buttonStyle(.plain)
                        Button { historyMetric = .average } label: {
                            ProfileStat(value: "\(WaterVolume.label(store.dailyAverageML))", label: "Daily average", icon: "drop.fill")
                        }.buttonStyle(.plain)
                    }
                    HStack(spacing: 12) {
                        ProfileStat(value: "\(store.bestStreak) days", label: "Personal record", icon: "trophy.fill")
                        ProfileStat(value: "\(store.entries.count)", label: "Total logs", icon: "list.bullet")
                    }
                }.padding()
                    // Keep the last row reachable above the floating navigation.
                    .padding(.bottom, 80)
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingCollection) { BottlePickerSheet() }
        .sheet(item: $historyMetric) { HydrationHistorySheet(metric: $0) }

    }

    private var memberSinceLabel: some View {
        Text(auth.user?.memberSince.map {
            "Member since \($0.formatted(.dateTime.month(.abbreviated).year()))"
        } ?? "Member since —")
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: true, vertical: false)
    }

}

private struct ProfileGoalCard: View {
    let amount: Int
    let goal: Int
    private var progress: Double { min(max(Double(amount) / Double(max(goal, 1)), 0), 1) }
    private var reachedGoal: Bool { goal > 0 && amount >= goal }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Daily goal").font(.headline.weight(.regular))
                Spacer()
                Label(reachedGoal ? "Complete" : "Today", systemImage: reachedGoal ? "checkmark.circle.fill" : "sun.max")
                    .font(.caption).foregroundStyle(.blue)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.blue.opacity(0.07), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(WaterVolume.number(goal))
                    .font(.system(size: 48, weight: .regular, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                Text("fl oz / day").font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(reachedGoal ? "You’ve reached your goal" : "Today’s progress")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .foregroundStyle(.blue).monospacedDigit()
                }.font(.subheadline)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.blue.opacity(0.08))
                        Capsule().fill(LinearGradient(
                            colors: [Color(red: 0.88, green: 0.95, blue: 1), .blue],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * progress)
                    }
                }.frame(height: 14)
                    .animation(.easeInOut(duration: 0.5), value: progress)
                    .accessibilityLabel("Today’s goal progress")
                    .accessibilityValue("\(WaterVolume.number(amount)) of \(WaterVolume.label(goal))")
            }

            HStack(spacing: 20) {
                amountLabel(amount, title: "Logged today")
                Rectangle().fill(.primary.opacity(0.08)).frame(width: 1, height: 36)
                amountLabel(max(goal - amount, 0), title: "Left to go")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(LiquidGlassSurface(shape: .rounded(28)))
    }

    private func amountLabel(_ value: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(WaterVolume.label(value))").font(.title3.weight(.regular)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProfileStat: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(label, systemImage: icon).font(.caption.weight(.regular)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.regular)).foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).modifier(LiquidGlassSurface(shape: .rounded(20)))
    }
}

enum HydrationHistoryMetric: String, Identifiable {
    case streak = "Streak", average = "Daily average"
    var id: String { rawValue }
}

struct HydrationHistorySheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    let metric: HydrationHistoryMetric
    @State private var monthOffset = 0
    @State private var selectedDay = Date.now
    private let calendar = Calendar.current

    private var currentMonth: Date {
        calendar.dateInterval(of: .month, for: .now)!.start
    }
    private var earliestOffset: Int {
        let first = min(store.entries.map(\.date).min() ?? .now, .now)
        let start = calendar.dateInterval(of: .month, for: first)!.start
        return min(-11, calendar.dateComponents([.month], from: currentMonth, to: start).month ?? 0)
    }
    private func month(_ offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: currentMonth)!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text(metric == .streak ? "\(store.currentStreak) days" : "\(WaterVolume.label(store.dailyAverageML))")
                            .font(.system(size: 32, weight: .regular, design: .rounded))
                        Text(metric == .streak ? "Consecutive days reaching your goal" : "7-day average · includes today and days without logs")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    VStack(spacing: 12) {
                        HStack {
                            Button { withAnimation { monthOffset -= 1 } } label: {
                                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            }.disabled(monthOffset <= earliestOffset).accessibilityLabel("Previous month")
                            Spacer()
                            Text(month(monthOffset).formatted(.dateTime.month(.wide).year())).font(.headline.weight(.regular))
                            Spacer()
                            Button { withAnimation { monthOffset += 1 } } label: {
                                Image(systemName: "chevron.right").frame(width: 44, height: 44)
                            }.disabled(monthOffset >= 0).accessibilityLabel("Next month")
                        }
                        TabView(selection: $monthOffset) {
                            ForEach(earliestOffset...0, id: \.self) { offset in
                                monthGrid(month(offset)).tag(offset)
                            }
                        }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 300)
                        Label("Goal reached", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(12).modifier(LiquidGlassSurface(shape: .rounded(24)))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedDay.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.regular))
                        Text("\(WaterVolume.label(store.amount(on: selectedDay)))")
                            .font(.title2.weight(.regular))
                        ProgressView(value: min(Double(store.amount(on: selectedDay)) / Double(max(store.dailyGoalML, 1)), 1)).tint(.blue)
                        Text(store.amount(on: selectedDay) == 0 ? "No water logged" : "\(store.entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }.count) water logs")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Compared with your current goal of \(WaterVolume.label(store.dailyGoalML))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                        .modifier(LiquidGlassSurface(shape: .rounded(24)))
                }.padding(20)
            }
            .navigationTitle(metric.rawValue).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .background(HydrationTheme.canvas.ignoresSafeArea())
        }
        .tint(.blue)
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private func monthGrid(_ date: Date) -> some View {
        let days = calendar.range(of: .day, in: .month, for: date)!.count
        let leading = (calendar.component(.weekday, from: date) - calendar.firstWeekday + 7) % 7
        return VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                        .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(0..<42) { cell in
                    if cell >= leading && cell < leading + days {
                        let day = calendar.date(byAdding: .day, value: cell - leading, to: date)!
                        let future = day > calendar.startOfDay(for: .now)
                        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
                        let reached = store.dailyGoalML > 0 && store.amount(on: day) >= store.dailyGoalML
                        Button { selectedDay = day } label: {
                            VStack(spacing: 3) {
                                Text("\(cell - leading + 1)").font(.subheadline.weight(selected ? .semibold : .regular))
                                Image(systemName: reached ? "checkmark.circle.fill" : "circle.fill")
                                    .font(.system(size: reached ? 9 : 4))
                                    .opacity(reached || store.amount(on: day) > 0 ? 1 : 0)
                            }.frame(maxWidth: .infinity).frame(height: 40)
                                .background(selected ? Color.blue.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(future ? Color.gray.opacity(0.4) : Color.primary)
                        }.buttonStyle(.plain).disabled(future)
                            .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(WaterVolume.label(store.amount(on: day)))\(reached ? ", goal reached" : "")")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }
}
