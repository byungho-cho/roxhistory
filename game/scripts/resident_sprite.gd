extends Sprite2D
## Four directions, with the same floor origin and world scale as the source render.
const FRAME:=Vector2(96,120)
const ASSET_ROOT:="res://assets/characters/residents/"
const ROWS:={"idle":Vector2i(0,2),"walk":Vector2i(2,6),"wood":Vector2i(8,4),"stone":Vector2i(12,4),
	"carry_wood":Vector2i(16,6),"carry_stone":Vector2i(22,6),"carry_grain":Vector2i(28,6)}
var walk_pose_count := 12
var direction_index:=0
var variant:="sturdy_male"

static func atlas_path(kind:String)->String:
	return ASSET_ROOT+kind.replace("_","-")+"-trial-atlas.png"

func _ready()->void:
	var walk_atlas := ASSET_ROOT + variant.replace("_", "-") + "-walk12-atlas.png"
	if walk_pose_count == 12 and ResourceLoader.exists(walk_atlas):
		texture = load(walk_atlas)
	else:
		walk_pose_count = 6
		texture = load(atlas_path(variant))
	if get_tree().has_meta("village_walk_pose_count"):
		print("ROX_WALK_SPRITE ", variant, " poses=", walk_pose_count)
	centered=false
	region_enabled=true
	region_filter_clip_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	scale=Vector2.ONE*(.46/1.5)*4.0*(1.08 if variant=="female" else 1.16)
	position=-Vector2(48,107)*scale
	region_rect=Rect2(Vector2.ZERO,FRAME)

func pose(facing:Vector2,phase:float,walking:bool,action:String,action_time:float,idle_time:float,cargo:Dictionary)->void:
	if facing.length_squared()>.01:
		direction_index=posmod(roundi(atan2(facing.x,facing.y)/(TAU/4.0)),4)
	var state:="carry_"+str(cargo.kind) if not cargo.is_empty() else action
	var cycle:=fposmod(action_time,1.2)/1.2
	if not ROWS.has(state):
		state="walk" if walking else "idle"
		cycle=fposmod(idle_time,1.2)/1.2
	if walking or state.begins_with("carry_"):
		cycle=fposmod(phase,TAU)/TAU
	var track:Vector2i=ROWS[state]
	var row := track.x+floori(cycle*track.y)
	if state == "walk" and walk_pose_count == 12:
		var walk_frame := floori(cycle*12.0)
		row = 2 + (walk_frame >> 1) if walk_frame % 2 == 0 else 34 + (walk_frame >> 1)
	region_rect.position=Vector2(direction_index,row)*FRAME
