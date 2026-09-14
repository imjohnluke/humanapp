import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var showingPro = false
    @State private var showingSettings = false
    @State private var historyMetric: HydrationHistoryMetric?
    private var isDemoAccount: Bool { auth.user?.email?.lowercased() == "test@example.com" }
    private var hasAccess: Bool { subscriptions.isPro || isDemoAccount }
    private var displayedStatistics: HydrationStatistics { isDemoAccount ? demoStatistics : store.statistics }

    var body: some View {
        Group {
            if hasAccess { insights }
            else { lockedInsights }
        }
        .sheet(isPresented: $showingPro) { ProSubscriptionSheet() }
    }

    private var lockedInsights: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "chart.bar.xaxis").font(.system(size: 48, weight: .light)).foregroundStyle(.blue)
                Text("Understand your hydration").font(.title2)
                Text("Unlock hourly patterns, seven-day trends, streak analysis, and personalized insights with Human Pro.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Explore Human Pro") { showingPro = true }
                    .buttonStyle(.borderedProminent).tint(.blue)
            }.padding(32).frame(maxWidth: 460)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HydrationTheme.canvas.ignoresSafeArea())
        }
    }

    private var insights: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Insights").font(.system(size: 38, weight: .regular))
                    if isDemoAccount { DemoRoutineCard() } else { HealthRoutineCard() }
                    Text("Your progress").font(.title3)
                    HStack(spacing: 14) {
                        Button { historyMetric = .streak } label: {
                            StatCard(title: "Day streak", value: "\(displayedStatistics.currentStreak) days", icon: "flame", color: .blue)
                        }
                        Button { historyMetric = .average } label: {
                            StatCard(title: "Daily average", value: "\(WaterVolume.label(displayedStatistics.dailyAverageML))", icon: "drop", color: .blue)
                        }
                    }.buttonStyle(.plain)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let statistics = isDemoAccount ? demoStatistics : HydrationStatistics(entries: store.entries, goalML: store.dailyGoalML, now: context.date)
                        VStack(alignment: .leading, spacing: 22) {
                            HourlyIntakeCard(statistics: statistics)
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Personal insights", systemImage: "sparkles")
                                    .font(.title3)
                                Text(statistics.comparisonInsight).font(.subheadline)
                                Divider()
                                Text(statistics.habitInsight).font(.subheadline)
                                Text("Based on your logged water. Missing logs may affect comparisons.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
                        }
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Your last 7 days").font(.title3)
                        Chart {
                            ForEach(displayedStatistics.week, id: \.date) { day in
                                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Water (fl oz)", WaterVolume.ounces(day.amount)))
                                    .foregroundStyle(LinearGradient(colors: [Color.cyan.opacity(0.6), Color.blue], startPoint: .bottom, endPoint: .top)).cornerRadius(6)
                                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                                    .accessibilityValue("\(WaterVolume.label(day.amount))")
                            }
                            RuleMark(y: .value("Current goal", WaterVolume.ounces(store.dailyGoalML)))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary)
                        }
                        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                        .frame(height: 200)
                        Text("Dashed line: your current \(WaterVolume.label(store.dailyGoalML)) goal. Average includes days without logs.")
                            .font(.caption).foregroundStyle(.secondary)
                        if displayedStatistics.week.allSatisfy({ $0.amount == 0 }) {
                            Text("Your first water log will start your chart.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
                }.padding().padding(.bottom, 80)
            }.navigationBarTitleDisplayMode(.inline)
                .background(HydrationTheme.canvas.ignoresSafeArea())
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .sheet(item: $historyMetric) { HydrationHistorySheet(metric: $0) }
        }
    }

    private var demoStatistics: HydrationStatistics {
        let calendar = Calendar.current
        let now = Date.now
        let dayStart = calendar.startOfDay(for: now)
        let fractions = [0.82, 1.05, 1.12, 0.94, 1.08, 1.03]
        var entries = fractions.enumerated().map { index, fraction in
            let day = calendar.date(byAdding: .day, value: index - 6, to: dayStart)!
            return HydrationEntry(amountML: Int(Double(store.dailyGoalML) * fraction), date: calendar.date(byAdding: .hour, value: 14, to: day)!)
        }
        entries.append(HydrationEntry(amountML: Int(Double(store.dailyGoalML) * 0.24), date: now.addingTimeInterval(-5 * 3600)))
        entries.append(HydrationEntry(amountML: Int(Double(store.dailyGoalML) * 0.18), date: now.addingTimeInterval(-2 * 3600)))
        entries.append(HydrationEntry(amountML: Int(Double(store.dailyGoalML) * 0.12), date: now.addingTimeInterval(-30 * 60)))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        entries.append(HydrationEntry(amountML: Int(Double(store.dailyGoalML) * 0.20), date: yesterday.addingTimeInterval(-4 * 3600)))
        entries.append(HydrationEntry(amountML: Int(Double(store.dailyGoalML) * 0.16), date: yesterday.addingTimeInterval(-90 * 60)))
        return HydrationStatistics(entries: entries, goalML: store.dailyGoalML, now: now, calendar: calendar)
    }
}

