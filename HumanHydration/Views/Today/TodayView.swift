import SwiftUI
import UIKit

struct TodayView: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var selectedDate = Date.now
    @State private var showingBottlePicker = false
    @State private var showingSettings = false
    @State private var historyMetric: HydrationHistoryMetric?

    var body: some View {
        ZStack {
            HydrationTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        HStack(spacing: 8) {
                            BundledLogoImage(name: "human-logo-mark")
                                .frame(width: 28, height: 28)
                            Text("human").font(.title3.weight(.regular)).foregroundStyle(.black)
                        }
                        Spacer()
                        Button { showingSettings = true } label: { Image(systemName: "gearshape").font(.headline.weight(.regular)).foregroundStyle(.black) }
                        Button { historyMetric = .streak } label: {
                            Label("\(store.currentStreak)", systemImage: "flame.fill").font(.headline.weight(.regular)).foregroundStyle(.orange).padding(.horizontal, 16).padding(.vertical, 11).modifier(LiquidGlassSurface(shape: .capsule))
                        }.buttonStyle(.plain)
                    }
                    DayStrip(selectedDate: $selectedDate)

                    if Calendar.current.isDateInToday(selectedDate) {
                        TodayHeroCard(store: store)
                        HStack(spacing: 12) {
                            Button { historyMetric = .streak } label: {
                                BentoCard(icon: "flame.fill", title: "Streak", value: "\(store.currentStreak) days", color: .orange)
                            }.buttonStyle(.plain)
                            Button { historyMetric = .average } label: {
                                BentoCard(icon: "drop.fill", title: "Daily average", value: "\(store.dailyAverageML) ml", color: .blue)
                            }.buttonStyle(.plain)
                        }
                    } else {
                        PastDayCard(amount: store.amount(on: selectedDate), goal: store.dailyGoalML, date: selectedDate)
                    }

                    DayEntriesView(date: selectedDate)

                    if Calendar.current.isDateInToday(selectedDate) {
                        Button { showingBottlePicker = true } label: {
                            HStack(spacing: 14) {
                                if let bottle = store.bottle {
                                    DrinkIcon(name: bottle.assetName, starter: true).frame(width: 54, height: 58)
                                } else {
                                    Image(systemName: "plus.viewfinder").font(.title2).foregroundStyle(.blue).frame(width: 54, height: 58)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("My bottle collection").font(.headline.weight(.regular))
                                    Text(store.bottle.map { "\($0.name) · \($0.capacityML) ml" } ?? "Choose a bottle to get started").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).foregroundStyle(.primary).modifier(LiquidGlassSurface(shape: .rounded(20)))
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingBottlePicker) { BottlePickerSheet() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(item: $historyMetric) { HydrationHistorySheet(metric: $0) }
    }

    private func bottleColor(_ name: String) -> Color {
        switch name { case "white": return .white; case "purple": return .purple; case "pink": return .pink; case "blue": return .blue; case "navy": return Color(red: 0.04, green: 0.10, blue: 0.25); case "black": return .black; default: return .white }
    }
}

struct BottlePickerSheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAsset = "bottle"
    @State private var page = 2
    @State private var lockedColor: String?
    @State private var previewColor = "clear"

    private let options = BottleCatalog.options
    private var colors: [(String, Color)] {
        BottleCatalog.colors(for: selectedAsset).map { name in
            (name, swatchColor(name))
        }
    }
    private func colorForPage(_ asset: String) -> String {
        asset == selectedAsset && BottleCatalog.colors(for: asset).contains(previewColor) ? previewColor : "clear"
    }
    private func swatchColor(_ name: String) -> Color {
        switch name {
        case "purple": return .purple
        case "pink": return .pink
        case "blue": return .blue
        case "green": return .green
        case "navy": return Color(red: 0.04, green: 0.10, blue: 0.25)
        case "black": return Color(white: 0.12)
        default: return .white
        }
    }
    private func needsTintPreview(_ asset: String) -> Bool {
        ["stanley", "big"].contains(asset) && !["clear", "pink"].contains(colorForPage(asset))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Choose your bottle").font(.title.weight(.regular))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    TabView(selection: $page) {
                        ForEach(0..<(options.count + 2), id: \.self) { index in
                            let option = options[(index + options.count - 1) % options.count]
                            VStack(spacing: 12) {
                                DrinkIcon(name: option.0, starter: colorForPage(option.0) == "clear" || needsTintPreview(option.0))
                                    .colorMultiply(needsTintPreview(option.0) ? swatchColor(colorForPage(option.0)) : .white)
                                    .frame(height: 230)
                                    .padding(.horizontal, 48)
                                    .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
                                Text(option.1).font(.title3.weight(.regular))
                                Text(option.0 == "glass" ? "\(option.2) ml" : "\(option.2) ml · \(colorForPage(option.0).capitalized)\(colorForPage(option.0) == "clear" ? " edition" : " preview")").font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 320)
                    .onChange(of: page) { _, newPage in
                        let option = options[(newPage + options.count - 1) % options.count]
                        if selectedAsset != option.0 {
                            selectedAsset = option.0
                            previewColor = "clear"
                        }
                    }
                    .task(id: page) {
                        guard page == 0 || page == options.count + 1 else { return }
                        do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { page = page == 0 ? options.count : 1 }
                    }
                    .overlay(alignment: .top) {
                    HStack {
                        Button { withAnimation { page = max(0, page - 1) } } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .accessibilityLabel("Previous bottle")
                        Spacer()
                        Button { withAnimation { page = min(options.count + 1, page + 1) } } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                            .accessibilityLabel("Next bottle")
                    }.foregroundStyle(.primary).frame(height: 230).padding(.top, 15)
                    }
                    if !colors.isEmpty {
                    GeometryReader { geometry in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(colors, id: \.0) { option in
                                Button {
                                    previewColor = option.0
                                    if option.0 != "clear" { lockedColor = option.0 }
                                } label: {
                                        Circle().fill(option.1).frame(width: 32, height: 32)
                                            .overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 1))
                                            .overlay {
                                                Image(systemName: option.0 == "clear" ? "checkmark" : "lock.fill")
                                                    .font(.caption2.weight(.regular))
                                                    .foregroundStyle(option.0 == "clear" ? .black : .white)
                                            }
                                            .padding(5)
                                            .overlay(Circle().stroke(option.0 == previewColor ? .black : .clear, lineWidth: 1.5))
                                            .frame(width: 44, height: 44)
                                }.buttonStyle(.plain)
                                    .accessibilityLabel("\(option.0), \(option.0 == "clear" ? "included" : "locked. Preview and view unlock requirement")")
                                    .accessibilityAddTraits(previewColor == option.0 ? .isSelected : [])
                            }
                        }.padding(.vertical, 8)
                            .frame(minWidth: geometry.size.width, alignment: .center)
                    }
                    }.frame(height: 60)
                    }
                    Button {
                        guard previewColor == "clear" else { lockedColor = previewColor; return }
                        let chosen = options.first { $0.0 == selectedAsset }!
                        store.bottle = WaterBottle(name: chosen.1, capacityML: chosen.2, assetName: chosen.0, colorName: BottleCatalog.startingColor(chosen.0))
                        dismiss()
                    } label: { Text(previewColor == "clear" ? "Use this bottle" : "How to unlock").font(.headline.weight(.regular)).frame(maxWidth: .infinity).padding(.vertical, 15) }.buttonStyle(.borderedProminent).tint(.black)
                }.padding()
            }.scrollContentBackground(.hidden)
                .background(Color.clear)
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationTitle("My bottle collection").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("My bottle collection").font(.headline.weight(.regular))
                    }
                }
                .alert("\(lockedColor?.capitalized ?? "Color") edition", isPresented: Binding(get: { lockedColor != nil }, set: { if !$0 { lockedColor = nil } })) {
                    Button("Got it", role: .cancel) { lockedColor = nil }
                } message: {
                    Text("Reach your daily goal for \(requiredDays(for: lockedColor ?? "")) consecutive days to earn this edition. Extra water above your goal won’t speed it up.\n\nReward unlocking is coming soon; clear is available now.")
                }
                .onAppear {
                    if let bottle = store.bottle, options.contains(where: { $0.0 == bottle.assetName }) {
                        selectedAsset = bottle.assetName
                        page = (options.firstIndex(where: { $0.0 == bottle.assetName }) ?? 1) + 1
                    }
                }
        }.presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground {
                if #available(iOS 26.0, *) {
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 32))
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
    }

    private func requiredDays(for color: String) -> Int {
        ["green": 3, "purple": 3, "pink": 7, "blue": 14, "navy": 30, "black": 60][color] ?? 3
    }
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
                    Text(date, format: .dateTime.weekday(.narrow)).font(.subheadline.weight(.regular))
                    Text(date, format: .dateTime.day()).font(.headline.weight(.regular))
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
                    Text("\(max(store.dailyGoalML - store.todayAmountML, 0))").font(.system(size: 30, weight: .regular, design: .rounded)).lineLimit(1).minimumScaleFactor(0.55).allowsTightening(true)
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
            HStack(alignment: .firstTextBaseline) { Text("\(amount) ml").font(.system(size: 38, weight: .regular, design: .rounded)); Spacer(); Text("\(Int(progress * 100))% of goal").font(.subheadline.weight(.regular)).foregroundStyle(.secondary) }
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
            Text("\(Calendar.current.isDateInToday(date) ? "Today’s" : "Day’s") entries").font(.headline.weight(.regular))
            if dayEntries.isEmpty {
                Text("No water logged yet").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ForEach(dayEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill").foregroundStyle(.blue)
                        Text("\(entry.amountML) ml").font(.subheadline.weight(.regular))
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
                VStack(spacing: 5) { Image(systemName: "drop.fill").font(.title2); Text("\(Int(progress * 100))%").font(.title3.weight(.regular)) }.foregroundStyle(.primary)
            }
        }
    }
}

private struct BentoCard: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) { Image(systemName: icon).foregroundStyle(color); Text(title).font(.caption.weight(.regular)) }
            Text(value).font(.title3.weight(.regular))
        }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).modifier(LiquidGlassSurface(shape: .rounded(20)))
    }
}

enum HydrationTheme {
    static let canvas = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.86, green: 0.93, blue: 0.99), location: 0),
            .init(color: Color(red: 0.96, green: 0.98, blue: 1), location: 0.24),
            .init(color: .white, location: 0.46)
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
            VStack(spacing: 5) { Image(systemName: "drop.fill").font(.title2); Text("\(Int(progress * 100))%").font(.title3.weight(.regular)) }.foregroundStyle(.white).shadow(radius: 3).padding(.bottom, 24)
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
