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
		for puff in 3:
			var sprite := Sprite2D.new()
			sprite.texture = preload("res://assets/effects/chimney-smoke.png")
			sprite.z_index = 6
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			prop.add_child(sprite)
			smoke.append({"hut":prop,"sprite":sprite,"phase":puff/3.0+prop.position.x*.001})
	for i in 5:
		var individual:=Sprite2D.new()
		var atlas:=AtlasTexture.new();atlas.atlas=preload("res://assets/effects/fish-school.png");atlas.region=Rect2(65,25,450,320);atlas.filter_clip=true
		individual.texture=atlas;individual.scale=Vector2.ONE*(42+i*3)/450.0
		individual.modulate=Color(.65,.85,.87,.72);individual.z_index=-18
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/fish_motion.gdshader");material.set_shader_parameter("phase",i*1.7);individual.material=material
		world.add_child(individual);school.append(individual)
	fish=school[0]

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
		var drift:=sin(clock*.09)*180
		individual.position=Vector2(1240+i*42+drift,470+i*10+drift*.24+sin(clock*.5+i)*6)
		individual.flip_h=cos(clock*.09)<0
		individual.rotation=.22+sin(clock*.7+i)*.04
		individual.visible=world.effects_enabled
