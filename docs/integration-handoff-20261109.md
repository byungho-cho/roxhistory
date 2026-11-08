# Rebuilt source integration handoff

Source integration only. No APK/EXE export, release or local-device gameplay was performed.

This is a new reconstruction of the lost cloud-only menu/road changes, not recovery of the original unpushed commit. Existing development history through `fb67044` is preserved. Original task commits: menu `dabfc51`, roads `3021911`; integrated as `a104893`, `b310a99`.

## Included
- Existing 0.1.65 development changes, including resident/farm, storage and separated farm assets.
- Compact six-slot scrolling construction submenu, retained touch targets, drag/wheel/arrows and press feedback.
- Farm progress/time readability polish.
- Brush road v002 16-tile connected graph with safe routing and full legacy fallback. Disable with `-- --legacy-roads`.

## Combined verification
Godot 4.6.3 headless with isolated `/tmp` XDG user directories; fresh editor import succeeded.
- build_side_scroll_tests: 23/23
- brush_road_network_tests: 305/305
- world_polish_pending_farm_tests: 54/54
- resident_farm_v0161_tests: 131/131
- storage_v0165_tests: 44/44
- foundation_tests: 24/29; five existing failures remain: four foundation-count assertions and restored save level mapping. Not claimed green.
- diff whitespace check passed.

## Next developer
Pull latest main without discarding existing local work. Verify road seams/zoom, saved building entrances, submenu touch/drag on real hardware and farm timer contrast. Headless checks do not establish visual acceptance. Resolve the known legacy foundation tests separately. Build only when requested, following AGENTS.md: Android and Windows together from one commit/version, existing signing material, repository build/ output.


## MY-NUROX local follow-up · 2026-11-09

Latest main feecb691 was a fast-forward descendant of the previous local development head fb67044. The worktree was clean. Existing source history and saves were retained; follow-up work is on codex/integration-final-20261109.

### Fixed foundation fixture

Reproduced the original five failures: four missing five-foundation counts and restored building mapping. The fixture now actually builds/completes the chief, upgrades through HQ4, then builds/completes three huts and one unlocked outpost, checking every call. Completion uses the current rule-derived duration. Each foundation must belong to an intended completed building; exact approved textures, anchors, scale, non-mutation and restored state checks remain. No game building rule was relaxed.

Local Godot4.5.1 checks:
- foundation_tests: 146/146, including all original five failing assertions now passing.
- brush_road_network_tests: 305/305.
- storage_v0165_tests: 44/44.
- resident_farm_v0161_tests: 131/131.
- build_side_scroll_tests: 23/23 (synthetic mouse/touch; not Windows hardware input).
- resident_bubble_alpha_tests: 5/5.

### UI comparison

Read-only Figma comparison: S40100 1474:6951, detailed frame1474:6954. The current PNG has substantial transparent margins; visible alpha>=10% is region(50,14,136,193) within236x216. FamilyArrival now uses an AtlasTexture of that region and places the visible portrait over the actual cream bubble front. Existing one-line invitation and immediate acceptance logic are preserved. The resource storage progress-bar proposal was not implemented.

Rendered source captures: game/reports/integration-resident-bubble.png, integration-brush-roads.png, integration-legacy-roads.png (ignored local outputs). Road captures use identical isolated fixture/camera, with the legacy capture selected by in-memory roxhistory/visuals/brush_roads=false. Existing CLI --legacy-roads remains supported. The brush network/legacy visual comparison is a renderer review, not direct gameplay or a physical-device acceptance result.

### Direct interaction blocker and isolated continuation

An interactive review scene was launched with --test-ui and SaveStore user://tests/integration-20261109. Computer Use found RoxHistory (DEBUG) but activation failed; fresh capture showed the Windows lock screen. App input was stopped immediately and the user was asked to unlock. No authentication action was attempted. Consequently direct Windows clicking/dragging, real-world movement, and interactive save/continue are still unverified; automated tests must not be presented as that missing work.

Reusable harness: game/tests/integration_manual_review.gd, requiring --test-ui. It seeds only the isolated review save if missing and reuses it afterward; --capture-review uses its own user://tests/integration-capture-20261109 path. Normal save and preferences are not reset. The review fixture includes completed storage/farm/huts, a growing crop, visitors, and capacity-room cases. On unlock, reopen the harness and verify menu paging, valid/locked presses, no world input leakage, worker assignment/gather/hauling/full capacity, crop phases, then quit/reopen and continue the isolated save. Compare road junctions and zoom manually in both modes.

### Local build

Version0.1.66 is reserved for this local follow-up. Use scripts/build-release.ps1 and repository build/ with existing signing material, producing the paired APK/EXE from one source commit under AGENTS.md. The requested Windows artifact is build/Roxhistory_0.1.66.exe. No GitHub release/upload was requested in this follow-up; previous remote releases remain untouched. Build/smoke result is separate from the locked-desktop gameplay blocker above.
