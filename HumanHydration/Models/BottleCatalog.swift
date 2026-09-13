import Foundation

enum BottleCatalog {
    // US fluid ounces converted to mL and rounded to the nearest whole mL.
    static let options: [(String, String, Int)] = [
        ("glass", "Glass of water", 250),
        ("bottle", "Smartwater", 1000),
        ("mountain-valley", "Mountain Valley", 750),
        ("gatorade", "Gatorade · 32 oz", 946),
        ("stanley", "Stanley · 40 oz", 1183),
        ("big", "Large bottle", 2000),
        ("gallon", "US gallon", 3785)
    ]
    static func sizeLabel(capacityML: Int) -> String {
        if capacityML == 3785 { return "1 gallon" }
        return WaterVolume.label(capacityML)
    }

    static func displayName(_ name: String) -> String {
        name.components(separatedBy: " · ").first ?? name
    }

    static func sizes(for asset: String) -> [Int] {
        switch asset {
        case "bottle": return [591, 700, 1000, 1500]
        case "mountain-valley": return [333, 500, 750, 1000]
        default: return []
        }
    }
    struct Finish: Identifiable {
        let id: String
        let days: Int
        let milestone: String
        var name: String { id.capitalized }
    }
    static let finishes: [Finish] = [
        .init(id: "clear", days: 0, milestone: "Starter"),
        .init(id: "black", days: 7, milestone: "1 week"),
        .init(id: "bronze", days: 30, milestone: "1 month"),
        .init(id: "silver", days: 90, milestone: "3 months"),
        .init(id: "gold", days: 180, milestone: "6 months"),
        .init(id: "platinum", days: 365, milestone: "12 months")
    ]
    static func customizable(_ asset: String) -> Bool { options.contains { $0.0 == asset } }
    static func startingColor(_ asset: String) -> String { "clear" }
    static func colors(for asset: String) -> [String] { finishes.map(\.id) }
    static func finish(_ id: String) -> Finish? { finishes.first { $0.id == id } }
    static func starterAsset(_ asset: String) -> String {
        asset == "glass" ? asset : "\(asset)-clear"
    }
}
