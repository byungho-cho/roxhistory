# RoxHistory UI assets — 2026-11-04

Approved visual drafts for construction actions, the top-left portrait and energy bar. These are newly generated PNG assets, not exports of original layered Figma components.

## Files
- build-cancel.png: red X construction-cancel button, 1263 × 1246 RGBA.
- build-confirm.png: green check construction-confirm button, 1263 × 1246 RGBA.
- chief-portrait.png: newly generated portrait based on the existing hero reference, 1315 × 1197 RGBA.
- energy-bar-frame.png: empty decorative energy frame with dark interior, 2172 × 724 RGBA.

## Integration
- Preserve the original files and aspect ratio. These images contain transparent padding; size by visible artwork bounds rather than stretching the full image box.
- Align cancel and confirm by visible circular body and use consistent displayed dimensions. Touch/hit rectangles are independent of visible artwork; keep them sufficiently large.
- Apply game actions through existing logic. Do not bake state, text or hitboxes into these PNGs.
- The portrait is a new rendering, not a fix to the original portrait source. Check edge rendering on light and dark terrain; do not stretch or clip the hair and shoulders.
- Energy values and the changing fill remain driven by actual game data. The supplied image is the empty frame/background, not a filled progress texture or a ready-made component. Keep fill inside the visible dark inner area and preserve the decorative border; implement as a clipped overlay or a separately masked fill. Do not merely put a fill behind this opaque dark center.
- Verify actual PC and Android display sizes, small-size legibility, alpha edges, scaling, and click targets before final integration. This package has file/alpha validation only, not in-game QA.
- For nine-slice scaling or alternate pressed/disabled states, inspect and prepare the required slices/states deliberately; they are not included here.

## Scope
No gameplay code changes or deployment are included. The user will relay these files and instructions to the development owner.
