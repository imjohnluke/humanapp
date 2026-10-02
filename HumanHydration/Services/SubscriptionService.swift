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
    @Published private(set) var didApplyEntitlements = false
    @Published private(set) var isBusy = false
    @Published var message: String?
    private let accountID: UUID
    private let session: URLSession
    private let defaults: UserDefaults?

    init(accountID: UUID, session: URLSession = .shared, defaults: UserDefaults? = nil) {
        self.accountID = accountID
        self.session = session
        self.defaults = defaults
        isPro = defaults?.bool(forKey: "cachedIsPro") ?? false
        purchasesAvailable = defaults?.bool(forKey: "cachedPurchasesAvailable") ?? false
    }

    func listen(auth: AuthService) async {
        await refresh(auth: auth)
        await reconcileCurrent(auth: auth)
        for await result in StoreKit.Transaction.updates {
            guard !Task.isCancelled, auth.user?.id == accountID else { return }
            do { try await sync(result, auth: auth) }
            catch is CancellationError { return }
            catch {
                if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID), transaction.appAccountToken == accountID {
                    message = "Your purchase is waiting to sync. Restore purchases to try again."
                }
            }
        }
    }

    func loadProducts(auth: AuthService, reportFailure: Bool = false) async {
        if message == Self.plansMessage { message = nil }
        isBusy = true
        defer { isBusy = false }
        await refresh(auth: auth)
        do {
            products = try await loadStoreProducts()
        } catch is CancellationError {
            return
        } catch {
            guard reportFailure, products.isEmpty else { return }
            message = Self.plansMessage
        }
    }

    func refresh(auth: AuthService) async {
        do { apply(try await request(auth: auth)) }
        catch is CancellationError { return }
        catch {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            if let access = try? await request(auth: auth) { apply(access) }
        }
    }

    func purchase(_ product: Product, auth: AuthService) async {
        guard !isBusy, AppConfig.privacyPolicyURL != nil, Self.productIDs.contains(product.id), auth.user?.id == accountID else { return }
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
        catch is CancellationError { return }
        catch SubscriptionError.pendingSync { message = "Your purchase is waiting to sync. Restore purchases to try again." }
        catch { }
    }

    private func syncEntitlements(auth: AuthService) async throws {
        var pendingSync = false
        for await result in StoreKit.Transaction.unfinished {
            try Task.checkCancellation()
            pendingSync = try await syncIfPossible(result, auth: auth) || pendingSync
        }
        for await result in StoreKit.Transaction.currentEntitlements {
            try Task.checkCancellation()
            pendingSync = try await syncIfPossible(result, auth: auth) || pendingSync
        }
        if pendingSync { throw SubscriptionError.pendingSync }
    }

    private func syncIfPossible(_ result: VerificationResult<StoreKit.Transaction>, auth: AuthService) async throws -> Bool {
        do {
            try await sync(result, auth: auth)
            return false
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.appAccountToken == accountID else { return false }
            return true
        }
    }

    private func loadStoreProducts() async throws -> [Product] {
        var lastError: Error?
        for attempt in 0..<3 {
            try Task.checkCancellation()
            if attempt > 0 { try await Task.sleep(for: .milliseconds(500 * UInt64(attempt))) }
            do {
                return try await Product.products(for: Self.productIDs)
                    .filter { $0.type == .autoRenewable }
                    .sorted { $0.price < $1.price }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError ?? SubscriptionError.unavailable
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
        didApplyEntitlements = true
        defaults?.set(value.isPro, forKey: "cachedIsPro")
        defaults?.set(value.purchasesAvailable, forKey: "cachedPurchasesAvailable")
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
    private static let plansMessage = "The App Store couldn’t load plans. Please try again."
    private enum SubscriptionError: Error { case unverified, unavailable, pendingSync }
}
