import WidgetKit
import SwiftUI

@main
struct HumanHydrationWidgetBundle: WidgetBundle {
    var body: some Widget {
        HumanHydrationWidget()
        HumanHydrationFillWidget()
        HydrationLiveActivityWidget()
    }
}

struct HumanHydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HydrationWidgetData.kind, provider: HydrationWidgetProvider()) { entry in
            HydrationWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily hydration")
        .description("Your ring, how much is left, and a button to log your usual drink.")
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
        .description("The square fills with blue. Tap + to log your usual drink.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct HydrationWidgetEntry: TimelineEntry {
    let date: Date
    let data: HydrationWidgetData?
    var amount: Int { data?.amount(on: date) ?? 0 }
    var goal: Int { data?.goalML ?? 3785 }
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
            showsLogButton: entry.data != nil && showsLogButton,
            logAmountML: entry.data?.logAmountML ?? 250,
            logName: entry.data?.logName ?? "Glass"
        )
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                AccessoryWidgetBackground()
            default:
                HydrationWidgetBackground()
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

    private var showsLogButton: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return false
        default: return true
        }
    }
}

struct HydrationLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HydrationActivityAttributes.self) { context in
            HydrationLiveBanner(state: context.state)
                .activityBackgroundTint(Color(red: 0.04, green: 0.09, blue: 0.14))
                .widgetURL(URL(string: "humanhydration://today"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Today", systemImage: "drop.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int((context.state.progress * 100).rounded()))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(context.state.reached ? "Goal reached" : "\(WaterVolume.label(context.state.remainingML)) left")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                            HydrationLiveFill(progress: context.state.progress)
                        }
                        Button(intent: LogWaterIntent(amountML: context.state.logAmountML)) {
                            VStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                Text("Log")
                                    .font(.caption.weight(.semibold))
                                Text(WaterVolume.label(context.state.logAmountML))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 64)
                        }
                        .buttonStyle(.plain)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Log \(context.state.logName), \(WaterVolume.label(context.state.logAmountML))")
                    }
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text("\(Int((context.state.progress * 100).rounded()))%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
            }
            .widgetURL(URL(string: "humanhydration://today"))
        }
    }
}

private struct HydrationLiveBanner: View {
    let state: HydrationActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Today", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(state.reached ? "Goal reached" : "\(WaterVolume.label(state.remainingML)) left")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                HydrationLiveFill(progress: state.progress)
            }
            Button(intent: LogWaterIntent(amountML: state.logAmountML)) {
                VStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                    Text("Log \(WaterVolume.label(state.logAmountML))")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 120)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
            .background(.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("Log \(state.logName), \(WaterVolume.label(state.logAmountML))")
        }
        .padding(16)
    }
}

private struct HydrationLiveFill: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule().fill(LinearGradient(
                    colors: [Color(red: 0.62, green: 0.84, blue: 1), Color(red: 0.12, green: 0.48, blue: 0.91)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: max(8, geometry.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 8)
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
