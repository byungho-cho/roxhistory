# Buildings asset handoff

- outpost-level1.png: approved Option2 low log lookout derived as transparent PNG. Terrain removed; place above separate reusable ground tile. Static image, not construction animation.
- hut-stages-existing.png: exact existing game atlas, not new design. Four huts ordered left to right. Manifest provides regions (L1 existing; L2–4 proposals). Level sizes are not intended world sizes: render to fixed footprint independent of native image size.
- Road / foundation / building remain separate. Existing construction animation can use the sprite but no frame sequence is supplied here.
- IMPORTANT: these PNGs have edge alpha/color residue. Check actual game-size composite on both grass and dirt. Do not declare final quality verified or force use if fringe is noticeable; retain known good current asset until improved extraction.
- Outpost extraction is AI-derived, not pixel-exact raw layer export. Buildings require asset-ID mapping, input/collision and cost logic separately.

Runtime note: hut-stages-existing.png is byte-identical to res://assets/refactor-v035/hut-stages.png; use that existing tracked atlas instead of adding a duplicate. Both assets are review candidates, not final release art.
