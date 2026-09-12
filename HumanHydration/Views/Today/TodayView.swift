import SwiftUI
import UIKit

struct TodayView: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var selectedDate = Date.now
    @State private var showingBottlePicker = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            HydrationTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        HStack(spacing: 8) {
                            BundledLogoImage(name: "human-logo-mark")
                                .frame(width: 28, height: 28)
                            Text("human").font(.title3.weight(.medium)).foregroundStyle(.black)
                        }
                        Spacer()
                        Button { showingSettings = true } label: { Image(systemName: "gearshape").font(.headline).foregroundStyle(.black) }
                        Label("1", systemImage: "flame.fill").font(.headline).foregroundStyle(.orange).padding(.horizontal, 16).padding(.vertical, 11).modifier(LiquidGlassSurface(shape: .capsule))
                    }
                    DayStrip(selectedDate: $selectedDate)

                    if Calendar.current.isDateInToday(selectedDate) {
                        TodayHeroCard(store: store)
                        HStack(spacing: 12) {
                            BentoCard(icon: "flame.fill", title: "Streak", value: "1 day", color: .orange)
                            BentoCard(icon: "drop.fill", title: "Daily average", value: "\(store.todayAmountML) ml", color: .blue)
                        }
                    } else {
                        PastDayCard(amount: store.amount(on: selectedDate), goal: store.dailyGoalML, date: selectedDate)
                    }

                    DayEntriesView(date: selectedDate)

                    if Calendar.current.isDateInToday(selectedDate) {
                        Button { showingBottlePicker = true } label: {
                            HStack(spacing: 14) {
                                if let bottle = store.bottle {
                                    DrinkIcon(name: bottle.assetName, tint: bottleColor(bottle.colorName)).frame(width: 54, height: 58)
                                } else {
                                    Image(systemName: "plus.viewfinder").font(.title2).foregroundStyle(.blue).frame(width: 54, height: 58)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("My bottle collection").font(.headline)
                                    Text(store.bottle.map { "\($0.name) · \($0.capacityML) ml" } ?? "Choose a bottle to get started").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).foregroundStyle(.primary).modifier(LiquidGlassSurface(shape: .rounded(20)))
                        ShareLink(item: "I’ve had \(store.todayAmountML) ml of water today with Human Hydration 💧") {
                            Label("Share today’s progress", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingBottlePicker) { BottlePickerSheet() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    private func bottleColor(_ name: String) -> Color {
        switch name { case "white": return .white; case "purple": return .purple; case "pink": return .pink; case "blue": return .blue; case "navy": return Color(red: 0.04, green: 0.10, blue: 0.25); case "black": return .black; default: return .white }
    }
}

private struct BottlePickerSheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAsset = "bottle"
    @State private var selectedColor = "blue"

    private let options: [(String, String, Int)] = [("glass", "Glass", 250), ("bottle", "Bottle", 500), ("gatorade", "Sport bottle", 750), ("stanley", "Tumbler", 1000), ("big", "Large bottle", 2000), ("gallon", "Gallon", 3785)]
    private let colors: [(String, Color)] = [("white", .white), ("purple", .purple), ("pink", .pink), ("blue", .blue), ("navy", Color(red: 0.04, green: 0.10, blue: 0.25)), ("black", .black)]
    private let unlockedColors = ["white", "pink", "blue"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Choose your bottle").font(.title.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 14)], spacing: 14) {
                        ForEach(options, id: \.0) { option in
                            Button { selectedAsset = option.0 } label: {
                                VStack(spacing: 8) {
                                    DrinkIcon(name: option.0, tint: selectedAsset == option.0 && (option.0 == "big" || option.0 == "stanley") ? selectedColorValue : nil).frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 16))
                                    Text(option.1).font(.subheadline.weight(.medium))
                                }.frame(maxWidth: .infinity).padding(10).background(selectedAsset == option.0 ? Color.blue.opacity(0.12) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain).foregroundStyle(.primary)
                        }
                    }
                    if selectedAsset == "big" || selectedAsset == "stanley" {
                        Text("Choose a color").font(.headline)
                        HStack(spacing: 14) {
                            ForEach(colors, id: \.0) { option in
                                Button { if unlockedColors.contains(option.0) { selectedColor = option.0 } } label: {
                                    Circle().fill(option.1).frame(width: 34, height: 34).overlay(Circle().stroke(selectedColor == option.0 ? .blue : .gray.opacity(0.25), lineWidth: selectedColor == option.0 ? 3 : 1)).overlay { if !unlockedColors.contains(option.0) { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.white).shadow(radius: 2) } }
                                }.buttonStyle(.plain).opacity(unlockedColors.contains(option.0) ? 1 : 0.68)
                            }
                        }
                    }
                    Button {
                        let chosen = options.first { $0.0 == selectedAsset }!
                        store.bottle = WaterBottle(name: chosen.1, capacityML: chosen.2, assetName: chosen.0, colorName: selectedColor)
                        dismiss()
                    } label: { Text("Use this bottle").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15) }.buttonStyle(.borderedProminent).tint(.black)
                }.padding()
            }.navigationTitle("Bottle setup").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.large])
    }

    private var selectedColorValue: Color { colors.first { $0.0 == selectedColor }?.1 ?? .pink }
}

private struct BundledLogoImage: View {
    let name: String

    var body: some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png"), let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 28, height: 28, alignment: .leading).clipped()
        } else if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "DrinkIcons"), let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 28, height: 28, alignment: .leading).clipped()
        } else if let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 28, height: 28, alignment: .leading).clipped()
        } else {
            EmptyView()
        }
    }

}

