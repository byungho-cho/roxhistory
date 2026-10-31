# C001 v0.3 — v0.1.9 game model and editable study

This editable Godot procedural 3D project supplies the model used by the v0.1.9 review build. Visual fidelity to the reference is still under review; this is not a claim of final art approval.

- Reference: Figma `196:11`, image node `198:868`; see the [report](../../../docs/shared-reports/2026-10-31-c001-character-ui/report.md).
- Source: `source/hybrid_character.gd`, `character_geometry.gd`, `hero_motion.gd`.
- Preview: run Godot 4.5.1 with `--path source --script res://preview.gd`.
- Textures: `--path source --script res://paint_textures.gd` generates the UV material textures in `source/textures`. These are authored noise/brush-stroke material textures, not hand-painted character atlases.
- Export: `--path source --script res://export.gd` creates `c001-rigged.glb`; the old `c001-study.glb` remains historical.
- Validate: `--headless --path source --script res://validate_export.gd` reimports the GLB and plays/seeks idle, walk, gather and build. Confirmed one skeleton with15 bones and four weighted limb meshes.
- The GLB contains baked skeletal/tool clips. Runtime eye blinking and the distance-driven gait/action state machine remain in `hybrid_character.gd` and `hero_motion.gd`; this is the animation authoring source. No Blender source or secondary hair/cloth simulation is claimed.
- Game counterparts: `game/scripts/hybrid_character.gd`, `character_geometry.gd`, `hero_motion.gd`, and `game/assets/characters/c001-textures`. The model source differs only in texture resource paths.
- Four-way comparison: `compare_reference.gd`; model turntable views: `preview.gd`. Preview images are genuine engine renders of this geometry.
- Geometry uses existing RoxHistory source and newly authored modifications. Reference supplied by the project owner; no independent public redistribution license is asserted.

Quality gaps: proportions remain younger/shorter than the reference, with simplified fur/hide layering, knots, hands and shoes. Hair silhouette and painterly detail still differ. Android emulator gameplay is validated separately in the report; physical-device performance, direct listening and user art approval remain unverified.
