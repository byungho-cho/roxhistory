class_name HybridCharacter
extends Node2D

# User-provided Meshy01 mesh, optimized and bound by tools/prepare_meshy_hero.py.
# Original 3D motion is retargeted through the imported bone rest orientations.
var model_path:="res://assets/characters/meshy01/hero.glb"
var render_size_factor:=1.0
var viewport: SubViewport
var rig: Skeleton3D
var pivot: Node3D
var display: Sprite2D
var camera: Camera3D
var attachments := {}
var bones := {}
var rests := {}
var rotation_left:Array[Quaternion]=[]
var rotation_right:Array[Quaternion]=[]
var profile_static:=OS.is_debug_build() and "--test-ui" in OS.get_cmdline_user_args() and "--profile-static-hero" in OS.get_cmdline_user_args()
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
var guard_weapon:Node3D
var last_action_time := 0.0
var idle_elapsed:=0.0
var idle_looking:=false
var ambient_allowed:=false
var ambient_offset:=0.0
var ambient_action:=""
const WALK_CLIP: Animation=preload("res://assets/characters/motion/brisk_walk_v003.tres")
const WALK_MAX_LIFT:=0.19

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
	viewport.size = Vector2i(roundi(384*render_size_factor),roundi(480*render_size_factor))
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
	display.scale = Vector2.ONE*(0.46/1.5)*(384.0/viewport.size.x)
	add_child(display)
	# Project the shared ground origin: rotation never changes the 2D foot anchor.
	display.position = -camera.unproject_position(Vector3.ZERO)*display.scale
	set_enabled(false)

func set_render_zoom(factor: float) -> void:
	# Base play already downsamples the hero substantially. Reserve 4x pixels for inspection.
	# Hysteresis avoids allocation churn around a pinch threshold; projection stays identical.
	if not viewport or not display:return
	var width:=viewport.size.x
	if factor>=1.5:width=roundi(768*render_size_factor)
	elif factor<=1.25:width=roundi(384*render_size_factor)
	if viewport.size.x==width:return
	viewport.size=Vector2i(width,width*5/4)
	display.scale=Vector2.ONE*(0.46/1.5)*(384.0/width)
	display.position=-camera.unproject_position(Vector3.ZERO)*display.scale

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func rotate_bone(label: String, euler: Vector3) -> void:
	var index: int=bones[label]
	rig.set_bone_pose_rotation(index,rotation_left[index]*Quaternion.from_euler(euler)*rotation_right[index])

func animate(delta: float, movement: Vector2, phase: float, walking: bool, action: String, action_time: float, paused: bool) -> void:
	if not enabled: return
	if profile_static and clock>0:return
	if paused:
		tool_3d.visible = false
		work_block.visible = false
		return
	if movement.length() > 0.1: target_heading = atan2(movement.x,movement.y)
	heading = lerp_angle(heading,target_heading,1.0-exp(-delta*12.0))
	pivot.rotation.y = heading
	if not paused: clock += delta
	walk_blend = move_toward(walk_blend,1.0 if walking and not paused else 0.0,delta*6.0)
	action_blend = move_toward(action_blend,1.0 if action != "" and action!="guard" and not paused else 0.0,delta*10.0)
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
	var walking_weight:=walk_blend
	if meshy_hunt_rig:
		apply_pose(phase,strike)
	else:
		walk_blend=0
		apply_pose(phase,strike)
		walk_blend=walking_weight
		apply_walk_clip(phase,walking_weight*(1.0-action_blend))
	ambient_action=""
	if action=="farm_care":apply_farm_care(action_time)
	elif action=="guard":
		blend_bone("armR",Vector3(-.8,0,-.18),1)
		blend_bone("forearmR",Vector3(-.7,0,0),1)
	elif action=="training":apply_training_pose(action_time)
	elif ambient_allowed and idle_elapsed>=1.5 and not walking and action=="":apply_ambient_idle(idle_elapsed)
	idle_looking=false
	if idle_elapsed>=2.5 and not walking and action=="" and ambient_action.is_empty():
		var t:=fposmod(idle_elapsed-2.5,14.0)
		if t<3.6:
			idle_looking=true
			var side:=1.0 if int((idle_elapsed-2.5)/14.0)%2==0 else -1.0
			var glance:=sin(t/3.6*PI)*side
			rotate_bone("head",Vector3(.025,glance*.28,0))
			rotate_bone("spine",Vector3(0,glance*.055,0))
	tool_3d.visible = action != "" and action!="farm_care" and not paused
	update_guard_weapon(action=="guard")

