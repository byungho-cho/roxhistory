# Play UI assets

- `hero_portrait.png`: rendered from the same original procedural 3D hero used in play. Editable geometry/materials/rig: `../../scripts/hybrid_character.gd` and `character_geometry.gd`. Regenerate with Godot 4.5.1 `--script res://tests/play_capture.gd -- --test-ui --portrait`, then import and update `../manifest.json`.
- `seed.svg`: original editable vector illustration authored for RoxHistory in this change. Represents the already implemented quest reward; no new currency or system.
- No external model, stock portrait, sampled audio or downloaded icon was added. Existing Figma reference and atlas usage retain the project's existing provenance and terms.
