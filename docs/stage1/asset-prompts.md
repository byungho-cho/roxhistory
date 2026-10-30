# Asset generation prompts and provenance

Tool: built-in `image_gen.imagegen`, 2026-10-30. Transparent background requested for every object; opaque landscape for terrain. Output files live in `game/assets/environment/`.

Shared art direction: RoxHistory Korean Neolithic riverside game, charming polished 2.5D hand-painted storybook game art, rounded chunky natural forms, warm sunlight from upper left, amber highlights, moss green foliage, tactile wood, stone and thatch. Orthographic elevated three-quarter camera around 40 degrees. No text, UI, characters, animals, or modern objects. Fully visible isolated objects, transparent padding, no landscape backdrop or exterior cast shadow.

## terrain.png

Reference: existing `game/assets/figma/98398.png` for style only. Terrain-only 16:9 map: remove huts, trees, bushes, props, characters, animals, fences, construction and lumber piles. Warm ochre worn dirt paths blend into moss-green grassy soil; fine pebble and short-grass ground texture. Spacious playable clearing in bottom two thirds, turquoise river in upper right, broad sandy shoreline with subtle earth lip. Soil pads for separately placed huts, arrival clearing near 41% width/76% height. No waterfalls, cliffs, foreground blur, tall vegetation, or shadows of absent objects. River guide from (37%,0%) through (38%,21%), (50%,27%), (59%,37%), (69%,40%), (79%,47%), (90%,52%) to (100%,61%). Runtime shoreline was traced to the generated result, rather than trusting prompt coordinates.

## tree.png

Single isolated deciduous oak-like riverside tree. Wide rounded clustered crown, chunky curved brown trunk and root flare at bottom center. Yellow-green upper-left highlights and moss shadows lower-right. Whole tree, generous transparent padding, no ground patch or props.

## hut.png

Single Korean Neolithic Amsa-dong pit dwelling: low broad rounded conical reed thatch roof almost reaching ground, shallow sunken oval earthen base, small dark entrance facing lower right supported by rough timber poles. No masonry walls, chimney, metal tools or windows. Bottom ground contact centered.

## grass.png

Lush little cluster of riverside grasses/reed leaves: mixed short broad blades and three taller softly bending stalks, curved olive-green forms with golden tips, roots together at bottom center.

## rock.png

One low group of three rounded weathered gray river stones, large center stone with warm ochre facets and subtle moss around base, smaller stones either side, chunky readable silhouette.

## props.png

Small grouped Neolithic daily-life props: two handmade brown comb-pattern clay vessels, shallow stone grinding slab and rounded handstone, loosely coiled plant-fiber fishing net. No wheel pottery, metal, modern tools or built furniture. Common ground contact plane.

## shrub.png

Small rounded riverside willow shrub: low broad dome of long drooping oval green leaves, short branching brown stems, upper-left golden light and lower-right moss shadows. Entire object on actual transparent background, bottom-center ground contact, no ground patch, glow, exterior shadow, text or characters.

Objects are original generated raster assets. Atlas bounds and runtime shadows/vegetation shaders are in `environment_prop.gd`; no opaque placeholder backgrounds are composited into the game. Alternate halo-removal image edits were inspected but not adopted.
