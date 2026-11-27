extends HybridCharacter

const MODEL := "res://assets/characters/village_han/village_han_12k.glb"
const APPROVED_GATHER := preload("res://assets/characters/village_han/han-village-approved-gather.scn")
const MOTIONS := preload("res://assets/characters/village_han/village_han_core.res")
const GATHER_CLIP := &"Village_Gather_3x"
const GATHER_SOURCE_START := 1.0
const GATHER_SECONDS := 4.0
const GATHER_FINISH_HOLD := .5
const GATHER_CONTACTS := [1.60, 2.60, 3.60]
const EDGE := Vector3(0,.5565,.236)
const FIRST_AMBIENT_IDLE := 5.25
const AMBIENT_IDLE_INTERVAL := 7.5
const AMBIENT_IDLE_BLEND := .36
var village_model: Node3D
var axe_visual: Node3D
var tracks: Dictionary = {}
var ambient_arm_corrections: Dictionary[int, Quaternion] = {}
var stride_phase := 0.0
var move_weight := 0.0
var run_weight := 0.0
var run_presentation := 0.0
var approved_gather: Node3D
var gather_player: AnimationPlayer
var gather_head: MeshInstance3D
var gather_generation := 0
var gather_running := false
var gather_finished_hold := false
var regular_camera_position := Vector3.ZERO
var regular_camera_size := 0.0

func build_villager() -> void:
	village_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	pivot.add_child(village_model)
	rig = village_model.find_children("*","Skeleton3D",true,false)[0]
	for player: AnimationPlayer in village_model.find_children("*","AnimationPlayer",true,false):
		player.active = false
	for key: StringName in MOTIONS.get_animation_list():
		var clip: Animation = MOTIONS.get_animation(key)
		var by_bone: Dictionary = {}
		for index in clip.get_track_count():
			var bone := rig.find_bone(clip.track_get_path(index).get_subname(0))
			if not by_bone.has(bone):by_bone[bone]=[-1,-1,-1]
			by_bone[bone][clip.track_get_type(index)-Animation.TYPE_POSITION_3D]=index
		tracks[key] = by_bone
	approved_gather = APPROVED_GATHER.instantiate() as Node3D
	pivot.add_child(approved_gather)
	gather_player = approved_gather.get_node("AnimationPlayer")
	axe_visual = approved_gather.get_node("GroundAnchor/StoneAxe")
	gather_head = approved_gather.find_children("*stone axe head*","MeshInstance3D",true,false)[0]
	gather_player.play(GATHER_CLIP)
	gather_player.pause()
	approved_gather.hide()
	_apply_core_pose(&"idle",0.0,0.0)
	rig.force_update_all_bone_transforms()
	for side in ["Left", "Right"]:
		_cache_ambient_arm_correction(side + "Arm", side + "ForeArm", .59)
		_cache_ambient_arm_correction(side + "ForeArm", side + "Hand", .45)
	var foot_l := rig.get_bone_global_pose(rig.find_bone("LeftFoot")).origin
	var foot_r := rig.get_bone_global_pose(rig.find_bone("RightFoot")).origin
	village_model.position.y -= minf(rig.to_global(foot_l).y,rig.to_global(foot_r).y)-.075

func _sample(key: StringName,index: int,age: float) -> Transform3D:
	var rest := rig.get_bone_rest(index)
	var clip: Animation = MOTIONS.get_animation(key)
	var ids: Array = tracks[key].get(index,[-1,-1,-1])
	var time := clampf(age,0.0,clip.length-.0001)
	var p := clip.position_track_interpolate(ids[0],time) if ids[0]>=0 else rest.origin
	var q := clip.rotation_track_interpolate(ids[1],time) if ids[1]>=0 else rest.basis.orthonormalized().get_rotation_quaternion()
	var s := clip.scale_track_interpolate(ids[2],time) if ids[2]>=0 else rest.basis.get_scale()
	return Transform3D(Basis(q).scaled_local(s),p)

func _apply_core_pose(key: StringName,age: float,weight: float) -> void:
	if key==&"idle":age=fposmod(age,MOTIONS.get_animation(key).length)
	var walk_time := fposmod(stride_phase,1.0)*maxf(.001,MOTIONS.get_animation(&"walk").length-.034)+.033
	var run_time := fposmod(stride_phase+.07,1.0)*maxf(.001,MOTIONS.get_animation(&"run").length-.034)+.033
	for index in rig.get_bone_count():
		var pose := _sample(key,index,age)
		if key==&"idle" and weight>0.0:
			pose=pose.interpolate_with(_sample(&"walk",index,walk_time),weight)
			if run_weight>.001:pose=pose.interpolate_with(_sample(&"run",index,run_time),run_weight)
		rig.set_bone_pose(index,pose)

func _cache_ambient_arm_correction(joint_name: StringName, child_name: StringName, amount: float) -> void:
	var joint := rig.find_bone(joint_name)
	var child := rig.find_bone(child_name)
	if joint < 0 or child < 0:
		return
	var pose := rig.get_bone_global_pose(joint)
	var child_origin := rig.get_bone_global_pose(child).origin
	var extended := (rig.to_global(child_origin) - rig.to_global(pose.origin)).normalized()
	var relaxed := extended.lerp(Vector3.DOWN, amount).normalized()
	var inverse_basis := (rig.global_basis * pose.basis).orthonormalized().inverse()
	var correction := Quaternion(inverse_basis * extended, inverse_basis * relaxed)
	ambient_arm_corrections[joint] = correction
	# Measure each forearm from the relaxed shoulder pose.
	rig.set_bone_pose_rotation(joint, rig.get_bone_pose_rotation(joint) * correction)
	rig.force_update_all_bone_transforms()

