# S40000 assets v001 — 2026-11-02

Approved concept-art direction: warm illustrated settlement, diagonal natural river, compact translucent HUD. These assets were generated from the conversation's approved reference images using built-in imagegen. They are reference-guided reconstructions, not pixel-identical extractions. See `manifest.json` for prompts and original hashes.

## Files

- `original/`: preserved 1254×1254 transparent masters (9 PNGs), plus the 1672×941 background with three huts removed.
- `game/`: 256×256 UI icons and expand button, 512×512 menu button, 1024×1024 world hut. Alpha-preserving bicubic downsampling; no original overwrite. Background retains source resolution for zoom.
- `figma-state.json`: component and screen links.

The background was edited only to remove the three huts and reconstruct sandy ground for independent building instances. It still contains the character, vegetation, animals, pots and resources as static concept imagery. It is not a complete production world asset decomposition.

## Figma

- [I10000 / S40000 assets](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=528-120)
- [S40000 / section 02](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=507-62)
- Original reference section 01 remains preserved. Background-containing crops moved to reference section 91 on I10000.

UI text, counts, energy bar and layout are editable. Shared raster components provide the artwork. Closed/open/minimum/maximum views use the same world and HUD; maximum world scale is 2.5× with fixed HUD size. Existing log and stone components remain linked; previous assets and regional-selection assets are preserved.

## Validation and limitations

PNG alpha checked in the previous generation pass; game exports preserve alpha. Figma upload succeeded for all ten files. Screens are 1600×900. Figma visual review is separate from game validation: no Godot import, Android execution or APK build was performed for this design-only change. Buttons' interaction states, navigation and auto-movement are not implemented by this asset package. Generated image detail and terrain repairs differ from the source art in places. Original-art minimap is a static design reference, not a live game map.

Do not treat Figma asset registration as runtime integration. Keep original/ and game/ separately for future updates.
