class_name TrainingHunter
extends Node2D
## Presentation-only practice actor using the current resident models.

const RESIDENT_SPRITE := preload("res://scripts/resident_sprite.gd")
const PRACTICE_ATLAS := preload("res://assets/characters/residents/res053-training.png")
const FRAME_SIZE := Vector2(112, 104)
const FLOOR := Vector2(56, 89)
const COLUMNS := 8
const SAMPLES := 32
const PRACTICE_SECONDS := 2.2

var visual: Sprite2D
var female: bool
var clock: float

func _init(facing: int, phase_offset: float) -> void:
	female = facing < 0
	clock = phase_offset
	visibility_layer = 2

func _ready() -> void:
	name = "TrainingHunter"
	visual = Sprite2D.new()
	visual.name = "TrainingSprite"
	visual.centered = false
	visual.region_enabled = true
	visual.region_filter_clip_enabled = true
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual.texture = PRACTICE_ATLAS
	visual.scale = Vector2.ONE * RESIDENT_SPRITE.display_scale(female)
	visual.position = -FLOOR * visual.scale
	add_child(visual)
	update_frame()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(2, -1), 0, Vector2(1, .28))
	draw_circle(Vector2.ZERO, 17, SceneStyle.CONTACT_COLOR)

func _process(delta: float) -> void:
	var world := get_parent().get_parent().get_parent() as DemoWorld
	if not is_visible_in_tree() or (world and world.simulation_paused):
		return
	clock = fposmod(clock + delta, PRACTICE_SECONDS)
	var point := get_global_transform_with_canvas().origin
	if Rect2(Vector2(-120, -120), get_viewport_rect().size + Vector2(240, 240)).has_point(point):
		update_frame()

func update_frame() -> void:
	var frame := floori(fposmod(clock, PRACTICE_SECONDS) / PRACTICE_SECONDS * SAMPLES)
	var tile := frame + (SAMPLES if female else 0)
	var region := Rect2(Vector2(tile % COLUMNS, floori(float(tile) / COLUMNS)) * FRAME_SIZE, FRAME_SIZE)
	if region != visual.region_rect:
		visual.region_rect = region
