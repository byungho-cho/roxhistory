class_name SceneStyle
extends RefCounted
# Shared art direction for the representative riverbank settlement.
const HEADER_HEIGHT := 48.0
const ACTION_SIZE := Vector2(96,64)
const ACTION_GAP := 8.0
const WOOD_WIDTH := 96.0
const STONE_WIDTH := 108.0
const SHADOW := Color(0.17,0.14,0.10,0.16)
const TERRAIN := "res://assets/environment/terrain-s40000.png"
const PROP_FILES := {"hut":"hut-v018","tree":"tree-v018","wood":"fallen-logs","rock":"rock-v018"}

# The painted landscape recedes across the north bank. Keep the playable village
# orthographic, blending only the distant bank into its painted depth scale.
static func ground_scale(world_y: float) -> float:
	return lerpf(0.62,1.0,smoothstep(200.0,650.0,world_y))

const CONTACT_OFFSET := Vector2(4,-2)
const CONTACT_COLOR := Color(0.17,0.14,0.10,0.17)
# Rock clusters already painted into the approved terrain, in world coordinates.
# Respawn must not put a second resource sprite over these scenic silhouettes.
const PAINTED_ROCKS := [Vector2(1925,930),Vector2(1390,1170),Vector2(750,1135),Vector2(110,575),Vector2(2160,455)]
