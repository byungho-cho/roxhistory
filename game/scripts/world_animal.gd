class_name WorldAnimal
extends Node2D

# True 3D Meshy wildlife composited into the same feet-sorted 2D world as the hero.
# Source meshes have no walking rig: soft head/grazing deformation and breathing.
# Locomotion stays disabled until feet and joint weights are professionally rigged.
const MODELS := {
	"bear": "res://assets/animals/bear.glb",
	"rabbit": "res://assets/animals/rabbit.glb",
	"deer": "res://assets/animals/deer.glb"
}
var species := "deer"
var world_height := 120.0
var heading := 0.0
var viewport: SubViewport
var pivot: Node3D
var display: Sprite2D
var camera: Camera3D
var effects_enabled := true
var presentation_paused := false
var clock := 0.0
var frame_clock := 0.0
var render_size := 256
var motion_materials:Array[ShaderMaterial]=[]

func _ready() -> void:
	clock = position.x*0.017+position.y*0.023
	viewport = SubViewport.new()
	viewport.size = Vector2i(render_size,render_size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff0d9")
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_color = Color("fff1d1")
	sun.light_energy = 0.9
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_energy = 0.25
	scene.add_child(fill)
	pivot = Node3D.new()
	pivot.rotation.y = heading
	scene.add_child(pivot)
	var model: Node3D = load(MODELS[species]).instantiate()
	pivot.add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:Material=mesh.get_active_material(surface)
			if source is StandardMaterial3D and source.albedo_texture:
				var material:=ShaderMaterial.new();material.shader=preload("res://shaders/wildlife_motion.gdshader")
				material.set_shader_parameter("coat",source.albedo_texture)
				material.set_shader_parameter("top",mesh.mesh.get_aabb().end.y)
				mesh.set_surface_override_material(surface,material);motion_materials.append(material)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.position = Vector3(0,3.6,6)
	scene.add_child(camera)
	camera.look_at(Vector3(0,1,0))
	display = Sprite2D.new()
	display.texture = viewport.get_texture()
	display.centered = false
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(display)
	update_geometry()
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var footprint := CircleShape2D.new()
	footprint.radius = world_height*0.22
	collision.shape = footprint
	body.add_child(collision)
	add_child(body)
	queue_redraw()

func update_geometry() -> void:
	# Ground point, not image center, anchors both zoom levels and the contact shadow.
	var projected_height := absf(camera.unproject_position(Vector3(0,2,0)).y-camera.unproject_position(Vector3.ZERO).y)
	display.scale = Vector2.ONE*world_height/maxf(1,projected_height)
	display.position = -camera.unproject_position(Vector3.ZERO)*display.scale

func _process(delta: float) -> void:
	var bounds := Rect2(get_global_transform_with_canvas()*Vector2.ZERO,Vector2.ZERO).grow(world_height*3)
	var on_screen := bounds.intersects(get_viewport_rect()) and is_visible_in_tree()
	if not on_screen:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var zoom := get_canvas_transform().get_scale().x
	var desired_size := 512 if zoom > 0.8 else 256
	if desired_size != render_size:
		render_size = desired_size
		viewport.size = Vector2i(render_size,render_size)
		update_geometry()
	if effects_enabled and not presentation_paused:
		clock += delta
		# Stretch around the ground origin by less than one percent; no sliding feet.
		pivot.scale.y = 1.0+sin(clock*1.6)*0.006
		var graze:=smoothstep(.25,.65,sin(clock*.5))
		for material in motion_materials:
			material.set_shader_parameter("clock",clock)
			material.set_shader_parameter("grazing",graze)
			material.set_shader_parameter("walking",0.0)
		pivot.rotation.y=heading+sin(clock*.23)*.12
	frame_clock += delta
	if frame_clock >= 1.0/20.0:
		frame_clock = fmod(frame_clock,1.0/20.0)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _draw() -> void:
	draw_set_transform(Vector2(3,-3),0,Vector2(1,0.28))
	draw_circle(Vector2.ZERO,world_height*0.40,Color(0.17,0.14,0.10,0.17))
	draw_set_transform(Vector2.ZERO)
