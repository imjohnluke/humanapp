# human app — release readiness

Updated September 12, 2026. This is a working release checklist, not a declaration that the app is ready to submit.

## TestFlight upload — September 12

- App Store Connect name approved: **human hydration** (`human app` was unavailable).
- App Store Connect ID: `6811384072`; bundle ID unchanged.
- Signing team: `DWFW94687C`; app and widget signed archive succeeded with App Group support.
- Corrected widget CFBundleDisplayName and iPad orientation declarations after Apple's first upload validation rejected them.
- Corrected archive: `/tmp/human-testflight-corrected.xcarchive`.
- Upload via `TestFlightExportOptions.plist` succeeded at 11:35 CDT. Apple processing completed and export compliance answered for system-provided encryption only. Future builds include ITSAppUsesNonExemptEncryption=false.
- Internal group `human internal` created with automatic distribution. Version 1.0 (1) verified **Testing**; account owner verified **Invited**. Installation on the owner's iPhone remains to be checked.
- No public App Store review submission or public external tester link created.

## Product decisions

- Display name: **human app**. Bundle ID remains `com.humanhydration.app`.
- Website supplied by owner: `thehumanapp.com`. Public pages and support contact not verified.
- Recommendation: free TestFlight and free first release. No pricing, paywall, or subscription product has been configured; owner has not committed to pricing.
- Final icon supplied as `/Users/johnluke/Downloads/f/Logo.png`, imported in AppIcon at 1024×1024 with white background and no alpha. Original artwork and spacing retained.

## Completed in this release pass

- Progress chart uses real last-seven-day logs instead of demo values.
- Home, Profile and Progress use the same day-based streak and average calculations.
- Average includes zero-log days. Today can be unfinished without breaking a streak through yesterday. Goal comparisons currently use the user's current goal, not a historical goal snapshot.
- Optional daily local reminder, permission handling, configurable time, cancellation on logout.
- Profile name can be edited in Settings.
- Password recovery UI and PKCE code exchange. Recovery session does not enter the account; after changing password, sign in normally. Reset must be started and completed on the same running app instance. If the app is terminated, request a fresh link.
- Required-reason UserDefaults privacy manifests for app and widget; account email/user-ID declarations for app. Re-audit if sync, analytics or other data collection is added.
- Removed unused HealthKit entitlement/usage descriptions. Health integration is not active.
- Display name and launch-screen generation set in `project.yml`; project regenerated.
- Repeatable checks: `DEVELOPER_DIR="/Users/johnluke/Downloads/Xcode-beta.app/Contents/Developer" zsh Tests/run-checks.sh`.

## Blockers before public release

1. **Signing completed:** team DWFW94687C configured for app and extension, App Group signing validated, and device archive accepted and processed by TestFlight. Repeat archive validation for the final public-release build.
2. **Apple sign-in:** last verified backend state was disabled. Verify/enable the correct Supabase Apple provider, bundle audience and Apple credentials. Device-test success, cancellation, existing account, and revoked authorization. Existing custom Apple button treatment needs Apple branding/accessibility review.
3. **Account deletion:** implement authenticated server-side self-deletion with in-app confirmation; revoke Apple authorization where applicable, remove related server rows and local account data. Never ship a service-role key in the app. Do not pretend logout is deletion. No deletion endpoint has been deployed or account deleted in this pass.
4. **Production email:** verify sender/domain and SMTP delivery, rate limits, confirmation and recovery templates. Use fresh emails to test the approved `humanhydration://email-confirmed` redirect. Recovery mock tests are not live delivery tests. Do not disable ownership verification to hide delivery failures.
5. **Privacy/support website:** publish approved privacy policy and real support contact on `thehumanapp.com`, then link from app and App Store Connect. Owner identity, contact, retention and launch audience still needed. No legal policy has been invented or published.
6. **Data reliability:** logs/onboarding/bottle are still account-scoped local defaults, not Supabase sync. Remote tables exist and have RLS but were empty on audit. Decide explicitly whether v1 is local-only; do not promise cross-device backup until sync, tombstones, conflict handling and account-isolation tests work. Preserve existing local data during any migration.
7. **Rewards:** locked colors and future slots are previews, not an implemented reward system. Either implement/test unlock persistence and clear rules or remove unreleased reward promises for v1. Never reward drinking beyond the goal.
8. **Subscription placeholder:** Settings still links to Apple subscription management and explicitly says no paid plan is configured. Remove for a free launch, or implement StoreKit products, restore, entitlement handling and purchase review before charging.
9. **Supabase security:** security advisor reported leaked-password protection disabled. Review availability/cost before enabling. No missing-RLS warning returned for the existing tables.
10. **Release QA:** new accounts A/B, confirmation, bad password, reset success/expired link, restart, offline state, midnight/timezone change, log/remove, goals, widgets, reminders denied/enabled, small iPhone, iPad and Dynamic Type. Test new auth UI on a real device before TestFlight.

## App Store Connect

App record human hydration is created with English (US) and the existing bundle ID. Version 1.0 (1) is available for internal TestFlight testing. Before public release, complete category, age rating, privacy labels, support and privacy URLs, screenshots, copyright, and review contact/demo account. No public App Store review submission, external testing link, or purchase has been made.

## References

- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Account deletion requirements](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Supabase password flows and production email](https://supabase.com/docs/guides/auth/passwords)
- [Supabase leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
- [Apple required-reason API declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
