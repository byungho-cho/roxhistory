extends HybridCharacter

const ASSETS := "res://assets/characters/d0048/"
const CLUB_SIZE := Vector2(1.43,.53)
var variant := 0
var use_retouch := false
var extra_motions := false
var comparison_model_path := ""
var club_tilt := 0.0
var shield_push := 0.0
var counter_cover := 0.0
var animator: AnimationPlayer
var skeleton: Skeleton3D
var root_bone: int
var current_clip := ""
var hand_bone: int
var shield_bone: int
var left_hand_bone: int
var grip_in_hand: Vector3
var tip_in_hand: Vector3
var shield_anchor: Vector3
var club: MeshInstance3D
var shield: MeshInstance3D

func build_villager() -> void:
	var path := comparison_model_path
	if path.is_empty():
		path = "res://assets/characters/res050/uram-latest.glb" if use_retouch else ASSETS+"uram-warm.glb"
	var packed := load(path) as PackedScene
	var rig := packed.instantiate() as Node3D
	pivot.add_child(rig)
	animator = rig.find_children("*","AnimationPlayer",true,false)[0]
	if extra_motions:preload("res://scripts/model_motion_profile.gd").install(animator,"uram")
	skeleton = rig.find_children("*","Skeleton3D",true,false)[0]
	root_bone = skeleton.find_bone("root")
	for item in rig.find_children("*","MeshInstance3D",true,false):
		var mesh := item as MeshInstance3D
		if "club" in String(mesh.name).to_lower():
			mesh.hide()
		elif variant > 0:
			var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
			material.albedo_texture = load(ASSETS+("brown.png" if variant == 1 else "red.png"))
			mesh.set_surface_override_material(0,material)
	hand_bone = skeleton.find_bone("hand.R")
	left_hand_bone = skeleton.find_bone("hand.L")
	shield_bone = skeleton.find_bone("forearm.L")
	var inverse_hand := skeleton.get_bone_global_rest(hand_bone).affine_inverse()
	var grip := Vector3(-.423,.763,.075)
	grip_in_hand = inverse_hand * grip
	tip_in_hand = inverse_hand * (grip + Vector3(-.025,.51,1.0).normalized())
	shield_anchor = skeleton.get_bone_global_rest(shield_bone).affine_inverse() * Vector3(.47,.99,.085)
	club = make_equipment("stone-club.png",CLUB_SIZE,.35)
	shield = make_equipment("hide-shield.png",Vector2(.61,.76),.36)
	show_pose("idle",0.0)

func make_equipment(file: String, dimensions: Vector2, threshold: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ASSETS+file)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = threshold
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = dimensions
	quad.material = material
	var equipment := MeshInstance3D.new()
	equipment.mesh = quad
	pivot.add_child(equipment)
	return equipment

func clip_length(clip: String) -> float:
	return animator.get_animation(clip).length

func show_pose(clip: String, seconds: float) -> void:
	if clip != current_clip:
		current_clip = clip
		skeleton.reset_bone_poses()
		animator.play(clip,0.0)
		animator.speed_scale = 0.0
	animator.seek(clampf(seconds,0.0,clip_length(clip)),true)
	var anchor := skeleton.get_bone_pose_position(root_bone)
	var rest := skeleton.get_bone_rest(root_bone).origin
	# Offset the entire preview so skin and equipment share the same root motion
	# compensation without changing the clip's bone transforms.
	pivot.position = Vector3.ZERO if clip.begins_with("req") else -(skeleton.global_basis * Vector3(anchor.x-rest.x,0.0,anchor.z-rest.z))
	skeleton.force_update_all_bone_transforms()
	if use_retouch:
		var phase := clampf(seconds/clip_length(clip),0.0,1.0)
		var gesture := clip
		if clip=="full_motion":
			if seconds >= 216.0/60.0 and seconds <= 256.0/60.0:
				gesture = "club_attack"
				phase = (seconds*60.0-216.0)/40.0
			elif seconds >= 304.0/60.0 and seconds <= 367.0/60.0:
				gesture = "parry"
				phase = (seconds*60.0-304.0)/63.0
		club_tilt = 0.0
		shield_push = 0.0
		counter_cover = 0.0
		if gesture=="req045_shield_counter":
			counter_cover = smoothstep(.14,.27,seconds)*(1.0-smoothstep(.75,1.15,seconds))
		if gesture=="club_attack":
			club_tilt = .44*smoothstep(.32,.50,phase)*(1.0-smoothstep(.66,.88,phase))
		elif gesture=="parry":
			club_tilt = .49*smoothstep(.63,.75,phase)*(1.0-smoothstep(.82,.95,phase))
			shield_push = smoothstep(.10,.28,phase)*(1.0-smoothstep(.49,.70,phase))
	update_equipment()

