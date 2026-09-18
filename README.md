# Hydrate

Native SwiftUI iOS app for simple, satisfying hydration tracking, by Human Goods.

## Backend foundation

The repository includes a Supabase migration for profiles, bottles, and hydration entries with row-level security. Link the local project to your Supabase project before applying it:

```sh
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Use only the Supabase publishable key in the iOS app. Never ship a service-role key.

Email authentication is available from the onboarding screen through Supabase Auth. New accounts may need to confirm their email before signing in, depending on the Email provider settings in the Supabase dashboard.

## Open the project

The project is generated with XcodeGen:

```sh
xcodegen generate
open HumanHydration.xcodeproj
```

After changing `project.yml`, run `xcodegen generate` again so Xcode picks up package or target changes.

The project includes the main iOS app and a Home Screen widget extension. HealthKit and local notification service foundations are included; enable the corresponding usage descriptions in Xcode before shipping.
