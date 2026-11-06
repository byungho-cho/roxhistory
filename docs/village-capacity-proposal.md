# Village capacity: investigation only

Requested goal: roughly 20–30 buildings. No boundary or save migration is shipped for this proposal.

## Subsequent user direction: fixed movement boundary

For future village development, use approximately 90% of the distance from the center toward the perimeter of the maximum-zoom-out view as the walkable extent. Restrict movement in the remaining outer band. This means radial/center-to-edge extent, not a claim that 90% of screen area is walkable.

Determine this boundary once in village world coordinates. Zooming in or out must not recalculate or resize the walkable boundary: the player can reach the same world-coordinate limits at every zoom level. Camera presentation and movement limits must remain separate.

The exact reference viewport/aspect ratio, camera center and final boundary polygon have not yet been supplied; resolve them against the approved expanded map before implementation. Do not derive different collision boundaries per device or per zoom. This is a recorded future requirement only, not authorization to modify the current map or publish an APK now.

## Current constraints

- `DemoConfig.BUILD_SITES`: six fixed shared hut/outpost sites; resident limit five. Chief hut is separate. Old saves may use the immutable three HOME_SITES legacy positions.
- Village world 2400x1350, an eight-point playable polygon approximately x160–2250/y180–1210. Background artwork 1672x941 displayed at 3000x1688 with a mirrored outer ground layer. Stretching it further worsens existing soft detail and repetition.
- Isometric axes (32,16)/(-32,16); ordinary pad spans four grid cells (256x128 diamond), chief six. Collision tests use existing 230/340-width hut polygons, so slot density cannot be decided by visual pad size alone.
- Navigation rebuilds a 100x56 grid at 24-world-unit cells on every route request and tests physics for each cell. Expanding both axes by one third raises grid cells by approximately 78%, before extra building collisions.
- Camera fit/limits, minimap projection, player save bounds (2380/1330), relocated resource bounds and route-grid bounds contain current dimensions. Expanding only the drawn background would leave movement and validation inconsistent.
- Homes/outposts persist stable IDs plus fixed site indices; legacy home positions and resource relocation/depletion must remain unchanged. Per-building upgrade jobs now attach to those IDs.

## Recommended next prototype

Start with a proposed 3200x1800 world envelope (33% wider/taller; 78% more area), retaining origin and all current coordinates. This is an estimate to test, not an approved or proven 30-building capacity. Extend toward positive coordinates first, or use a world-rectangle origin offset without translating saved objects. Preserve site indices 0–5 and append reviewed new candidates; never reorder them. Target 24 additional slots for 30 shared sites, while keeping the chief separate. If the intended count includes the chief, cap occupied sites at 29.

Lay out residential clusters with clear routes and resource pockets before finalizing the playable polygon. Run polygon-overlap and actual path-to-contact tests for every candidate with all sites occupied and stage-4 silhouettes. Retain all current houses and resources; resolve any conflict by moving proposed new sites, not existing saved objects. Keep the current grid spacing and building collision sizes initially.

Centralize world bounds/site capacity for navigation, camera, GPS and save validation. Make route-grid dimensions derive from the approved world rectangle; profile on Android and consider cached static occupancy if route planning becomes slow. Add optional terrain/site revision metadata with a migration that preserves IDs, site indices, balances, depletion, claim status and upgrade timestamps. Keep old save backups and test loaded old homes, legacy slots, outposts and active upgrades together.

## Design resources needed

- A continuous expanded natural-terrain master with the old village landmarks aligned to unchanged world coordinates. Preliminary delivery target: at least 4096x2304 RGBA/color image for the proposed 3200x1800 envelope, plus decorative edge bleed. Confirm final dimensions against actual maximum-zoom device pixel density before painting; this is not a guaranteed final resolution.
- Separate natural edge/river/mountain/cloud layers or matching seamless transition tiles. Avoid baked buildings/resources that would duplicate gameplay objects. Existing fog can remain a sparse separate overlay.
- A reviewed candidate-site/road/river mask in world coordinates, including no-build and walkable boundaries. Candidate placements must accommodate up to 30 buildings plus harvest access, not merely fill an image.

The supplied Library attachment was not inspected because the previously observed official Windows materialization incompatibility remains unresolved. This proposal derives only from repository code and current rendering. No claim is made about the attachment's intended exact boundary.


## Development preparation after authorization

World size, movement polygon, save bounds and navigation dimensions now share VillageBounds; overview camera reference size is a separate constant so expanding the world cannot silently change the maximum-zoom-out reference. Current geometry, six sites and existing camera scale remain unchanged until approved map assets arrive. The 90-percent helper accepts an already frozen world-space polygon; it never derives runtime collisions from a device viewport or live zoom.

Important correction to the preliminary 3200x1800 proposal: at the current 16:9 minimum zoom 0.56, the 2400x1350 camera reference displays approximately 4285.7x2410.7 world units. A 90% center-to-edge inset spans approximately 3857.1x2169.6, centered at (1200,675): roughly x=-728.6..3128.6 and y=-409.8..1759.8. This exceeds the preliminary proposal and includes negative coordinates. These numbers are diagnostic, NOT an approved new boundary. The new retouched minimum-zoom reference must determine the final polygon, origin offset and background coverage. Navigation will need an origin offset as well as more cells if that footprint is approved; saved existing coordinates must not be translated.

The current detailed background covers x=-300..2700 and y=-169..1519 (3000x1688); the rest is mirrored ground. It does not provide continuous authored scenery for that tentative 90% area, let alone full outer bleed. A newly authored expanded terrain asset is therefore required. Its world-coordinate coverage/pivot must accompany the image. For the current diagnostic framing the visible rectangle is about 4286x2411; at least that logical coverage, plus pan/edge bleed, is needed. Pixel resolution is a separate maximum-zoom/device-density requirement and must not be confused with world coverage.

Final integrated menu asset dimensions and anchor/state contract are documented in menu-integrated-asset-handoff.md. Final visuals, exact reference viewport and terrain coverage are blocking the actual expanded polygon/site rollout and APK publication; no temporary menu art is applied.
