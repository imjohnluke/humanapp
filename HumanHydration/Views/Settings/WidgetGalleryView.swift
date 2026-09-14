import SwiftUI

struct WidgetGalleryView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var showingPro = false
    var body: some View {
        Group {
            if subscriptions.isPro { gallery }
            else {
                VStack(spacing: 18) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 44, weight: .light)).foregroundStyle(.blue)
                    Text("Hydration at a glance").font(.title2)
                    Text("Home & Lock Screen widgets are included with Human Pro.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Explore Human Pro") { showingPro = true }.buttonStyle(.borderedProminent).tint(.blue)
                }.padding(32)
            }
        }
        .sheet(isPresented: $showingPro) { ProSubscriptionSheet() }
        .navigationTitle("Widgets").navigationBarTitleDisplayMode(.inline)
        .background(HydrationTheme.canvas.ignoresSafeArea())
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your day, at a glance.").font(.title2.weight(.regular))
                Text("Live progress on your Home Screen. Updates when you log or remove water; iOS controls refresh timing.").foregroundStyle(.secondary)
                HydrationWidgetCard(amount: store.todayAmountML, goal: store.dailyGoalML)
                    .padding(18).frame(width: 170, height: 170)
                    .background { HydrationWidgetBackground().clipShape(RoundedRectangle(cornerRadius: 24)) }
                Text("Small · daily total").font(.caption).foregroundStyle(.secondary)
                HydrationWidgetCard(amount: store.todayAmountML, goal: store.dailyGoalML, expanded: true)
                    .padding(20).frame(height: 170)
                    .background { HydrationWidgetBackground().clipShape(RoundedRectangle(cornerRadius: 24)) }
                Text("Medium · goal progress").font(.caption).foregroundStyle(.secondary)
                Text("Add a widget").font(.headline.weight(.regular))
                Text("Touch and hold your Home Screen, tap Edit → Add Widget, then search for Human Hydration. For Lock Screen widgets, touch and hold your Lock Screen and choose Customize.").foregroundStyle(.secondary)
            }.padding(24)
        }
    }
}
