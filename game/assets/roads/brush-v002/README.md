# RoxHistory connectable dirt roads v002 brush experiment

Integration candidate, not gameplay implementation. No existing asset or code is replaced.
Figma: I10000 / 12 · 흙길 붓터치 실험: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=1766-367

## Files
- `png/road-00.png` through `road-15.png`: transparent runtime tiles, 520 × 264.
- `svg/`: editable contour sources; keep `../soil-source.png` relative reference.
- `soil-source.png`: AI-generated dirt material. Source pixels are unmodified; vector clipping and mirrored placement ensure repetition.
- `manifest.json`: tile bit masks, scale, anchor and grid specification.
- `preview/connected.png`: assembled connection example, not game capture.
- `verification.json`: offline transparency and connected-port tests.

## Grid contract
Existing game `VillageLayout.AXIS_X=(32,16)`, `AXIS_Y=(-32,16)`.
Each tile covers **2 × 2 grid cells**; road width is **1 grid cell**. This provides rounded elbows without widening the road. Do not shrink the tile to one grid cell.
PNG scale 0.25; centered sprite anchor (260,132). Center steps are (64,32) and (-64,32), equivalent to two existing grid steps. Image includes one-world-pixel transparent border.
Bits: 1 = +u/down-right, 2 = +v/down-left, 4 = -u/up-left, 8 = -v/up-right. Select the mask by actual neighbours. Examples: 05/10 straight, 03/06/09/12 elbows, 07/11/13/14 T junctions, 15 cross, 01/02/04/08 ends, 00 isolated.
Do not rotate/recolor individual tiles. Use consistent scale, linear filtering and shared pixel alignment. Neighbour facing bits must agree. Shared ports have a small overlap to avoid antialias cracks.

## Integration work still required
Current game uses Polygon2D ribbons and stretches the central 8% of GROUND-ROAD through a shader. These tiles are not a drop-in replacement for that ribbon texture. A developer must build neighbour masks on a two-grid-cell road graph, use the manifest anchors, and connect building entrances to the graph. Endpoint offsets for arbitrary existing buildings need handling. Do not apply the old ribbon shader to these PNGs.

## Visual scope / limitations
No grass fringes, per user's connection-first direction. Organic contour, tangent dry-brush bristles and longitudinal pigment strokes retained; the painterly concept's rich grass and scenic detail are not reproduced. Repeat patterns can be visible on long roads. The preview has no gaps, and 128 valid adjacent-mask combinations passed interior-seam alpha tests (105,600 samples). This is not full engine/pixel-color seam certification. Zoom levels, building overlap and engine integration remain to be reviewed in game.

## Rebuild
Python 3 with Shapely and Pillow; Inkscape CLI. Run `python build_assets.py`, then `python verify_assets.py`. Generator creates native vector geometry rather than cutting raster tiles from the concept sheet. No changes to gameplay source or existing road assets.

## v002 experiment
Original v001 retained unchanged. This version uses new native vector bristles and strokes, not extracted pieces from the generated brush concept. The generated concept is looser and more painterly; these technical tiles intentionally moderate the brushwork near ports to preserve compatibility. Same width, anchor, neighbour masks and 2×2 grid footprint as v001. Fine brushwork may disappear at distant zoom. No runtime game or source edits.
