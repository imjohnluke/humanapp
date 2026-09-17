import SwiftUI

struct WidgetGalleryView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingPro = false

    private var amount: Int { store.todayAmountML }
    private var goal: Int { store.dailyGoalML }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if !subscriptions.isPro { proCallout }
                homeStage
                lockStage
                howToAdd
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .sheet(isPresented: $showingPro) { ProSubscriptionSheet() }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
        .background(HydrationTheme.canvas.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("At a glance")
                .font(.title.weight(.regular))
            Text("Choose a ring, a fill, or a Lock Screen glance. These previews use today’s numbers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var proCallout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Included with Human Pro", systemImage: "square.grid.2x2")
                .font(.headline.weight(.regular))
            Text("Add these widgets once Pro is active. They update when you log or remove water.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Explore Human Pro") { showingPro = true }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(LiquidGlassSurface(shape: .rounded(24)))
    }

    private var homeStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            stageLabel("Home Screen", "apps.iphone")
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    smallTile
                    fillTile
                }
                mediumTile
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { homeWallpaper }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(HydrationTheme.border, lineWidth: 1)
            )
        }
    }

    private var lockStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            stageLabel("Lock Screen", "lock.fill")
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        HydrationWidgetCard(amount: amount, goal: goal, style: .lockCircular)
                            .frame(width: 72, height: 72)
                            .padding(8)
                            .background(.white.opacity(0.08), in: Circle())
                            .environment(\.colorScheme, .dark)
                        Text("Circular").font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                    VStack(spacing: 8) {
                        HydrationWidgetCard(amount: amount, goal: goal, style: .lockRectangular)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .environment(\.colorScheme, .dark)
                        Text("Rectangular").font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.20, blue: 0.26),
                        Color(red: 0.07, green: 0.09, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
    }

    private var howToAdd: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a widget")
                .font(.headline.weight(.regular))
            step(1, "Touch and hold your Home Screen.")
            step(2, "Tap Edit, then Add Widget.")
            step(3, "Search Hydrate, then pick Daily hydration or Fill.")
            Text("For Lock Screen widgets, touch and hold the Lock Screen, tap Customize, then add a circular or rectangular widget.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(LiquidGlassSurface(shape: .rounded(24)))
    }

    private var smallTile: some View {
        widgetTile(style: .small, caption: "Daily hydration")
    }

    private var fillTile: some View {
        widgetTile(style: .fill, caption: "Fill")
    }

    private var mediumTile: some View {
        widgetTile(style: .medium, caption: "Daily hydration · medium", height: 158)
    }

    private func widgetTile(style: HydrationWidgetStyle, caption: String, height: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HydrationWidgetCard(amount: amount, goal: goal, style: style)
                .frame(maxWidth: .infinity)
                .aspectRatio(height == nil ? 1 : nil, contentMode: .fit)
                .frame(height: height)
                .background { HydrationWidgetBackground() }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stageLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.regular))
            .foregroundStyle(.primary)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.regular))
                .monospacedDigit()
                .frame(width: 28, height: 28)
                .background(.blue.opacity(0.10), in: Circle())
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var homeWallpaper: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.04, green: 0.10, blue: 0.16), Color(red: 0.06, green: 0.08, blue: 0.11)]
                : [Color(red: 0.74, green: 0.87, blue: 0.97), Color(red: 0.90, green: 0.95, blue: 1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
