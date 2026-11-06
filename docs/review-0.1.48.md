# 0.1.48 expanded village review

## Changes
- Fixed world rectangle: (-728,-410) to (3128,1760), size 3856x2170. This is approximately 90% of each axis of the frozen 16:9 minimum-zoom overview centered at (1200,675). At 1280x720 overview, margins are about 64px horizontal and 36px vertical, rather than a device-dependent 50px boundary. Other aspects pan over the same world boundary. Player center has a 24-world-unit safety inset.
- Navigation grid origin, camera bounds, negative-coordinate save validation, regrowth placement and GPS projection now share the new world rectangle. Existing object/save coordinates and six site indices are unchanged. Existing obstacle collisions, including the reserved old shoreline, remain; no new creek art.
- Added 12 stable catalog resource IDs (six wood, six stone), each three charges, using existing art. Old depletion/relocation stays intact, new IDs appear on old saves without duplicate appends or resetting resources. Added four existing-species animals (one deer, two rabbits, one bear), instantiated once per world. Existing animals retained. All actors remain excluded from GPS.
- Building action menu and close X moved 50 logical UI pixels upward relative to the selected sprite bottom, preserving touch sizes. X sits above action touch areas to prevent overlap. Move stays hidden/disabled: supplied hold artwork has unresolved wording and no implemented relocation flow. Showing an approved disabled move image is a small UI task; enabling relocation requires site/road/collision/save/upgrade-job decisions and is not implemented.

## Validation
- 1092 state/save checks, 74 expanded-world checks, 61 menu checks passed, plus fixed-boundary assertions.
- Actual physics travel reached an outer negative-coordinate destination and persisted across save/reload. All 12 new contact positions routed successfully; original home, resource depletion and relocated node preserved. New resource gather/depletion/respawn persisted without duplicates. Physical outer boundary blocked escape. Landscape/portrait min/max camera pans stayed inside existing single-image coverage.
- Desktop route planning maximum measured 11.95 ms in this test, not an Android benchmark. Grid is 161x91 cells versus previous 100x56; mobile latency remains unmeasured.
- Actual desktop min/max zoom/aspect captures reviewed. Menu touch close and non-overlap checked. Android physical device testing not performed.
- Geometric packing probe with current resources and 340-wide footprints found 52 additional candidates (24 needed for 30 shared slots). This is capacity evidence only: no new build sites installed, resident limit remains five; full routes/all occupied houses/saved relocated resource conflicts need separate validation.

## Remaining limitations
Background is the same 1672x941 trial; maximum-zoom softness unchanged. Mountain and new diagonal corner-cloud assets are awaiting delivery and not included. Existing clouds retained. No new animal species, creek, building relocation, or background retouch. Expanded saves may be incompatible with older APK validation; keep updating forward rather than downgrading.

Package com.roxhistory.demo, versionName 0.1.48, versionCode 49, existing signing certificate retained. Public APK verification recorded in delivery response.
