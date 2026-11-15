class_name DemolitionEffect
extends Node2D
## The model commits once. The retained art and sound are presentation only.
const HAMMER := preload("res://assets/effects/construction-hammer.png")
const HIT := preload("res://assets/audio/d0006-approved/demolition-b.mp3")
const DUST := preload("res://assets/ui/d0019/ground-dust-soft.png")
const HIT_INTERVAL := .46
const HIT_COUNT := 3
const FADE_OUT := .38
const HAMMER_SIZE := Vector2(66,61)
const GRIP := Vector2(.28,.89) * HAMMER_SIZE
const HEAD := Vector2(.57,.30) * HAMMER_SIZE
var ghost: Sprite2D
var app: Node
var voice := AudioStreamPlayer.new()
var hammer := Node2D.new()
var ground := Node2D.new()
var age := 0.0
var last_hit := -1.0
var hits := 0
var side := 1.0
var rest_position := Vector2.ZERO
var kind: String
var level: int

func _init(image: Sprite2D, owner_app: Node, building_kind: String, building_level: int) -> void:
	ghost = image
	app = owner_app
	kind = building_kind
	level = building_level
	name = "DemolitionEffect"
	visibility_layer = 2
	z_index = 2
	side = -1.0 if randf() < .5 else 1.0
	voice.stream = HIT
	voice.bus = &"SFX"
	add_child(voice)
	ground.visibility_layer = 2
	add_child(ground)
	ground.draw.connect(draw_foundation)
	ghost.z_index = 1
	ghost.visibility_layer = 2
	add_child(ghost)
	hammer.z_index = 2
	hammer.visibility_layer = 2
	add_child(hammer)
	hammer.draw.connect(draw_impact)

func _process(delta: float) -> void:
	if app.screen != "play" or app.world_map_open or app.map_transition_active or not app.application_active:
		queue_free()
		return
	age += delta
	if hits < HIT_COUNT and age >= (hits + 1) * HIT_INTERVAL:
		hits += 1
		last_hit = age
		voice.stop()
		voice.volume_db = randf_range(-16,-12)
		voice.pitch_scale = randf_range(.94,1.06)
		if not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")):
			voice.play()
	var end := HIT_INTERVAL * HIT_COUNT + FADE_OUT
	var alpha := 1.0 - smoothstep(HIT_INTERVAL, end, age)
	var impact := 1.0 - clampf((age - last_hit) / .17,0,1)
	ground.modulate.a = alpha
	ghost.modulate.a = alpha
	ghost.position = rest_position + Vector2(-side * impact * 7,-impact * 4 + (1.0-alpha)*10)
	hammer.queue_redraw()
	if age >= end:
		queue_free()

func draw_foundation() -> void:
	if not BuildingVisuals.has_own_ground(kind):
		VillageLayout.draw_move_foundation(ground,Vector2.ZERO,kind,level)

func draw_impact() -> void:
	var contact := Vector2(side * 11,-37)
	if hits < HIT_COUNT or age - last_hit < .09:
		var phase := clampf((age - hits * HIT_INTERVAL) / HIT_INTERVAL,0,1)
		var swing := pow(phase,2.6)
		if age - last_hit < .09:
			swing = 1.0
		var grip := contact + Vector2(side * 30,24)
		var head_direction := Vector2(-side * swing,-1.0).normalized()
		var angle := head_direction.angle() - (HEAD - GRIP).angle()
		hammer.draw_set_transform(grip,angle)
		hammer.draw_texture_rect(HAMMER,Rect2(-GRIP,HAMMER_SIZE),false)
		hammer.draw_set_transform(Vector2.ZERO)
	var elapsed := age - last_hit
	if elapsed >= .38:return
	var fade := 1.0 - smoothstep(.04,.38,elapsed)
	for sign_value in [-1,1]:
		var center := Vector2(sign_value * (24 + elapsed * 90),-7-elapsed*32)
		var extent := Vector2(66,31) * (1.0+elapsed)
		hammer.draw_texture_rect(DUST,Rect2(center-extent*.5,extent),false,Color(1,1,1,fade))
