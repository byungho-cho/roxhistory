extends Node2D

const RESIDENT_SPRITE := preload("res://scripts/resident_sprite.gd")
const MODELS := [
	preload("res://assets/characters/resident-v02-review/female-resident-v02.glb"),
	preload("res://assets/characters/resident-v02-review/male-resident-v02.glb"),
]
var existing: Array[Sprite2D] = []
var prototypes: Array[Sprite2D] = []
var enabled := false

func _ready() -> void:
	for index in MODELS.size():
		var at := Vector2(-70 + index * 140,0)
		var reference := RESIDENT_SPRITE.new()
		reference.variant = "female" if index == 0 else "sturdy_male"
		add_child(reference)
		reference.position += at
		reference.pose(Vector2.DOWN,0,false,"",0,0,{})
		existing.append(reference)
		prototypes.append(make_prototype(MODELS[index],at,107.0*reference.scale.y))
	set_comparison(false)

func set_comparison(value: bool) -> void:
	enabled = value
	for sprite in existing: sprite.visible = not value
	for sprite in prototypes: sprite.visible = value

func make_prototype(scene: PackedScene, at: Vector2, target_height: float) -> Sprite2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	var model := scene.instantiate() as Node3D
	pivot.add_child(model)
	var corners := PackedVector3Array()
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var bounds := mesh.get_aabb()
		for index in 8:
			corners.append(mesh.global_transform * bounds.get_endpoint(index))
	var bounds := AABB(corners[0],Vector3.ZERO)
	for point in corners: bounds = bounds.expand(point)
	var foot := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	model.position -= foot
	var height := bounds.size.y
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height * 1.8
	viewport.add_child(camera)
	var focus := Vector3.UP * height*.45
	camera.position = focus + Vector3(0,2.15,6).normalized()*maxf(height*4,3.0)
	camera.look_at(focus)
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38,-25,0)
	light.light_energy = 1.0
	viewport.add_child(light)
	var lighting := WorldEnvironment.new()
	lighting.environment = Environment.new()
	lighting.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.environment.ambient_light_color = Color.WHITE
	lighting.environment.ambient_light_energy = .55
	viewport.add_child(lighting)
	var min_y := INF
	for point in corners: min_y = minf(min_y,camera.unproject_position(point-foot).y)
	var floor_pixel := camera.unproject_position(Vector3.ZERO)
	var sprite := Sprite2D.new()
	sprite.texture = viewport.get_texture()
	sprite.centered = false
	sprite.scale = Vector2.ONE * target_height / maxf(1.0,floor_pixel.y-min_y)
	sprite.position = at-floor_pixel*sprite.scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite
