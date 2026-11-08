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


### Unlocked desktop follow-up — direct play completed

The user unlocked Windows and resolved StarDesk mouse capture. The earlier direct-interaction blocker is resolved. A fresh source review game was selected by its returned window and brought to the foreground through Computer Use. All interaction below used actual Windows mouse input, not root.push_input:

- Opened construction submenu: six slots visible. Dragged horizontally from the rightmost group to the leftmost; observed all eight entries in the requested order. Clicked paging arrow. Menu-only drag retained camera(1250,916.25) and hero(1150,920) positions. A built sawmill entry showed the one-building restriction toast and did not place anything. Selecting the available farm entered site selection; its cancel button canceled without starting construction.
- Assigned resident3 to farm via its building bubble, resident1 to sawmill via its bubble, then used chief management to verify the shared jobs and assign resident2 to stone gathering. Chief summary showed the wood worker actually gathering. Saw wood/stone work movement and carried stone while returning.
- Existing farm was at mature/ready state. Four harvest/delivery passes increased grain20→60, then crops cleared for preparation and the farm entered growth again. Growth/worker activity continued while assignment/settings popups were open.
- Sawmill capacity300: wood297→300 after a ten-unit load arrived, with no inventory increase past300; wood gathering then waited. Stone increased90→100→110→120 and later150 through delivered ten-unit loads. Over-cap historical inventory preservation is covered by storage_v0165_tests; this direct session started below cap, so it is not described as a manual over-cap migration test.
- Returned to title via Settings→Start screen, clicked the title prompt to continue, and retained wood300, stone110, grain60 and jobs. Closed the game window, restarted the review harness in a separate process using the same isolated save and --legacy-roads. It loaded wood300, stone120, grain60, all three jobs, growing farm state and a carried stone10 load. Subsequent deposits/growth continued. Snapshot: shared-reports/2026-11-09-integration-check/evidence/integration-after-reload.json.
- Compared brush/default roads and legacy roads directly in the running game, including closer wheel zoom. Observed straight runs, bends, branch joins and building connections showed no visible gap in this fixture. Four-way/all-mask connectivity is covered by the305-check model suite, not a claim that every possible map configuration was manually inspected.

Remaining limits: no Android physical touch/hardware play; synthetic23-check menu tests cover touch ownership, release-outside and drag cancellation, while direct desktop review used mouse. Full long-duration farm10-minute growth was not waited out in direct play; growth→ready and phase transitions are automated, and direct play covered mature→harvest/delivery→preparation→new growth. No newly confirmed gameplay defect remained in the inspected flows. No resource-cap progress bar was added. StarDesk settings were not changed by the agent.

Final local build uses the report-update source commit on codex/integration-final-20261109, version0.1.66. scripts/build-release.ps1 builds both platforms under repository rules, with only the requested Windows path highlighted in the result. No release publication or older remote asset deletion was performed.


## 0.1.67 · screenshot readability and explicit development refill

User scope: improve construction menu size/contrast, roads, duplicate building ground and floating assignment badges. Quest text and storage-full gathering policy are explicitly excluded. Additional instruction replaces automatic99,999 starting stock with a development refill action.

- Fresh/new/reset state now starts with wood0/stone0/grain0 (legacy token0). Existing saves are not migrated or clamped. Development settings offers 자원 채우기: wood/stone/grain are topped up to9,999; higher existing balances are preserved. Copper, residents, legacy token balance and saved work are unchanged. Failed saves roll back normally. Tested fresh0 can gather20wood/20stone and start chief construction.
- Menu hit slots80x92, artwork90% instead of60%, max6 visible and horizontal scrolling retained. Warm translucent backing replaces the heavy black panel; locked images use60% opacity while labels stay full contrast and lock icons remain readable. Integrated art opts out of extra disabled dimming. No changes to building order/availability.
- Default road presentation is OrganicRoadNetwork: a connected tree branches from existing street samples to nearby building anchors, avoiding perimeter-like L detours. NaturalRoad width1.16/minimum1grid cell, smaller soft banks, gentle curves. Default paint reuses v002 road-15 source soil pixels; no new road bitmap or saved-data changes. --grid-roads retains the previous tile-graph review path; --legacy-roads/brush_roads=false retains the old-paint fallback, now using the same narrower visual width/organic links. No road collision or navigation rules changed.
- Shared square foundation is omitted for farm, stone_store, wood_store, hearth and shrine because those originals already contain ground. Chief/hut/outpost/training pads remain. Building positions, occupancy and levels are unchanged.
- Assignment badge anchor uses alpha-visible sprite bounds (cached12% alpha sample), not PNG canvas edges. Normal50%/selected100% visual sizes and full46x44 touch area remain; the badge overlaps the visible roof by8logical px.

Checks: readability_v0167_tests19/19, foundation_tests146/146, storage_v0165_tests44/44, resident_farm_v0161_tests131/131, build_side_scroll_tests23/23, brush_road_network_tests305/305, world_polish_pending_farm_tests54/54 —722 targeted checks. Historical full legacy suite is not claimed green. Dense15-resident renderer capture: game/reports/readability-dense.png. Direct Windows mouse verification used user://tests/integration-20261109: developer refill changed300/170/60 to9,999/9,999/9,999 while residents stayed3; ordinary player save was not used or reset. Android physical-device visual/touch acceptance remains unverified.
