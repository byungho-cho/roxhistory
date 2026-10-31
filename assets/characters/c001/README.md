# C001 v0.3 — unfinished model study

This is an editable Godot procedural 3D modeling project, not the final game model. It has not replaced the production character.

- Reference: Figma `196:11`, image node `198:868`; see the [report](../../../docs/shared-reports/2026-10-31-c001-character-ui/report.md).
- Source: `source/hybrid_character.gd`, `character_geometry.gd`, `hero_motion.gd`.
- Preview: run Godot 4.5.1 with `--path source --script res://preview.gd`.
- Export: `--path source --script res://export.gd` creates `c001-study.glb`.
- Materials are flat procedural materials; painted textures are not delivered yet.
- Skeleton/weighted limbs exist; final exported animation clips and export/import parity remain unverified. This is not a validated game-ready GLB.
- Geometry uses existing RoxHistory source and newly authored modifications. Reference supplied by the project owner; no independent public redistribution license is asserted.

Quality gaps: hair remains too regular, body and joints too primitive, fur layering and costume details do not sufficiently reproduce the approved illustration. No user approval, Android validation, merge or APK release for this study.
