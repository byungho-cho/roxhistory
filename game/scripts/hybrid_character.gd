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
var skinned_limbs: Array[MeshInstance3D] = []
var eye_nodes: Array[Node3D] = []

func material(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.86
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
	env.environment.ambient_light_color = Color("ffe1b4")
	env.environment.ambient_light_energy = 0.65
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_color = Color("fff1d1")
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 8.0
	sun.shadow_bias = 0.03
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
	build_villager()
	display = Sprite2D.new()
	display.name = "Rendered3DCharacter"
	display.texture = viewport.get_texture()
	display.centered = false
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.scale = Vector2.ONE*(0.53/1.5)
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
	rig.set_bone_pose_position(bones.hips,rests.hips+Vector3(0,-0.04,0))
	rig.set_bone_pose_position(bones.spine,rests.spine+Vector3(0,breath*0.5,0))
	var blink := 1.0-0.94*pow(maxf(0.0,cos(clock*TAU/4.7)),80.0)
	for eye in eye_nodes: eye.scale.y = 0.90*blink
	rotate_bone("spine",Vector3(strike*0.15,sin(clock)*0.025+strike*0.12,-gait*0.035))
	rotate_bone("head",Vector3(-strike*0.10,sin(clock*0.7)*0.05,0))
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		var step: float = gait*side
		var foot_z := step*0.19
		var lift := maxf(0.0,cos(phase)*side)*0.10*walk_blend
		var foot_y := -0.52+lift
		var distance := minf(0.559,sqrt(foot_y*foot_y+foot_z*foot_z))
		var knee := acos(clampf((distance*distance-2*0.28*0.28)/(2*0.28*0.28),-1,1))
		var thigh := atan2(-foot_z,-foot_y)-knee*0.5
		rotate_bone("thigh"+suffix,Vector3(thigh,0,0))
		rotate_bone("shin"+suffix,Vector3(knee,0,0))
		rotate_bone("foot"+suffix,Vector3(-thigh-knee,0,0))
		var swing: float = -step*0.45
		if suffix == "R": swing = lerpf(swing,-1.0+strike*1.25,action_blend)
		else: swing = lerpf(swing,-0.18,action_blend)
		rotate_bone("arm"+suffix,Vector3(swing,0,-side*0.11))
		rotate_bone("forearm"+suffix,Vector3(-0.15-strike*0.55 if suffix == "R" else -0.12,0,0))
	tool_3d.visible = action != "" and not paused

func lock(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, width: float, depth: float, normal: Vector3, mat: Material) -> Node3D:
	mesh_count += 1
	return CharacterGeometry.strand(parent,[a,b,c],width,depth,normal,mat)

func braid(parent: Node3D, height: float, radius: float, mat: Material) -> void:
	for strand in 2:
		for i in 24:
			var pts: Array[Vector3] = []
			for j in 3:
				var a := TAU*(i+j*0.5)/24.0
				var wave := a*12+strand*PI
				pts.append(Vector3(sin(a)*(radius+cos(wave)*0.012),height+sin(wave)*0.019,cos(a)*(radius+cos(wave)*0.012)))
			CharacterGeometry.strand(parent,pts,0.022,0.022,Vector3.UP,mat,false)
			mesh_count += 1

func build_villager() -> void:
	var skin := material("f0b184")
	var hair := material("493024")
	var hair_mid := material("60402d")
	var hair_glow := material("765035")
	var cream := material("f0d9ae")
	var cloth := material("b78857")
	var rope := material("b98740")
	var leaf := material("75804b")
	var white := material("fff3df")
	var dark := material("321b12")
	var iris := material("794a28")
	bone("hips","",Vector3(0,0.77,0))
	var torso := bone("spine","hips",Vector3(0,0.23,0))
	ellipsoid(torso,Vector3(0,0.11,0),Vector3(0.70,0.67,0.52),cream)
	cone(torso,Vector3(0,-0.15,0),0.28,0.38,0.38,cloth)
	# Layered pointed hide hem, rather than rounded beads around a cylinder.
	for i in 13:
		var a := TAU*i/13.0
		var n := Vector3(sin(a),0,cos(a))
		lock(torso,n*0.27+Vector3(0,0.04,0),n*0.36+Vector3(0,-0.14,0),n*0.38+Vector3(0,-0.39-(i%3)*0.025,0),0.095,0.028,n,cream if i%3 else cloth)
	# Soft short hide sleeves, diagonal overlapping front and rope belt.
	lock(torso,Vector3(-0.19,0.39,0.17),Vector3(-0.04,0.18,0.29),Vector3(0.22,-0.10,0.26),0.12,0.025,Vector3.FORWARD,cream)
	braid(torso,-0.065,0.31,rope)
	braid(torso,-0.125,0.325,rope)
	for side in [-1.0,1.0]:
		lock(torso,Vector3(0.02,-0.08,0.34),Vector3(side*0.12,-0.07,0.39),Vector3(side*0.08,-0.19,0.36),0.025,0.025,Vector3.FORWARD,rope)
		lock(torso,Vector3(0.02,-0.13,0.34),Vector3(side*0.09,-0.26,0.39),Vector3(side*0.11,-0.38,0.34),0.045,0.018,Vector3.FORWARD,leaf)
	# Front diagonal cord, keeping the reference costume's asymmetry.
	lock(torso,Vector3(0.24,0.36,0.14),Vector3(0.04,0.15,0.29),Vector3(-0.27,-0.03,0.18),0.025,0.025,Vector3.FORWARD,rope)
	var head := bone("head","spine",Vector3(0,0.72,0))
	ellipsoid(head,Vector3(0,-0.025,0),Vector3(1.04,0.96,0.89),skin)
	ellipsoid(head,Vector3(0,0.17,-0.11),Vector3(1.10,0.82,0.95),hair)
	for side in [-1.0,1.0]:
		ellipsoid(head,Vector3(side*0.49,-0.07,0.025),Vector3(0.19,0.26,0.17),skin)
		ellipsoid(head,Vector3(side*0.51,-0.075,0.105),Vector3(0.10,0.15,0.035),material("d88d6f"))
		# Large warm eyes: dark contour, cream sclera, brown iris and two glints.
		var eye := Node3D.new(); head.add_child(eye); eye.position=Vector3(side*0.205,-0.018,0.413); eye.scale=Vector3(0.90,0.90,0.45); eye_nodes.append(eye)
		ellipsoid(eye,Vector3.ZERO,Vector3(0.255,0.31,0.10),dark)
		ellipsoid(eye,Vector3(0,-0.002,0.014),Vector3(0.224,0.278,0.095),white)
		ellipsoid(eye,Vector3(side*-0.009,-0.008,0.061),Vector3(0.157,0.227,0.044),iris)
		ellipsoid(eye,Vector3(side*-0.009,0.0,0.082),Vector3(0.089,0.160,0.025),dark)
		ellipsoid(eye,Vector3(-0.029,0.053,0.097),Vector3(0.049,0.063,0.015),white)
		ellipsoid(eye,Vector3(0.028,-0.051,0.094),Vector3(0.021,0.026,0.012),white)
		lock(head,Vector3(side*0.10,0.19,0.41),Vector3(side*0.20,0.25,0.41),Vector3(side*0.31,0.20,0.37),0.025,0.018,Vector3.FORWARD,hair)
		ellipsoid(head,Vector3(side*0.32,-0.17,0.333),Vector3(0.14,0.055,0.018),material("e99b80"))
	ellipsoid(head,Vector3(0,-0.12,0.45),Vector3(0.105,0.075,0.09),skin)
	ellipsoid(head,Vector3(0,-0.265,0.365),Vector3(0.225,0.11,0.036),material("7b3427"))
	ellipsoid(head,Vector3(0,-0.232,0.391),Vector3(0.16,0.019,0.014),white)
	ellipsoid(head,Vector3(0,-0.286,0.383),Vector3(0.12,0.028,0.014),material("e08b78"))
	# Sculpted, tapered overlapping locks around the crown, sides and back.
	for row in 2:
		for i in 13:
			var a := TAU*i/13.0+row*0.20
			var n := Vector3(sin(a),0,cos(a))
			var front := cos(a)>0.50
			var end_y := 0.30 if front else -0.10
			end_y -= row*0.07
			var start := n*0.23+Vector3(0,0.48-row*0.12,-0.07)
			var mid := n*0.57+Vector3(0,0.37-row*0.11,-0.05)
			var end := n*0.49+Vector3(sin(a+0.8)*0.07,end_y,-0.03)
			lock(head,start,mid,end,0.15,0.065,n,[hair,hair_mid,hair_glow][i%3])
	# Swept fringe in front, with a readable pointed center lock.
	for i in 5:
		var x := (i-2)*0.17
		lock(head,Vector3(x-0.10,0.49,0.25),Vector3(x+0.12,0.43,0.51),Vector3(x-0.04,0.27-0.055*(i%2),0.43),0.14,0.065,Vector3.FORWARD,hair_mid if i%2 else hair)
	braid(head,0.58,0.16,rope)
	for i in 5:
		var a := TAU*i/5.0
		lock(head,Vector3(0,0.56,-0.08),Vector3(sin(a)*0.27,0.91,cos(a)*0.16-0.08),Vector3(sin(a)*0.30,0.86,cos(a)*0.22-0.08),0.11,0.065,Vector3(sin(a),0,cos(a)),hair_mid if i%2 else hair)
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		var upper := bone("arm"+suffix,"spine",Vector3(side*0.31,0.33,0))
		ellipsoid(upper,Vector3(side*0.02,-0.045,0),Vector3(0.27,0.22,0.28),cream)
		bone("forearm"+suffix,"arm"+suffix,Vector3(side*0.045,-0.33,0))
		var hand := bone("hand"+suffix,"forearm"+suffix,Vector3(0,-0.29,0.015))
		ellipsoid(hand,Vector3(0,-0.015,0),Vector3(0.20,0.23,0.19),skin)
		ellipsoid(hand,Vector3(-side*0.075,0.005,0.045),Vector3(0.09,0.13,0.10),skin)
		if suffix == "R":
			tool_3d = Node3D.new(); hand.add_child(tool_3d)
			cone(tool_3d,Vector3(0,0,0.19),0.025,0.03,0.52,material("775039")).rotation.x=PI/2
			ellipsoid(tool_3d,Vector3(0,0.025,0.43),Vector3(0.23,0.10,0.17),material("8b9184"))
		bone("thigh"+suffix,"hips",Vector3(side*0.145,-0.07,0))
		bone("shin"+suffix,"thigh"+suffix,Vector3(0,-0.28,0))
		var foot := bone("foot"+suffix,"shin"+suffix,Vector3(0,-0.28,0))
		ellipsoid(foot,Vector3(0,-0.065,0.07),Vector3(0.23,0.15,0.34),skin)
		for toe in 3:
			ellipsoid(foot,Vector3((toe-1)*0.058,-0.078,0.213),Vector3(0.073,0.09,0.095),skin)
	# Continuous weighted surfaces bridge the elbows and knees with no detached balls.
	for side in [-1.0,1.0]:
		var suffix := "L" if side<0 else "R"
		skinned_limbs.append(CharacterGeometry.limb(pivot,rig,bones["arm"+suffix],bones["forearm"+suffix],Vector3(side*0.31,1.36,0),Vector3(side*0.355,1.0,0),Vector3(side*0.355,0.69,0.015),0.115,skin))
		skinned_limbs.append(CharacterGeometry.limb(pivot,rig,bones["thigh"+suffix],bones["shin"+suffix],Vector3(side*0.145,0.74,0),Vector3(side*0.145,0.42,0),Vector3(side*0.145,0.12,0),0.14,skin))
		mesh_count += 2
	batch_static(rig)

func batch_static(root: Node) -> void:
	var groups := {}
	for child in root.get_children():
		if child is MeshInstance3D and child.skin == null:
			var key: int = child.material_override.get_instance_id()
			if not groups.has(key): groups[key] = []
			groups[key].append(child)
		else: batch_static(child)
	for group in groups.values():
		if group.size() < 2: continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in group: st.append_from(part.mesh,0,part.transform)
		var combined := MeshInstance3D.new()
		combined.name = "BatchedDetails"
		combined.mesh = st.commit()
		combined.material_override = group[0].material_override
		root.add_child(combined)
		for part in group: part.free()
