class_name WorldAnimal
extends Node2D

# True 3D Meshy wildlife composited into the same feet-sorted 2D world as the hero.
# Derived meshes retain the original coat and silhouette, with editable limb skins.
const MODELS := {
	"bear": "res://assets/animals/bear-rigged.glb",
	"rabbit": "res://assets/animals/rabbit-rigged.glb",
	"deer": "res://assets/animals/deer-rigged.glb"
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
var rig:Skeleton3D
var bones:Dictionary={}
var rest_rotations:Dictionary={}
var home_position:=Vector2.ZERO
var destination:=Vector2.ZERO
var resting:=1.0
var gait_phase:=0.0
var walking:=0.0
var random:=RandomNumberGenerator.new()
var walked_distance:=0.0
var footprint_body: StaticBody2D

func _ready() -> void:
	home_position=position;destination=position;random.seed=int(position.x*100+position.y);resting=random.randf_range(.4,2.0)
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
	environment.environment.ambient_light_energy = 0.50
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_color = Color("fff1d1")
	sun.light_energy = 1.05
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color=Color("e7edda");fill.light_energy = 0.22
	scene.add_child(fill)
	pivot = Node3D.new()
	pivot.rotation.y = heading
	scene.add_child(pivot)
	var model: Node3D = load(MODELS[species]).instantiate()
	pivot.add_child(model)
	rig=model.find_children("*","Skeleton3D",true,false)[0]
	for i in rig.get_bone_count():
		bones[rig.get_bone_name(i)]=i
		rest_rotations[i]=rig.get_bone_rest(i).basis.get_rotation_quaternion()
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
	footprint_body=body
	var collision := CollisionShape2D.new()
	var footprint := CircleShape2D.new()
	footprint.radius = world_height*0.26
	collision.shape = footprint
	body.add_child(collision)
	add_child(body)
	scale=Vector2.ONE*SceneStyle.ground_scale(position.y)
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
		animate_rig(delta)
	frame_clock += delta
	if frame_clock >= 1.0/20.0:
		frame_clock = fmod(frame_clock,1.0/20.0)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _draw() -> void:
	draw_set_transform(SceneStyle.CONTACT_OFFSET,0,Vector2(1,0.28))
	draw_circle(Vector2.ZERO,world_height*0.42,Color(SceneStyle.CONTACT_COLOR,0.07))
	draw_circle(Vector2.ZERO,world_height*0.30,SceneStyle.CONTACT_COLOR)
	draw_set_transform(Vector2.ZERO)

func turn_bone(label:String,angle:Vector3)->void:
	var index:int=bones[label]
	rig.set_bone_pose_rotation(index,rest_rotations[index]*Quaternion.from_euler(angle))

func safe_ground(point:Vector2)->bool:
	if point.x<100 or point.x>2300 or point.y<100 or point.y>1250:return false
	# Northern wildlife must remain below the title/resources and above the river.
	if not VillageLayout.ground_ok(point):return false
	if Geometry2D.is_point_in_polygon(point,PackedVector2Array(DemoWorld.RIVER_POLYGON)):return false
	var world:DemoWorld=get_parent()
	if world.player and point.distance_to(world.player.position)<65:return false
	for place in DemoConfig.BUILD_SITES:
		if ((point-place+Vector2(0,24))/Vector2(160,95)).length()<1:return false
	for resource in world.model.nodes():
		if not world.exhausted(resource) and point.distance_to(DemoConfig.point(resource.position))<85:return false
	for animal in world.animals:
		if animal!=self and point.distance_to(animal.position)<55:return false
	for hut in world.environment_props:
		if hut.kind=="hut" and hut.visible and point.distance_to(hut.position+Vector2(0,-40))<180:return false
	var query:=PhysicsPointQueryParameters2D.new();query.position=point
	if footprint_body:query.exclude=[footprint_body.get_rid()]
	if not get_world_2d().direct_space_state.intersect_point(query,1).is_empty():return false
	return true

func _physics_process(delta:float)->void:
	if not effects_enabled or presentation_paused:return
	if resting>0:
		resting-=delta;walking=move_toward(walking,0,delta*4)
		if resting<=0:
			for attempt in 12:
				var next:=home_position+Vector2.from_angle(random.randf()*TAU)*random.randf_range(25,100)
				if safe_ground(next):destination=next;break
		return
	var direction:=destination-position
	if direction.length()<4:
		resting=random.randf_range(2,5);return
	var speed:=30.0 if species=="rabbit" else 22.0
	var next:=position+direction.normalized()*speed*delta
	if not safe_ground(next):resting=1;return
	var distance:=position.distance_to(next);position=next;walked_distance+=distance
	scale=Vector2.ONE*SceneStyle.ground_scale(position.y)
	gait_phase+=distance/maxf(20,world_height*.45*scale.x)*TAU
	walking=move_toward(walking,1,delta*3)
	heading=lerp_angle(heading,atan2(direction.x,direction.y),1-exp(-delta*3))

func animate_rig(_delta:float)->void:
	pivot.rotation.y=heading
	var graze:float=smoothstep(.1,.8,sin(clock*.7))*(1-walking)
	turn_bone("neck",Vector3(graze*.40,0,0))
	turn_bone("head",Vector3(graze*.22,sin(clock*.6)*.055*(1-walking),0))
	for side in ["L","R"]:
		for end in ["F","B"]:
			var offset:=0.0 if (side=="L")== (end=="F") else PI
			if species=="rabbit":offset=0.0 if end=="F" else PI*.6
			var phase:=gait_phase+offset
			var swing:=sin(phase)*.27*walking
			var bend:=maxf(0,cos(phase))*.30*walking
			turn_bone("upper"+end+side,Vector3(swing,0,0))
			turn_bone("lower"+end+side,Vector3(-bend,0,0))
			turn_bone("foot"+end+side,Vector3(-swing+bend,0,0))
	var body:int=bones.body
	var rest:Vector3=rig.get_bone_rest(body).origin
	rig.set_bone_pose_position(body,rest+Vector3(0,(maxf(0,sin(gait_phase))*.045 if species=="rabbit" else sin(gait_phase*2)*.012)*walking,0))
