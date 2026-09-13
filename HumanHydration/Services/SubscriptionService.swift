import Foundation
import Combine
import StoreKit

struct SubscriptionAccess: Decodable {
    let isPro: Bool
    let expiresAt: String?
    let purchasesAvailable: Bool
    enum CodingKeys: String, CodingKey {
        case isPro = "is_pro", expiresAt = "expires_at", purchasesAvailable = "purchases_available"
    }
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let productIDs = ["com.humanhydration.pro.monthly"]
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var purchasesAvailable = false
    @Published private(set) var isBusy = false
    @Published var message: String?
    private let accountID: UUID
    private let session: URLSession

    init(accountID: UUID, session: URLSession = .shared) {
        self.accountID = accountID
        self.session = session
    }

    func listen(auth: AuthService) async {
        await refresh(auth: auth)
        await reconcileCurrent(auth: auth)
        for await result in StoreKit.Transaction.updates {
            guard !Task.isCancelled, auth.user?.id == accountID else { return }
            do { try await sync(result, auth: auth) }
            catch { message = "Your purchase is waiting to sync. Restore purchases to try again." }
        }
    }

    func loadProducts(auth: AuthService) async {
        isBusy = true
        defer { isBusy = false }
        await refresh(auth: auth)
        do {
            products = try await Product.products(for: Self.productIDs)
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }
        } catch { message = "The App Store couldn’t load plans. Please try again." }
    }

    func refresh(auth: AuthService) async {
        do { apply(try await request(auth: auth)) }
        catch { purchasesAvailable = false }
    }

    func purchase(_ product: Product, auth: AuthService) async {
        guard !isBusy, purchasesAvailable, AppConfig.privacyPolicyURL != nil, Self.productIDs.contains(product.id), auth.user?.id == accountID else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let result = try await product.purchase(options: [.appAccountToken(accountID)])
            switch result {
            case .success(let verification):
                try await sync(verification, auth: auth)
                message = isPro ? "Human Pro is active." : "Purchase synced. No active Pro subscription was found."
            case .pending: message = "Your purchase is awaiting approval. Pro will unlock when Apple confirms it."
            case .userCancelled: break
            @unknown default: message = "The purchase didn’t finish. Please try again."
            }
        } catch { message = "The purchase couldn’t be confirmed. If Apple charged you, use Restore purchases; don’t buy again." }
    }

    func restore(auth: AuthService) async {
        guard !isBusy else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            try await syncEntitlements(auth: auth)
            apply(try await request(auth: auth))
            message = isPro ? "Human Pro is active." : "No active subscription was found for this human account. Use the account that originally purchased Pro."
        } catch { message = "Restore couldn’t finish. Check your connection and try again." }
    }

    func reconcileCurrent(auth: AuthService) async {
        do { try await syncEntitlements(auth: auth); await refresh(auth: auth) }
        catch { message = "Your purchase is waiting to sync. Restore purchases to try again." }
    }

    private func syncEntitlements(auth: AuthService) async throws {
        for await result in StoreKit.Transaction.unfinished { try Task.checkCancellation(); try await sync(result, auth: auth) }
        for await result in StoreKit.Transaction.currentEntitlements { try Task.checkCancellation(); try await sync(result, auth: auth) }
    }

    private func sync(_ result: VerificationResult<StoreKit.Transaction>, auth: AuthService) async throws {
        guard case .verified(let transaction) = result else { throw SubscriptionError.unverified }
        guard Self.productIDs.contains(transaction.productID) else { return }
        guard transaction.appAccountToken == accountID, auth.user?.id == accountID else { return }
        let access = try await request(auth: auth, signedTransaction: result.jwsRepresentation)
        try Task.checkCancellation()
        guard auth.user?.id == accountID else { throw CancellationError() }
        apply(access)
        // Keep unfinished transactions available for retry until the server confirms them.
        await transaction.finish()
    }

    private func apply(_ value: SubscriptionAccess) {
        isPro = value.isPro
        purchasesAvailable = value.purchasesAvailable
    }

    private func request(auth: AuthService, signedTransaction: String? = nil) async throws -> SubscriptionAccess {
        guard auth.user?.id == accountID else { throw CancellationError() }
        let token = try await auth.accessTokenForAPI()
        var request = URLRequest(url: AppConfig.supabaseURL.appendingPathComponent("functions/v1/apple-subscriptions"))
        request.httpMethod = signedTransaction == nil ? "GET" : "POST"
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        if let signedTransaction {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["signed_transaction": signedTransaction])
        }
        let (data, response) = try await session.data(for: request)
        guard auth.user?.id == accountID else { throw CancellationError() }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SubscriptionError.unavailable }
        return try JSONDecoder().decode(SubscriptionAccess.self, from: data)
    }
    private enum SubscriptionError: Error { case unverified, unavailable }
}