func update_equipment() -> void:
	if campaign_right_shield:
		_update_campaign_right_shield()
		return
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(hand_bone)
	var grip := hand * grip_in_hand
	var axis := (hand * tip_in_hand - grip).normalized()
	if club_tilt > 0.0:
		var camera_out := camera.global_basis.z.normalized()
		var flat := axis-camera_out*axis.dot(camera_out)
		if flat.length_squared() < .025: flat += camera.global_basis.x*.22
		axis = axis.lerp(flat.normalized(),club_tilt).normalized()
	var up := camera.global_basis.z.cross(axis)
	if up.length_squared() < .001:
		up = camera.global_basis.y.cross(axis)
	up = up.normalized()
	club.global_transform = Transform3D(Basis(axis,up,axis.cross(up)),
		grip + axis * (CLUB_SIZE.x * .36) + up * (CLUB_SIZE.y * .19))
	var forearm := skeleton.global_transform * skeleton.get_bone_global_pose(shield_bone)
	var wrist := skeleton.to_global(skeleton.get_bone_global_pose(left_hand_bone).origin)
	var forward := pivot.global_basis.z.normalized()
	var toward_camera := camera.global_basis.z.normalized()
	var ratio := lerpf(.47 + shield_push*.30,.82,counter_cover)
	var normal := (toward_camera * ratio + forward * (1.0-ratio)).normalized()
	var arm := (forearm.origin - wrist).normalized()
	var right := (Vector3.UP * .72 + arm * .28).cross(normal).normalized()
	var rise := clampf((wrist.y - forearm.origin.y + .10) / .26,0.0,1.0)
	var center := forearm * shield_anchor + normal * .14 + forward * .05 + toward_camera * .075
	center.y -= lerpf(.19,.04,rise)
	if shield_push > 0.0:
		var correction := clampf((wrist-center).dot(normal)+.085,0.0,.18)
		center += (normal*correction+toward_camera*.075)*shield_push
	if counter_cover > 0.0:
		# Apply the supplied attachment correction in this actual rig's space.
		# Keep ordinary depth testing; do not force the shield on top.
		var palm := skeleton.global_transform * skeleton.get_bone_global_pose(left_hand_bone)
		var knuckles := wrist + palm.basis.y.normalized()*.13
		var face_up := normal.cross(right).normalized()
		var covered := knuckles + normal*.10 + face_up*.025
		center = center.lerp(covered,counter_cover)
	shield.global_transform = Transform3D(Basis(right,normal.cross(right),normal),center)
# Story squad only. Lab/shared-world shields deliberately retain their old mount.
var campaign_right_shield := false
var prep_shield_face_camera := false
const STORY_SHIELD_GRIP_DEPTH := .20

func enable_campaign_right_shield() -> void:
	campaign_right_shield = true
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#3a2111")
	m.roughness = .94
	var mid := Vector3(0.,0.,-STORY_SHIELD_GRIP_DEPTH)
	_story_shield_handle_segment(mid-Vector3.UP*.085,mid+Vector3.UP*.085,m)
	_story_shield_handle_segment(mid-Vector3.UP*.085,Vector3(0.,-.085,-.01),m)
	_story_shield_handle_segment(mid+Vector3.UP*.085,Vector3(0.,.085,-.01),m)
	update_equipment()

func _story_shield_handle_segment(a:Vector3,b:Vector3,m:StandardMaterial3D) -> void:
	var piece := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.height = a.distance_to(b)
	rod.top_radius = .022
	rod.bottom_radius = .022
	rod.radial_segments = 10
	piece.mesh = rod
	piece.material_override = m
	piece.position = (a+b)*.5
	piece.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	shield.add_child(piece)

func campaign_shield_grip() -> Vector3:
	var wrist := skeleton.to_global(skeleton.get_bone_global_pose(hand_bone).origin)
	var elbow := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("forearm.R")).origin)
	return wrist+(wrist-elbow).normalized()*.061

func _update_campaign_right_shield() -> void:
	var wrist := skeleton.to_global(skeleton.get_bone_global_pose(hand_bone).origin)
	var elbow := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("forearm.R")).origin)
	var arm := (wrist-elbow).normalized()
	var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm.R")).origin)
	var left := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm.L")).origin)
	var side := (shoulder-left).slide(Vector3.UP).normalized()
	var forward := pivot.global_basis.z.slide(Vector3.UP).normalized()
	var normal := (side*.65+forward*.66).normalized()
	normal = normal.lerp((side*.28+forward*.92).normalized(), maxf(shield_push,counter_cover)).normalized()
	if prep_shield_face_camera:
		var toward := camera.global_basis.z.slide(Vector3.UP).normalized()
		var delta := normal.signed_angle_to(toward,Vector3.UP)
		normal = normal.rotated(Vector3.UP,clampf(delta,-deg_to_rad(22.0),deg_to_rad(22.0)))
	var up := Vector3.UP.slide(normal).normalized()
	var fore_up := arm.slide(normal).normalized()
	if fore_up.dot(up)<0.:fore_up=-fore_up
	up=up.lerp(fore_up,.18).normalized()
	var basis := Basis(up.cross(normal).normalized(),up,normal)
	shield.global_transform = Transform3D(basis,wrist+arm*.061+normal*STORY_SHIELD_GRIP_DEPTH)
	club.hide()

