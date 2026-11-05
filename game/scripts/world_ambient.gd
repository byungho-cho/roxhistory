class_name WorldAmbient
extends Node2D

var world: DemoWorld
var smoke: Array[Dictionary] = []
var fish: Sprite2D
var school:Array[Sprite2D]=[]
var clock := 0.0

func _init(owner_world: DemoWorld) -> void: world = owner_world

func _ready() -> void:
	for prop in world.environment_props:
		if prop.kind != "hut" or AssetCatalog.entry("BLD-HUT-L1").size()>0: continue # Level 1 has no chimney.
		for puff in 3:
			var sprite := Sprite2D.new()
			sprite.texture = preload("res://assets/effects/chimney-smoke.png")
			sprite.z_index = 6
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			prop.add_child(sprite)
			smoke.append({"hut":prop,"sprite":sprite,"phase":puff/3.0+prop.position.x*.001})

func _process(delta: float) -> void:
	if not world.player.presentation_paused and world.effects_enabled: clock += delta
	for item in smoke:
		var hut: EnvironmentProp = item.hut
		var sprite: Sprite2D = item.sprite
		var t := fposmod(clock*0.18+item.phase,1.0)
		var width := lerpf(80,140,t)
		sprite.scale = Vector2.ONE*width/sprite.texture.get_width()
		sprite.position = hut.chimney_socket()+Vector2(sin(clock*0.45+item.phase)*8+t*18,-sprite.texture.get_height()*sprite.scale.y*0.50-t*50)
		sprite.modulate.a = sin(t*PI)*0.60
		sprite.visible = hut.visible and world.effects_enabled
	# Entire school follows a gentle closed route strictly inside the river polygon.
	for i in school.size():
		var individual:=school[i]
		individual.material.set_shader_parameter("clock",clock)
		var phase:=clock*.09+i*.65
		var x:=1240+i*37+sin(phase)*150
		individual.position=Vector2(x,x*.24+172+sin(clock*.19+i*.9)*13+i*3)
		individual.flip_h=cos(phase)<0
		individual.rotation=.22+sin(clock*.35+i)*.12
		individual.visible=world.effects_enabled
