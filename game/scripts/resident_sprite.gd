extends Sprite2D
## Shared directional animation textures keep the costs independent of the number of residents.
const APPROVED_FRAME := Vector2(80, 100)
const APPROVED_FLOOR := Vector2(40, 89)
const APPROVED_COLUMNS := 32
const CARRY_RENDER_SCALE := 1.5
const CARRY_COLUMNS := 16
# Each entry is the first sample, sample count, and clip length at the source frame rate.
const APPROVED_ROWS := {
	"idle": Vector3i(0, 24, 122), "stretch": Vector3i(24, 24, 129),
	"listen": Vector3i(48, 24, 120), "speak": Vector3i(72, 31, 155),
	"cheer": Vector3i(103, 24, 79), "walk": Vector3i(127, 32, 96),
	"wood": Vector3i(159, 24, 73), "grain": Vector3i(183, 24, 76),
	"stone": Vector3i(207, 8, 36), "carry_wood": Vector3i(215, 16, 96),
	"carry_stone": Vector3i(231, 16, 96), "carry_grain": Vector3i(247, 16, 96),
}
const APPROVED_MAN := preload("res://assets/characters/residents/res053-man.png")
const APPROVED_WOMAN := preload("res://assets/characters/residents/res053-woman.png")
const CARRY_MAN := preload("res://assets/characters/residents/res053-man-carry.png")
const CARRY_WOMAN := preload("res://assets/characters/residents/res053-woman-carry.png")
const DISPLAY_SIZE_MULTIPLIER := 1.5
const GRAIN_HARVEST_SECONDS := 1.2
const WOOD_CONTACTS := [35.0 / 30.0, 65.0 / 30.0]
var direction_index:=0
var variant:="sturdy_male"
var shown_state := "idle"
var approved_walk_cycle := 0.0

func _ready()->void:
	centered=false
	region_enabled=true
	region_filter_clip_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_pose_approved("idle", 0.0)

static func display_scale(female: bool) -> float:
	return (.46 / 1.5) * 4.0 * (1.08 if female else 1.16) * DISPLAY_SIZE_MULTIPLIER

static func gesture_duration(gesture: String) -> float:
	var track: Vector3i = APPROVED_ROWS[gesture]
	return track.z / 30.0

static func wood_contact_crossed(before: float, after: float) -> bool:
	var span := gesture_duration("wood")
	for contact: float in WOOD_CONTACTS:
		if floori((after - contact) / span) > floori((before - contact) / span):
			return true
	return false

func advance_walk(distance: float) -> void:
	# The approved walk covers roughly 4.1 m (man) or 4.3 m (woman) over this cycle.
	var cycle_distance := (211.0 if variant == "female" else 218.0) * DISPLAY_SIZE_MULTIPLIER
	approved_walk_cycle = fposmod(approved_walk_cycle + distance / cycle_distance, 1.0)

func pose(facing: Vector2, walking: bool, action: String, action_time: float, idle_time: float, cargo: Dictionary, gesture: String, gesture_time: float) -> void:
	if facing.length_squared()>.01:
		direction_index=posmod(roundi(atan2(facing.x,facing.y)/(TAU/4.0)),4)
	var state := "idle" if gesture.is_empty() else gesture
	var fraction := 0.0
	if not cargo.is_empty() or walking:
		state = "walk" if cargo.is_empty() else "carry_" + str(cargo.kind)
		fraction = approved_walk_cycle
	elif action in ["wood", "stone"]:
		state = action
		fraction = fposmod(action_time, gesture_duration(state)) / gesture_duration(state)
	elif action == "grain":
		state = action
		fraction = clampf(action_time / GRAIN_HARVEST_SECONDS, 0.0, .9999)
	elif state == "idle":
		fraction = fposmod(idle_time, gesture_duration(state)) / gesture_duration(state)
	else:
		fraction = clampf(gesture_time / gesture_duration(state), 0.0, .9999)
	_pose_approved(state, fraction)

func _pose_approved(state: String, fraction: float) -> void:
	var track: Vector3i = APPROVED_ROWS[state]
	var tile := (track.x + floori(fraction * track.y)) * 4 + direction_index
	var female := variant == "female"
	var atlas := APPROVED_WOMAN if female else APPROVED_MAN
	var columns := APPROVED_COLUMNS
	var render_scale := 1.0
	if state.begins_with("carry_"):
		atlas = CARRY_WOMAN if female else CARRY_MAN
		columns = CARRY_COLUMNS
		render_scale = CARRY_RENDER_SCALE
		tile -= APPROVED_ROWS.carry_wood.x * 4
	if texture != atlas:
		texture = atlas
		scale = Vector2.ONE * display_scale(female) / render_scale
	position = -APPROVED_FLOOR * render_scale * scale
	var frame_size := APPROVED_FRAME * render_scale
	region_rect = Rect2(Vector2(tile % columns, floori(float(tile) / columns)) * frame_size, frame_size)
	shown_state = state
