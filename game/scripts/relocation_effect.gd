class_name RelocationEffect
extends Node2D

const DROP_TIME := .34
const FOUNDATION_FADE_TIME := .39
const DROP_HEIGHT := 104.0
const SETTLE_TIME := .16
const LANDING_CUE_DELAY := .08
const ROAD_PAUSE := .12
var app: Node
var key: String
var source: Sprite2D
var destination: Sprite2D
var foundation: Sprite2D
var target: Vector2
var kind: String
var level: int
var destination_position := Vector2.ZERO
var destination_scale := Vector2.ONE
var destination_foot_y := 0.0
var destination_color := Color.WHITE
var clock := 0.0
var landed := false
var played_landing_cue := false
var ground_art := Node2D.new()

static func drop_delay(building_kind: String) -> float:
	return .14 if building_kind == "farm" else 0.0

static func road_delay(building_kind: String) -> float:
	return maxf(FOUNDATION_FADE_TIME, drop_delay(building_kind) + DROP_TIME + SETTLE_TIME) + ROAD_PAUSE

func _init(owner_app: Node,id: String,old_image: Sprite2D,to: Vector2,building_kind: String, building_level: int) -> void:
	app=owner_app;key=id;source=old_image;target=to;kind=building_kind;level=building_level
	name="RelocationEffect";visibility_layer=2;z_index=2
	ground_art.z_as_relative = false
	ground_art.z_index = -14
	ground_art.visibility_layer = 2
	ground_art.draw.connect(draw_ground)
	add_child(ground_art)

func _ready() -> void:
	add_child(source)
	destination=app.world.building_sprite(key)
	if not is_instance_valid(destination):
		queue_free()
		return
	destination_color=destination.self_modulate
	destination_position=destination.position
	destination_scale=destination.scale
	destination_foot_y=destination.get_rect().end.y * destination_scale.y
	destination.self_modulate.a=0.0
	foundation = app.world.get_node("VillageLayout").foundation_at(target)
	if is_instance_valid(foundation):
		foundation.self_modulate.a = foundation_opacity()

func _process(delta: float) -> void:
	if not is_instance_valid(destination):
		queue_free()
		return
	clock+=delta
	if clock>0.0:
		source.hide()
		var progress := clampf((clock-drop_delay(kind))/DROP_TIME,0,1)
		destination.self_modulate=destination_color
		destination.position=destination_position+Vector2(0,-DROP_HEIGHT*(1-progress*progress))
		if is_instance_valid(foundation):
			foundation.self_modulate.a = foundation_opacity()
		if progress>=1.0 and not landed:
			landed=true
			var dust := preload("res://scripts/village_upgrade_feedback.gd").new(target,0)
			app.world.add_child(dust)
	if landed:
		var contact_age := clock - drop_delay(kind) - DROP_TIME
		if not played_landing_cue and contact_age >= LANDING_CUE_DELAY:
			played_landing_cue = true
			app.audio.cue("relocation_landing")
		var settle := clampf(contact_age / SETTLE_TIME, 0.0, 1.0)
		var compression := sin(PI * settle) * (1.0 - settle)
		destination.scale = destination_scale * Vector2(1.0 + .055 * compression, 1.0 - .12 * compression)
		destination.position.y = destination_position.y + destination_foot_y * .12 * compression
		if settle >= 1.0:
			queue_free()
	ground_art.queue_redraw()

func draw_ground() -> void:
	if not is_instance_valid(foundation):
		VillageLayout.draw_move_foundation(ground_art,target,kind,level,foundation_opacity())
	var drop_age := clock-drop_delay(kind)
	var approach := clampf(drop_age / DROP_TIME, 0.0, 1.0)
	var fade := 1.0 - clampf((drop_age - DROP_TIME) / SETTLE_TIME, 0.0, 1.0)
	var pad := VillageLayout.foundation_rect(6 if kind == "chief" else 4)
	var radius := pad.size * lerpf(.33, .23, approach)
	var center := target + pad.get_center()
	for layer in range(3):
		var points := PackedVector2Array()
		for segment in range(24):
			points.append(center + Vector2.from_angle(TAU * segment / 24.0) * radius * (1.0 - layer * .18))
		ground_art.draw_colored_polygon(points, Color(.16, .10, .05, lerpf(.035, .10, approach) * fade))

func foundation_opacity() -> float:
	return lerpf(.42 if kind=="farm" else .30, 1.0, smoothstep(0.0, FOUNDATION_FADE_TIME, clock))

func _exit_tree() -> void:
	if is_instance_valid(foundation):
		foundation.self_modulate.a = 1.0
	if is_instance_valid(destination):
		destination.self_modulate=destination_color
		destination.position=destination_position
		destination.scale=destination_scale
	if is_instance_valid(app):app.relocating_key=""
