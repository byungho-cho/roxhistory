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
	m.roughness = 0.92
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
	mesh.radial_segments = 40
	mesh.rings = 24
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
	mesh.radial_segments = 40
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
	pivot.scale=Vector3(1.08,1.0,1.02)
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
	rig.set_bone_pose_rotation(bones[label],Quaternion.from_euler(euler))

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
	var weight_shift:=maxf(0,strike)*(0.08 if work_kind=="wood" else 0.025)
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
		var foot_y := -0.52+lift+weight_shift
		var distance := minf(0.559,sqrt(foot_y*foot_y+foot_z*foot_z))
		var knee := acos(clampf((distance*distance-2*0.28*0.28)/(2*0.28*0.28),-1,1))
		var thigh := atan2(-foot_z,-foot_y)-knee*0.5
		rotate_bone("thigh"+suffix,Vector3(thigh,0,0))
		rotate_bone("shin"+suffix,Vector3(knee,0,0))
		rotate_bone("foot"+suffix,Vector3(-thigh-knee,0,0))
		var swing: float = -step*0.45
		if suffix == "R": swing = lerpf(swing,-1.25+(1.05 if work_kind == "wood" else 1.45)*strike,action_blend)
		else: swing = lerpf(swing,-0.32-strike*0.14,action_blend)
		rotate_bone("arm"+suffix,Vector3(swing,0,-side*lerpf(0.11,0.30,action_blend)))
		rotate_bone("forearm"+suffix,Vector3(lerpf(-0.15,-0.48+strike*0.22,action_blend) if suffix == "R" else -0.12-strike*0.10,0,0))

func tool_contact_world() -> Vector2:
	# Project the stone head through the same camera used to draw the character.
	var point := pivot.global_transform*rig.get_bone_global_pose(bones.handR)*tool_3d.transform*Vector3(0,0.025,0.43)
	return global_position+display.position+camera.unproject_position(point)*display.scale

