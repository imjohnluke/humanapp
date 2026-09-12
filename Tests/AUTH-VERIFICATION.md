# Authentication verification

## Automated regression checks

Compile `Tests/AuthChecks.swift` with AuthService, AppConfig, SessionVault,
AccountStorage, HydrationStore, HydrationEntry and HydrationWidgetData using swiftc.
The executable uses URLProtocol mocks and isolated temporary defaults, not real users.
It covers missing tokens, wrong passwords, confirmation-pending and immediate signup,
server identity verification, expired/invalid sessions, refresh, logout, callback
account-switch prevention, and two-account onboarding/data isolation.

## Supabase dashboard configuration and verification

Project: `vcjklnjczsgyxllgehin` (human app).

- Authentication → URL Configuration was previously saved and reload-verified with
  `humanhydration://email-confirmed` as Site URL and an allowed redirect. Test fresh emails on a device before release.
- Emails → Confirm signup: use Supabase's `{{ .ConfirmationURL }}` link;
  remove any hardcoded URL to a different project. Inspect other auth templates too.
- The callback opens this app and asks the user to sign in. It does not trust
  tokens supplied in arbitrary deep links or replace an active account.
- Email confirmation is currently ON. Turning it OFF is optional for testing:
  new signups still need a real Supabase session, but email ownership is not verified.
- Apple is currently disabled server-side. Enable it with this app's Apple bundle
  identifier before testing native Apple sign-in. The previous local-only bypass
  has been removed; provider configuration errors are now shown honestly.

Existing emails retain their original destination; test a newly sent email after
correcting the dashboard configuration.

## Device acceptance checklist (not yet performed)

1. New email A → confirm if enabled → log in → starts at Your name.
2. Complete onboarding, log water, quit and reopen → same A profile/logs.
3. Logout → login screen; wrong password remains there with an error.
4. New email B → its own onboarding, no A name/bottle/logs.
5. Logout B, login A → A's onboarding remains completed and A's logs return.
6. Tap a newly sent confirmation email → human opens, not another website.
7. Verify Apple on a device after enabling its Supabase provider.
8. Sign in → Forgot password → fresh email on the same running app → new password screen → save → sign in with the new password. Confirm expired/unsolicited links cannot enter recovery or switch accounts. After terminating the app, start a fresh reset request.

## Data boundary

Hydration/onboarding are still stored locally, now scoped to verified Supabase UUID.
They do not sync across devices yet. Legacy unscoped data is preserved in the old
defaults but not assigned to any account because its owner cannot be proven.
Sessions are stored in Keychain; legacy tokens migrate only after server verification.
