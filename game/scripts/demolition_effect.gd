class_name DemolitionEffect
extends Node2D
## The model commits once. Only this retained sprite and its sound are timed.
const HAMMER := preload("res://assets/effects/construction-hammer.png")
const HIT := preload("res://assets/audio/d0006-approved/demolition-b.mp3")
var ghost: Sprite2D
var app: Node
var voice := AudioStreamPlayer.new()
var hammer := Node2D.new()
var random := RandomNumberGenerator.new()
var bursts: int
var striking := true
var remaining: float
var to_hit := .24
var impact := 0.0
var direction: Vector2
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
	bursts = 2
	remaining = .75
	direction = Vector2.from_angle(random.randf_range(.15, .75) + (PI if random.randf() < .5 else 0.0))
	voice.stream = HIT
	voice.bus = &"SFX"
	add_child(voice)
	ghost.z_index = 1
	ghost.visibility_layer = 2
	add_child(ghost)
	hammer.z_index = 2
	hammer.visibility_layer = 2
	add_child(hammer)
	hammer.draw.connect(draw_hammer)

func _ready() -> void:
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			voice.stop()
			queue_free())

func _process(delta: float) -> void:
	if app.screen != "play" or app.world_map_open or app.map_transition_active or not app.application_active:
		voice.stop()
		queue_free()
		return
	remaining -= delta
	impact = maxf(0, impact - delta * 7)
	ghost.position = rest_position + Vector2(direction.x * impact * 7, -impact * 4)
	if remaining <= 0.0:
		if striking:
			bursts -= 1
			if bursts == 0:
				striking = false
				voice.stop()
				set_process(false)
				var fade := create_tween()
				fade.set_parallel(true)
				fade.tween_property(self, "modulate:a", 0.0, .36)
				fade.tween_property(ghost, "position:y", rest_position.y + 12, .36)
				fade.chain()
				fade.tween_callback(queue_free)
				hammer.hide()
				return
		striking = not striking
		remaining = .75 if striking else .28
		to_hit = .26
	if striking:
		to_hit -= delta
		if to_hit <= 0.0:
			to_hit = random.randf_range(.36, .57)
			impact = 1.0
			voice.stop()
			voice.volume_db = random.randf_range(-16, -12)
			voice.pitch_scale = random.randf_range(.94, 1.06)
			if not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")):voice.play()
	hammer.queue_redraw()

func _draw() -> void:
	if not BuildingVisuals.has_own_ground(kind):
		VillageLayout.draw_move_foundation(self,Vector2.ZERO,kind,level)

func draw_hammer() -> void:
	if not striking or bursts == 0:return
	var contact := Vector2(0, -28)
	var grip := contact + direction * (29 + clampf(to_hit * 3, 0, 1) * 22)
	hammer.draw_set_transform(grip, (contact - grip).angle() + PI * .5)
	hammer.draw_texture_rect(HAMMER, Rect2(-17, -32, 34, 40), false)
	hammer.draw_set_transform(Vector2.ZERO)
	if impact > 0:
		hammer.draw_circle(contact, 5 + (1 - impact) * 13, Color(.82, .66, .4, impact * .28))