func stride_world_length() -> float:
	# Stylized isometric gait: don't speed up the cadence with camera foreshortening.
	return 64.0

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
	var skin := material("f3b589")
	skin.roughness = 0.94
	var hair := material("342016")
	hair.roughness = 0.96
	var hair_mid := material("4b3227")
	var hair_glow := material("61432f")
	var cream := material("99603a")
	var trim := material("e9d3a7")
	var cloth := material("96704e")
	var rope := material("b98740")
	var leaf := material("75804b")
	var white := material("fff3df")
	var dark := material("321b12")
	var iris := material("794a28")
	bone("hips","",Vector3(0,0.77,0))
	var torso := bone("spine","hips",Vector3(0,0.23,0))
	# One softly shaped hide tunic: broad shoulders, cinched waist, folded hem.
	CharacterGeometry.profile(torso,[Vector3(-0.40,0.29,0.23),Vector3(-0.36,0.37,0.27),Vector3(-0.20,0.34,0.25),Vector3(-0.07,0.33,0.27),Vector3(0.10,0.37,0.30),Vector3(0.29,0.34,0.23),Vector3(0.38,0.22,0.18),Vector3(0.40,0.14,0.12)],cream,0.055)
	mesh_count += 1
	CharacterGeometry.profile(torso,[Vector3(-0.405,0.30,0.24),Vector3(-0.375,0.385,0.282),Vector3(-0.33,0.37,0.275)],trim,0.045)
	CharacterGeometry.profile(torso,[Vector3(0.29,0.35,0.25),Vector3(0.35,0.27,0.21),Vector3(0.40,0.15,0.13)],trim,0.025)
	mesh_count += 2
	# The hem remains one continuous surface rather than dangling bead shapes.
	lock(torso,Vector3(-0.20,0.34,0.16),Vector3(-0.10,0.12,0.27),Vector3(0.15,-0.25,0.25),0.10,0.014,Vector3.FORWARD,material("ead2a5"))
	braid(torso,-0.075,0.34,rope)
	# Small knot and two broad cord ends read at gameplay size.
	for side in [-1.0,1.0]:
		lock(torso,Vector3(0.08,-0.08,0.28),Vector3(side*0.06,-0.12,0.32),Vector3(side*0.06,-0.29,0.28),0.022,0.018,Vector3.FORWARD,rope)
	# Overlapping hide panels and leaf tie reproduce the original layered silhouette.
	for i in 11:
		var a:=TAU*i/11.0
		var n:=Vector3(sin(a),0,cos(a))
		lock(torso,n*0.29+Vector3(0,-0.10,0),n*0.37+Vector3(0,-0.29,0),n*0.34+Vector3(0,-0.45-0.045*sin(i*2.1),0),0.115,0.025,n,cream if i%3 else trim)
	for i in 3:
		lock(torso,Vector3(-0.15,-0.09,0.30),Vector3(-0.20+i*0.07,-0.21,0.34),Vector3(-0.28+i*0.11,-0.35,0.31),0.060,0.016,Vector3.FORWARD,leaf)
	for i in 14:
		var t:=float(i)/13.0
		var x:=lerpf(-0.28,0.30,t)
		var y:=lerpf(-0.02,0.35,t)
		lock(torso,Vector3(x,y+0.12,0.23),Vector3(x-0.03,y+0.035,0.33),Vector3(x-0.12,y-0.08-0.025*sin(i*4.0),0.30),0.066,0.018,Vector3.FORWARD,trim)
	for i in 9:
		var a:=TAU*i/9.0
		var n:=Vector3(sin(a),0,cos(a))
		lock(torso,n*0.32+Vector3(0,-0.22,0),n*0.40+Vector3(0,-0.35,0),n*0.36+Vector3(0,-0.50+0.035*sin(i*2.0),0),0.11,0.020,n,trim if i%3 else cloth)
	# Neck and sleeve overlap cover the joint while the continuous skin bends.
	ellipsoid(torso,Vector3(0,0.39,0),Vector3(0.25,0.21,0.24),skin)
	# Front diagonal cord, keeping the reference costume's asymmetry.
	lock(torso,Vector3(0.24,0.36,0.14),Vector3(0.04,0.15,0.29),Vector3(-0.27,-0.03,0.18),0.025,0.025,Vector3.FORWARD,rope)
	var head := bone("head","spine",Vector3(0,0.72,0))
	rig.set_bone_pose_scale(bones.head,Vector3(0.98,1.04,1.0))
	CharacterGeometry.profile(head,[Vector3(-0.45,0.06,0.08),Vector3(-0.38,0.31,0.29),Vector3(-0.23,0.47,0.40),Vector3(-0.02,0.51,0.44),Vector3(0.20,0.49,0.42),Vector3(0.38,0.34,0.31),Vector3(0.46,0.02,0.02)],skin)
	mesh_count += 1
	ellipsoid(head,Vector3(0,0.17,-0.11),Vector3(1.10,0.82,0.95),hair)
	for side in [-1.0,1.0]:
		ellipsoid(head,Vector3(side*0.49,-0.07,0.025),Vector3(0.19,0.26,0.17),skin)
		ellipsoid(head,Vector3(side*0.51,-0.075,0.105),Vector3(0.10,0.15,0.035),material("d88d6f"))
		# Large warm eyes: dark contour, cream sclera, brown iris and two glints.
		var eye := Node3D.new(); head.add_child(eye); eye.position=Vector3(side*0.205,-0.018,0.411); eye.scale=Vector3(0.88,0.90,0.32); eye_nodes.append(eye)
		ellipsoid(eye,Vector3.ZERO,Vector3(0.245,0.295,0.10),dark)
		ellipsoid(eye,Vector3(0,-0.002,0.014),Vector3(0.220,0.264,0.095),white)
		ellipsoid(eye,Vector3(side*-0.009,-0.008,0.061),Vector3(0.190,0.235,0.044),iris)
		ellipsoid(eye,Vector3(side*-0.009,0.0,0.082),Vector3(0.110,0.177,0.025),dark)
		ellipsoid(eye,Vector3(-0.029,0.053,0.097),Vector3(0.049,0.063,0.015),white)
		ellipsoid(eye,Vector3(0.028,-0.051,0.094),Vector3(0.021,0.026,0.012),white)
		lock(head,Vector3(side*0.10,0.19,0.41),Vector3(side*0.20,0.25,0.41),Vector3(side*0.39,0.20,0.37),0.025,0.018,Vector3.FORWARD,hair)
		ellipsoid(head,Vector3(side*0.32,-0.17,0.333),Vector3(0.13,0.055,0.009),material("e99b80"))
	ellipsoid(head,Vector3(0,-0.12,0.45),Vector3(0.10,0.08,0.058),skin)
	lock(head,Vector3(-0.10,-0.25,0.376),Vector3(0,-0.295,0.40),Vector3(0.10,-0.25,0.376),0.009,0.008,Vector3.FORWARD,material("8b4931"))
	# Swept locks follow the skull; slender raised ridges share each lock's curve.
	for row in 2:
		for i in 19:
			var a:=TAU*i/19.0+row*0.14+0.045*sin(i*5.2)
			if cos(a)>0.55: continue
			var n:=Vector3(sin(a),0,cos(a))
			var sweep:=Vector3(cos(a),0,-sin(a))
			var start:=n*0.26+Vector3(0,0.53-row*0.17,-0.08)
			var mid:=n*0.58+sweep*0.10+Vector3(0,0.35-row*0.19,-0.07)
			var end:=n*(0.56+0.025*sin(i*2.3))+sweep*(0.11+0.08*sin(i*1.9))+Vector3(0,-0.03-row*0.12+0.06*sin(i*2.1),-0.06)
			lock(head,start,mid,end,0.095,0.035,n,hair_mid if i%4==0 else hair)
			for line in 3:
				var offset:=sweep*(line-1)*0.026+n*0.028
				lock(head,start+offset,mid+offset,end,0.006,0.004,n,hair_mid)
	# Asymmetric swept fringe: narrow tapered tips, open forehead and eyes.
	for i in 9:
		var x:=(i-4)*0.104
		var start:=Vector3(x*0.65+0.10,0.51,0.25)
		var mid:=Vector3(x+0.11,0.37,0.49)
		var end:=Vector3(x-0.08+0.03*sin(i*2.0),0.10+0.17*absf(float(i-4)/4.0)+0.04*sin(i*2.3),0.44)
		lock(head,start,mid,end,0.090,0.032,Vector3.FORWARD,hair_mid if i%4==1 else hair)
		for line in 3:
			var offset:=Vector3((line-1)*0.022,0,0.029)
			lock(head,start+offset,mid+offset,end,0.005,0.003,Vector3.FORWARD,hair_mid)
	braid(head,0.53,0.145,rope)
	for i in 7:
		var x:=(i-3)*0.045
		lock(head,Vector3(x,0.54,-0.09),Vector3(x-0.15,0.81,-0.10),Vector3(x-0.20+0.07*sin(i*2.0),0.73+0.09*cos(i*2.1),-0.32),0.061,0.028,Vector3.UP,hair_mid if i%3==0 else hair)
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		var upper := bone("arm"+suffix,"spine",Vector3(side*0.39,0.33,0))
		CharacterGeometry.profile(upper,[Vector3(-0.18,0.12,0.13),Vector3(-0.12,0.145,0.15),Vector3(0.02,0.15,0.16),Vector3(0.08,0.04,0.05)],cream)
		mesh_count += 1
		bone("forearm"+suffix,"arm"+suffix,Vector3(side*0.045,-0.33,0))
		var forearm: Node3D=attachments["forearm"+suffix]
		cone(forearm,Vector3(0,-0.21,0),0.125,0.12,0.20,cloth)
		for band in 3:
			cone(forearm,Vector3(0,-0.135-band*0.060,0),0.13,0.13,0.023,rope).rotation.z=0.12*side
		var hand := bone("hand"+suffix,"forearm"+suffix,Vector3(0,-0.29,0.015))
		ellipsoid(hand,Vector3(0,-0.015,0),Vector3(0.25,0.26,0.23),skin)
		ellipsoid(hand,Vector3(-side*0.075,0.005,0.045),Vector3(0.09,0.13,0.10),skin)
		if suffix == "R":
			tool_3d = Node3D.new(); hand.add_child(tool_3d)
			cone(tool_3d,Vector3(0,0,0.19),0.025,0.03,0.52,material("775039")).rotation.x=PI/2
			var stone := ellipsoid(tool_3d,Vector3(0,0.025,0.43),Vector3(0.30,0.13,0.18),material("858879"))
			stone.mesh.radial_segments=7;stone.mesh.rings=3
			for band in 3:
				cone(tool_3d,Vector3(0,0,0.35+band*0.024),0.036,0.036,0.018,rope).rotation.x=PI/2
		bone("thigh"+suffix,"hips",Vector3(side*0.19,-0.07,0))
		bone("shin"+suffix,"thigh"+suffix,Vector3(0,-0.28,0))
		var foot := bone("foot"+suffix,"shin"+suffix,Vector3(0,-0.28,0))
		ellipsoid(foot,Vector3(0,-0.055,0.09),Vector3(0.29,0.22,0.43),cloth)
		cone(foot,Vector3(0,0.10,0),0.14,0.13,0.24,cloth)
		for band in 4:
			cone(foot,Vector3(0,0.02+band*0.05,0),0.148,0.148,0.025,rope).rotation.z=0.15*side
		for f in 9:
			var a:=TAU*f/9.0
			var n:=Vector3(sin(a),0,cos(a))
			lock(foot,n*0.13+Vector3(0,0.25,0),n*0.17+Vector3(0,0.23,0),n*0.17+Vector3(0,0.16,0),0.055,0.018,n,trim)
	# Continuous weighted surfaces bridge the elbows and knees with no detached balls.
	for side in [-1.0,1.0]:
		var suffix := "L" if side<0 else "R"
		skinned_limbs.append(CharacterGeometry.limb(pivot,rig,bones["arm"+suffix],bones["forearm"+suffix],Vector3(side*0.39,1.33,0),Vector3(side*0.435,1.0,0),Vector3(side*0.435,0.71,0.015),0.155,skin))
		skinned_limbs.append(CharacterGeometry.limb(pivot,rig,bones["thigh"+suffix],bones["shin"+suffix],Vector3(side*0.19,0.70,0),Vector3(side*0.19,0.42,0),Vector3(side*0.19,0.14,0),0.175,skin))
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