static func idle_gesture(elapsed:float,offset:float)->Dictionary:
	var t:=fposmod(elapsed+offset,26.0)
	for gesture in [{"kind":"yawn","start":2.0,"duration":3.5},{"kind":"stretch","start":10.0,"duration":4.0},{"kind":"doze","start":19.0,"duration":4.5}]:
		if t>=gesture.start and t<gesture.start+gesture.duration:
			return {"kind":gesture.kind,"weight":sin((t-float(gesture.start))/float(gesture.duration)*PI)}
	return {"kind":"","weight":0.0}
func blend_bone(label:String,euler:Vector3,weight:float)->void:
	var index:int=bones[label]
	var target:Quaternion=rotation_left[index]*Quaternion.from_euler(euler)*rotation_right[index]
	rig.set_bone_pose_rotation(index,rig.get_bone_pose_rotation(index).slerp(target,weight))
func apply_ambient_idle(elapsed:float)->void:
	var state:=idle_gesture(elapsed,ambient_offset);ambient_action=state.kind;var weight:float=state.weight
	match ambient_action:
		"yawn":
			blend_bone("armR",Vector3(-1.35,.15,-.18),weight);blend_bone("forearmR",Vector3(-1.7,0,.1),weight);blend_bone("head",Vector3(-.13,0,.05),weight)
		"stretch":
			for side in [-1,1]:
				var suffix:="L" if side<0 else "R"
				blend_bone("arm"+suffix,Vector3(-2.3,0,side*.65),weight);blend_bone("forearm"+suffix,Vector3(-.25,0,0),weight)
			blend_bone("spine",Vector3(-.15,0,0),weight);blend_bone("head",Vector3(-.2,0,0),weight)
		"doze":
			blend_bone("head",Vector3(.36,0,.09*sin(elapsed*1.8)),weight);blend_bone("spine",Vector3(.12,0,0),weight)
			for eye in eye_nodes:eye.scale.y*=1-.85*weight
func apply_training_pose(seconds:float)->void:
	var beat:float=pow(maxf(0,sin(seconds*TAU/2.2)),2)
	blend_bone("spine",Vector3(.03+beat*.1,-.15+beat*.24,0),1)
	blend_bone("armR",Vector3(-1.1+beat*.35,0,-.15),1);blend_bone("forearmR",Vector3(-1.0+beat*.9,0,0),1)
	blend_bone("armL",Vector3(-.7,0,.2),1);blend_bone("forearmL",Vector3(-.9,0,0),1)
	blend_bone("head",Vector3(-.05,.1,0),1)
func use_training_spear()->void:
	for child in tool_3d.get_children():child.queue_free()
	tool_3d.name="TrainingSpear"
	if meshy_hunt_rig:tool_3d.scale = Vector3.ONE / MESHY_HUNT_SCALE
	cone(tool_3d,Vector3(0,0,.48),.018,.022,1.15,material("775039")).rotation.x=PI/2
	cone(tool_3d,Vector3(0,0,1.13),0,.075,.23,material("b0b3a2")).rotation.x=PI/2

