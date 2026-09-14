import SwiftUI
import UIKit

struct TodayView: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var selectedDate = Date.now
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
                            Text("Human Hydration").font(.title3.weight(.regular)).foregroundStyle(.primary)
                        }
                        Spacer()
                        Button { historyMetric = .streak } label: {
                            Label("\(store.currentStreak)", systemImage: "flame.fill").font(.headline.weight(.regular)).foregroundStyle(.orange).padding(.horizontal, 16).padding(.vertical, 11).modifier(LiquidGlassSurface(shape: .capsule))
                        }.buttonStyle(.plain)
                    }
                    DayStrip(selectedDate: $selectedDate)

                    if Calendar.current.isDateInToday(selectedDate) {
                        TodayHydrationSection(store: store)
                        HStack(spacing: 12) {
                            Button { historyMetric = .streak } label: {
                                BentoCard(icon: "flame.fill", title: "Streak", value: "\(store.currentStreak) days", color: .orange)
                            }.buttonStyle(.plain)
                            Button { historyMetric = .average } label: {
                                BentoCard(icon: "drop.fill", title: "Daily average", value: "\(WaterVolume.label(store.dailyAverageML))", color: .blue)
                            }.buttonStyle(.plain)
                        }
                        HStack(spacing: 14) {
                            Image(systemName: "trophy.fill")
                                .font(.title2).foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Personal record").font(.headline.weight(.regular))
                                Text("Longest streak hitting your full daily goal")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text("\(store.bestStreak) \(store.bestStreak == 1 ? "day" : "days")")
                                .font(.title3.weight(.regular)).monospacedDigit()
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(18)
                        .modifier(LiquidGlassSurface(shape: .rounded(20)))
                    } else {
                        PastDayCard(amount: store.amount(on: selectedDate), goal: store.dailyGoalML, date: selectedDate)
                        DayEntriesView(date: selectedDate)
                    }

                }
                .padding()
                // Let the final card scroll fully above the floating navigation.
                .padding(.bottom, 80)
            }
        }
        .sheet(item: $historyMetric) { HydrationHistorySheet(metric: $0) }
    }


}

