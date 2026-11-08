# Construction submenu polish (source only)

Base: development commit `fb67044`. No release/export or remote push performed.

- Maximum six horizontal slots; narrower viewports show fewer complete slots rather than shrinking the touch targets.
- Starts at the rightmost hut when opened. Existing building order and unlock rules are unchanged.
- Artwork uses 60% of a 72×80 touch slot (base two-thirds, then the requested extra 10% reduction). Main action size stays unchanged.
- Horizontal mouse/touch drag, mouse wheel and directional page arrows navigate overflow. Arrows disappear at their boundary.
- Menu owns its press through release, including releases outside. A scroll cannot place a building or pan the camera. Hiding or focus-loss cleanup resets pressed visuals.
- Subtle dark translucent background and a slightly larger farm progress/time brush improve map contrast without changing farm timing, yields or save data.

Validation: Godot 4.6.3 headless, isolated XDG data/config/cache under `/tmp`.

- `tests/build_side_scroll_tests.gd`: 23 checks passed (synthetic mouse/touch, layout, locked selection, drag cancellation, press feedback, overflow and narrow layout).
- `tests/world_polish_pending_farm_tests.gd`: 54 checks passed.
- `tests/resident_farm_v0161_tests.gd`: 131 checks passed.
- `git diff --check`: passed.

These are headless regression checks, not Android/Windows hardware gameplay or a visual screenshot review. Initial import/test attempt could not write the default user-data directory; subsequent runs used isolated writable XDG directories and passed. No APK/EXE was built.
