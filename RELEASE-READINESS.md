# human app — release readiness

## Glass Apple button restored — pending next upload

Restored the original glass capsule and white Apple label using a real SwiftUI Button that directly starts ASAuthorizationController. A retained coordinator supplies the active window, prevents duplicate presentations, and releases request state on success/cancellation/error. The nonce and Supabase token exchange remain intact. Simulator Debug build passed. This change has not been uploaded; build 6 still has the standard white Apple button. Real-device sign-in should be rechecked after this presentation change.

## Calendar and glass-first onboarding — build 6, September 14, 2026

- Home's date strip scrolls horizontally through a year of dates or the full saved history, whichever is longer. Earlier dates extends the range; Today returns to the current day. Date selection continues to display that day's entries and total.
- Onboarding starts with a glass of water and uses large, swipeable bottle pages with previous/next arrows, matching Home's chooser style. It explicitly asks what the user drinks water from most often, allows capacity adjustment, and saves the selection as the usual drink for Home. The chooser's fallback and new WaterBottle defaults are glass; saved existing choices are retained.
- Swift checks, simulator Debug build, and signed Release archive passed. No device interaction test was performed for these UI changes.
- Version 1.0 (6) uploaded successfully at **01:18:54 CDT**. Apple reports package processing. Archive: `/tmp/human-calendar-bottle-build6.xcarchive`; upload log: `/tmp/human-calendar-bottle-upload.log`. Tester availability and external beta review status remain unverified.

## Apple sign-in and onboarding upsell — build 5, September 14, 2026

- Replaced the Apple sign-in control at 1% opacity over a custom label with a visible native button. The transparent control was a likely cause of the reported failure to open Apple's authorization sheet. Clear stale messages and nonce state, dismiss the keyboard on authorization, and prevent starting another Apple exchange while authentication is loading.
- Live public Auth settings confirm `external.apple=true` and signup enabled. Build 4 already carried the Apple sign-in entitlement. Real-device authorization, cancellation, and returning-account login still need verification; mocked token checks do not prove Apple's sheet completes.
- Signup explicitly starts free. After the personal plan summary, new free accounts see a full-screen Human Pro offer with a persistent Continue with free option. Existing Pro users skip the offer; successful purchase/restore exits it. Onboarding completion remains account-scoped.
- Uses the existing StoreKit purchase and restore implementation. Paid checkout remains gated by backend availability and a configured privacy URL; the offer explains when purchases are unavailable.
- Swift checks, including added Apple token success, identity mismatch, rejection, and empty-credential cases, passed. Simulator Debug build and signed Release archive passed; app and widget are both 1.0 (5).
- Archive: `/tmp/human-apple-upsell-build5.xcarchive`. Apple accepted the upload at **01:04:05 CDT**: `Upload succeeded`, `EXPORT SUCCEEDED`, package processing. Upload log: `/tmp/human-apple-upsell-upload.log`. Final TestFlight availability and external beta review status remain unverified; no public App Store submission was made.

## Latest TestFlight upload — September 14, 2026

Version **1.0 (4)** was successfully uploaded to Apple at **00:53:45 CDT** on September 14. Verified from `/tmp/human-testflight-build4.xcarchive/Info.plist`: distribution upload state `success`, title `Uploaded to Apple`, uploaded build number `4`, no errors or warnings. Archive creation followed merge commit `1c1c6f4` (personalized hydration plans and adaptive Pro experience). The working tree was clean when checked. No duplicate upload was needed.

Live processing, internal testing availability, and external Beta App Review status for build 4 remain unverified because App Store Connect requires renewed sign-in. The earlier external-review submission below refers to build 3, not build 4.

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
- Recommendation: free TestFlight and free first release. Subscription implementation and a US $4.99/month draft now exist; there is no annual plan. Paid-launch validation remains pending. See APPLE-BILLING.md.
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
8. **Subscriptions:** StoreKit purchase/restore and server verification are implemented. Finish availability, notification delivery verification, privacy URL, OpenAI setup and device sandbox testing before enabling billing; see APPLE-BILLING.md.
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

## TestFlight upload — September 13

All Swift checks passed under Xcode 27 (27A5252f). Full signed release archive succeeded at `/tmp/human-testflight-20260913.xcarchive`. Export/upload through the existing automatic signing configuration succeeded at 15:37 CDT; Apple reported “Uploaded package is processing.” This includes the latest guided scanner, saved drinks, ounce displays, profile and Home/nav changes.

App Store Connect browser authentication expired, so final processing and internal-group Testing status are not yet independently verified. The existing human internal group was previously configured for automatic distribution. No public App Store submission was made. Source version settings now keep app and widget build numbers aligned; Xcode managed versions during upload.

## Health integration release — September 13, 2026

Signed Release archive succeeded at `/tmp/human-health-testflight-20260913.xcarchive`, version 1.0 build 3, with HealthKit entitlement. This supersedes the earlier note that HealthKit was removed: workout and optional sleep reads now support on-device Insights and the optional onboarding/Settings connection. No automatic workout notifications or health-to-AI upload are implemented. Full Debug build and Swift checks passed before archive.

Fresh public Supabase Auth settings check returned `external.apple=false`: Apple sign-in is not operational. Paid subscription checkout remains gated pending privacy URL, product availability, signed notification verification and sandbox purchase testing. Test Pro access is separate from paid checkout.

The initial build 3 upload failed Apple validation because NSHealthUpdateUsageDescription was missing. Added an accurate purpose string explaining that this version does not request Health write access, regenerated, and rebuilt. Corrected signed archive: `/tmp/human-health-testflight-fixed-20260913.xcarchive`. Upload accepted at 16:03:57 CDT: “Uploaded package is processing”, “Upload succeeded”, EXPORT SUCCEEDED. Final TestFlight processing/internal-group availability has not been independently confirmed. No public App Store release.

## Apple sign-in configuration corrected — September 13, 2026

Enabled Supabase Apple provider with native Client ID `com.humanhydration.app`. Fresh uncached public `/auth/v1/settings` response confirms `external.apple=true`. No OAuth secret is required for this native ID-token flow. Device sign-in still needs verification. This supersedes the disabled-provider findings above. App Store Connect display-name correction remains pending renewed browser sign-in; the uploaded app bundle display name is already `Human Hydration`.

App Store Connect name updated to `Human Hydration` in English (U.S.) App Information and saved on September 13. Build 3 upload is Complete and associated with human internal; list displays Ready to Submit (no external review submitted).

## External TestFlight setup

Created external group `Human Hydration Public Beta` and selected build 3 in the Add Builds flow. Apple requires Beta App Review information before submission. Prepared beta description, known owner name/email, and the existing test Pro reviewer login in the form. Contact phone number is required and awaiting the owner; submission is not complete and no usable public invite link has been verified. The browser is left on the review information form.

Owner supplied required beta review contact phone. Submitted 1.0 (3) to external Beta App Review; verified Waiting for Review. Created open public invite link https://testflight.apple.com/join/bWrHt9Qp for Human Hydration Public Beta. Apple states testers cannot join until the group has an approved build. No public App Store release was submitted.
