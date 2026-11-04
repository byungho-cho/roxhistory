# Expanded village terrain — approved concept, 2026-11-04

`terrain-s40000-open-village-edited-v002.png` is a new generated edit approved for the RoxHistory village background. It is not a recovered layered original or a seamless world-map tile.

- Dimensions: 1672 × 941, RGB PNG.
- The creek is now near the upper-left edge. Distant hills occupy a narrow upper strip, leaving much more continuous village construction space.
- Freestanding trees, rocks, buildings and animals should be separate game objects.
- Previous reference files and the runtime terrain remain unchanged. This package does not change gameplay code.

## Integration checks

Do not replace the runtime PNG without remapping and testing:
1. River/water boundaries and any fish or water-only object placement.
2. Walkable area, collision masks and navigation paths.
3. Building candidate sites, footprint bounds and object exclusions.
4. Existing save positions and camera edges at all supported zoom levels.

For the current planned version, areas occupied by animals/plants are not buildable. Future planning may allow clearing animals by hunting and trees by gathering before building; that future behavior is not implemented by this asset.

The user will relay this asset to the development owner. Perform PC/gameplay verification before final integration.
