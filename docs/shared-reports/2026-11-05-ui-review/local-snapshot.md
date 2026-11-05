# Iterative PC review snapshot

This working-branch snapshot preserves the user's iterative PC review changes. It is not a final art approval or a main-branch release.

Included: HUD alignment, construction artwork at 90%, submenu four pixels lower and half-height label overlap; Figma 861:50 menu assets and animation; natural-only GPS and red position triangle; temporary gathering bars; animated resource counts; settings-menu access; revised building image placement and village zoom. Original 3D residents are restored. New resident source PNGs remain inactive references for later retouch.

## Asset cleanup

Already-retired tracked files are committed together with their replacement references:

- `refactor-v035/mountain-map.png` and import metadata: byte-identical retained source `figma-latest/94b86.png` (SHA-256 `64170ffb72632d32dc93d6a560dae0432dfd4e4699a6d8ea7afe09a1be87a033`).
- `refactor-v036/menu-collapse.png`, `ui/s40000/{menu-button-v001.png,expand-button-v001.png,collapse.svg}` and import metadata: replaced by the Figma 861:50 source sheets, catalog entries and menu rendering code in this snapshot.
- `ui/review-v037/home-toggle.png` and import metadata: retired composed image; current split frame and village overlay implementation is preserved. Its final approved icon replacement remains pending.

That is 12 tracked files (six resources plus six import files). Six additional retired local-only files were never in Git: duplicate home-border/home-icon source PNGs and their import metadata, plus the intermediate menu-toggle shader and UID. All 18 were preserved in a verified local recovery ZIP before their earlier removal. No additional deletion is performed by this snapshot. Original design files and future-use assets are retained.

Local backup archives contain working changes and preview save profiles; they are intentionally not uploaded to Git. Generated logs, APKs and player data are not part of this source commit.

## Incomplete features / assets

- Outpost and chief-upgrade data transactions are prepared and tested, but gameplay activation, final visuals and upgrade animation integration are incomplete. The outpost menu remains disabled pending its approved level-one asset. The existing Figma 886:36 icon is explicitly marked unverified.
- Outpost rule: chief hut plus three completed resident huts; wood 15 / stone 10. Demolition below the threshold relocks new construction while preserving existing outposts.
- Chief upgrade rule: completed outpost required; each step uses the current hut cost (wood 20 / stone 20); base construction time 2 seconds gives 4 / 8 / 16 seconds for levels 2 / 3 / 4. Persisted start/end timestamps prevent repeated payment and completion. Device-clock changes can accelerate or delay offline completion; there is no server time authority.
- Terrain/fog subsequently arrived through the approved Git asset branch and are integrated as candidates; see `terrain-candidate-review.md`. The approved black submenu brush and radial menu also arrived through Git and are applied; see `building-menu-review.md`. Village-return icon and bubbles remain unavailable through the Windows Library transfer path. Brown replacement brush was not applied.
- Building radial menu is connected to existing selection and demolition confirmation. Relocation remains explicitly disabled; chief upgrades remain gated by completed outpost and approved building-stage assets. No invented replacement artwork is included.
- Village outer terrain and world-map texture remain provisional. Maximum village zoom matching the supplied reference remains unresolved.

## Verification and distribution

State regression: 343 checks passed. Outpost/upgrade transactions: 66 checks passed. Construction icon size/center and unchanged touch bounds checked. Desktop render captured after submenu adjustment. Dedicated source-snapshot smoke test covers village startup, replacement assets, build menu, both map scenes and save.

APK 0.1.38 (version code 39) was built locally with the same certificate as 0.1.37. Physical Android installation was not verified. External APK publication remains blocked pending explicit approval; this source snapshot does not publish an APK or merge main.

## Subsequent workflow wiring (not in the existing 0.1.38 APK)

`BuildingWorkflow.request_upgrade()` is the entry point connected to the approved radial menu. It uses the existing confirmation modal, invalidates canceled callbacks, rechecks resources/current level/assets before payment, and processes durable completion independently of ordinary work and map switching. The existing construction scaffold is reused at the chief hut and excluded from GPS. Final construction effects remain pending.

Building textures require explicit `approved: true` catalog records under `BLD-CHIEF-L2/L3/L4` and `BLD-OUTPOST-L1`; absent, invalid or unapproved resources never become catalog fallback artwork. These records are deliberately not added without the approved source files. Outpost menu conditions are centralized, but outpost placement/rendering is still pending. No new feature is exposed as playable, and no new APK is built or published by this follow-up.
