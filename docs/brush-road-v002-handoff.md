# Brush road v002 implementation

Reconstructed against fb67044 after the original cloud-only integration worktree
became unavailable. This is a new implementation, not recovery of its old commit.

- Runtime assets: game/assets/roads/brush-v002, 16 transparent 520×264 PNGs.
- Source: Library roxhistory-road-brush-v002.zip, version 0,
  SHA256 c1d4512f2e07594d94617a22b2cc6e44ffc5cc6082270de781b9c926b5ed8911.
- Tiles use scale 0.25 with a centered anchor. Centers are two ground cells apart.
  Bits 1/2/4/8 follow +u/+v/-u/-v; road width is one ground cell.
- BrushRoadNetwork merges every branch into one cell graph before assigning masks.
  Crossings and T junctions have exactly one sprite, never overlapping ribbons.
- BFS uses safe side entrances and avoids all building ground footprints. It also
  confines complete tiles to playable terrain. Existing positions/save data and
  gameplay occupancy/collision code remain unchanged.
- VillageLayout rebuilds from actual saved building anchors. Assets missing or
  an unrouteable placement switch the whole network to the previous NaturalRoad.
  This deliberately avoids a half-finished disconnected hybrid.
- Disable via project setting roxhistory/visuals/brush_roads=false, or launch
  with '-- --legacy-roads'. NaturalRoad itself is unchanged.
- No grass fringe, shader stretching, tile rotation or color variation.
- The tile art has technical seams designed to match, but long paths can show
  repetition. Safe entrances terminate near the pad rather than entering the
  building center. In-game visual acceptance is still pending.
- No export/build/distribution or remote push performed by this task.

Verification (Godot 4.6.3 headless; isolated /tmp userdata):
brush_road_network_tests: all pass; see final handoff for final check count.
world_polish_pending_farm_tests: 54 pass.
storage_v0165_tests: 44 pass.
foundation_tests: 5 pre-existing failures of 29 (four foundation count assertions
and save level mapping), not claimed green. Previous baseline report has the same
failures. Real gameplay/zoom appearance was not verified.
