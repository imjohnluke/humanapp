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
                    HStack { Text("Progress").font(.system(size: 38, weight: .regular)); Spacer(); Button { showingSettings = true } label: { Image(systemName: "gearshape").font(.headline.weight(.regular)).foregroundStyle(.black) } }
                    HStack(spacing: 14) {
                        Button { historyMetric = .streak } label: {
                            StatCard(title: "Day streak", value: "\(store.currentStreak) days", icon: "flame", color: .black)
                        }
                        Button { historyMetric = .average } label: {
                            StatCard(title: "Daily average", value: "\(store.dailyAverageML) ml", icon: "drop", color: .black)
                        }
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Your last 7 days").font(.title3)
                        Chart {
                            ForEach(store.statistics.week, id: \.date) { day in
                                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Water (ml)", day.amount))
                                    .foregroundStyle(Color.blue.opacity(0.45)).cornerRadius(6)
                                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                                    .accessibilityValue("\(day.amount) milliliters")
                            }
                            RuleMark(y: .value("Current goal", store.dailyGoalML))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary)
                        }
                        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                        .frame(height: 200)
                        Text("Dashed line: your current \(store.dailyGoalML) ml goal. Average includes days without logs.")
                            .font(.caption).foregroundStyle(.secondary)
                        if store.statistics.week.allSatisfy({ $0.amount == 0 }) {
                            Text("Your first water log will start your chart.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
                }.padding()
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