func _story_bash_turn(index:int, axis:Vector3, angle:float) -> void:
	if index<0 or absf(angle)<.0001:return
	var world := skeleton.global_basis*skeleton.get_bone_global_pose(index).basis
	var local_axis := (world.orthonormalized().inverse()*axis).normalized()
	skeleton.set_bone_pose_rotation(index,(skeleton.get_bone_pose_rotation(index)*Quaternion(local_axis,angle)).normalized())
	skeleton.force_update_all_bone_transforms()

func present_campaign_shield_bash(phase:float) -> void:
	shield_push=smoothstep(.22,.54,phase)*(1.-smoothstep(.57,.87,phase))
	# Draw back first, then drive the same right hand forward at the
	# existing .54 contact. Only arm/spine rotations; feet/root stay put.
	var wind:=smoothstep(.02,.28,phase)*(1.-smoothstep(.30,.54,phase))
	var strike:=smoothstep(.30,.54,phase)*(1.-smoothstep(.58,.91,phase))
	var forward:=pivot.global_basis.z.slide(Vector3.UP).normalized()
	var axis:=Vector3.UP.cross(forward).normalized()
	_story_bash_turn(skeleton.find_bone("spine"),axis,.22*wind-.30*strike)
	_story_bash_turn(skeleton.find_bone("upper_arm.R"),axis,.52*wind-.85*strike)
	_story_bash_turn(skeleton.find_bone("forearm.R"),axis,-.16*wind+.24*strike)
	update_equipment()


# Original Skill_01 sampled at 1x. The .46 source beat is aligned with the
# unchanged gameplay contact clock; anticipation before that is planted idle.
const CAMPAIGN_ROAR_CLIP:Animation=preload("res://assets/characters/d0048/uram-roar-skill-01-upper.res")

func present_campaign_taunt_roar(age:float, action_duration:float) -> void:
	var t:=age-(action_duration*.54-CAMPAIGN_ROAR_CLIP.length*.46)
	var w:=smoothstep(0.,.15,t)*(1.-smoothstep(CAMPAIGN_ROAR_CLIP.length-.14,CAMPAIGN_ROAR_CLIP.length+.02,t))
	var hand_rest:=_campaign_bone_q(hand_bone)
	var grip:=campaign_shield_grip()
	if w>.0001:
		var clip_time:=clampf(t,0.,CAMPAIGN_ROAR_CLIP.length)
		# Skeleton parent order follows the original A/B retarget exactly.
		for i in skeleton.get_bone_count():
			var track:=CAMPAIGN_ROAR_CLIP.find_track(NodePath("Uram:"+String(skeleton.get_bone_name(i))),Animation.TYPE_ROTATION_3D)
			if track<0:continue
			var delta:=CAMPAIGN_ROAR_CLIP.rotation_track_interpolate(track,clip_time)
			var target:=delta*skeleton.get_bone_global_rest(i).basis.orthonormalized().get_rotation_quaternion()
			var parent:=skeleton.get_bone_parent(i)
			if parent>=0:target=_campaign_bone_q(parent).inverse()*target
			skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i).slerp(target.normalized(),w))
			skeleton.force_update_all_bone_transforms()
		grip=campaign_shield_grip()
	var base:=shield.global_basis.orthonormalized()
	var motion:=_campaign_bone_q(hand_bone)*hand_rest.inverse()
	var basis:=Basis(Quaternion.IDENTITY.slerp(motion.normalized(),.20))*base
	# Keep the palm fixed. During the roar the shield sits closer to the
	# forearm, with a clearer face angle from the actual campaign camera.
	var amount:=smoothstep(0.,.20,w)
	var normal:=basis.z
	var toward:=(camera.global_position-grip).slide(Vector3.UP).normalized()
	if normal.dot(toward)<0.:toward=-toward
	normal=normal.lerp(toward,.62*amount).normalized()
	var up:=basis.y.slide(normal).normalized()
	basis=Basis(up.cross(normal).normalized(),up,normal*lerpf(1.,.49,amount))
	shield.global_transform=Transform3D(basis,grip+basis.z*STORY_SHIELD_GRIP_DEPTH)
	shield.show()

func _campaign_bone_q(i:int) -> Quaternion:
	return skeleton.get_bone_global_pose(i).basis.orthonormalized().get_rotation_quaternion()
