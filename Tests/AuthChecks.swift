import Foundation

final class MemoryVault: SessionVault {
    var value: StoredSession?
    func read() throws -> StoredSession? { value }
    func save(_ session: StoredSession) throws { value = session }
    func clear() { value = nil }
}

final class AuthMockProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, String))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body) = Self.handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
enum AuthChecks {
    @MainActor static func main() async throws {
        let domain = "com.humanhydration.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthMockProtocol.self]
        let session = URLSession(configuration: config)
        let vault = MemoryVault()
        let userA = UUID()
        let userB = UUID()
        func makeAuth() -> AuthService { AuthService(session: session, vault: vault, defaults: defaults, clearWidgets: {}) }
        func userJSON(_ id: UUID) -> String { "{\"id\":\"\(id)\",\"email\":\"test@example.com\"}" }
        func tokenJSON(_ id: UUID) -> String { "{\"access_token\":\"mock-access\",\"refresh_token\":\"mock-refresh\",\"user\":\(userJSON(id))}" }

        defaults.set(true, forKey: "isSignedIn")
        let legacy = makeAuth()
        await legacy.restoreSession()
        precondition(!legacy.isAuthenticated, "Legacy boolean must never grant access")

        AuthMockProtocol.handler = { _ in (200, "{}") }
        let malformed = makeAuth()
        let malformedOK = await malformed.signIn(email: "test@example.com", password: "password123")
        precondition(!malformedOK && !malformed.isAuthenticated, "200 without tokens is not login")

        AuthMockProtocol.handler = { request in
            precondition(request.url!.path == "/auth/v1/signup")
            let redirect = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "redirect_to" })?.value
            precondition(redirect == AppConfig.emailRedirectURL.absoluteString)
            return (200, userJSON(userA))
        }
        let pending = makeAuth()
        vault.value = StoredSession(accessToken: "stale-other-account", refreshToken: "stale")
        let pendingOK = await pending.signUp(email: "test@example.com", password: "password123")
        precondition(!pendingOK && pending.confirmationMessage != nil && vault.value == nil, "Unconfirmed signup must wait")

        AuthMockProtocol.handler = { _ in (400, "{\"msg\":\"Invalid login credentials\"}") }
        let wrongPassword = makeAuth()
        let wrongOK = await wrongPassword.signIn(email: "test@example.com", password: "wrong-password")
        precondition(!wrongOK && !wrongPassword.isAuthenticated && wrongPassword.errorMessage != nil)

        AuthMockProtocol.handler = { request in
            if request.url!.path == "/auth/v1/user" { return (200, userJSON(userB)) }
            return (200, tokenJSON(userB))
        }
        let immediateSignup = makeAuth()
        let immediateOK = await immediateSignup.signUp(email: "test@example.com", password: "password123")
        precondition(immediateOK && immediateSignup.user?.id == userB, "Confirmation-disabled signup requires verified session")
        vault.clear()

        AuthMockProtocol.handler = { request in
            if request.url!.path == "/auth/v1/user" { return (200, userJSON(userB)) }
            return (200, tokenJSON(userA))
        }
        let mismatch = makeAuth()
        let mismatchOK = await mismatch.signIn(email: "test@example.com", password: "password123")
        precondition(!mismatchOK && vault.value == nil, "Mismatched identity rejected")

        AuthMockProtocol.handler = { request in
            if request.url!.path == "/auth/v1/user" { return (200, userJSON(userA)) }
            return (200, tokenJSON(userA))
        }
        let valid = makeAuth()
        let validOK = await valid.signIn(email: "test@example.com", password: "password123")
        precondition(validOK && valid.user?.id == userA && vault.value != nil)
        valid.handleEmailCallback(URL(string: "humanhydration://email-confirmed#access_token=other-account")!)
        precondition(valid.user?.id == userA, "Email link cannot switch active accounts")
        AuthMockProtocol.handler = { _ in (204, "") }
        valid.signOut()
        precondition(valid.user == nil && vault.value == nil && defaults.string(forKey: "activeWidgetAccountID") == nil)
        // Allow the best-effort server logout request to finish before installing another handler.
        try await Task.sleep(nanoseconds: 100_000_000)

        // Apple ID-token login must verify the returned identity before saving a session.
        AuthMockProtocol.handler = { request in
            if request.url!.path == "/auth/v1/user" { return (200, userJSON(userA)) }
            precondition(request.url!.query == "grant_type=id_token")
            return (200, tokenJSON(userA))
        }
        let apple = makeAuth()
        await apple.signInWithApple(idToken: "mock-apple-token", nonce: "mock-nonce")
        precondition(apple.user?.id == userA && vault.value != nil && !apple.isLoading)
        vault.clear()

        AuthMockProtocol.handler = { request in
            if request.url!.path == "/auth/v1/user" { return (200, userJSON(userB)) }
            return (200, tokenJSON(userA))
        }
        let appleMismatch = makeAuth()
        await appleMismatch.signInWithApple(idToken: "mock-apple-token", nonce: "mock-nonce")
        precondition(!appleMismatch.isAuthenticated && vault.value == nil && !appleMismatch.isLoading)

        AuthMockProtocol.handler = { _ in (400, "{\"msg\":\"Invalid Apple token\"}") }
        let appleRejected = makeAuth()
        vault.value = StoredSession(accessToken: "stale", refreshToken: "stale")
        await appleRejected.signInWithApple(idToken: "rejected-token", nonce: "mock-nonce")
        precondition(!appleRejected.isAuthenticated && appleRejected.errorMessage != nil && !appleRejected.isLoading && vault.value == nil)
        AuthMockProtocol.handler = { _ in preconditionFailure("Empty Apple credentials must not reach the server") }
        await appleRejected.signInWithApple(idToken: "", nonce: "")
        precondition(!appleRejected.isLoading && !appleRejected.isAuthenticated)

        var userRequests = 0
        vault.value = StoredSession(accessToken: "expired", refreshToken: "refresh")
        AuthMockProtocol.handler = { request in
            if request.url!.path == "/auth/v1/user" {
                userRequests += 1
                return userRequests == 1 ? (401, "{\"msg\":\"expired\"}") : (200, userJSON(userA))
            }
            precondition(request.url!.query == "grant_type=refresh_token")
            return (200, tokenJSON(userA))
        }
        let restored = makeAuth()
        await restored.restoreSession()
        precondition(restored.user?.id == userA && userRequests == 2, "Refresh must reverify the user")

        vault.value = StoredSession(accessToken: "bad", refreshToken: "bad")
        AuthMockProtocol.handler = { request in
            request.url!.path == "/auth/v1/user" ? (401, "{\"msg\":\"invalid token\"}") : (400, "{\"msg\":\"invalid refresh token\"}")
        }
        let rejected = makeAuth()
        await rejected.restoreSession()
        precondition(!rejected.isAuthenticated && vault.value == nil)

        let recovery = makeAuth()
        var recoveryRequests = 0
        AuthMockProtocol.handler = { request in
            recoveryRequests += 1
            if request.url!.path == "/auth/v1/recover" { return (200, "{}") }
            if request.url!.path == "/auth/v1/token" {
                precondition(request.url!.query == "grant_type=pkce")
                return (200, tokenJSON(userA))
            }
            if request.url!.path == "/auth/v1/logout" { return (204, "") }
            precondition(request.url!.path == "/auth/v1/user")
            return (200, userJSON(userA))
        }
        recovery.handleEmailCallback(URL(string: "humanhydration://email-confirmed?code=unsolicited")!)
        try await Task.sleep(nanoseconds: 100_000_000)
        precondition(recoveryRequests == 0 && !recovery.needsPasswordReset)
        await recovery.requestPasswordReset(email: "test@example.com")
        precondition(recovery.confirmationMessage != nil)
        recovery.handleEmailCallback(URL(string: "humanhydration://email-confirmed?code=mock-code")!)
        try await Task.sleep(nanoseconds: 100_000_000)
        precondition(recovery.needsPasswordReset && !recovery.isAuthenticated, "Recovery must not enter the app")
        await recovery.finishPasswordReset(password: "new-password123")
        precondition(!recovery.needsPasswordReset && !recovery.isAuthenticated && recovery.confirmationMessage != nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        AuthMockProtocol.handler = { request in
            request.url!.path == "/auth/v1/user" ? (200, userJSON(userA)) : (200, tokenJSON(userA))
        }
        let photoAuth = makeAuth()
        let photoSignedIn = await photoAuth.signIn(email: "test@example.com", password: "password123")
        precondition(photoSignedIn)
        let photoToken = try await photoAuth.accessTokenForAPI()
        precondition(photoToken == "mock-access")
        var photoUserRequests = 0
        AuthMockProtocol.handler = { request in
            if request.url!.path == "/auth/v1/user" {
                photoUserRequests += 1
                return photoUserRequests == 1 ? (401, "{}") : (200, userJSON(userA))
            }
            precondition(request.url!.query == "grant_type=refresh_token")
            return (200, tokenJSON(userA))
        }
        _ = try await photoAuth.accessTokenForAPI()
        precondition(photoUserRequests == 2, "Photo API refresh revalidates identity")
        AuthMockProtocol.handler = { _ in (200, userJSON(userB)) }
        do { _ = try await photoAuth.accessTokenForAPI(); preconditionFailure("Must reject switched identity") }
        catch { }
        print("PASS: photo API session validation, refresh, and identity mismatch")

        let a = AccountStorage.defaults(for: userA)
        let b = AccountStorage.defaults(for: userB)
        defer {
            a.removePersistentDomain(forName: "com.humanhydration.account.\(userA.uuidString.lowercased())")
            b.removePersistentDomain(forName: "com.humanhydration.account.\(userB.uuidString.lowercased())")
        }
        let storeA = HydrationStore(defaults: a)
        storeA.displayName = "Account A"
        storeA.addWater(500)
        a.set(true, forKey: "hasCompletedOnboarding")
        let storeB = HydrationStore(defaults: b)
        precondition(storeB.displayName.isEmpty && storeB.entries.isEmpty && !b.bool(forKey: "hasCompletedOnboarding"))
        let returningA = HydrationStore(defaults: AccountStorage.defaults(for: userA))
        precondition(returningA.displayName == "Account A" && returningA.todayAmountML == 500 && a.bool(forKey: "hasCompletedOnboarding"))
        print("PASS: legacy bypass, malformed session, pending signup + redirect, identity mismatch, verified login, safe callback, logout, refresh, invalid session, PKCE recovery, account isolation + onboarding persistence.")
    }
}
