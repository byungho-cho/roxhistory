# Terrain candidate integration

Source: `share/reference-assets`, commit `7b3b2a29e6bb5188fc0a380fb16527a4b2d8b7dc`. All four PNGs are copied byte-for-byte into `game/assets/terrain-review-v001/`; their source paths and hashes are retained in `provenance.json` and registered in the game manifest. Existing terrain and shaders are preserved for comparison/rollback.

- Village: native 1672×941 image, mapped to a 3000×1688 decorative rectangle at (-300,-169), with a narrow alpha feather over mirrored ground A. Additional surrounding ground fills maximum zoom-out. Playable polygon, 2400×1350 world size, collision bodies, saved positions and zoom limits are unchanged.
- The new village art paints its own distant river. The former water overlay is hidden to avoid sampling the new background at the old river coordinates. Old shoreline physics remains unchanged outside the village's playable boundary; water animation/shoreside presentation needs art review before a final terrain release.
- World: 1254×1254 A is mirrored continuously, B is blended through a continuous organic mask. No random per-cell rotations or hard A/B tile switches. Both inputs contain ground only, so the existing separate mountain, river, lake and village are retained once.
- Outer fog uses the supplied RGBA cloud separately. Its static coverage mask and texture coordinates are anchored in map coordinates and shared camera transforms; no exploration/reveal gameplay or save fields were added. Cloud borders are feathered. Fog draws above terrain but below HUD and is omitted from the natural-only GPS.

## Observed results / limits

Godot 4.5.1 Windows/OpenGL render: village min .56 and max 1.6, world min 1 and max 2.4, distant pan and return all passed. The test checks unchanged save state, unchanged playable extent, source dimensions and world-coordinate reconstruction across camera movement. No script/shader errors were logged. HUD remains above fog.

At 960×540 logical resolution, actual Camera2D zoom is .224 at minimum and .64 at maximum. The village native pixel is therefore scaled .402× / 1.148× logically, or approximately .536× / 1.531× in the captured 1280×720 output. This differs from the source README's calculation using zoom factor directly. The PNG is still not 4K; enlarged grass is visibly softer than independent building sprites. Upscaling does not create detail.

The reviewed world views show no hard tile color discontinuity. Mirrored texture symmetry and repeated cloud forms remain visible and require user art feedback. Maximum village zoom-out no longer reveals the old flat outer margin, but the candidate's peripheral trees/rocks and the surrounding ground have different detail density. This is a review candidate, not final artwork.

Validation script: `game/tests/terrain_review_capture.gd` (run with graphics and an isolated APPDATA save profile). Captures are written to ignored `game/reports/terrain-review/`. Physical Android GPU/memory/performance testing has not been performed. No new APK is published; existing 0.1.38 APK predates this terrain integration and subsequent building workflow wiring.
