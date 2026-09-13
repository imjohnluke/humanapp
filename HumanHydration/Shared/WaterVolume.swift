import Foundation

/// UI uses US fluid ounces; persisted amounts remain milliliters.
enum WaterVolume {
    static let mlPerOunce = 29.5735295625
    static func ounces(_ ml: Int) -> Double { Double(ml) / mlPerOunce }
    static func number(_ ml: Int) -> String {
        ounces(ml).formatted(.number.precision(.fractionLength(0...1)))
    }
    static func label(_ ml: Int) -> String { "\(number(ml)) fl oz" }
    static func input(_ ml: Int) -> String { String(format: "%.1f", ounces(ml)) }
    static func milliliters(_ text: String, minimum: Int = 10) -> Int? {
        guard let oz = Double(text.replacingOccurrences(of: ",", with: ".")), oz.isFinite,
              oz > 0, oz <= 256 else { return nil }
        let ml = Int((oz * mlPerOunce).rounded())
        guard (minimum...7570).contains(ml) else { return nil }
        return ml
    }
}
