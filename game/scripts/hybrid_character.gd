class_name HybridCharacter
extends Node2D

# Original procedural 3D model and skeletal motion authored for RoxHistory.
# All visible parts are volumetric meshes attached to a real Skeleton3D.
var viewport: SubViewport
var rig: Skeleton3D
var pivot: Node3D
var display: Sprite2D
var camera: Camera3D
var attachments := {}
var bones := {}
var rests := {}
var tool_3d: Node3D
var heading := 0.0
var target_heading := 0.0
var walk_blend := 0.0
var action_blend := 0.0
var clock := 0.0
var enabled := false
var mesh_count := 0

func material(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.85
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
	mesh.radial_segments = 16
	mesh.rings = 8
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
	mesh.radial_segments = 16
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	mesh_count += 1
	return node

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "Character3DViewport"
	viewport.size = Vector2i(256,320)
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
	env.environment.ambient_light_color = Color("ffe1b4")
	env.environment.ambient_light_energy = 0.4
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_color = Color("fff1d1")
	sun.light_energy = 1.35
	scene.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.15
	scene.add_child(camera)
	camera.position = Vector3(0,3.6,6)
	camera.look_at(Vector3(0,1.25,0))
	pivot = Node3D.new()
	scene.add_child(pivot)
	rig = Skeleton3D.new()
	rig.name = "VillagerSkeleton"
	pivot.add_child(rig)
	var skin := material("e7ad79")
	var hair := material("493022")
	var hair_light := material("63412b")
	var cloth := material("c99458")
	var trim := material("e6c493")
	var green := material("687345")
	var white := material("fff5db")
	var pupil := material("251c16")
	var iris := material("6d4028")
	bone("hips","",Vector3(0,0.77,0))
	var torso := bone("spine","hips",Vector3(0,0.23,0))
	cone(torso,Vector3(0,0.14,0),0.24,0.32,0.6,cloth)
	cone(torso,Vector3(0,-0.05,0),0.325,0.325,0.065,green)
	for i in 9:
		var a := TAU*i/9.0
		ellipsoid(torso,Vector3(sin(a)*0.28,-0.17,cos(a)*0.28),Vector3(0.17,0.25,0.10),trim).rotation.z = sin(a)*0.2
	ellipsoid(torso,Vector3(0,0.37,0),Vector3(0.47,0.22,0.43),trim)
	var sash := ellipsoid(torso,Vector3(0,0.18,0.245),Vector3(0.13,0.61,0.075),trim)
	sash.rotation.z = -0.55
	for i in 5:
		ellipsoid(torso,Vector3(-0.12+i*0.06,-0.055,0.319),Vector3(0.065,0.055,0.045),hair_light)
	ellipsoid(torso,Vector3(0.06,-0.14,0.31),Vector3(0.12,0.25,0.05),green).rotation.z = 0.35
	var head := bone("head","spine",Vector3(0,0.72,0))
	ellipsoid(head,Vector3.ZERO,Vector3(0.99,1.02,0.88),skin)
	ellipsoid(head,Vector3(0,0.19,-0.13),Vector3(1.05,0.86,0.88),hair)
	for side in [-1.0,1.0]:
		ellipsoid(head,Vector3(side*0.49,-0.02,0.01),Vector3(0.18,0.27,0.18),skin)
		ellipsoid(head,Vector3(side*0.195,0.025,0.409),Vector3(0.23,0.28,0.08),white)
		ellipsoid(head,Vector3(side*0.195,0.015,0.451),Vector3(0.135,0.19,0.035),iris)
		ellipsoid(head,Vector3(side*0.195,0.015,0.47),Vector3(0.075,0.13,0.02),pupil)
		ellipsoid(head,Vector3(side*0.195-0.023,0.058,0.483),Vector3(0.035,0.045,0.012),white)
		ellipsoid(head,Vector3(side*0.195,0.21,0.40),Vector3(0.24,0.055,0.055),hair).rotation.z = side*0.12
	ellipsoid(head,Vector3(0,-0.08,0.46),Vector3(0.105,0.10,0.105),skin)
	ellipsoid(head,Vector3(0,-0.225,0.412),Vector3(0.20,0.105,0.045),material("8c4836"))
	ellipsoid(head,Vector3(0,-0.25,0.439),Vector3(0.115,0.035,0.015),material("dc8a75"))
	for i in 7:
		var x := (i-3)*0.135
		var tuft := ellipsoid(head,Vector3(x,0.30+0.04*cos(i),0.31-absf(x)*0.2),Vector3(0.25,0.48,0.25),hair if i%2==0 else hair_light)
		tuft.rotation.z = -0.35+x*0.8
	cone(head,Vector3(0,0.60,-0.10),0.15,0.15,0.08,green)
	ellipsoid(head,Vector3(0.02,0.73,-0.12),Vector3(0.40,0.35,0.36),hair)
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		var upper := bone("arm"+suffix,"spine",Vector3(side*0.31,0.33,0))
		ellipsoid(upper,Vector3(side*0.035,-0.17,0),Vector3(0.22,0.43,0.23),skin)
		ellipsoid(upper,Vector3(0,-0.035,0),Vector3(0.26,0.21,0.27),trim)
		var lower := bone("forearm"+suffix,"arm"+suffix,Vector3(side*0.045,-0.33,0))
		ellipsoid(lower,Vector3(0,-0.14,0),Vector3(0.18,0.34,0.19),skin)
		var hand := bone("hand"+suffix,"forearm"+suffix,Vector3(0,-0.29,0.015))
		ellipsoid(hand,Vector3.ZERO,Vector3(0.20,0.22,0.19),skin)
		if suffix == "R":
			tool_3d = Node3D.new()
			hand.add_child(tool_3d)
			cone(tool_3d,Vector3(0,0,0.19),0.025,0.025,0.52,hair_light).rotation.x = PI/2
			ellipsoid(tool_3d,Vector3(0,0.03,0.43),Vector3(0.21,0.10,0.16),material("8b9184"))
		var thigh := bone("thigh"+suffix,"hips",Vector3(side*0.145,-0.07,0))
		ellipsoid(thigh,Vector3(0,-0.135,0),Vector3(0.23,0.34,0.25),skin)
		var shin := bone("shin"+suffix,"thigh"+suffix,Vector3(0,-0.28,0))
		ellipsoid(shin,Vector3(0,-0.15,0),Vector3(0.18,0.35,0.20),skin)
		var foot := bone("foot"+suffix,"shin"+suffix,Vector3(0,-0.28,0))
		ellipsoid(foot,Vector3(0,-0.035,0.08),Vector3(0.22,0.15,0.34),skin)
	display = Sprite2D.new()
	display.name = "Rendered3DCharacter"
	display.texture = viewport.get_texture()
	display.centered = false
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.scale = Vector2.ONE*0.53
	add_child(display)
	# Project the shared ground origin: rotation never changes the 2D foot anchor.
	display.position = -camera.unproject_position(Vector3.ZERO)*display.scale
	set_enabled(false)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func rotate_bone(label: String, euler: Vector3) -> void:
	rig.set_bone_pose_rotation(bones[label],Quaternion.from_euler(euler))

func animate(delta: float, movement: Vector2, phase: float, walking: bool, action: String, action_time: float, paused: bool) -> void:
	if not enabled: return
	if paused:
		tool_3d.visible = false
		return
	if movement.length() > 0.1: target_heading = atan2(movement.x,movement.y)
	heading = lerp_angle(heading,target_heading,1.0-exp(-delta*12.0))
	pivot.rotation.y = heading
	if not paused: clock += delta
	walk_blend = move_toward(walk_blend,1.0 if walking and not paused else 0.0,delta*8.0)
	action_blend = move_toward(action_blend,1.0 if action != "" and not paused else 0.0,delta*10.0)
	var gait := sin(phase)*walk_blend
	var strike := (0.5-0.5*cos(action_time*TAU*1.8))*action_blend
	var breath := sin(clock*2.3)*0.015
	rig.set_bone_pose_position(bones.hips,rests.hips+Vector3(0,absf(gait)*0.018+breath,0))
	rotate_bone("spine",Vector3(strike*0.15,sin(clock)*0.025+strike*0.12,-gait*0.035))
	rotate_bone("head",Vector3(-strike*0.10,sin(clock*0.7)*0.05,0))
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		var step: float = gait*side
		rotate_bone("thigh"+suffix,Vector3(step*0.48,0,0))
		rotate_bone("shin"+suffix,Vector3(maxf(0,-step)*0.58,0,0))
		rotate_bone("foot"+suffix,Vector3(-step*0.18,0,0))
		var swing: float = -step*0.45
		if suffix == "R": swing = lerpf(swing,-1.0+strike*1.25,action_blend)
		else: swing = lerpf(swing,-0.18,action_blend)
		rotate_bone("arm"+suffix,Vector3(swing,0,-side*0.11))
		rotate_bone("forearm"+suffix,Vector3(-0.15-strike*0.55 if suffix == "R" else -0.12,0,0))
	tool_3d.visible = action != "" and not paused
