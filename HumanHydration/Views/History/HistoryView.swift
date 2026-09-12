import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: HydrationStore
    private let days = Array(-6...0)

    var body: some View {
        NavigationStack {
            List {
                ForEach(days, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
                    let amount = store.amount(on: date)
                    let dayEntries = store.entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date }
                    Section {
                        HStack {
                            ProgressView(value: Double(amount), total: Double(store.dailyGoalML)).frame(width: 90)
                            Spacer()
                            Text("\(amount) ml").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ForEach(dayEntries) { entry in
                            HStack { Image(systemName: "drop.fill").foregroundStyle(.blue); Text("\(entry.amountML) ml"); Spacer(); Text(entry.date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary) }
                        }
                    } header: {
                        Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