func apply_pose(phase: float, strike: float) -> void:
	var gait := sin(phase)*walk_blend
	var breath := sin(clock*2.3)*0.015
	var hip_drop:=.04+.07*walk_blend
	var weight_shift:=maxf(0,strike)*(0.32 if work_kind=="wood" else 0.40 if work_kind=="stone" else 0.025)
	tool_3d.rotation.x=1.15*strike if work_kind=="wood" else (0.35*strike if work_kind=="stone" else 0.0)
	rig.set_bone_pose_position(bones.hips,rests.hips+Vector3(0,-hip_drop-weight_shift,weight_shift))
	rig.set_bone_pose_position(bones.spine,rests.spine+Vector3(0,breath*0.5,0))
	var blink := 1.0-0.94*pow(maxf(0.0,cos(clock*TAU/4.7)),80.0)
	for eye in eye_nodes: eye.scale.y = 0.88*blink
	rotate_bone("spine",Vector3(strike*0.16,sin(clock)*0.018*(1-walk_blend)+strike*0.10+gait*0.025,-gait*0.006+sin(clock*1.1)*0.009*(1-walk_blend)))
	rotate_bone("head",Vector3(-strike*0.08,sin(clock*0.7)*0.04*(1-action_blend),gait*0.01))
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		var step: float = gait*side
		var stride := HeroMotion.step(phase,side)
		var foot_z := stride.x*walk_blend-weight_shift
		var lift := stride.y*walk_blend
		var upper:float=rests["shin"+suffix].length()
		var lower:float=rests["foot"+suffix].length()
		var foot_y := -(upper+lower-hip_drop)+lift+weight_shift
		var distance := minf(upper+lower-.001,sqrt(foot_y*foot_y+foot_z*foot_z))
		var knee := acos(clampf((distance*distance-upper*upper-lower*lower)/(2*upper*lower),-1,1))
		var thigh := atan2(-foot_z,-foot_y)-atan2(lower*sin(knee),upper+lower*cos(knee))
		rotate_bone("thigh"+suffix,Vector3(thigh,0,0))
		rotate_bone("shin"+suffix,Vector3(knee,0,0))
		rotate_bone("foot"+suffix,Vector3(-thigh-knee,0,0))
		var swing: float = -step*0.34
		if suffix == "R": swing = lerpf(swing,-1.25+(1.05 if work_kind=="wood" else 1.30 if work_kind=="stone" else 1.45)*strike,action_blend)
		else: swing = lerpf(swing,-0.32-strike*0.14,action_blend)
		rotate_bone("arm"+suffix,Vector3(swing,0,side*lerpf(-0.05,-0.30,action_blend)))
		rotate_bone("forearm"+suffix,Vector3(lerpf(-0.15,-0.48+strike*(-0.03 if work_kind=="stone" else 0.22),action_blend) if suffix == "R" else -0.12-strike*0.10,0,0))

func apply_walk_clip(phase:float,weight:float)->void:
	if weight<=0:return
	var t:=fposmod(phase/TAU,1.0)*WALK_CLIP.length
	for track in WALK_CLIP.get_track_count():
		var label:=str(WALK_CLIP.track_get_path(track).get_subname(0))
		var index:int=bones[label]
		if WALK_CLIP.track_get_type(track)==Animation.TYPE_ROTATION_3D:
			rig.set_bone_pose_rotation(index,rig.get_bone_pose_rotation(index).slerp(WALK_CLIP.rotation_track_interpolate(track,t),weight))
		else:
			rig.set_bone_pose_position(index,rig.get_bone_pose_position(index).lerp(WALK_CLIP.position_track_interpolate(track,t),weight))

func tool_contact_world() -> Vector2:
	# Project the stone head through the same camera used to draw the character.
	var point := pivot.global_transform*rig.get_bone_global_pose(bones.handR)*tool_3d.transform*Vector3(0,0.025,0.43)
	return global_position+display.position+camera.unproject_position(point)*display.scale

func stride_world_length() -> float:
	# Stylized isometric gait: don't speed up the cadence with camera foreshortening.
	return 104.0

var meshy_hunt_rig := false
const MESHY_HUNT_SCALE := 1.58
const MESHY_HUNT_MODEL := "res://assets/characters/residents/female-meshy6k-hunt.glb"
const MESHY_BONE_NAMES := {"pelvis":"hips", "upper_arm":"arm"}
const MESHY_OUTFIT := preload("res://shaders/meshy_hunt_outfit.gdshader")

