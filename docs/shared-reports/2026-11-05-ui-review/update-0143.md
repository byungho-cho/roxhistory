# 0.1.43 review build

Includes queued-action lifecycle changes described in queued-action-lifecycle.md: three flashes, persistence through reserved travel, one second after actual gathering/construction start, immediate newest-reservation replacement, cancellation/invalidation and stale-hide protection. Movement clears on arrival. Family invitation still lacks a dedicated icon. Position was not changed because the attached screenshot could not be materialized by the official Windows Library helper (os.setxattr failure); the affected icon remains unidentified.

Chief upgrade presentation now uses the same ConstructionProgress control, countdown and animated hammer as ordinary construction. It reads durable upgrade timestamps independently of the hero's simultaneous task. Existing scaffold, dust/light/spark drawing and completion burst are reused; ordinary and upgrade construction call the same draw_build_activity helper. Completion crossfades the old/new building over 0.35 seconds while the scaffold fades away. No new decorative assets were added. Work effects are excluded from GPS. Costs, 4/8/16-second timings, offline completion and single-charge rules are unchanged. Pending/completed reloads remain valid; local device-clock changes remain a limitation.

Main-menu toggle closes the construction side menu, ignores repeated toggle input during the 0.22-second animation, and blocks row input from falling through to the world. Normal menu functionality resumes after the tween.

New testing games start with 500 wood and 500 stone. Only DemoConfig.fresh changes; existing saves, including zero-resource saves, are not topped up or reset. Continuing an existing game will not show the new starting grant.

Validation: 26 queued lifecycle + 15 existing queue tests, 33 upgrade presentation tests and 20 controller regression checks, 15 menu transition/input checks, 7 new-game/load checks and 344 core state checks passed. Desktop rendering captured working upgrade stages 2/3/4 with timer/hammer/scaffold and shared effects. Android physical-device verification remains pending.

Investigation only: resident huts can reuse existing staged hut atlas, but need per-UID levels/jobs, strict save validation, radial-menu routing, cost accounting and demolition-job handling. Outpost storage currently explicitly validates only level 1, and only L1 approved separated art exists. Outpost L2-L4 art is required. Costs/max-level expansion await confirmation; no resident/outpost upgrades or guessed prices were added. Existing chief rules remain unchanged. Unspecified entrance-animation target also remains unresolved.

APK 0.1.43 / code44 is eligible for public prerelease under the user's standing publication authorization. Do not merge main. User saves and source changes are backed up; tests use isolated APPDATA profiles.
