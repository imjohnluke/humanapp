# human Pro billing — September 13, 2026

## Implemented

StoreKit 2 monthly subscription, purchase, restore, transaction updates and account binding are wired into Profile and photo logging. Server verification uses Apple's official library and fresh subscription status; signed notifications reconcile renewals, expiry, revocation and grace periods. Manual test access remains independent of paid access. Sandbox purchases are restricted to explicitly allowlisted app accounts.

Deployed to Supabase project `vcjklnjczsgyxllgehin`: migration `20260913095700`, `apple-subscriptions` v1, `apple-notifications` v1 and `estimate-water` v2. Gateway JWT checking is disabled; handlers validate Supabase user tokens or Apple signatures themselves. Billing credentials are server secrets only.

## Apple configuration

App `6811384072`, bundle `com.humanhydration.app`, group human Pro `22381329`.

| Plan | Product ID | Apple ID |
|---|---|---|
| Monthly | com.humanhydration.pro.monthly | 6811562815 |

The sole plan is US $4.99 per month, with Apple-generated equivalent storefront prices. English US localization is saved. The unused annual draft (6811563131) was deleted at the owner’s request; the app only loads and purchases the monthly product. Availability remains unset.

The approved In-App Purchase key human Pro server (`Z99A54TH5K`) was generated and configured as `APPLE_IAP_PRIVATE_KEY`, `APPLE_IAP_KEY_ID`, and `APPLE_IAP_ISSUER_ID`. Its private backup is outside the repository under `~/.codex/private/`. Never embed it in an iOS build.

Production and sandbox notification URL fields were saved to:
`https://vcjklnjczsgyxllgehin.supabase.co/functions/v1/apple-notifications`

The UI did not expose a version selector. Verify V2 with an actual signed test notification. Initial Apple test API requests returned 4040007 (no notification URL found), including immediately after saving; propagation or configuration still needs verification. Do not treat delivery as tested.

Paid Apps Agreement, banking and tax setup were observed active. No purchase, submission or public release was performed.

## Internal Pro account

`test@example.com` has server-side Pro through December 12, 2026 and is allowlisted for Apple sandbox transactions. Password and UUID are stored privately in `~/.codex/private/human-hydration-pro-test.json`. This is an app account, not an Apple Sandbox Apple Account. Password sign-in and both live access endpoints were verified.

## Remaining before paid launch

- Configure availability, review details and screenshot. Monthly pricing is approved and configured.
- `OPENAI_API_KEY` is configured; model access and live Pro photo availability are verified. Evaluate real photo estimates on device.
- Publish a verified privacy policy and set the app Info.plist `PrivacyPolicyURL` to its HTTPS URL; align App Store privacy disclosures.
- Verify signed Apple test notification delivery for both environments.
- On full Xcode/iPhone, test purchase, pending/cancelled purchase, restore, renewal, expiration, refund and account switching with Apple Sandbox. This Mac currently has only command-line tools.
- Enable `APPLE_BILLING_ENABLED=true` only when the above are ready. It is currently unset, so purchase availability is false.

## Validation completed

Swift checks, ten Node backend tests, Deno type checks and SwiftUI syntax parsing passed. Live transaction-scoped SQL tests covered account binding, stale refund replay, manual grants and sandbox restrictions. The notification endpoint rejected unsigned payloads. Full iOS build, genuine Apple transaction verification and live OpenAI calls remain unverified.

## TestFlight release build — September 13, 2026

Full Xcode 27 was located at `/Users/johnluke/Downloads/Xcode-beta.app`. The complete signed iOS release archive (including the custom camera, StoreKit and widget targets) succeeded, and the full Swift check suite passed under this toolchain. This supersedes earlier notes saying only syntax validation was available. Real iPhone camera and purchase behavior still require testing.
