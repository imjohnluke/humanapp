import WidgetKit
import SwiftUI

@main
struct HumanHydrationWidgetBundle: WidgetBundle {
    var body: some Widget {
        HumanHydrationWidget()
    }
}

struct HumanHydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HumanHydrationWidget", provider: HydrationWidgetProvider()) { entry in
            HydrationWidgetView(entry: entry)
                .containerBackground(for: .widget) { HydrationWidgetBackground() }
        }.configurationDisplayName("Daily hydration")
            .description("Your water logged, and what’s left today.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct HydrationWidgetEntry: TimelineEntry {
    let date: Date
    let data: HydrationWidgetData?
    var amount: Int { data?.amount(on: date) ?? 0 }
    var goal: Int { data?.goalML ?? 2400 }
    var progress: Double { min(Double(amount) / Double(max(goal, 1)), 1) }
}

struct HydrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HydrationWidgetEntry
    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.progress) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                if entry.data == nil { Image(systemName: "lock") }
                else { Text("\(Int(entry.progress * 100))%") }
            }.gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("human", systemImage: "drop.fill").font(.headline)
                Text(entry.data == nil ? "Open app to sign in" : "\(max(entry.goal - entry.amount, 0)) ml left today").font(.caption)
                ProgressView(value: entry.progress)
            }
        default:
            HydrationWidgetCard(amount: entry.amount, goal: entry.goal, expanded: family == .systemMedium, signedIn: entry.data != nil)
        }
    }
}

struct HydrationWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationWidgetEntry {
        .init(date: .now, data: .init(goalML: 2400, drinks: [.init(date: .now, amountML: 1200)]))
    }
    func getSnapshot(in context: Context, completion: @escaping (HydrationWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : .init(date: .now, data: .read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationWidgetEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        let data = HydrationWidgetData.read()
        completion(Timeline(entries: [.init(date: now, data: data), .init(date: midnight, data: data)], policy: .after(midnight)))
    }
}
