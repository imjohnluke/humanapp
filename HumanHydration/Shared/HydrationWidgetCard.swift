import SwiftUI

enum HydrationWidgetStyle {
    case small, fill, medium, lockCircular, lockRectangular
}

struct HydrationWidgetCard: View {
    let amount: Int
    let goal: Int
    var style: HydrationWidgetStyle = .small
    var signedIn = true
    var includeFill = true

    private var progress: Double { min(Double(amount) / Double(max(goal, 1)), 1) }
    private var remaining: Int { max(goal - amount, 0) }
    private var reached: Bool { goal > 0 && amount >= goal }

    var body: some View {
        Group {
            switch style {
            case .small: smallLayout
            case .fill: fillLayout
            case .medium: mediumLayout
            case .lockCircular: lockCircularLayout
            case .lockRectangular: lockRectangularLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fontDesign(.rounded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var smallLayout: some View {
        VStack(spacing: 6) {
            HydrationWidgetRing(progress: signedIn ? progress : 0, lineWidth: 10, dropSize: 13, percentFont: .caption.weight(.regular))
                .frame(width: 78, height: 78)
            if signedIn {
                Text(reached ? "Goal reached" : WaterVolume.number(remaining))
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(reached ? WaterVolume.label(amount) : "fl oz left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            } else {
                Text("A little water.")
                    .font(.subheadline.weight(.regular))
                    .multilineTextAlignment(.center)
                Text("Open the app")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var fillLayout: some View {
        let fill = signedIn ? progress : 0
        return ZStack(alignment: .bottomTrailing) {
            if includeFill { HydrationWidgetWaterFill(progress: fill) }
            Text(signedIn ? "\(Int((fill * 100).rounded()))%" : "")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(fill >= 0.16 ? Color.white.opacity(0.95) : Color.primary.opacity(0.42))
                .shadow(color: fill >= 0.16 ? .black.opacity(0.18) : .clear, radius: 4, y: 1)
                .padding(.trailing, 10)
                .padding(.bottom, 8)
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(signedIn ? (reached ? "Goal reached" : "Today") : "human")
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if signedIn {
                    Text(reached ? WaterVolume.number(amount) : WaterVolume.number(remaining))
                        .font(.system(size: 34, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(reached ? "fl oz logged" : "fl oz left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(WaterVolume.label(amount)) of \(WaterVolume.label(goal))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                } else {
                    Text("A little water.\nA better day.")
                        .font(.title3.weight(.regular))
                    Text("Open Hydrate to update")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HydrationWidgetRing(progress: signedIn ? progress : 0, lineWidth: 12, dropSize: 16, percentFont: .subheadline.weight(.regular))
                .frame(width: 104, height: 104)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var lockCircularLayout: some View {
        Gauge(value: signedIn ? progress : 0) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            if signedIn {
                Text("\(Int(progress * 100))")
                    .font(.system(.caption, design: .rounded).weight(.regular))
                    .monospacedDigit()
            } else {
                Image(systemName: "drop")
            }
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var lockRectangularLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Today", systemImage: "drop.fill")
                .font(.headline.weight(.regular))
            if signedIn {
                Text(reached ? "Goal reached" : "\(WaterVolume.label(remaining)) left")
                    .font(.caption)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                ProgressView(value: progress)
                    .tint(.blue)
            } else {
                Text("Open Hydrate")
                    .font(.caption)
                ProgressView(value: 0)
            }
        }
        .padding(.horizontal, 2)
    }

    private var accessibilityText: String {
        guard signedIn else { return "Open Hydrate to update widgets" }
        return "\(WaterVolume.label(amount)) of \(WaterVolume.label(goal)), \(Int(progress * 100)) percent"
    }
}

struct HydrationWidgetRing: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var dropSize: CGFloat = 15
    var percentFont: Font = .caption.weight(.regular)

    private let start = 0.08
    private let end = 0.92

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        ZStack {
            Circle()
                .trim(from: start, to: end)
                .stroke(.primary.opacity(0.10), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle()
                .trim(from: start, to: start + ((end - start) * max(clamped, 0.001)))
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.88, green: 0.95, blue: 1.0),
                            Color(red: 0.38, green: 0.69, blue: 0.96),
                            Color(red: 0.12, green: 0.48, blue: 0.91)
                        ],
                        center: .center,
                        startAngle: .degrees(start * 360),
                        endAngle: .degrees((start + (end - start) * max(clamped, 0.001)) * 360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .opacity(clamped == 0 ? 0 : 1)
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: dropSize, weight: .regular))
                    .foregroundStyle(.blue)
                Text("\(Int(clamped * 100))%")
                    .font(percentFont)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct HydrationWidgetWaterFill: View {
    var progress: Double

    var body: some View {
        let fill = min(max(progress, 0), 1)
        GeometryReader { _ in
            ZStack {
                HydrationWidgetWater(progress: fill, phase: 0.35, amplitude: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.62, green: 0.84, blue: 1.0),
                                Color(red: 0.20, green: 0.54, blue: 0.95),
                                Color(red: 0.08, green: 0.38, blue: 0.84)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                HydrationWidgetWater(progress: fill, phase: 2.1, amplitude: 3.5)
                    .fill(Color.white.opacity(fill >= 1 ? 0.08 : 0.20))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct HydrationWidgetWater: Shape {
    var progress: Double
    var phase: Double
    var amplitude: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let fill = min(max(progress, 0), 1)
        if fill <= 0 { return Path() }
        if fill >= 1 { return Path(rect) }
        var path = Path()
        let y = rect.height * (1 - fill)
        let width = max(rect.width, 1)
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: y))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let wave = sin((x / width) * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y + wave))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct HydrationWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        LinearGradient(
            stops: colorScheme == .dark
                ? [
                    .init(color: Color(red: 0.03, green: 0.09, blue: 0.15), location: 0),
                    .init(color: Color(red: 0.05, green: 0.08, blue: 0.12), location: 1)
                ]
                : [
                    .init(color: Color(red: 0.86, green: 0.93, blue: 0.99), location: 0),
                    .init(color: Color(red: 0.97, green: 0.99, blue: 1), location: 0.55),
                    .init(color: .white, location: 1)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
