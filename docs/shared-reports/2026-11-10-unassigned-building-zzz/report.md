# Unassigned building Zzz indicators

Date: 2026-11-10 KST. Base: `ba090c2194e3a4c7c61e647e088b420d89ad2438`.
Branch: `codex/unassigned-building-zzz`.

## Behavior

- Completed farms, sawmills, quarries and watchtowers show three gently rising, fading `z` letters while their assigned-resident list is empty.
- The existing assignment UI and indicator share `ResidentJobs.BUILDING_JOBS`; occupancy is read through `ResidentJobs.assigned_ids`. Existing shared wood/stone roles count, including a role assigned without an explicit storage-building key.
- Assignment hides the marker immediately. Reassignment updates both farms, and a multi-worker building remains awake until its final worker is unassigned. Workers travelling, carrying cargo or waiting for food/storage still count as assigned.
- The indicator is a presentation-only child of the building, anchored to the visible artwork's upper-right edge. It follows upgrades, relocation, zoom and pan, stays away from the centered assignment bubble, and cannot intercept input.
- Construction/upgrade visuals take priority. Hidden worlds and application pauses stop its animation. Demolition removes it, and loading a save reconstructs the correct state without changing the save format.
- No economy, production clock, assets, release version, main branch or distribution files were changed.

## Verification

Godot 4.5.1 on Windows, using isolated test saves and muted test audio:

- Final editor import: passed, no script/engine errors.
- `unassigned_building_indicator_tests.gd`: 50 checks passed headless and 50 passed with Windows OpenGL rendering, after the final readability adjustment.
- Coverage: initial empty buildings, all four workplace types, assignment/removal/reassignment, multiple workers, implicit storage assignments, food shortage, upgrades/cancel/completion, zoom/pan, bubble touch, building menu, pause/resume, hiding, relocation, repeated refresh, reload and demolition.
- `storage_v0165_tests.gd`: 44 checks passed.
- `first_quests_tests.gd`: 77 checks passed.
- Asset verifier: 163 bundled size/SHA-256 checks passed.
- Audio verifier: 16 assets passed.
- Static code review found no actionable issue; `git diff --check` passed.

The broader legacy regression set is **not green**. `resident_farm_v0161_tests` reports five notification assertions. `resident_bubble_alpha_tests` and `menu_transition_tests` report one assertion each. `readability_v0167_tests`, `owned_upgrade_tests`, `building_model_v0151_tests` and `ui_camera_v0160_tests` encounter outdated fixture/UI assumptions and then script errors. These tests were not changed to hide failures. All seven suites reproduce the same failures on a separate copy of base commit `ba090c2`. The three replaced baseline source files were verified byte-for-byte against their Git objects; the six rendered comparisons have identical normalized error lists. Detailed comparisons are recorded in the local logs.

The first empty-cache font import exited with a native Godot error; copying only the existing generated asset cache into this isolated worktree allowed a clean import. The headless feature test also reports Godot's non-fatal ObjectDB exit-leak warning; the rendered test exits cleanly.

Android hardware, APK/EXE export, the complete `check-village.sh` suite and deployment were not performed. Passing focused tests does not imply those stages passed.

## Local artifacts and reproduction

Workspace: `D:\workspace\roxhistory-zzz`.

- Logs and comparison summaries: `.work/zzz/`.
- Rendered screenshots: `game/reports/unassigned-empty-workplaces.png`, `unassigned-farm-menu.png`, `unassigned-farm-zzz-a.png` and `unassigned-farm-zzz-b.png`.
- Run the new suite with `godot --headless --fixed-fps 60 --audio-driver Dummy --path game --resolution 1280x720 --script res://tests/unassigned_building_indicator_tests.gd -- --test-ui`.
- Omit `--headless` to run rendered coverage and regenerate screenshots. Create `game/reports/` first in a fresh checkout.

The original `D:\workspace\roxhistory` checkout remains on `codex/journal-reward-baseline`; its pre-existing untracked `video/` directory was preserved. No push, main merge or release was performed.
