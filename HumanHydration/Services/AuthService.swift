import Foundation
import Combine
import CryptoKit

struct AuthUser: Decodable, Equatable {
    let id: UUID
    let email: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }

    var memberSince: Date? {
        guard let createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isRestoring = true
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var confirmationMessage: String?
    @Published private(set) var needsPasswordReset = false
    private var recoveryVerifier: String?
    private var recoveryEmail: String?
    private var recoveryToken: String?
    var isAuthenticated: Bool { user != nil }
    private let session: URLSession
    private let vault: any SessionVault
    private let defaults: UserDefaults
    private let clearWidgets: () -> Void
    private var generation = 0

    init(session: URLSession = .shared, vault: any SessionVault = KeychainSessionVault(), defaults: UserDefaults = .standard, clearWidgets: @escaping () -> Void = { HydrationWidgetData.clear() }) {
        self.session = session
        self.vault = vault
        self.defaults = defaults
        self.clearWidgets = clearWidgets
    }

    func restoreSession() async {
        guard isRestoring else { return }
        let operation = generation
        defer { isRestoring = false }
        defaults.removeObject(forKey: "isSignedIn")
        do {
            var saved = try vault.read()
            // Migrate tokens only after server verification. Never trust the legacy login flag.
            if saved == nil,
               let access = defaults.string(forKey: "supabaseAccessToken"),
               let refresh = defaults.string(forKey: "supabaseRefreshToken") {
                saved = StoredSession(accessToken: access, refreshToken: refresh)
            }
            guard let saved else {
                forgetWidgets()
                return
            }
            do {
                try await accept(saved, expectedID: nil, operation: operation)
            } catch AuthError.http(let code, _) where code == 401 || code == 403 {
                let response: AuthResponse = try await request(path: "/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": saved.refreshToken])
                try await accept(response, operation: operation)
            }
        } catch {
            guard operation == generation else { return }
            if case AuthError.http(let status, _) = error, (400...499).contains(status), status != 429 {
                vault.clear()
                removeLegacyTokens()
                forgetWidgets()
            }
            errorMessage = "Please sign in again. " + friendlyMessage(for: error)
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        await authenticate(path: "/auth/v1/token?grant_type=password", email: email, password: password, signup: false)
    }

    func signUp(email: String, password: String) async -> Bool {
        let redirect = AppConfig.emailRedirectURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        return await authenticate(path: "/auth/v1/signup?redirect_to=\(redirect)", email: email, password: password, signup: true)
    }

    func requestPasswordReset(email: String) async {
        guard !isLoading, user == nil else { return }
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.contains("@"), clean.contains(".") else {
            errorMessage = "Enter your email address first."
            return
        }
        isLoading = true
        errorMessage = nil
        confirmationMessage = nil
        let operation = generation
        let verifier = UUID().uuidString + UUID().uuidString
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        defer { isLoading = false }
        do {
            let redirect = AppConfig.emailRedirectURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            _ = try await send(path: "/auth/v1/recover?redirect_to=\(redirect)", method: "POST", body: ["email": clean, "code_challenge": challenge, "code_challenge_method": "s256"])
            guard operation == generation else { return }
            recoveryVerifier = verifier
            recoveryEmail = clean
            confirmationMessage = "If that account exists, we’ve sent a reset link. Open it on this device without quitting Human Hydration."
        } catch {
            if operation == generation { errorMessage = friendlyMessage(for: error) }
        }
    }

    private func openPasswordRecovery(code: String) async {
        guard !isLoading, user == nil, let verifier = recoveryVerifier, let email = recoveryEmail else {
            errorMessage = "Request a new password reset from this device, then open its latest email."
            return
        }
        isLoading = true
        let operation = generation
        defer { isLoading = false }
        do {
            let response: AuthResponse = try await request(path: "/auth/v1/token?grant_type=pkce", body: ["auth_code": code, "code_verifier": verifier])
            guard let token = response.accessToken, let expected = response.user else { throw AuthError.invalidResponse }
            let verified: AuthUser = try await request(path: "/auth/v1/user", method: "GET", token: token)
            guard operation == generation else { return }
            guard verified.id == expected.id, verified.email?.lowercased() == email.lowercased() else { throw AuthError.invalidResponse }
            recoveryVerifier = nil
            recoveryToken = token
            errorMessage = nil
            confirmationMessage = nil
            needsPasswordReset = true
        } catch {
            if operation == generation { errorMessage = friendlyMessage(for: error) }
        }
    }

    func finishPasswordReset(password: String) async {
        guard !isLoading, user == nil, let token = recoveryToken else { return }
        guard password.count >= 8 else { errorMessage = "Use at least 8 characters."; return }
        isLoading = true
        let operation = generation
        defer { isLoading = false }
        do {
            _ = try await send(path: "/auth/v1/user", method: "PUT", body: ["password": password], token: token)
            guard operation == generation else { return }
            cancelPasswordReset()
            confirmationMessage = "Password updated. Sign in with your new password."
        } catch {
            if operation == generation { errorMessage = friendlyMessage(for: error) }
        }
    }

    func cancelPasswordReset() {
        let token = recoveryToken
        recoveryToken = nil
        recoveryVerifier = nil
        recoveryEmail = nil
        needsPasswordReset = false
        if let token {
            Task { _ = try? await send(path: "/auth/v1/logout?scope=local", method: "POST", token: token) }
        }
    }

    private func authenticate(path: String, email: String, password: String, signup: Bool) async -> Bool {
        guard !isLoading, !isAuthenticated, validate(email: email, password: password) else { return false }
        cancelPasswordReset()
        // An explicit login/signup attempt must not resurrect a different cached session later.
        vault.clear()
        removeLegacyTokens()
        isLoading = true
        let operation = generation
        defer { isLoading = false }
        do {
            let response: AuthResponse = try await request(path: path, body: ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password])
            guard operation == generation else { return false }
            if signup, response.accessToken == nil {
                confirmationMessage = "Check your email to confirm your account, then sign in here. If you already registered, use Sign in."
                return false
            }
            try await accept(response, operation: operation)
            return user != nil
        } catch {
            if operation == generation { errorMessage = friendlyMessage(for: error) }
            return false
        }
    }

    func signInWithApple(idToken: String, nonce: String) async {
        guard !isLoading, !isAuthenticated else { return }
        guard !idToken.isEmpty, !nonce.isEmpty else {
            errorMessage = "Apple didn’t return a valid sign-in token. Please try again."
            return
        }
        cancelPasswordReset()
        vault.clear()
        removeLegacyTokens()
        confirmationMessage = nil
        isLoading = true
        errorMessage = nil
        let operation = generation
        defer { isLoading = false }
        do {
            let response: AuthResponse = try await request(path: "/auth/v1/token?grant_type=id_token", body: ["provider": "apple", "id_token": idToken, "nonce": nonce])
            try await accept(response, operation: operation)
        } catch {
            if operation == generation { errorMessage = friendlyMessage(for: error) }
        }
    }

    private func accept(_ response: AuthResponse, operation: Int) async throws {
        guard let access = response.accessToken, !access.isEmpty,
              let refresh = response.refreshToken, !refresh.isEmpty,
              let responseUser = response.user else { throw AuthError.invalidResponse }
        try await accept(.init(accessToken: access, refreshToken: refresh), expectedID: responseUser.id, operation: operation)
    }

    private func accept(_ tokens: StoredSession, expectedID: UUID?, operation: Int) async throws {
        let verified: AuthUser = try await request(path: "/auth/v1/user", method: "GET", token: tokens.accessToken)
        guard expectedID == nil || verified.id == expectedID else { throw AuthError.invalidResponse }
        guard operation == generation else { throw CancellationError() }
        try vault.save(tokens)
        removeLegacyTokens()
        defaults.set(verified.id.uuidString.lowercased(), forKey: "activeWidgetAccountID")
        errorMessage = nil
        confirmationMessage = nil
        user = verified
    }

    /// Return a verified, refreshed session for authenticated app API calls.
    func accessTokenForAPI() async throws -> String {
        guard let expectedID = user?.id, let saved = try vault.read() else { throw AuthError.invalidResponse }
        let operation = generation
        do {
            let verified: AuthUser = try await request(path: "/auth/v1/user", method: "GET", token: saved.accessToken)
            guard operation == generation, user?.id == expectedID, verified.id == expectedID else { throw CancellationError() }
            return saved.accessToken
        } catch AuthError.http(let code, _) where code == 401 || code == 403 {
            let response: AuthResponse = try await request(path: "/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": saved.refreshToken])
            guard response.user?.id == expectedID, operation == generation else { throw AuthError.invalidResponse }
            try await accept(response, operation: operation)
            guard let refreshed = try vault.read(), user?.id == expectedID else { throw AuthError.invalidResponse }
            return refreshed.accessToken
        }
    }

    func deleteAccount() async -> Bool {
        guard !isLoading, let userID = user?.id else { return false }
        isLoading = true
        errorMessage = nil
        confirmationMessage = nil
        defer { isLoading = false }
        do {
            let token = try await accessTokenForAPI()
            var request = URLRequest(url: AppConfig.supabaseURL.appendingPathComponent("functions/v1/delete-account"))
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
            let (_, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw AuthError.http((response as? HTTPURLResponse)?.statusCode ?? 0, "Couldn’t delete your account. Check your connection and try again.")
            }
            AccountStorage.wipe(userID)
            signOut()
            return true
        } catch {
            errorMessage = "Couldn’t delete your account. Check your connection and try again."
            return false
        }
    }

    func signOut() {
        cancelPasswordReset()
        let tokens = try? vault.read()
        generation += 1
        user = nil
        vault.clear()
        removeLegacyTokens()
        defaults.removeObject(forKey: "isSignedIn")
        forgetWidgets()
        errorMessage = nil
        confirmationMessage = nil
        if let tokens {
            Task {
                // Local logout succeeds even offline. Revoke this server session when reachable.
                _ = try? await send(path: "/auth/v1/logout?scope=local", method: "POST", token: tokens.accessToken)
            }
        }
    }

    func handleEmailCallback(_ url: URL) {
        guard url.scheme == AppConfig.emailRedirectURL.scheme,
              url.host == AppConfig.emailRedirectURL.host else { return }
        // Never replace an active account from an unsolicited email link.
        guard user == nil else { return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let items = query + (URLComponents(string: "https://callback.invalid/?" + (url.fragment ?? ""))?.queryItems ?? [])
        if items.contains(where: { $0.name == "error" || $0.name == "error_code" }) {
            errorMessage = "This confirmation link is invalid or expired. Request a new email, then try again."
        } else if let code = query.first(where: { $0.name == "code" })?.value {
            Task { await openPasswordRecovery(code: code) }
        } else {
            confirmationMessage = "Return to Sign in with your email and password to verify your account."
        }
    }

    private func forgetWidgets() {
        defaults.removeObject(forKey: "activeWidgetAccountID")
        clearWidgets()
    }

    private func removeLegacyTokens() {
        defaults.removeObject(forKey: "supabaseAccessToken")
        defaults.removeObject(forKey: "supabaseRefreshToken")
    }

    private func request<T: Decodable>(path: String, method: String = "POST", body: [String: String]? = nil, token: String? = nil) async throws -> T {
        let data = try await send(path: path, method: method, body: body, token: token)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func send(path: String, method: String, body: [String: String]? = nil, token: String? = nil) async throws -> Data {
        var components = URLComponents(url: AppConfig.supabaseURL, resolvingAgainstBaseURL: false)!
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        components.path = String(parts[0])
        components.percentEncodedQuery = parts.count > 1 ? String(parts[1]) : nil
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.httpMethod = method
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw AuthError.http(http.statusCode, error?.errorDescription ?? error?.msg ?? error?.message ?? error?.errorCode ?? "Authentication failed (HTTP \(http.statusCode)).")
        }
        return data
    }

    private func validate(email: String, password: String) -> Bool {
        errorMessage = nil
        confirmationMessage = nil
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.contains("@"), clean.contains(".") else { errorMessage = "Enter a valid email address."; return false }
        guard password.count >= 6 else { errorMessage = "Your password must be at least 6 characters."; return false }
        return true
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("email not confirmed") || message.contains("email_not_confirmed") { return "Confirm your email from the link we sent, then sign in again." }
        if message.localizedCaseInsensitiveContains("invalid login credentials") { return "That email or password doesn’t look right." }
        return message
    }
}

private struct AuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: AuthUser?
    enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", user }
}
private struct AuthErrorResponse: Decodable {
    let errorDescription: String?
    let message: String?
    let msg: String?
    let errorCode: String?
    enum CodingKeys: String, CodingKey { case errorDescription = "error_description", message, msg, errorCode = "error_code" }
}
private enum AuthError: LocalizedError {
    case invalidResponse
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server didn’t return a valid account session. Please sign in again."
        case .http(_, let message): return message
        }
    }
}