func _turn_idle_bone(bone: int, yaw: float, pitch: float) -> void:
	if bone < 0:
		return
	var basis := (rig.global_basis * rig.get_bone_global_pose(bone).basis).orthonormalized().inverse()
	var rotation := rig.get_bone_pose_rotation(bone)
	rig.set_bone_pose_rotation(bone, rotation * Quaternion(basis * Vector3.UP, yaw) * Quaternion(basis * Vector3.RIGHT, pitch))

func ambient_idle_phase(time: float) -> float:
	var phase := fposmod(time - FIRST_AMBIENT_IDLE, AMBIENT_IDLE_INTERVAL)
	return phase if time >= FIRST_AMBIENT_IDLE and phase < MOTIONS.get_animation(&"idle").length else -1.0

func _apply_ambient_idle(time: float) -> void:
	var phase := ambient_idle_phase(time)
	var length := MOTIONS.get_animation(&"idle").length
	var blend := 0.0
	if phase >= 0.0:
		blend = smoothstep(0.0, AMBIENT_IDLE_BLEND, phase) * (1.0 - smoothstep(length - AMBIENT_IDLE_BLEND, length, phase))
	if blend >= .999:
		_apply_core_pose(&"idle", phase, 0.0)
		return
	_apply_core_pose(&"idle", 0.0, 0.0)
	if blend > 0.0:
		for i in rig.get_bone_count():
			rig.set_bone_pose(i, rig.get_bone_pose(i).interpolate_with(_sample(&"idle", i, phase), blend))
	var relax := (1.0 - blend) * smoothstep(0.0, .20, time)
	for arm in ambient_arm_corrections:
		var correction := Quaternion.IDENTITY.slerp(ambient_arm_corrections[arm], relax)
		rig.set_bone_pose_rotation(arm, rig.get_bone_pose_rotation(arm) * correction)
	var look := deg_to_rad(21.0) * sin(TAU * time / 5.3) * (1.0 - blend)
	var raise := deg_to_rad(2.3) * sin(TAU * time / 4.8 + .3) * (1.0 - blend)
	_turn_idle_bone(rig.find_bone("neck"), look * .29, raise * .36)
	_turn_idle_bone(rig.find_bone("Head"), look * .71, raise * .64)

func on_village_activity_change(previous: String, next: String, previous_age:float) -> void:
	if previous!="gather" and next!="gather":return
	gather_generation+=1
	if next=="gather":
		gather_running=true
		gather_finished_hold=false
		_show_gather(0.0)
	elif previous_age>=GATHER_SECONDS-.06 and gather_running:
		gather_running=false
		gather_finished_hold=true
		_show_gather(GATHER_SECONDS)
		var generation := gather_generation
		get_tree().create_timer(GATHER_FINISH_HOLD).timeout.connect(func():
			if generation==gather_generation:
				gather_finished_hold=false
				_end_gather_display()
		, CONNECT_ONE_SHOT)
	else:
		gather_running=false
		gather_finished_hold=false
		_end_gather_display()

func _show_gather(action_age: float) -> void:
	if not approved_gather.visible:
		regular_camera_position=camera.position
		regular_camera_size=camera.size
		# The edited scene is already scaled by two. Normalize only its isolated
		# actor viewport, not the village camera or the animated scene transform.
		camera.position*=2.0
		camera.size*=2.0
	approved_gather.show()
	village_model.hide()
	gather_player.seek(GATHER_SOURCE_START+clampf(action_age,0.0,GATHER_SECONDS),true,true)

func _end_gather_display() -> void:
	if approved_gather.visible:
		camera.position=regular_camera_position
		camera.size=regular_camera_size
	approved_gather.hide()
	village_model.show()

func animate(delta: float,movement: Vector2,_phase: float,walking: bool,action: String,action_time: float,paused: bool) -> void:
	if not enabled or paused:return
	if movement.length_squared()>.01:target_heading=atan2(movement.x,movement.y)
	heading=lerp_angle(heading,target_heading,clampf(delta*14.0,0.0,1.0))
	pivot.rotation.y=heading
	var gathering := action=="gather"
	var working := gathering or action=="build"
	if gathering:
		_show_gather(action_time)
		work_block.hide()
		return
	if walking and gather_finished_hold:
		gather_generation+=1
		gather_finished_hold=false
		_end_gather_display()
	move_weight=move_toward(move_weight,1.0 if walking and not working else 0.0,delta*5.0)
	run_weight=move_toward(run_weight,run_presentation if walking else 0.0,delta*5.0)
	if walking:stride_phase+=delta*lerpf(.96,1.56,run_weight)
	if working:
		# Synchronize the unchanged donor joint path to the existing resource contact cadence.
		var beat := fposmod(action_time,HeroMotion.CYCLE)/HeroMotion.CYCLE
		var age := lerpf(0.0,.58235,beat*2.0) if beat<.5 else lerpf(.58235,1.0,(beat-.5)*2.0)
		_apply_core_pose(&"gather",age,0.0)
	elif not walking and idle_elapsed > 0.0 and move_weight <= .001:
		_apply_ambient_idle(idle_elapsed)
	else:
		_apply_core_pose(&"idle",0.0,move_weight)
	rig.force_update_all_bone_transforms()
	work_block.visible=action=="build"

func tool_contact_world() -> Vector2:
	var point := gather_head.to_global(EDGE)
	return display.to_global(camera.unproject_position(point))
