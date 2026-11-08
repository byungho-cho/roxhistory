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
