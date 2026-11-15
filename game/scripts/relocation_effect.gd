class_name RelocationEffect
extends Node2D

const GROUND_LEAD := .08
const DROP_TIME := .21
var app: Node
var key: String
var source: Sprite2D
var destination: Sprite2D
var target: Vector2
var outline: PackedVector2Array
var destination_position := Vector2.ZERO
var destination_color := Color.WHITE
var clock := 0.0
var landed := false

func _init(owner_app: Node,id: String,old_image: Sprite2D,to: Vector2,footprint: PackedVector2Array) -> void:
	app=owner_app;key=id;source=old_image;target=to;outline=footprint
	name="RelocationEffect";visibility_layer=2;z_index=2

func _ready() -> void:
	add_child(source)
	destination=app.world.building_sprite(key)
	if not is_instance_valid(destination):
		queue_free()
		return
	destination_color=destination.self_modulate
	destination_position=destination.position
	destination.self_modulate.a=0.0

func _process(delta: float) -> void:
	if not is_instance_valid(destination):
		queue_free()
		return
	clock+=delta
	if clock>=GROUND_LEAD:
		source.hide()
		var progress := clampf((clock-GROUND_LEAD)/DROP_TIME,0,1)
		destination.self_modulate=destination_color
		destination.position=destination_position+Vector2(0,-72*(1-progress*progress))
		if progress>=1.0 and not landed:
			landed=true
			app.audio.cue("complete")
			for side in [-1,1]:
				app.world.feedback.burst(target+Vector2(side*44,0),Color("c3a675"),6,.33)
	if landed: queue_free()

func _draw() -> void:
	var ground := outline.duplicate()
	for i in ground.size(): ground[i]+=target
	draw_colored_polygon(ground,Color(.66,.48,.27,.42))

func _exit_tree() -> void:
	if is_instance_valid(destination):
		destination.self_modulate=destination_color
		destination.position=destination_position
	if is_instance_valid(app):app.relocating_key=""
