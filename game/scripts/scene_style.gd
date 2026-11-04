class_name SceneStyle
extends RefCounted
# Shared art direction for the representative riverbank settlement.
const HEADER_HEIGHT := 48.0
const ACTION_SIZE := Vector2(96,64)
const ACTION_GAP := 8.0
const WOOD_WIDTH := 96.0
const STONE_WIDTH := 108.0
const SHADOW := Color(0.17,0.14,0.10,0.16)
const TERRAIN := "res://assets/environment/terrain-isometric-v034.png"
const PROP_FILES := {"hut":"hut-v018","tree":"tree-v018","wood":"fallen-logs","rock":"rock-v018"}

# The painted landscape recedes across the north bank. Keep the playable village
# orthographic, blending only the distant bank into its painted depth scale.
static func ground_scale(world_y: float) -> float:
	return 1.0 # Orthographic isometric ground; no north-bank perspective shrinking.

const CONTACT_OFFSET := Vector2(4,-2)
const CONTACT_COLOR := Color(0.17,0.14,0.10,0.17)
# Rock clusters already painted into the approved terrain, in world coordinates.
# Respawn must not put a second resource sprite over these scenic silhouettes.
const SCENIC_TREES := [Vector2(410,690),Vector2(720,380),Vector2(1980,540),Vector2(1770,1110)]
const PAINTED_ROCKS := [Vector2(1930,890),Vector2(550,1000)]
