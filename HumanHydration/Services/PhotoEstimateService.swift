import Foundation

struct PhotoEstimate: Decodable {
    let canEstimate: Bool
    let amountML: Int?
    let capacityML: Int?
    let confidence: String
    let container: String
    let explanation: String
    enum CodingKeys: String, CodingKey {
        case canEstimate = "can_estimate", amountML = "amount_ml", capacityML = "capacity_ml"
        case confidence, container, explanation
    }
    var isValid: Bool {
        guard canEstimate, let amountML, let capacityML else { return false }
        return (10...7570).contains(amountML) && (amountML...7570).contains(capacityML)
            && ["low", "medium", "high"].contains(confidence)
            && container.count <= 80 && !explanation.isEmpty && explanation.count <= 400
    }
}

struct PhotoProAccess: Decodable {
    let isPro: Bool
    let available: Bool
    enum CodingKeys: String, CodingKey { case isPro = "is_pro", available }
}

enum PhotoEstimateError: LocalizedError, Equatable {
    case signIn, proRequired, dailyLimit, invalidPhoto, cannotEstimate, unavailable
    var errorDescription: String? {
        switch self {
        case .signIn: return "Please sign in again to use photo logging."
        case .proRequired: return "Photo logging requires Human Pro."
        case .dailyLimit: return "You’ve used today’s 20 photo estimates. You can still log water manually. Scans reset at midnight UTC."
        case .invalidPhoto: return "Choose a clear photo of one glass or bottle."
        case .cannotEstimate: return "We couldn’t estimate this photo. Show one container, its water level, and any size markings—or enter the amount manually."
        case .unavailable: return "Photo estimates aren’t available right now. Please try again later or log manually."
        }
    }
}

struct PhotoEstimateService {
    var session: URLSession = .shared
    private var endpoint: URL { AppConfig.supabaseURL.appendingPathComponent("functions/v1/estimate-water") }

    func access(token: String) async throws -> PhotoProAccess {
        try JSONDecoder().decode(PhotoProAccess.self, from: await send(token: token, image: nil))
    }

    func estimate(jpeg: Data, token: String) async throws -> PhotoEstimate {
        guard jpeg.count <= 2 * 1024 * 1024, jpeg.count >= 4,
              jpeg.starts(with: [0xff, 0xd8, 0xff]) else { throw PhotoEstimateError.invalidPhoto }
        let data = try await send(token: token, image: jpeg)
        guard let estimate = try? JSONDecoder().decode(PhotoEstimate.self, from: data), estimate.isValid else {
            throw PhotoEstimateError.cannotEstimate
        }
        return estimate
    }

    private func send(token: String, image: Data?) async throws -> Data {
        guard !token.isEmpty else { throw PhotoEstimateError.signIn }
        var request = URLRequest(url: endpoint)
        request.httpMethod = image == nil ? "GET" : "POST"
        request.timeoutInterval = 75
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        if let image {
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.httpBody = image
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PhotoEstimateError.unavailable }
        switch http.statusCode {
        case 200: return data
        case 401: throw PhotoEstimateError.signIn
        case 403: throw PhotoEstimateError.proRequired
        case 429: throw PhotoEstimateError.dailyLimit
        case 400, 413, 415: throw PhotoEstimateError.invalidPhoto
        case 422: throw PhotoEstimateError.cannotEstimate
        default: throw PhotoEstimateError.unavailable
        }
    }
}
