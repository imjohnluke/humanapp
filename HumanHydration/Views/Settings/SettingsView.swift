import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    var title: String = "Settings"
    var body: some View {
        NavigationStack {
            Form {
                Section("Daily goal") {
                    Stepper("\(store.dailyGoalML) ml", value: $store.dailyGoalML, in: 500...6000, step: 100)
                }
                Section("Bottle") {
                    Toggle("I use a water bottle", isOn: Binding(get: { store.bottle != nil }, set: { store.bottle = $0 ? WaterBottle() : nil }))
                    if let bottle = store.bottle { Text("\(bottle.name) · \(bottle.capacityML) ml").foregroundStyle(.secondary) }
                }
                Section("Coming next") { Label("Reminders", systemImage: "bell"); Label("Apple Health", systemImage: "heart.fill"); Label("Home Screen widgets", systemImage: "square.grid.2x2") }
            }.navigationTitle(title)
        }
    }
}
