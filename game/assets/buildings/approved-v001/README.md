# Building integration, 2026-11-07

The 24 PNG masters are byte-for-byte copies of the final cleaned `separated-v003` artwork supplied for this game update: hut, outpost, training, shrine, hearth and common foundation, levels 1–4. No image regeneration, recoloring or permanent raster resizing was performed.

`source-manifest.json` preserves the original extraction audit, including its earlier review-candidate descriptions. `integration-manifest.json` records this update's integration authorization separately. It does not claim that AI-assisted source extractions were pixel-identical to their earlier concept artwork.

## Runtime contract

- Catalog: `game/data/assets.json`, IDs `BLD-{HUT,OUTPOST,TRAINING,SHRINE,HEARTH}-L1` through `L4`, plus `BLD-CHIEF-L1` through `L4` aliases of hut art.
- Foundations: `GROUND-PAD-L1` through `L4`; use the full source canvas with existing foundation placement metadata. No training-specific circular ground.
- Structure crops: alpha-8 visible bounds with a four-source-pixel margin, specified as metadata. The original pixels are unchanged.
- `BuildingVisuals.apply(sprite, kind, level, ground_width)` applies a uniform aspect-preserving scale and the agreed contact alignment. Use ground width 340 for chief huts, 230 for ordinary buildings. If the sprite has a translated visual-only parent, subtract that parent's translation after application; do not shift collision or saved world coordinates.
- Hut and outpost images remain horizontally centered, and each family retains a common visual center. Hearths remain centered over their independent pad. Training and shrine stages use a common bottom line, `ground_width * 0.12` below the building origin.
- Training reference heights are 104, 84.8, 92, 120 at reference width 320. Level 2's approved 0.8 reduction is already included; never apply it again. Shrine reference heights are 166, 184, 202, 222. Hearth heights are 114.57, 139.37, 182.4, 184.3. Source aspect ratio is preserved throughout.

The source road reference, unapproved gold line variants and character review proposals were not imported. Existing source sets remain untouched for compatibility and audit history.
