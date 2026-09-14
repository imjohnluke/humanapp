import SwiftUI

struct SavedDrinkSheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "My glass"
    @State private var capacity = "8"
    @State private var approximate = true
    private var validCapacity: Int? {
        return WaterVolume.milliliters(capacity, minimum: 40)
    }
    var body: some View {
        NavigationStack {
            Form {
                if !store.savedDrinks.isEmpty {
                    Section("Your drinks") {
                        ForEach(store.savedDrinks) { drink in
                            Button {
                                store.selectedDrinkID = drink.id
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(drink.name)
                                        Text("\(drink.isEstimate ? "About " : "")\(WaterVolume.label(drink.capacityML))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if store.selectedDrink?.id == drink.id { Image(systemName: "checkmark") }
                                }
                            }
                            .swipeActions { Button("Delete", role: .destructive) { store.deleteDrink(drink) } }
                        }
                    }
                }
                Section("Save a usual drink") {
                    TextField("Name", text: $name)
                    Menu("Choose an approximate size") {
                        Button("Small glass · about 7 fl oz") { name = "My glass"; capacity = "7"; approximate = true }
                        Button("Medium glass · about 10 fl oz") { name = "My glass"; capacity = "10"; approximate = true }
                        Button("Large glass · about 15 fl oz") { name = "My glass"; capacity = "15"; approximate = true }
                        Button("Water bottle · about 17 fl oz") { name = "My bottle"; capacity = "17"; approximate = true }
                    }
                    HStack {
                        TextField("Full capacity", text: $capacity).keyboardType(.decimalPad)
                        Text("fl oz").foregroundStyle(.secondary)
                    }
                    Toggle("Approximate size", isOn: $approximate)
                    Text("Use the full capacity on your bottle’s label if you know it. Glass sizes vary; presets are estimates.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Save drink") {
                        guard let value = validCapacity else { return }
                        store.saveDrink(name: name, capacityML: value, isEstimate: approximate)
                        dismiss()
                    }.disabled(validCapacity == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("My usual drinks").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }.tint(.blue)
    }
}

struct DrinkSizeSheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var size = "10"
    private let options = BottleCatalog.options
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose your size").font(.title2.weight(.regular))
                Text("How much does your full glass or bottle hold?")
                    .font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(options, id: \.0) { option in
                        Button {
                            let finish = store.bottle?.assetName == option.0
                                ? (store.bottle?.colorName ?? "clear") : "clear"
                            store.selectBottle(WaterBottle(name: option.1, capacityML: option.2,
                                                           assetName: option.0, colorName: finish))
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                BottleFinishIcon(asset: option.0, finish: "clear")
                                    .frame(height: 76)
                                Text(BottleCatalog.displayName(option.1)).font(.caption).multilineTextAlignment(.center)
                                Text(BottleCatalog.sizeLabel(capacityML: option.2)).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).frame(minHeight: 128)
                                .padding(8)
                                .modifier(LiquidGlassSurface(shape: .rounded(16)))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("\(BottleCatalog.displayName(option.1)), \(BottleCatalog.sizeLabel(capacityML: option.2))")
                    }
                }
                Text("Sizes are approximate. Use your bottle’s label if you know it.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("Custom size", text: $size).keyboardType(.decimalPad)
                    Text("fl oz").foregroundStyle(.secondary)
                    Button("Use size") {
                        if let value = WaterVolume.milliliters(size, minimum: 40) { choose(value) }
                    }.disabled(WaterVolume.milliliters(size, minimum: 40) == nil)
                }.padding(14).modifier(LiquidGlassSurface(shape: .rounded(16)))
            }.padding(24)
        }
        .onAppear { size = WaterVolume.input(store.selectedDrink?.capacityML ?? 300) }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground { HydrationTheme.canvas }
        .tint(.blue)
    }
    private func choose(_ capacity: Int) {
        guard (40...7570).contains(capacity) else { return }
        let name = capacity < 500 ? "My glass" : "My bottle"
        if let existing = store.savedDrinks.first(where: { $0.name == name && $0.capacityML == capacity }) {
            store.selectedDrinkID = existing.id
        } else {
            store.saveDrink(name: name, capacityML: capacity, isEstimate: true)
        }
        dismiss()
    }
}
