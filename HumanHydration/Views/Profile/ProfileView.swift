import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: HydrationStore

    var body: some View {
        ZStack {
            HydrationTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle().fill(.thinMaterial).frame(width: 92, height: 92)
                                .overlay(Image(systemName: "person.fill").font(.system(size: 38)).foregroundStyle(.secondary))
                            Image(systemName: "pencil.circle.fill").font(.title2).foregroundStyle(.black).background(.white, in: Circle())
                        }
                        Text(store.displayName.isEmpty ? "Your name" : store.displayName).font(.title2.weight(.semibold))
                        Text("Hydration score").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(Int(store.todayProgress * 100))").font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 18)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("My bottle collection").font(.headline)
                        HStack(spacing: 16) {
                            if let bottle = store.bottle { DrinkIcon(name: bottle.assetName, tint: profileColor(bottle.colorName)).frame(width: 64, height: 78) }
                            else { Image(systemName: "waterbottle.fill").font(.largeTitle).foregroundStyle(.blue).frame(width: 64, height: 78) }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(store.bottle?.name ?? "No bottle selected").font(.title3.weight(.semibold))
                                Text(store.bottle.map { "\($0.capacityML) ml capacity" } ?? "Choose one from Home").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).modifier(LiquidGlassSurface(shape: .rounded(24)))

                    HStack(spacing: 12) {
                        ProfileStat(value: "1", label: "Day streak", icon: "flame.fill", color: .orange)
                        ProfileStat(value: "\(store.todayAmountML) ml", label: "Today", icon: "drop.fill", color: .blue)
                    }
                    HStack(spacing: 12) {
                        ProfileStat(value: "\(store.dailyGoalML) ml", label: "Daily goal", icon: "target", color: .green)
                        ProfileStat(value: "\(store.entries.count)", label: "Total logs", icon: "list.bullet", color: .purple)
                    }
                }.padding()
            }
        }
    }

    private func profileColor(_ name: String) -> Color {
        switch name { case "white": return .white; case "purple": return .purple; case "pink": return .pink; case "blue": return .blue; case "navy": return Color(red: 0.04, green: 0.10, blue: 0.25); case "black": return .black; default: return .white }
    }
}

private struct ProfileStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { Image(systemName: icon).foregroundStyle(color); Text(value).font(.title3.bold()); Text(label).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).modifier(LiquidGlassSurface(shape: .rounded(20)))
    }
}