struct BottlePickerSheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAsset = "glass"
    @State private var page = 1
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
    private func swatchColor(_ name: String) -> Color { BottleFinishIcon.color(name) }

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
                                BottleFinishIcon(asset: option.0, finish: colorForPage(option.0))
                                    .frame(height: 230)
                                    .padding(.horizontal, 48)
                                    .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
                                Text(option.1).font(.title3.weight(.regular))
                                Text("\(BottleCatalog.sizeLabel(capacityML: option.2)) · \(colorForPage(option.0).capitalized)\(store.isFinishUnlocked(colorForPage(option.0)) ? " edition" : " preview")").font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 320)
                    .onChange(of: page) { _, newPage in
                        let option = options[(newPage + options.count - 1) % options.count]
                        if selectedAsset != option.0 {
                            selectedAsset = option.0
                            // The selected finish applies to every bottle style.
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
                                    if !store.isFinishUnlocked(option.0) { lockedColor = option.0 }
                                } label: {
                                        Circle().fill(option.1).frame(width: 32, height: 32)
                                            .overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 1))
                                            .overlay {
                                                Image(systemName: store.isFinishUnlocked(option.0) ? "checkmark" : "lock.fill")
                                                    .font(.caption2.weight(.regular))
                                                    .foregroundStyle(option.0 == "black" ? .white : .black)
                                            }
                                            .padding(5)
                                            .overlay(Circle().stroke(option.0 == previewColor ? .black : .clear, lineWidth: 1.5))
                                            .frame(width: 44, height: 44)
                                }.buttonStyle(.plain)
                                    .accessibilityLabel("\(option.0), \(store.isFinishUnlocked(option.0) ? "unlocked" : "locked. Preview and view unlock requirement")")
                                    .accessibilityAddTraits(previewColor == option.0 ? .isSelected : [])
                            }
                        }.padding(.vertical, 8)
                            .frame(minWidth: geometry.size.width, alignment: .center)
                    }
                    }.frame(height: 60)
                    }
                    Button {
                        guard store.isFinishUnlocked(previewColor) else { lockedColor = previewColor; return }
                        let chosen = options.first { $0.0 == selectedAsset }!
                        store.selectBottle(WaterBottle(name: chosen.1, capacityML: chosen.2, assetName: chosen.0, colorName: previewColor))
                        dismiss()
                    } label: { Text(store.isFinishUnlocked(previewColor) ? "Use this bottle" : "How to unlock").font(.headline.weight(.regular)).frame(maxWidth: .infinity).padding(.vertical, 15) }.buttonStyle(.borderedProminent).tint(.blue)
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
                    Text("Reach your daily goal for \(BottleCatalog.finish(lockedColor ?? "")?.days ?? 0) consecutive days to unlock this finish for every bottle style. Once earned, it stays unlocked. Extra water above your goal won’t speed it up.")
                }
                .onAppear {
                    if let bottle = store.bottle, options.contains(where: { $0.0 == bottle.assetName }) {
                        selectedAsset = bottle.assetName
                        previewColor = store.isFinishUnlocked(bottle.colorName) ? bottle.colorName : "clear"
                        page = (options.firstIndex(where: { $0.0 == bottle.assetName }) ?? 0) + 1
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
    @EnvironmentObject private var store: HydrationStore
    @Binding var selectedDate: Date
    @State private var daysBack = 365
    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var historyDays: Int {
        let earliest = store.entries.map(\.date).min() ?? today
        return max(daysBack, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: earliest), to: today).day ?? 0)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 8) {
                HStack {
                    Text(selectedDate, format: .dateTime.month(.wide).year())
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button("Today") {
                        selectedDate = today
                        withAnimation { proxy.scrollTo(0, anchor: .trailing) }
                    }.font(.subheadline)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        Button("Earlier dates") { daysBack = historyDays + 365 }
                            .font(.caption).frame(width: 80)
                        ForEach(-historyDays...0, id: \.self) { offset in
                            let date = Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let amount = store.amount(on: date)
                            let reachedGoal = store.dailyGoalML > 0 && amount >= store.dailyGoalML
                            let isToday = Calendar.current.isDateInToday(date)
                            Button { selectedDate = date } label: {
                                VStack(spacing: 7) {
                                    Text(date, format: .dateTime.weekday(.narrow)).font(.subheadline.weight(.regular))
                                    ZStack {
                                        Circle().trim(from: 0.1, to: 0.9)
                                            .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                            .rotationEffect(.degrees(90))
                                        Circle()
                                            .trim(from: 0.1, to: 0.1 + 0.8 * min(Double(amount) / Double(max(store.dailyGoalML, 1)), 1))
                                            .stroke(
                                                reachedGoal ? Color.blue : Color(red: 0.48, green: 0.72, blue: 0.92),
                                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                            )
                                            .rotationEffect(.degrees(90))
                                        Circle().fill(isSelected ? .white.opacity(0.85) : .clear)
                                            .padding(6)
                                        Text(date, format: .dateTime.day())
                                            .font(.subheadline.weight(.regular))
                                    }
                                    .frame(width: 38, height: 38)
                                }
                                .frame(width: 48).padding(.vertical, 10)
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                            }
                            .id(offset)
                            .buttonStyle(.plain)
                            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                            .accessibilityValue("\(WaterVolume.number(amount)) of \(WaterVolume.label(store.dailyGoalML)). \(reachedGoal ? "Goal reached" : isToday ? "In progress" : "Goal not reached")")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .onAppear { proxy.scrollTo(0, anchor: .trailing) }
                Text("Swipe to browse previous days")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct TodayHydrationSection: View {
    @ObservedObject var store: HydrationStore
    @State private var showingAddWater = false
    @State private var showingDrinks = false

    var body: some View {
        VStack(spacing: 22) {
            Text("Today’s hydration")
                .font(.headline.weight(.regular))
                .frame(maxWidth: .infinity, alignment: .leading)


            HydrationProgressView(progress: store.todayProgress, amount: store.todayAmountML, goal: store.dailyGoalML)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 280)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Today’s hydration")
                .accessibilityValue("\(WaterVolume.number(store.todayAmountML)) of \(WaterVolume.label(store.dailyGoalML))")

            if let drink = store.selectedDrink {
                Button { store.addWater(drink.capacityML) } label: {
                    HStack(spacing: 8) {
                        Text("Log \(BottleCatalog.displayName(drink.name).lowercased())")
                            .font(.subheadline.weight(.medium))
                        Text("\(drink.isEstimate && drink.capacityML != 3785 ? "~" : "")\(BottleCatalog.sizeLabel(capacityML: drink.capacityML))")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: 46)
                }.buttonStyle(.plain).foregroundStyle(.primary)
                    .background(Color.blue.opacity(0.07), in: Capsule())
                    .modifier(LiquidGlassSurface(shape: .capsule))
            } else {
                Text("Make your usual drink a one-tap log.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Set up my glass or bottle") { showingDrinks = true }
                    .buttonStyle(.borderedProminent).tint(.blue)
            }
            HStack(spacing: 24) {
                Button("Enter manually") { showingAddWater = true }
                if store.selectedDrink != nil {
                    Button("Change default size") { showingDrinks = true }
                }
            }.font(.caption).foregroundStyle(.secondary)

            Divider()
            DayEntriesView(date: .now, embedded: true)

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassSurface(shape: .rounded(28)))
        .sheet(isPresented: $showingAddWater) { AddWaterSheet() }
        .sheet(isPresented: $showingDrinks) { DrinkSizeSheet() }
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
            HStack(alignment: .firstTextBaseline) { Text("\(WaterVolume.label(amount))").font(.system(size: 38, weight: .regular, design: .rounded)); Spacer(); Text("\(Int(progress * 100))% of goal").font(.subheadline.weight(.regular)).foregroundStyle(.secondary) }
            ProgressView(value: progress).tint(progress >= 1 ? .green : .blue)
            Text(progress >= 1 ? "Goal reached" : "\(WaterVolume.label(max(goal - amount, 0))) short of your goal").font(.subheadline).foregroundStyle(.secondary)
        }.padding(24).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }
}

private struct DayEntriesView: View {
    @EnvironmentObject private var store: HydrationStore
    let date: Date
    var embedded = false

    private var dayEntries: [HydrationEntry] {
        store.entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        if embedded {
            entriesContent
        } else {
            entriesContent.padding(18)
                .modifier(LiquidGlassSurface(shape: .rounded(20)))
        }
    }

    private var entriesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(Calendar.current.isDateInToday(date) ? "Today’s" : "Day’s") entries").font(.headline.weight(.regular))
                Spacer()
                if let entry = store.undoEntry, dayEntries.contains(where: { $0.id == entry.id }) {
                    Button("Undo") { store.undoLastLog() }.font(.caption)
                        .accessibilityLabel("Undo last water log")
                }
            }
            if dayEntries.isEmpty {
                Text("No water logged yet").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ForEach(dayEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill").foregroundStyle(.blue)
                        Text("\(WaterVolume.label(entry.amountML))").font(.subheadline.weight(.regular))
                        Spacer()
                        Text(entry.date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                        Button(role: .destructive) { store.removeEntry(entry) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                    if entry.id != dayEntries.last?.id { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Circle().trim(from: start, to: start + ((end - start) * progress))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 0.88, green: 0.95, blue: 1.0),
                                Color(red: 0.38, green: 0.69, blue: 0.96),
                                Color(red: 0.12, green: 0.48, blue: 0.91)
                            ],
                            center: .center,
                            startAngle: .degrees(start * 360),
                            endAngle: .degrees((start + (end - start) * max(progress, 0.001)) * 360)
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
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

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum HydrationTheme {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static let surface = adaptive(
        light: UIColor.white.withAlphaComponent(0.42),
        dark: UIColor(red: 0.10, green: 0.16, blue: 0.22, alpha: 0.78)
    )
    static let subtleSurface = adaptive(
        light: UIColor.white.withAlphaComponent(0.24),
        dark: UIColor.white.withAlphaComponent(0.055)
    )
    static let border = adaptive(
        light: UIColor.white.withAlphaComponent(0.75),
        dark: UIColor.white.withAlphaComponent(0.14)
    )
    static let canvas = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: adaptive(light: UIColor(red: 0.86, green: 0.93, blue: 0.99, alpha: 1), dark: UIColor(red: 0.025, green: 0.08, blue: 0.14, alpha: 1)), location: 0),
            .init(color: adaptive(light: UIColor(red: 0.96, green: 0.98, blue: 1, alpha: 1), dark: UIColor(red: 0.035, green: 0.095, blue: 0.16, alpha: 1)), location: 0.24),
            .init(color: adaptive(light: .white, dark: UIColor(red: 0.045, green: 0.06, blue: 0.085, alpha: 1)), location: 0.46)
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
            case .capsule: content.background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().stroke(HydrationTheme.border, lineWidth: 1))
            case .rounded(let radius): content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius)).overlay(RoundedRectangle(cornerRadius: radius).stroke(HydrationTheme.border, lineWidth: 1))
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
            RoundedRectangle(cornerRadius: 42).fill(HydrationTheme.surface).shadow(color: .blue.opacity(0.16), radius: 12, y: 8)
            WaveShape(level: 1 - progress, phase: phase).fill(.blue.gradient).clipShape(RoundedRectangle(cornerRadius: 42)).animation(.easeInOut(duration: 0.8), value: progress)
            RoundedRectangle(cornerRadius: 42).stroke(HydrationTheme.border, lineWidth: 3)
            Capsule().fill(HydrationTheme.border).frame(width: 14).padding(.leading, 22).padding(.vertical, 22).frame(maxWidth: .infinity, alignment: .leading)
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

struct BottleFinishIcon: View {
    let asset: String
    let finish: String

    static func color(_ finish: String) -> Color {
        switch finish {
        case "black": return Color(white: 0.16)
        case "bronze": return Color(red: 0.72, green: 0.43, blue: 0.23)
        case "silver": return Color(red: 0.68, green: 0.72, blue: 0.77)
        case "gold": return Color(red: 0.91, green: 0.71, blue: 0.29)
        case "platinum": return Color(red: 0.88, green: 0.94, blue: 0.98)
        default: return .white
        }
    }

    var body: some View {
        DrinkIcon(name: asset, starter: true)
            .saturation(finish == "clear" ? 1 : 0)
            .colorMultiply(Self.color(finish))
    }
}
