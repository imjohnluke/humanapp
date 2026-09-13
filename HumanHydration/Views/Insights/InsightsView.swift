import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var showingSettings = false
    @State private var historyMetric: HydrationHistoryMetric?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Insights").font(.system(size: 38, weight: .regular))
                    HealthRoutineCard()
                    Text("Your progress").font(.title3)
                    HStack(spacing: 14) {
                        Button { historyMetric = .streak } label: {
                            StatCard(title: "Day streak", value: "\(store.currentStreak) days", icon: "flame", color: .black)
                        }
                        Button { historyMetric = .average } label: {
                            StatCard(title: "Daily average", value: "\(WaterVolume.label(store.dailyAverageML))", icon: "drop", color: .black)
                        }
                    }.buttonStyle(.plain)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let statistics = HydrationStatistics(entries: store.entries, goalML: store.dailyGoalML, now: context.date)
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
                            ForEach(store.statistics.week, id: \.date) { day in
                                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Water (fl oz)", WaterVolume.ounces(day.amount)))
                                    .foregroundStyle(Color.blue.opacity(0.45)).cornerRadius(6)
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
                        if store.statistics.week.allSatisfy({ $0.amount == 0 }) {
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
                            .foregroundStyle(by: .value("Day", "Today"))
                            .position(by: .value("Day", "Today"))
                            .cornerRadius(3)
                            .accessibilityLabel("Today, \(hourLabel(hour.hour))")
                            .accessibilityValue("\(WaterVolume.label(hour.todayML))")
                    }
                    BarMark(x: .value("Hour", hour.hour), y: .value("Water (fl oz)", WaterVolume.ounces(hour.yesterdayML)))
                        .foregroundStyle(by: .value("Day", "Yesterday"))
                        .position(by: .value("Day", "Yesterday"))
                        .cornerRadius(3)
                        .accessibilityLabel("Yesterday, \(hourLabel(hour.hour))")
                        .accessibilityValue("\(WaterVolume.label(hour.yesterdayML))")
                }
            }
            .chartForegroundStyleScale(["Today": Color.blue, "Yesterday": Color.blue.opacity(0.25)])
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
            if statistics.hourlyIntake.allSatisfy({ $0.todayML == 0 && $0.yesterdayML == 0 }) {
                Text("Log your first drink to start seeing your hourly pattern.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }
}
