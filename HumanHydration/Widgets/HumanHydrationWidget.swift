import WidgetKit
import SwiftUI

@main
struct HumanHydrationWidgetBundle: WidgetBundle {
    var body: some Widget {
        HumanHydrationWidget()
        HumanHydrationFillWidget()
    }
}

struct HumanHydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HydrationWidgetData.kind, provider: HydrationWidgetProvider()) { entry in
            HydrationWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily hydration")
        .description("Your ring, and how much is left today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct HumanHydrationFillWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HydrationWidgetData.fillKind, provider: HydrationWidgetProvider()) { entry in
            HydrationWidgetView(entry: entry, fill: true)
        }
        .configurationDisplayName("Fill")
        .description("The square fills with blue as you hydrate.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct HydrationWidgetEntry: TimelineEntry {
    let date: Date
    let data: HydrationWidgetData?
    var amount: Int { data?.amount(on: date) ?? 0 }
    var goal: Int { data?.goalML ?? 3785 }
    var progress: Double { min(Double(amount) / Double(max(goal, 1)), 1) }
}

struct HydrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HydrationWidgetEntry
    var fill = false
    var body: some View {
        HydrationWidgetCard(
            amount: entry.amount,
            goal: entry.goal,
            style: style,
            signedIn: entry.data != nil,
            includeFill: !fill
        )
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                AccessoryWidgetBackground()
            default:
                if fill {
                    ZStack {
                        HydrationWidgetBackground()
                        HydrationWidgetWaterFill(progress: entry.data == nil ? 0 : entry.progress)
                    }
                } else {
                    HydrationWidgetBackground()
                }
            }
        }
    }

    private var style: HydrationWidgetStyle {
        if fill { return .fill }
        switch family {
        case .systemMedium: return .medium
        case .accessoryCircular: return .lockCircular
        case .accessoryRectangular: return .lockRectangular
        default: return .small
        }
    }
}

struct HydrationWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationWidgetEntry {
        .init(date: .now, data: .init(goalML: 3785, drinks: [.init(date: .now, amountML: 1500)]))
    }
    func getSnapshot(in context: Context, completion: @escaping (HydrationWidgetEntry) -> Void) {
        completion(.init(date: .now, data: HydrationWidgetData.read() ?? (context.isPreview ? placeholder(in: context).data : nil)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationWidgetEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400))
        let data = HydrationWidgetData.read()
        completion(Timeline(entries: [.init(date: now, data: data), .init(date: midnight, data: data)], policy: .after(midnight)))
    }
}
