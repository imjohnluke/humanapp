import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var showingCollection = false
    @State private var showingMilestones = false
    @State private var historyMetric: HydrationHistoryMetric?

    var body: some View {
        ZStack {
            HydrationTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Circle().fill(.white.opacity(0.65)).frame(width: 84, height: 84)
                            .overlay(Image(systemName: "person.fill").font(.system(size: 34, weight: .light)).foregroundStyle(.black.opacity(0.55)))
                            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                        Text(store.displayName.isEmpty ? "Your name" : store.displayName).font(.title2.weight(.regular))
                    }
                    .frame(maxWidth: .infinity).padding(.top, 18).padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Hydration score", systemImage: "drop.fill").font(.headline.weight(.regular))
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(Int(store.todayProgress * 100))").font(.system(size: 42, weight: .regular, design: .rounded))
                            Text("/ 100").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text("Today").font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: store.todayProgress).tint(.black)
                        Text("Your daily goal completion—not a medical health score.").font(.caption).foregroundStyle(.secondary)
                    }.foregroundStyle(.black).padding(20)
                        .modifier(LiquidGlassSurface(shape: .rounded(24)))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("My bottle collection").font(.headline.weight(.regular))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(0..<6) { slot in
                                Button {
                                    if slot == 0 { showingCollection = true }
                                    else { showingMilestones = true }
                                } label: {
                                    VStack(spacing: 8) {
                                        if slot == 0, let bottle = store.bottle {
                                            DrinkIcon(name: bottle.assetName, starter: true).frame(height: 72)
                                            Text("Starter").font(.caption2)
                                        } else {
                                            Image(systemName: slot == 0 ? "plus" : "lock.fill")
                                                .font(.title3.weight(.light)).frame(height: 72)
                                            Text(slot == 0 ? "Choose bottle" : "Milestone").font(.caption2)
                                        }
                                    }.foregroundStyle(slot == 0 ? Color.primary : Color.secondary)
                                        .frame(maxWidth: .infinity).frame(height: 110)
                                        .background(.white.opacity(slot == 0 ? 0.25 : 0.08), in: RoundedRectangle(cornerRadius: 18))
                                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: slot == 0 ? [] : [4, 4])))
                                }.buttonStyle(.plain)
                                    .accessibilityLabel(slot == 0 ? "Choose your starter bottle" : "Locked milestone slot \(slot)")
                            }
                        }
                        Label("More colors & tumblers coming through streak milestones", systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).modifier(LiquidGlassSurface(shape: .rounded(24)))

                    HStack(spacing: 12) {
                        Button { historyMetric = .streak } label: {
                            ProfileStat(value: "\(store.currentStreak)", label: "Day streak", icon: "flame.fill")
                        }.buttonStyle(.plain)
                        Button { historyMetric = .average } label: {
                            ProfileStat(value: "\(store.dailyAverageML) ml", label: "Daily average", icon: "drop.fill")
                        }.buttonStyle(.plain)
                    }
                    HStack(spacing: 12) {
                        ProfileStat(value: "\(store.dailyGoalML) ml", label: "Daily goal", icon: "target")
                        ProfileStat(value: "\(store.entries.count)", label: "Total logs", icon: "list.bullet")
                    }
                }.padding()
            }
        }
        .sheet(isPresented: $showingCollection) { BottlePickerSheet() }
        .sheet(item: $historyMetric) { HydrationHistorySheet(metric: $0) }
        .alert("Room for your progress", isPresented: $showingMilestones) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("These slots are reserved for future streak and consistency rewards. Your clear starter is available now; milestone unlocking is coming soon.")
        }
    }

}

private struct ProfileStat: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(label, systemImage: icon).font(.caption.weight(.regular)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.regular)).foregroundStyle(.black)
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
                        Text(metric == .streak ? "\(store.currentStreak) days" : "\(store.dailyAverageML) ml")
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
                        Text("\(store.amount(on: selectedDay)) ml")
                            .font(.title2.weight(.regular))
                        ProgressView(value: min(Double(store.amount(on: selectedDay)) / Double(max(store.dailyGoalML, 1)), 1)).tint(.black)
                        Text(store.amount(on: selectedDay) == 0 ? "No water logged" : "\(store.entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }.count) water logs")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Compared with your current goal of \(store.dailyGoalML) ml")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                        .modifier(LiquidGlassSurface(shape: .rounded(24)))
                }.padding(20)
            }
            .navigationTitle(metric.rawValue).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .background(HydrationTheme.canvas.ignoresSafeArea())
        }
        .tint(.black)
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
                                .background(selected ? Color.black.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(future ? Color.gray.opacity(0.4) : Color.black)
                        }.buttonStyle(.plain).disabled(future)
                            .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(store.amount(on: day)) milliliters\(reached ? ", goal reached" : "")")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }
}
