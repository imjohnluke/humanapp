# Pro photo logging

The Add water sheet has a **Log with a photo · PRO** entry. A signed-in Pro user can take or choose a photo, explicitly send it for analysis, edit the estimate, and log the amount they drank. No entry is created during capture or analysis. Confirming uses the existing account-scoped HydrationStore, updating entries, streaks, rewards and widgets.

The estimate describes visible water, not proof of consumption. Hidden fill levels, ambiguous multiple vessels, empty vessels and unusable scale cues should be declined. Capacity and remaining water are separate fields. Real-world accuracy needs evaluation with measured glasses and bottles before release.

## Server configuration

Project: `vcjklnjczsgyxllgehin` (human app).

- Apply `supabase/migrations/20260912202624_photo_logging_pro.sql`.
- Deploy `supabase/functions/estimate-water` with gateway JWT verification disabled: the handler verifies the bearer token through Supabase Auth before every access check and scan.
- Set **OPENAI_API_KEY** in the project's Edge Function secrets. Never put it in Info.plist, Swift source, or a committed file. The service-role key is supplied by Supabase at runtime.
- Optional secret **OPENAI_PHOTO_MODEL** overrides the default `gpt-4.1-mini-2025-04-14`.
- Set an appropriate project budget in OpenAI. The server reserves at most 20 attempts per user per UTC day, atomically. Failed AI requests count toward the limit. GET access checks do not.

The endpoint returns `available: false` if the OpenAI key is absent. There is no client bypass or fabricated AI response.

## Pro activation and billing boundary

`public.pro_entitlements` stores an expiry for each user. Clients can read their own row but cannot grant, extend or remove access. Only a trusted server or administrator can write it. For an internal test account, insert its existing Auth UUID and chosen expiry using the Supabase SQL editor. Never use user-editable metadata to authorize Pro.

StoreKit purchase/restore and verified Apple subscription processing are now implemented; see [APPLE-BILLING.md](APPLE-BILLING.md). `pro_access` combines manual grants with eligible Apple subscriptions. Purchases remain disabled until launch configuration is complete.

## Privacy

Before upload, the app explains that the selected photo goes to OpenAI. It re-renders the image to at most 1280 pixels on its longest edge, removes source metadata, and sends a JPEG capped at 2 MiB. Neither the Edge Function nor the app persists photos or provider responses. OpenAI receives the image without a user identifier; `store: false` is set. Provider abuse-monitoring retention is separate from response storage. Only per-user usage counts and Pro expiry persist on the backend. The privacy manifest declares photo data for app functionality; align App Store disclosures and the published privacy policy before release.

## Verification

- `zsh Tests/run-checks.sh`: Swift transport, response bounds, Pro/error states, session refresh/identity checks, and existing app checks.
- `node --test supabase/functions/estimate-water/handler.test.ts`: backend auth, quota enforcement, image validation, strict Responses payload, refusals and malformed model results.
- `npx --yes deno@2.5.6 check supabase/functions/estimate-water/index.ts`: Edge Function type checking.
- `Tests/PhotoDatabaseChecks.sql`: transaction-scoped entitlement, quota and privilege checks; leaves no test account or usage behind.

On an iPhone with Xcode: test denied camera access, photo picker cancellation, rotation, low-confidence images, a full and half-full labeled bottle, an opaque bottle, an empty glass, multiple vessels, offline/retry, expired Pro, double-tapping Log, and logout during analysis. Confirm logs go to the correct account exactly once. Live model estimates remain unverified until the server key is configured.

Implementation references: [OpenAI image inputs](https://developers.openai.com/api/docs/guides/images-vision), [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [Supabase function authentication](https://supabase.com/docs/guides/functions/auth), [Apple privacy data types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype).

## Deployment verification (September 12, 2026)

Migration `20260912202624` and Edge Function `estimate-water` version 1 are deployed to human app. Live database assertions passed and the endpoint returned 401 for an unauthenticated request. Swift checks, eight backend tests, Deno type checking, plist validation, and SwiftUI syntax parsing passed. No OpenAI key or Pro entitlements were configured by this change, and no photos were sent to OpenAI.

The Supabase advisor's no-policy notice on `photo_estimate_usage` is intentional: only service-role access is granted, and clients must not read or modify usage. It also reports the pre-existing [leaked-password protection setting](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection); this photo feature does not change Auth policy.

Full iOS build, camera interaction and live model quality testing remain pending; this Mac has command-line tools but no full Xcode installation.

## September 13 update

The Pro test account is provisioned, Apple server credentials are configured, and estimate-water v2 reads combined Pro access. OpenAI credentials and live model testing remain pending. See APPLE-BILLING.md for current deployment and payment status.

## OpenAI activation — September 13, 2026

OPENAI_API_KEY is now configured privately in Supabase. OpenAI returned HTTP 200 for the configured model lookup. The real Pro test login returned `is_pro: true, available: true` from estimate-water. No real photo was submitted in this activation check; end-to-end photo accuracy and iPhone camera testing remain pending.

## Guided scanner and usual drinks

Scan opens a custom AVFoundation preview. The user sees the OpenAI photo disclosure before Start scan. Core Motion measures device steadiness; after 1.6 seconds steady, the camera captures one still, then the backend estimates it. The guide/scan line is a visual aid, not live vessel detection. Capture now is available if motion sensing is unavailable or holding steady is difficult. No video stream is sent to OpenAI. Backgrounding and leaving the preview stop camera/motion capture.

The result supports quarter/half/all of the visible water, editable consumed milliliters, and a separate editable full-capacity value for saving a usual drink. Saving a drink does not log consumption. Home supports named saved drinks, quarter/half/full portions, manual entry and exact-entry Undo. Free users can save approximate size presets or a capacity from a label. Saved drinks are account-scoped local data like hydration logs; no cloud synchronization is claimed.

Validation: existing Swift checks and new saved-drink validation, rounding, persistence, deletion and Undo assertions pass. New UI files pass Swift syntax parsing and are included in the regenerated Xcode project. Full iOS type checking and device camera QA remain pending: test permission denial, steady auto-capture, manual capture, background/foreground, rotation, cancel during analysis, retake, saved-capacity correction, and measured glass/bottle accuracy. This machine has no full Xcode installation.

## TestFlight release build — September 13, 2026

Full Xcode 27 was located at `/Users/johnluke/Downloads/Xcode-beta.app`. The complete signed iOS release archive (including the custom camera, StoreKit and widget targets) succeeded, and the full Swift check suite passed under this toolchain. This supersedes earlier notes saying only syntax validation was available. Real iPhone camera and purchase behavior still require testing.

## Scanner flow correction — September 13

The scanner is now the initial full-screen view; no intermediate Pro/intro sheet. A captured still starts the estimate request directly, removing the dismissal-callback dependency. Review shows Submit and Retake on one row. Requested instructional/provider copy was removed. Backend auth and Pro checks remain enforced.

A live product-image test with the real Pro account returned HTTP 200 and a medium-confidence water estimate. A non-water/ambiguous product image returned 422; neither test returned an insufficient-quota error. This establishes working inference at test time, not measured-volume accuracy or the cause of every previous scan failure. Safe provider error categories now distinguish quota/auth/rate-limit failures without exposing provider error bodies. Full iOS Debug build and nine backend tests passed. Updated iOS flow requires a new device/TestFlight build.
