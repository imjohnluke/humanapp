import SwiftUI

struct HydrationWidgetCard: View {
    let amount: Int
    let goal: Int
    var expanded = false
    var signedIn = true
    private var progress: Double { min(Double(amount) / Double(max(goal, 1)), 1) }
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                if signedIn {
                    Text(amount >= goal ? "Goal reached" : "Today’s hydration").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text("\(WaterVolume.label(max(goal - amount, 0)))")
                        .font(.system(size: expanded ? 29 : 25, weight: .semibold)).minimumScaleFactor(0.65).lineLimit(1)
                    Text("left · \(WaterVolume.label(amount)) logged").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("A little water.\nA better day.").font(.headline)
                    Spacer(minLength: 4)
                    Text("Open the app to sign in").font(.caption).foregroundStyle(.secondary)
                }
            }
            if expanded {
                ZStack {
                    Circle().trim(from: 0.09, to: 0.91).stroke(Color.primary.opacity(0.09), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    Circle().trim(from: 0.09, to: 0.09 + 0.82 * progress).stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    VStack(spacing: 3) {
                        Image(systemName: "drop.fill").foregroundStyle(.blue)
                        Text("\(Int(progress * 100))%").font(.caption.bold())
                    }.rotationEffect(.degrees(-90))
                }.rotationEffect(.degrees(90)).frame(width: 98, height: 98)
            }
        }.foregroundStyle(.primary).accessibilityElement(children: .combine)
    }
}

struct HydrationWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.035, green: 0.08, blue: 0.13), Color(red: 0.06, green: 0.18, blue: 0.29)]
                : [.white, Color(red: 0.83, green: 0.92, blue: 1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
