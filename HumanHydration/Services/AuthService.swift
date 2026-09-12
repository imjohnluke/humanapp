import Foundation
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var confirmationMessage: String?

    init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        if UserDefaults.standard.string(forKey: "supabaseAccessToken") != nil {
            isAuthenticated = true
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        guard validate(email: email, password: password) else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await request(
                path: "/auth/v1/token?grant_type=password",
                body: [
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                    "password": password
                ]
            )
            saveSession(from: response)
            isAuthenticated = true
            errorMessage = nil
            confirmationMessage = nil
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func signUp(email: String, password: String) async -> Bool {
        guard validate(email: email, password: password) else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await request(
                path: "/auth/v1/signup",
                body: [
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                    "password": password
                ]
            )
            if response.accessToken != nil {
                saveSession(from: response)
                isAuthenticated = true
                confirmationMessage = nil
            } else {
                confirmationMessage = "Check your email to confirm your account, then sign in here."
            }
            errorMessage = nil
            return isAuthenticated
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func useLocalAppleSession() {
        // Apple UI remains available while its Supabase provider settings are finalized.
        // The native Apple credential flow can be swapped into this service without changing the screen.
        isAuthenticated = true
    }

    private func request(path: String, body: [String: String]) async throws -> AuthResponse {
        var request = URLRequest(url: AppConfig.supabaseURL.appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        let decoder = JSONDecoder()
        if (200...299).contains(httpResponse.statusCode) {
            return try decoder.decode(AuthResponse.self, from: data)
        }

        if let error = try? decoder.decode(AuthErrorResponse.self, from: data) {
            throw AuthError.server(error.errorDescription ?? error.msg ?? error.message ?? error.errorCode ?? "Authentication failed.")
        }
        let serverBody = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw AuthError.server("Authentication failed (HTTP \(httpResponse.statusCode)). \(serverBody ?? "Try again.")")
    }

    private func saveSession(from response: AuthResponse) {
        guard let accessToken = response.accessToken else { return }
        UserDefaults.standard.set(accessToken, forKey: "supabaseAccessToken")
        if let refreshToken = response.refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "supabaseRefreshToken")
        }
    }

    private func validate(email: String, password: String) -> Bool {
        errorMessage = nil
        confirmationMessage = nil

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            errorMessage = "Enter a valid email address."
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "Your password must be at least 6 characters."
            return false
        }

        return true
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("email not confirmed") || message.localizedCaseInsensitiveContains("email_not_confirmed") {
            return "Confirm your email from the link we sent, then try signing in again."
        }
        if message.localizedCaseInsensitiveContains("invalid login credentials") {
            return "That email or password doesn’t look right."
        }
        if message.localizedCaseInsensitiveContains("already registered") {
            return "That email already has an account. Try signing in."
        }
        return message
    }
}

private struct AuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct AuthErrorResponse: Decodable {
    let errorDescription: String?
    let message: String?
    let msg: String?
    let errorCode: String?

    enum CodingKeys: String, CodingKey {
        case errorDescription = "error_description"
        case message
        case msg
        case errorCode = "error_code"
    }
}

private enum AuthError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .server(let message):
            return message
        }
    }
}
