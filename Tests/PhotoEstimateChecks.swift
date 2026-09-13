import Foundation

final class PhotoMockProtocol: URLProtocol {
    static var status = 200
    static var body = Data()
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

@main
struct PhotoEstimateChecks {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PhotoMockProtocol.self]
        let service = PhotoEstimateService(session: URLSession(configuration: config))
        let jpeg = Data([0xff, 0xd8, 0xff, 0xd9])
        let good = #"{"can_estimate":true,"amount_ml":250,"capacity_ml":500,"confidence":"medium","container":"Glass","explanation":"Half full; approximate size."}"#
        PhotoMockProtocol.body = Data(good.utf8)
        let result = try await service.estimate(jpeg: jpeg, token: "test-token")
        precondition(result.amountML == 250 && result.isValid)
        let request = PhotoMockProtocol.requests.last!
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        precondition(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        precondition(request.httpMethod == "POST")
        PhotoMockProtocol.body = Data(#"{"is_pro":false,"available":true}"#.utf8)
        let access = try await service.access(token: "test-token")
        precondition(!access.isPro && access.available)
        precondition(PhotoMockProtocol.requests.last!.httpMethod == "GET")
        for (status, expected) in [(401, PhotoEstimateError.signIn), (403, .proRequired), (429, .dailyLimit), (422, .cannotEstimate), (413, .invalidPhoto), (500, .unavailable)] {
            PhotoMockProtocol.status = status
            do { _ = try await service.estimate(jpeg: jpeg, token: "test-token"); preconditionFailure("Must reject HTTP error") }
            catch let error as PhotoEstimateError { precondition(error == expected) }
        }
        PhotoMockProtocol.status = 200
        for invalid in [good.replacingOccurrences(of: "250", with: "9000"), good.replacingOccurrences(of: "250", with: "600"), good.replacingOccurrences(of: "medium", with: "certain"), "{}"] {
            PhotoMockProtocol.body = Data(invalid.utf8)
            do { _ = try await service.estimate(jpeg: jpeg, token: "test-token"); preconditionFailure("Must validate response") }
            catch let error as PhotoEstimateError { precondition(error == .cannotEstimate) }
        }
        let before = PhotoMockProtocol.requests.count
        do { _ = try await service.estimate(jpeg: Data([1, 2]), token: "test-token"); preconditionFailure() }
        catch let error as PhotoEstimateError { precondition(error == .invalidPhoto) }
        precondition(PhotoMockProtocol.requests.count == before)
        print("PASS: photo request, access, error mapping, invalid image and estimate validation")
    }
}
