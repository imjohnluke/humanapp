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
            VStack(alignment: .leading) {
                Label("Hydration", systemImage: "drop.fill").foregroundStyle(.blue)
                Spacer()
                Text("Today").font(.caption).foregroundStyle(.secondary)
                Text("\(entry.amountML) ml").font(.title2.bold())
            }.padding()
        }.configurationDisplayName("Hydration progress").description("See today's water intake at a glance.")
    }
}

struct HydrationWidgetEntry: TimelineEntry { let date: Date; let amountML: Int }
struct HydrationWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationWidgetEntry { .init(date: .now, amountML: 0) }
    func getSnapshot(in context: Context, completion: @escaping (HydrationWidgetEntry) -> Void) { completion(.init(date: .now, amountML: 0)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationWidgetEntry>) -> Void) { completion(Timeline(entries: [.init(date: .now, amountML: 0)], policy: .after(.now.addingTimeInterval(900)))) }
}
