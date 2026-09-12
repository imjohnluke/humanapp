import Foundation

struct HydrationEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let amountML: Int

    init(amountML: Int, date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.amountML = amountML
    }
}

struct WaterBottle: Identifiable, Codable {
    let id: UUID
    var name: String
    var capacityML: Int
    var assetName: String
    var colorName: String

    init(name: String = "My bottle", capacityML: Int = 750, assetName: String = "bottle", colorName: String = "blue") {
        self.id = UUID()
        self.name = name
        self.capacityML = capacityML
        self.assetName = assetName
        self.colorName = colorName
    }

    enum CodingKeys: String, CodingKey { case id, name, capacityML, assetName, colorName }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "My bottle"
        capacityML = try container.decodeIfPresent(Int.self, forKey: .capacityML) ?? 750
        assetName = try container.decodeIfPresent(String.self, forKey: .assetName) ?? "bottle"
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName) ?? "blue"
    }
}
