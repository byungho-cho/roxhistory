class_name HybridCharacter
extends Node2D

# User-provided Meshy01 mesh, optimized and bound by tools/prepare_meshy_hero.py.
# Original 3D motion is retargeted through the imported bone rest orientations.
var viewport: SubViewport
var rig: Skeleton3D
var pivot: Node3D
var display: Sprite2D
var camera: Camera3D
var attachments := {}
var bones := {}
var rests := {}
var tool_3d: Node3D
var work_block: Node3D
var heading := 0.0
var target_heading := 0.0
var walk_blend := 0.0
var action_blend := 0.0
var clock := 0.0
var enabled := false
var mesh_count := 0
var skinned_limbs: Array[MeshInstance3D] = []
var eye_nodes: Array[Node3D] = []
var work_kind := "wood"
var last_action_time := 0.0

func material(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.94
	m.metallic_specular = 0.12
	var texture_path: String = "res://assets/characters/c001-textures/"+color+".png"
	if ResourceLoader.exists(texture_path):
		m.albedo_texture=load(texture_path)
		m.albedo_color=Color.WHITE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func bone(label: String, parent: String, offset: Vector3) -> Node3D:
	var index := rig.get_bone_count()
	rig.add_bone(label)
	bones[label] = index
	rests[label] = offset
	if parent != "": rig.set_bone_parent(index,bones[parent])
	rig.set_bone_rest(index,Transform3D(Basis.IDENTITY,offset))
	rig.set_bone_pose_position(index,offset)
	var attach := BoneAttachment3D.new()
	attach.name = label+"Attachment"
	attach.bone_name = label
	rig.add_child(attach)
	attachments[label] = attach
	return attach

func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 14
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = size
	parent.add_child(node)
	mesh_count += 1
	return node

func cone(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	mesh_count += 1
	return node

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "Character3DViewport"
	viewport.size = Vector2i(384,480)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0,0,0,0)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff0d9")
	env.environment.ambient_light_energy = 0.50
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_color = Color("fff1d1")
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 8.0
	sun.shadow_bias = 0.03
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color = Color("e7edda"); fill.light_energy = 0.22
	scene.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	scene.add_child(camera)
	camera.position = Vector3(0,3.6,6)
	camera.look_at(Vector3(0,1.45,0))
	pivot = Node3D.new()
	scene.add_child(pivot)
	build_villager()
	# A ground-supported piece of timber makes construction a visible task.
	# It is presentation-only, sharing the hero viewport and contact projection.
	work_block = Node3D.new(); pivot.add_child(work_block)
	cone(work_block,Vector3(0,0.5,0),0.20,0.22,1.0,material("936438"))
	cone(work_block,Vector3(0,0.998,0),0.185,0.185,0.006,material("d8ae70"))
	cone(work_block,Vector3(0,1.002,0),0.12,0.12,0.004,material("b68750"))
	cone(work_block,Vector3(0,1.005,0),0.07,0.07,0.004,material("d8ae70"))
	work_block.visible = false
	display = Sprite2D.new()
	display.name = "Rendered3DCharacter"
	display.texture = viewport.get_texture()
	display.centered = false
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.scale = Vector2.ONE*(0.70/1.5)*(384.0/viewport.size.x)
	add_child(display)
	# Project the shared ground origin: rotation never changes the 2D foot anchor.
	display.position = -camera.unproject_position(Vector3.ZERO)*display.scale
	set_enabled(false)

func set_render_zoom(factor: float) -> void:
	# Base play already downsamples the hero substantially. Reserve 4x pixels for inspection.
	# Hysteresis avoids allocation churn around a pinch threshold; projection stays identical.
	if not viewport or not display:return
	var width:=viewport.size.x
	if factor>=1.5:width=768
	elif factor<=1.25:width=384
	if viewport.size.x==width:return
	viewport.size=Vector2i(width,width*5/4)
	display.scale=Vector2.ONE*(0.70/1.5)*(384.0/width)
	display.position=-camera.unproject_position(Vector3.ZERO)*display.scale

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func rotate_bone(label: String, euler: Vector3) -> void:
	var index: int=bones[label]
	var local_rest:=rig.get_bone_rest(index).basis.orthonormalized()
	var global_rest:=rig.get_bone_global_rest(index).basis.orthonormalized()
	rig.set_bone_pose_rotation(index,(local_rest*global_rest.inverse()*Basis.from_euler(euler)*global_rest).get_rotation_quaternion())

func animate(delta: float, movement: Vector2, phase: float, walking: bool, action: String, action_time: float, paused: bool) -> void:
	if not enabled: return
	if paused:
		tool_3d.visible = false
		work_block.visible = false
		return
	if movement.length() > 0.1: target_heading = atan2(movement.x,movement.y)
	heading = lerp_angle(heading,target_heading,1.0-exp(-delta*12.0))
	pivot.rotation.y = heading
	if not paused: clock += delta
	walk_blend = move_toward(walk_blend,1.0 if walking and not paused else 0.0,delta*8.0)
	action_blend = move_toward(action_blend,1.0 if action != "" and not paused else 0.0,delta*10.0)
	# Retain the last work pose during release instead of jumping to t=0.
	if action != "": last_action_time = action_time
	var strike := HeroMotion.stroke(last_action_time)*action_blend
	if action == "build" and not work_block.visible:
		# Evaluate the fully engaged contact pose once; restore the current pose
		# below. The timber then stays on the ground throughout the stroke.
		var blend_before := action_blend
		action_blend = 1.0
		apply_pose(0,1.0)
		var hit := rig.get_bone_global_pose(bones.handR)*tool_3d.transform*Vector3(0,0.025,0.43)
		work_block.position = Vector3(hit.x,0,hit.z)
		work_block.scale.y = maxf(0.15,hit.y-0.04)
		action_blend = blend_before
	work_block.visible = action == "build"
	apply_pose(phase,strike)
	tool_3d.visible = action != "" and not paused

func apply_pose(phase: float, strike: float) -> void:
	var gait := sin(phase)*walk_blend
	var breath := sin(clock*2.3)*0.015
	var weight_shift:=maxf(0,strike)*(0.32 if work_kind=="wood" else 0.40 if work_kind=="stone" else 0.025)
	tool_3d.rotation.x=1.15*strike if work_kind=="wood" else (0.35*strike if work_kind=="stone" else 0.0)
	rig.set_bone_pose_position(bones.hips,rests.hips+Vector3(0,-0.04-weight_shift,weight_shift))
	rig.set_bone_pose_position(bones.spine,rests.spine+Vector3(0,breath*0.5,0))
	var blink := 1.0-0.94*pow(maxf(0.0,cos(clock*TAU/4.7)),80.0)
	for eye in eye_nodes: eye.scale.y = 0.88*blink
	rotate_bone("spine",Vector3(strike*0.16,sin(clock)*0.018*(1-walk_blend)+strike*0.10+gait*0.045,-gait*0.045+sin(clock*1.1)*0.012*(1-walk_blend)))
	rotate_bone("head",Vector3(-strike*0.08,sin(clock*0.7)*0.04*(1-action_blend),gait*0.02))
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		var step: float = gait*side
		var stride := HeroMotion.step(phase,side)
		var foot_z := stride.x*walk_blend-weight_shift
		var lift := stride.y*walk_blend
		var upper:float=rests["shin"+suffix].length()
		var lower:float=rests["foot"+suffix].length()
		var foot_y := -(upper+lower-.04)+lift+weight_shift
		var distance := minf(upper+lower-.001,sqrt(foot_y*foot_y+foot_z*foot_z))
		var knee := acos(clampf((distance*distance-upper*upper-lower*lower)/(2*upper*lower),-1,1))
		var thigh := atan2(-foot_z,-foot_y)-atan2(lower*sin(knee),upper+lower*cos(knee))
		rotate_bone("thigh"+suffix,Vector3(thigh,0,0))
		rotate_bone("shin"+suffix,Vector3(knee,0,0))
		rotate_bone("foot"+suffix,Vector3(-thigh-knee,0,0))
		var swing: float = -step*0.45
		if suffix == "R": swing = lerpf(swing,-1.25+(1.05 if work_kind=="wood" else 1.30 if work_kind=="stone" else 1.45)*strike,action_blend)
		else: swing = lerpf(swing,-0.32-strike*0.14,action_blend)
		rotate_bone("arm"+suffix,Vector3(swing,0,side*lerpf(-0.05,-0.30,action_blend)))
		rotate_bone("forearm"+suffix,Vector3(lerpf(-0.15,-0.48+strike*(-0.03 if work_kind=="stone" else 0.22),action_blend) if suffix == "R" else -0.12-strike*0.10,0,0))

func tool_contact_world() -> Vector2:
	# Project the stone head through the same camera used to draw the character.
	var point := pivot.global_transform*rig.get_bone_global_pose(bones.handR)*tool_3d.transform*Vector3(0,0.025,0.43)
	return global_position+display.position+camera.unproject_position(point)*display.scale

func stride_world_length() -> float:
	# Stylized isometric gait: don't speed up the cadence with camera foreshortening.
	return 64.0

func build_villager() -> void:
	var imported=preload("res://assets/characters/meshy01/hero.glb").instantiate()
	pivot.add_child(imported)
	rig=imported.find_children("*","Skeleton3D",true,false)[0]
	for i in rig.get_bone_count():
		var label:=rig.get_bone_name(i)
		bones[label]=i;rests[label]=rig.get_bone_rest(i).origin
		var attach:=BoneAttachment3D.new();attach.bone_name=label;rig.add_child(attach);attachments[label]=attach
	for mesh in imported.find_children("*","MeshInstance3D",true,false):
		mesh_count+=mesh.mesh.get_surface_count()
		if mesh.skin:skinned_limbs.append(mesh)
		for surface in mesh.mesh.get_surface_count():
			var mat:StandardMaterial3D=mesh.get_active_material(surface).duplicate()
			mat.roughness=.92;mat.metallic_specular=.12;mat.normal_scale=.22
			mesh.set_surface_override_material(surface,mat)
	tool_3d=Node3D.new();tool_3d.name="StoneAxe";attachments.handR.add_child(tool_3d)
	cone(tool_3d,Vector3(0,0,.19),.025,.03,.52,material("775039")).rotation.x=PI/2
	var stone:=ellipsoid(tool_3d,Vector3(0,.025,.43),Vector3(.30,.13,.18),material("858879"))
	stone.mesh.radial_segments=7;stone.mesh.rings=3
	for band in 3:cone(tool_3d,Vector3(0,0,.35+band*.024),.036,.036,.018,material("b98740")).rotation.x=PI/2
