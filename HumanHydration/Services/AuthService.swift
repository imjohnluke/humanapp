import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var confirmationMessage: String?

    let client: SupabaseClient

    init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabasePublishableKey
        )

        Task { await restoreSession() }
    }

    func restoreSession() async {
        do {
            _ = try await client.auth.session
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        guard validate(email: email, password: password) else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
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
            try await client.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            if client.auth.currentSession != nil {
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
        if message.localizedCaseInsensitiveContains("invalid login credentials") {
            return "That email or password doesn’t look right."
        }
        if message.localizedCaseInsensitiveContains("already registered") {
            return "That email already has an account. Try signing in."
        }
        return message
    }
}
