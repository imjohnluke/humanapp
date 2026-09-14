import SwiftUI
import StoreKit

struct ProSubscriptionSheet: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var showingManage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Human Pro").font(.largeTitle.weight(.regular))
                    Text("See the patterns behind your hydration and keep today’s progress visible at a glance.")
                        .foregroundStyle(.secondary)
                    Label("Advanced hydration insights", systemImage: "chart.bar.xaxis")
                    Label("Hourly and 7-day trends", systemImage: "chart.xyaxis.line")
                    Label("Home & Lock Screen widgets", systemImage: "square.grid.2x2")
                    if subscriptions.isPro {
                        Label("Your Pro access is active", systemImage: "checkmark.circle.fill").foregroundStyle(.blue)
                        Button("Manage Apple subscription") { showingManage = true }
                    } else if subscriptions.purchasesAvailable && AppConfig.privacyPolicyURL != nil && !subscriptions.products.isEmpty {
                        ForEach(subscriptions.products, id: \.id) { product in
                            Button { Task { await subscriptions.purchase(product, auth: auth) } } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(product.displayName).font(.headline.weight(.regular))
                                        Text("\(product.displayPrice) / month").font(.subheadline)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.padding(18).frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).modifier(LiquidGlassSurface(shape: .rounded(20)))
                                .disabled(subscriptions.isBusy)
                        }
                    } else if !subscriptions.isBusy {
                        Text("Pro subscriptions are getting ready. Purchasing isn’t available yet.").foregroundStyle(.secondary)
                        Button("Check subscription again") { Task { await subscriptions.loadProducts(auth: auth) } }
                    }
                    if subscriptions.isBusy { ProgressView() }
                    if let message = subscriptions.message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
                    Button("Restore purchases") { Task { await subscriptions.restore(auth: auth) } }
                        .disabled(subscriptions.isBusy)
                    HStack(spacing: 20) {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        if let privacyURL = AppConfig.privacyPolicyURL { Link("Privacy", destination: privacyURL) }
                    }.font(.caption)
                }.padding(24)
            }
            .background(HydrationTheme.canvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task { await subscriptions.loadProducts(auth: auth) }
        .manageSubscriptionsSheet(isPresented: $showingManage)
    }
}
