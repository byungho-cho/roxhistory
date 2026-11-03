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
		if prop.kind != "hut": continue
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/effects/chimney-smoke.png")
		sprite.z_index = 6
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		prop.add_child(sprite)
		smoke.append({"hut":prop,"sprite":sprite,"phase":smoke.size()*0.91})
	for i in 5:
		var individual:=Sprite2D.new()
		var atlas:=AtlasTexture.new();atlas.atlas=preload("res://assets/effects/fish-school.png");atlas.region=Rect2(65,25,450,320);atlas.filter_clip=true
		individual.texture=atlas;individual.scale=Vector2.ONE*(22+i*2)/450.0
		individual.modulate=Color(.65,.85,.87,.48);individual.z_index=-18
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/fish_motion.gdshader");material.set_shader_parameter("phase",i*1.7);individual.material=material
		world.add_child(individual);school.append(individual)
	fish=school[0]

func _process(delta: float) -> void:
	if not world.player.presentation_paused and world.effects_enabled: clock += delta
	for item in smoke:
		var hut: EnvironmentProp = item.hut
		var sprite: Sprite2D = item.sprite
		var t := fposmod(clock*0.18+item.phase,1.0)
		var width := lerpf(46,72,t)
		sprite.scale = Vector2.ONE*width/sprite.texture.get_width()
		sprite.position = hut.chimney_socket()+Vector2(sin(clock*0.45+item.phase)*6,-sprite.texture.get_height()*sprite.scale.y*0.42-t*24)
		sprite.modulate.a = .20+sin(t*PI)*0.40
		sprite.visible = hut.visible and world.effects_enabled
	# Entire school follows a gentle closed route strictly inside the river polygon.
	for i in school.size():
		var individual:=school[i]
		individual.material.set_shader_parameter("clock",clock)
		individual.position=Vector2(1570+i*28,250+i%2*24)+Vector2(sin(clock*.12+i*.18)*110,sin(clock*.3+i)*8)
		individual.flip_h=cos(clock*.12+i*.18)<0
		individual.rotation=sin(clock*.7+i)*.08
		individual.visible=world.effects_enabled
