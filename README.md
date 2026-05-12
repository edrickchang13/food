# Bulk AI

Dynamic, adherence-neutral nutrition tracker for iOS. Forked from [Fud AI](https://github.com/apoorvdarshan/fud-ai) (MIT) — keeps the food logging + HealthKit shell, replaces the coaching engine.

The difference is the engine: Bulk AI computes your TDEE from the energy-balance equation (`expenditure = avg intake - (trend weight change × 7700 kcal/kg) / days`) instead of `BMR × activity multiplier`. After two weeks of logs the dynamic estimate replaces the onboarding seed, and a weekly check-in proposes new targets you can accept, adjust, or skip.

## What's in the box

- **Dynamic TDEE engine.** EWMA-smoothed trend weight with linear-interpolation gap fill; deterministic expenditure formula with ±15% per-update clamp and 1.1×BMR / 2.5×BMR safety bounds; 48 unit tests behind a pure-Swift package at [ios/Packages/BulkAIEngine/](ios/Packages/BulkAIEngine/).
- **Weekly check-in.** Auto-presents when due, surfaces last 7 days of intake + trend delta + proposed plan, three exits (Accept / Adjust / Skip), adherence-neutral wording throughout.
- **Three program modes.** Coached (engine sets everything), Collaborative (engine sets weekly budget, user redistributes), Manual (engine tracks silently, user sets all targets). Picker in Settings.
- **Body measurements** for 15 anatomical sites with per-site history.
- **Period tracking** with rolling-average cycle length stats.
- **Progress photos** stored encrypted-at-rest in the app's Documents directory, filterable by front / back / sides.
- **Recipes** with manual ingredient entry plus a schema.org JSON-LD importer for sites like NYT Cooking, AllRecipes, Serious Eats.
- **Local-first.** No accounts, no cloud sync beyond CloudKit private DB. Photos, weight, period, measurements all stay on-device.

Inherited from Fud AI: SwiftUI shell, food logging via snap / voice / text using Gemini, HealthKit bidirectional sync, 13 nutrient tracking, widgets, 15 languages, theme colors.

## Building

```sh
open ios/calorietracker.xcodeproj
# Pick the "calorietracker" scheme, any iOS Simulator destination, Cmd+R.
```

The engine package is local; it resolves automatically on first build. To run engine tests headlessly:

```sh
cd ios/Packages/BulkAIEngine && swift test
```

## Plan & architecture

See [PLAN.md](PLAN.md) for the phased build plan (P0 engine → P4 polish) and the algorithm spec for trend weight, dynamic TDEE, target macros, and the weekly check-in cadence.

## License

MIT, original copyright by Apoorv Darshan. See [LICENSE](LICENSE). Modifications by edrickchang13.
