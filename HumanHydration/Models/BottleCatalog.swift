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
    static func sizes(for asset: String) -> [Int] {
        switch asset {
        case "bottle": return [591, 700, 1000, 1500]
        case "mountain-valley": return [333, 500, 750, 1000]
        default: return []
        }
    }
    static func customizable(_ asset: String) -> Bool { ["stanley", "big", "gatorade"].contains(asset) }
    static func startingColor(_ asset: String) -> String { "clear" }
    static func colors(for asset: String) -> [String] {
        switch asset {
        case "glass": return []
        case "mountain-valley", "gatorade": return ["clear", "green"]
        case "stanley", "big": return ["clear", "purple", "pink", "blue", "navy", "black"]
        case "bottle", "gallon": return ["clear", "blue"]
        default: return ["clear"]
        }
    }
    static func starterAsset(_ asset: String) -> String {
        asset == "glass" ? asset : "\(asset)-clear"
    }
}
