# Construction side menu v006

Read-only source: Figma zkbflw9fCdAlWbphhw5pSS, I10000 nodes 1295:229 and 1277:243, checked 2026-11-08.
Original image exports downloaded from get_design_context; no image pixels modified. Runtime source-atlas clipping, overlap positions and label geometry follow 1295:229. Lock geometry follows 1277:243: 64.8 x 64.8 at (-3,165) on a 216 x 240 reference (54 x 54 at (-2.5,137.5) on the 180 x 200 composition). Existing approved transparent lock artwork is reused once.

Left-to-right order: outpost, shrine, hearth, training, farm, hut. One row shrinks uniformly with available safe width. Artwork, label and lock share the same transforms. Existing build availability and callbacks are preserved.

Main comparison: origin/main 61408be is an ancestor of feature development, so no incoming main implementation was replaced. PR #67 farm and gold assets already integrated at 54811f2. Farm crops remain baked into completed images; separate growth-stage overlays are intentionally unused pending clean empty-field/crop layers. Existing preparation/growth bars remain as temporary phase indication.

Resident assignment review against S40200 1673:8: existing chief-wide allocation, farm/outpost assignment entry bubbles, guard job and per-building selection are retained. This pass does not approve or redesign those draft combinations. No resource migrations, rates, cargo policy, new production systems or notifications were changed. Runtime code contains no remaining user-visible 씨앗 wording.

Validation: Godot import passed; farm_assets_v002_tests 23 checks passed; resident_farm_v0161_tests 131 checks passed. Screenshot: game/reports/construction-side-v006.png (local ignored). These are desktop automated checks, not Android hardware verification. No distribution build or publication in this pass. Distribution location remains repository build/; development launch uses game/project.godot.
