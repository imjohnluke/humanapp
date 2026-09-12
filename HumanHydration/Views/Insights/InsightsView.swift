import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var showingSettings = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Text("Progress").font(.system(size: 38, weight: .bold)); Spacer(); Button { showingSettings = true } label: { Image(systemName: "gearshape").font(.headline).foregroundStyle(.black) } }
                    HStack(spacing: 14) {
                        StatCard(title: "Day streak", value: "1 day", icon: "flame.fill", color: .orange)
                        StatCard(title: "Daily average", value: "0 ml", icon: "drop.fill", color: .blue)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("Hydration this week").font(.title3.bold()); Spacer(); Text("Goal: \(store.dailyGoalML) ml").font(.caption).foregroundStyle(.secondary) }
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(0..<7, id: \.self) { index in
                                let height = CGFloat(index == 6 ? max(store.todayProgress, 0.08) : 0.18 + Double(index % 3) * 0.12)
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 8).fill(index == 6 ? .blue : .blue.opacity(0.18)).frame(height: 150 * height)
                                    Text(["S", "M", "T", "W", "T", "F", "S"][index]).font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .bottom)
                            }
                        }.frame(height: 190, alignment: .bottom)
                    }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
                }.padding()
            }.navigationBarTitleDisplayMode(.inline)
                .background(HydrationTheme.canvas.ignoresSafeArea())
                .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
}

private struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View { VStack(alignment: .leading, spacing: 12) { Image(systemName: icon).foregroundStyle(color); Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(18).modifier(LiquidGlassSurface(shape: .rounded(22))) }
}
