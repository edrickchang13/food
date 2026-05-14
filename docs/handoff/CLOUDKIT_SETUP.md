# CloudKit Setup

P20 wired SwiftData with `cloudKitDatabase: .automatic`, which enables
cross-device sync of `BulkAISchemaV1` models the moment iCloud is signed
in and the container is provisioned. The container ID currently expected
by the app is:

```
iCloud.com.edrickchang.bulkai
```

The fallback container ID for the debug build is:

```
iCloud.com.edrickchang.bulkai.debug
```

Until you provision these containers in the Apple Developer console, the
app falls back to a local-only SwiftData store. Everything still works.
What you DON'T get without provisioning: cross-device sync to iPad / Mac,
iCloud backup of user data, the "sign into your other device and your
data appears" pitch.

This doc walks you through the one-time setup. ~10 minutes if your Apple
Developer account is already set up.

---

## Prerequisites

- Apple Developer account in good standing
- The two app IDs already registered: `com.edrickchang.bulkai` (release)
  and `com.edrickchang.bulkai.debug` (development). If they aren't, do
  that first under Certificates, Identifiers & Profiles → Identifiers
  → App IDs.

## Step 1 — Enable iCloud on each App ID

For each of the two app IDs:

1. Open [developer.apple.com](https://developer.apple.com) → Certificates,
   Identifiers & Profiles → Identifiers
2. Click your App ID (e.g. `com.edrickchang.bulkai`)
3. Scroll to Capabilities, check **iCloud**, click "Configure"
4. Choose "Include CloudKit support"
5. Save

If iCloud was already enabled, skip to Step 2.

## Step 2 — Create the CloudKit containers

Still under Identifiers, switch the dropdown at the top of the left
sidebar from "App IDs" to **iCloud Containers**, then click the "+" to
register two containers:

1. **Description:** Bulk AI Production
   **Identifier:** `iCloud.com.edrickchang.bulkai`

2. **Description:** Bulk AI Debug
   **Identifier:** `iCloud.com.edrickchang.bulkai.debug`

The `iCloud.` prefix is required — Apple's container-naming convention.

## Step 3 — Associate each container with its App ID

Go back to App IDs → click `com.edrickchang.bulkai` → iCloud Configure →
in the "iCloud Containers" list, check `iCloud.com.edrickchang.bulkai`
and save.

Repeat for the debug App ID, attaching `iCloud.com.edrickchang.bulkai.debug`.

## Step 4 — Regenerate provisioning profiles

In Xcode → Signing & Capabilities → click "Try Again" or toggle "Automatically
manage signing" off and back on. Xcode pulls the updated entitlements that
now include the CloudKit container. If you're using manual provisioning,
re-download the profiles from the developer portal.

## Step 5 — Verify the entitlement in Xcode

Open `ios/calorietracker.xcodeproj`. Select the calorietracker target →
Signing & Capabilities → confirm:

- iCloud capability is present
- Services: **CloudKit** is checked
- Containers: `iCloud.com.edrickchang.bulkai` appears in the list

Repeat for the debug scheme if you use a separate target. (The current
project uses one target with a debug-bundle-ID flavor; capabilities apply
across both flavors.)

## Step 6 — Deploy the schema

The first time a user with iCloud signed in launches the app, SwiftData
writes its v1 schema (`BulkAISchemaV1`) to the user's private CloudKit
database. CloudKit treats the first push as the **development** schema.

Before shipping to TestFlight or the App Store, you need to promote the
development schema to **production**:

1. Open [icloud.developer.apple.com](https://icloud.developer.apple.com)
2. Select your container (`iCloud.com.edrickchang.bulkai`)
3. Click **Schema** → **Development**
4. Verify the 5 record types (`FoodEntryModel`, `UserProfileModel`,
   `WeightEntryModel`, `BodyFatEntryModel`, `FavoriteModel`) appear with
   their fields
5. Click **Deploy Schema Changes...** → **Deploy** when prompted

Until you deploy, only your own development device sees the records.
TestFlight + App Store builds use the production schema, which must be
deployed at least once.

## Step 7 — Verify on a real device

1. Run the app on a real iPhone signed into iCloud
2. Log a food entry
3. Open `icloud.developer.apple.com` → Data → Records → query
   `FoodEntryModel` — the row should appear within a minute
4. Install the app on a second device signed into the same iCloud
   account — within a minute, the food entry should appear there too

If the row doesn't appear on iCloud's Data tab, check:

- The device is signed into iCloud (Settings → top of Settings list)
- iCloud Drive is enabled
- The app's iCloud capability is on (Settings → Apple ID → iCloud →
  Apps Using iCloud → Bulk AI)

## What happens if you don't do this

Nothing breaks — the app continues working with local-only SwiftData
storage. `SwiftDataContainer.makeContainer()` catches the
"container not provisioned" error and falls back to a local config:

```swift
ModelConfiguration(schema: schema, cloudKitDatabase: .none)
```

The user just doesn't get sync. P22's view cutover from UserDefaults
to `@Query` works either way.

## Future considerations

When you add a v2 schema (P22 or later), you need to repeat **Step 6**
on the new record types. CloudKit production schema is append-only;
you can't remove fields once deployed. Plan v1 fields carefully.
