import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: "https://vcjklnjczsgyxllgehin.supabase.co")!

    // This is Supabase's publishable client key. It is safe to include in an iOS app;
    // access is enforced by Supabase Auth and the row-level security policies.
    static let supabasePublishableKey = "sb_publishable_66CSIXhspdDNl6RS_MJ-CA_w4x4i5XI"
}