private struct DayStrip: View {
    @Binding var selectedDate: Date
    private let days = Array(-5...0)
    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                VStack(spacing: 7) {
                    Text(date, format: .dateTime.weekday(.narrow)).font(.subheadline.weight(.semibold))
                    Text(date, format: .dateTime.day()).font(.headline)
                }.frame(maxWidth: .infinity).padding(.vertical, 10).foregroundStyle(.primary).modifier(isSelected ? LiquidGlassSurface(shape: .rounded(10)) : LiquidGlassSurface(shape: .none))
                    .contentShape(Rectangle()).onTapGesture { selectedDate = date }
            }
        }
    }
}

private struct TodayHeroCard: View {
    @ObservedObject var store: HydrationStore
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Today’s hydration").font(.subheadline.weight(.regular)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(max(store.dailyGoalML - store.todayAmountML, 0))").font(.system(size: 30, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.55).allowsTightening(true)
                    Text("ml left").font(.body)
                }
            }
            Spacer()
            HydrationProgressView(progress: store.todayProgress, amount: store.todayAmountML, goal: store.dailyGoalML).frame(width: 170, height: 170)
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }
}

private struct PastDayCard: View {
    let amount: Int
    let goal: Int
    let date: Date
    private var progress: Double { min(Double(amount) / Double(max(goal, 1)), 1) }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { VStack(alignment: .leading, spacing: 4) { Text(date, format: .dateTime.weekday(.wide)); Text("Daily result").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName: progress >= 1 ? "checkmark.circle.fill" : "drop.fill").font(.title).foregroundStyle(progress >= 1 ? .green : .blue) }
            HStack(alignment: .firstTextBaseline) { Text("\(amount) ml").font(.system(size: 38, weight: .bold, design: .rounded)); Spacer(); Text("\(Int(progress * 100))% of goal").font(.subheadline.weight(.medium)).foregroundStyle(.secondary) }
            ProgressView(value: progress).tint(progress >= 1 ? .green : .blue)
            Text(progress >= 1 ? "Goal reached" : "\(max(goal - amount, 0)) ml short of your goal").font(.subheadline).foregroundStyle(.secondary)
        }.padding(24).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }
}

private struct DayEntriesView: View {
    @EnvironmentObject private var store: HydrationStore
    let date: Date

    private var dayEntries: [HydrationEntry] {
        store.entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(Calendar.current.isDateInToday(date) ? "Today’s" : "Day’s") entries").font(.headline)
            if dayEntries.isEmpty {
                Text("No water logged yet").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ForEach(dayEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill").foregroundStyle(.blue)
                        Text("\(entry.amountML) ml").font(.subheadline.weight(.medium))
                        Spacer()
                        Text(entry.date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                        Button(role: .destructive) { store.removeEntry(entry) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                    if entry.id != dayEntries.last?.id { Divider() }
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).modifier(LiquidGlassSurface(shape: .rounded(20)))
    }
}

struct HydrationProgressView: View {
    let progress: Double
    let amount: Int
    let goal: Int

    var body: some View {
        TimelineView(.animation) { context in
            ZStack {
                let start = 0.08
                let end = 0.92
                Circle().trim(from: start, to: end).stroke(.gray.opacity(0.14), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(90))
                Circle().trim(from: start, to: start + ((end - start) * progress)).stroke(.gray.opacity(0.62), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(90)).animation(.easeInOut(duration: 0.8), value: progress)
                VStack(spacing: 5) { Image(systemName: "drop.fill").font(.title2); Text("\(Int(progress * 100))%").font(.title3.bold()) }.foregroundStyle(.primary)
            }
        }
    }
}

private struct BentoCard: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) { Image(systemName: icon).foregroundStyle(color); Text(title).font(.caption.weight(.medium)) }
            Text(value).font(.title3.bold())
        }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).modifier(LiquidGlassSurface(shape: .rounded(20)))
    }
}

enum HydrationTheme {
    static let canvas = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.78, green: 0.90, blue: 1.0), location: 0),
            .init(color: Color(red: 0.90, green: 0.96, blue: 1.0), location: 0.68),
            .init(color: .white, location: 1)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
}

struct LiquidGlassSurface: ViewModifier {
    enum ShapeStyle { case capsule, rounded(CGFloat), none }
    let shape: ShapeStyle
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule: content.glassEffect(.clear.interactive(), in: .capsule)
            case .rounded(let radius): content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: radius))
            case .none: content
            }
        } else {
            switch shape {
            case .capsule: content.background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 1))
            case .rounded(let radius): content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius)).overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.75), lineWidth: 1))
            case .none: content
            }
        }
    }
}

private struct WaterBottleVisual: View {
    let progress: Double
    let phase: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 42).fill(.white.opacity(0.72)).shadow(color: .blue.opacity(0.16), radius: 12, y: 8)
            WaveShape(level: 1 - progress, phase: phase).fill(.blue.gradient).clipShape(RoundedRectangle(cornerRadius: 42)).animation(.easeInOut(duration: 0.8), value: progress)
            RoundedRectangle(cornerRadius: 42).stroke(.white.opacity(0.8), lineWidth: 3)
            Capsule().fill(.white.opacity(0.55)).frame(width: 14).padding(.leading, 22).padding(.vertical, 22).frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 5) { Image(systemName: "drop.fill").font(.title2); Text("\(Int(progress * 100))%").font(.title3.bold()) }.foregroundStyle(.white).shadow(radius: 3).padding(.bottom, 24)
        }.frame(width: 116, height: 168).overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 8).fill(.gray.gradient).frame(width: 48, height: 20).offset(y: -10)
        }
    }
}

struct WaveShape: Shape {
    var level: Double
    var phase: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, phase) }
        set { level = newValue.first; phase = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.height * level
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: y))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let wave = sin((x / rect.width) * .pi * 2 + phase) * 7
            path.addLine(to: CGPoint(x: x, y: y + wave))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}