private struct DemoRoutineCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Your routine", systemImage: "sparkles").font(.title3)
            RoutineWeekChart(days: demoDays)
            HStack {
                Label("4 workout days", systemImage: "calendar")
                Spacer()
                Label("Usually 6 PM", systemImage: "clock")
            }.font(.caption).foregroundStyle(.secondary)
            Text("A 52-minute strength workout was recorded today. You logged water shortly afterward.").font(.subheadline)
            Divider()
            Text("Coach tip: Keep your usual bottle ready before your workout and aim to reach the afternoon checkpoint before training.")
                .font(.subheadline)
            Text("Demo routine for the test account.").font(.caption).foregroundStyle(.secondary)
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }

    private var demoDays: [RoutineDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let minutes = [0, 48, 0, 61, 45, 0, 52]
        return zip(-6...0, minutes).map { offset, duration in
            RoutineDay(date: calendar.date(byAdding: .day, value: offset, to: today)!, workoutMinutes: duration)
        }
    }
}

private struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View { VStack(alignment: .leading, spacing: 12) { Image(systemName: icon).foregroundStyle(color); Text(value).font(.title2.weight(.regular)); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(18).modifier(LiquidGlassSurface(shape: .rounded(22))) }
}

private struct HourlyIntakeCard: View {
    let statistics: HydrationStatistics

    private func hourLabel(_ hour: Int) -> String {
        let date = statistics.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: statistics.now)!
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Water by the hour").font(.title3)
            Text("Today so far alongside yesterday’s full day")
                .font(.caption).foregroundStyle(.secondary)
            Chart {
                ForEach(statistics.hourlyIntake) { hour in
                    if hour.hour <= statistics.calendar.component(.hour, from: statistics.now) {
                        BarMark(x: .value("Hour", hour.hour), y: .value("Water (fl oz)", WaterVolume.ounces(hour.todayML)))
                            .foregroundStyle(LinearGradient(colors: [Color.cyan.opacity(0.65), Color.blue], startPoint: .bottom, endPoint: .top))
                            .position(by: .value("Day", "Today"))
                            .cornerRadius(3)
                            .accessibilityLabel("Today, \(hourLabel(hour.hour))")
                            .accessibilityValue("\(WaterVolume.label(hour.todayML))")
                    }
                    BarMark(x: .value("Hour", hour.hour), y: .value("Water (fl oz)", WaterVolume.ounces(hour.yesterdayML)))
                        .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.38)], startPoint: .bottom, endPoint: .top))
                        .position(by: .value("Day", "Yesterday"))
                        .cornerRadius(3)
                        .accessibilityLabel("Yesterday, \(hourLabel(hour.hour))")
                        .accessibilityValue("\(WaterVolume.label(hour.yesterdayML))")
                }
            }
            .chartXScale(domain: -0.5...23.5)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) { Text(hourLabel(hour)) }
                    }
                }
            }
            .chartYAxisLabel("fl oz")
            .frame(height: 210)
            HStack(spacing: 16) {
                Label("Today", systemImage: "circle.fill").foregroundStyle(.blue)
                Label("Yesterday", systemImage: "circle.fill").foregroundStyle(Color.blue.opacity(0.3))
            }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            if statistics.hourlyIntake.allSatisfy({ $0.todayML == 0 && $0.yesterdayML == 0 }) {
                Text("Log your first drink to start seeing your hourly pattern.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }
}