func build_villager() -> void:
	var imported: Node3D = load(model_path).instantiate()
	meshy_hunt_rig = model_path == MESHY_HUNT_MODEL
	if meshy_hunt_rig:imported.scale = Vector3.ONE * MESHY_HUNT_SCALE
	pivot.add_child(imported)
	if OS.is_debug_build() and "--test-ui" in OS.get_cmdline_user_args() and "--profile-no-hero" in OS.get_cmdline_user_args():imported.visible=false
	rig=imported.find_children("*","Skeleton3D",true,false)[0]
	for i in rig.get_bone_count():
		var label := String(rig.get_bone_name(i))
		if meshy_hunt_rig:
			var base := label.get_slice(".", 0)
			label = String(MESHY_BONE_NAMES.get(base, base)) + (label.get_slice(".", 1) if "." in label else "")
		bones[label]=i;rests[label]=rig.get_bone_rest(i).origin
		var local_rest:=rig.get_bone_rest(i).basis.orthonormalized()
		var global_rest:=rig.get_bone_global_rest(i).basis.orthonormalized()
		rotation_left.append((local_rest*global_rest.inverse()).get_rotation_quaternion());rotation_right.append(global_rest.get_rotation_quaternion())
		if label=="handR":
			var attach:=BoneAttachment3D.new();attach.bone_name=rig.get_bone_name(i);rig.add_child(attach);attachments[label]=attach
	for mesh in imported.find_children("*","MeshInstance3D",true,false):
		mesh_count+=mesh.mesh.get_surface_count()
		if mesh.skin:skinned_limbs.append(mesh)
		for surface in mesh.mesh.get_surface_count():
			var source_material: StandardMaterial3D = mesh.get_active_material(surface)
			var mat: StandardMaterial3D = source_material.duplicate()
			mat.roughness=.92;mat.metallic_specular=.12;mat.normal_scale=.22
			if meshy_hunt_rig:
				match source_material.resource_name:
					"hair": mat.albedo_color = Color("27232b")
					"skin": mat.albedo_color = Color("e7a478")
					"hide":
						var outfit := ShaderMaterial.new()
						outfit.shader = MESHY_OUTFIT
						mesh.set_surface_override_material(surface, outfit)
						continue
			mesh.set_surface_override_material(surface,mat)
	tool_3d=Node3D.new();tool_3d.name="StoneAxe";attachments.handR.add_child(tool_3d)
	cone(tool_3d,Vector3(0,0,.19),.025,.03,.52,material("775039")).rotation.x=PI/2
	var stone:=ellipsoid(tool_3d,Vector3(0,.025,.43),Vector3(.30,.13,.18),material("858879"))
	stone.mesh.radial_segments=7;stone.mesh.rings=3
	for band in 3:cone(tool_3d,Vector3(0,0,.35+band*.024),.036,.036,.018,material("b98740")).rotation.x=PI/2


func apply_farm_care(seconds:float)->void:
	var weight:=pow(maxf(0,sin(seconds*TAU/4.5)),2)
	blend_bone("spine",Vector3(.08+weight*.35,0,0),1)
	blend_bone("head",Vector3(.12+weight*.15,0,0),1)
	blend_bone("armR",Vector3(-.35-weight*.65,0,-.18),1)
	blend_bone("armL",Vector3(-.2-weight*.45,0,.18),1)
	blend_bone("forearmR",Vector3(-.5-weight*.35,0,0),1)
func update_guard_weapon(active:bool)->void:
	if active and guard_weapon==null:
		guard_weapon=Node3D.new();guard_weapon.name="GuardSpear";tool_3d.add_child(guard_weapon)
		cone(guard_weapon,Vector3(0,0,.48),.018,.022,1.15,material("775039")).rotation.x=PI/2
		cone(guard_weapon,Vector3(0,0,1.13),0,.075,.23,material("b0b3a2")).rotation.x=PI/2
	for child in tool_3d.get_children():
		if child is Node3D:child.visible=active if child==guard_weapon else not active
