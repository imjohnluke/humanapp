import Foundation

enum AppConfig {
    // Configure a published privacy policy before enabling paid purchases.
    static var privacyPolicyURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PrivacyPolicyURL") as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    static let emailRedirectURL = URL(string: "humanhydration://email-confirmed")!
    static let supabaseURL = URL(string: "https://vcjklnjczsgyxllgehin.supabase.co")!

    // This is Supabase's publishable client key. It is safe to include in an iOS app;
    // access is enforced by Supabase Auth and the row-level security policies.
    static let supabasePublishableKey = "sb_publishable_66CSIXhspdDNl6RS_MJ-CA_w4x4i5XI"
}
