class_name WorldAmbient
extends Node2D

var world: DemoWorld
var smoke: Array[Dictionary] = []
var fish: Sprite2D
var clock := 0.0

func _init(owner_world: DemoWorld) -> void: world = owner_world

func _ready() -> void:
	for prop in world.environment_props:
		if prop.kind != "hut": continue
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/effects/chimney-smoke.png")
		sprite.z_index = 6
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		prop.add_child(sprite)
		smoke.append({"hut":prop,"sprite":sprite,"phase":smoke.size()*0.91})
	fish = Sprite2D.new()
	fish.texture = preload("res://assets/effects/fish-school.png")
	fish.scale = Vector2.ONE*150.0/fish.texture.get_width()
	fish.modulate = Color(0.66,0.85,0.86,0.48)
	fish.z_index = -18
	world.add_child(fish)

func _process(delta: float) -> void:
	if not world.player.presentation_paused and world.effects_enabled: clock += delta
	for item in smoke:
		var hut: EnvironmentProp = item.hut
		var sprite: Sprite2D = item.sprite
		var t := fposmod(clock*0.18+item.phase,1.0)
		var width := lerpf(46,72,t)
		sprite.scale = Vector2.ONE*width/sprite.texture.get_width()
		sprite.position = hut.chimney_socket()+Vector2(sin(clock*0.45+item.phase)*6,-sprite.texture.get_height()*sprite.scale.y*0.42-t*24)
		sprite.modulate.a = sin(t*PI)*0.36
		sprite.visible = hut.visible and world.effects_enabled
	# Entire school follows a gentle closed route strictly inside the river polygon.
	fish.position = Vector2(1640,270)+Vector2(sin(clock*0.085)*150,sin(clock*0.14)*34)
	fish.rotation = sin(clock*0.085)*0.07
	fish.visible = world.effects_enabled
