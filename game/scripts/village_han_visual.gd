extends HybridCharacter

const MODEL := "res://assets/characters/village_han/village_han_12k.glb"
const APPROVED_GATHER := preload("res://assets/characters/village_han/han-village-approved-gather.scn")
const MOTIONS := preload("res://assets/characters/village_han/village_han_core.res")
const QUIET_IDLE := preload("res://assets/characters/village_han/village_han_idle09.res")
const VILLAGE_GESTURES := preload("res://assets/characters/village_han/village_han_event_gestures.res")
const GESTURE_BLEND := .20
const QUIET_LOOP_BLEND := .12
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
var village_gesture: StringName
var gesture_age := 0.0
var gesture_entry_pose: Array[Transform3D] = []

func build_villager() -> void:
	village_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	pivot.add_child(village_model)
	rig = village_model.find_children("*","Skeleton3D",true,false)[0]
	for player: AnimationPlayer in village_model.find_children("*","AnimationPlayer",true,false):
		player.active = false
	var clips := MOTIONS.get_animation_list()
	clips.append("quiet_idle")
	clips.append_array(VILLAGE_GESTURES.get_animation_list())
	for key: StringName in clips:
		var clip := _core_clip(key)
		var by_bone: Dictionary = {}
		for index in clip.get_track_count():
			var bone := rig.find_bone(clip.track_get_path(index).get_subname(0))
			var channel := clip.track_get_type(index)-Animation.TYPE_POSITION_3D
			if bone < 0 or channel < 0 or channel > 2:
				continue
			if not by_bone.has(bone):by_bone[bone]=[-1,-1,-1]
			by_bone[bone][channel]=index
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
	var foot_l := rig.get_bone_global_pose(rig.find_bone("LeftFoot")).origin
	var foot_r := rig.get_bone_global_pose(rig.find_bone("RightFoot")).origin
	village_model.position.y -= minf(rig.to_global(foot_l).y,rig.to_global(foot_r).y)-.075

func _core_clip(key: StringName) -> Animation:
	if VILLAGE_GESTURES.has_animation(key):
		return VILLAGE_GESTURES.get_animation(key)
	return QUIET_IDLE if key == &"quiet_idle" else MOTIONS.get_animation(key)

func _sample(key: StringName,index: int,age: float) -> Transform3D:
	var rest := rig.get_bone_pose(index) if key == village_gesture else rig.get_bone_rest(index)
	var clip := _core_clip(key)
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
	var cycle := QUIET_IDLE.length - .001 - QUIET_LOOP_BLEND
	var quiet_time := fposmod(time, cycle)
	var loop_blend := smoothstep(0.0, QUIET_LOOP_BLEND, quiet_time)
	for joint in rig.get_bone_count():
		var pose := _sample(&"quiet_idle", joint, quiet_time)
		if time >= cycle and quiet_time < QUIET_LOOP_BLEND:
			pose = _sample(&"quiet_idle", joint, cycle + quiet_time).interpolate_with(pose, loop_blend)
		if blend > 0.0:
			pose = pose.interpolate_with(_sample(&"idle", joint, phase), blend)
		rig.set_bone_pose(joint, pose)

func play_village_gesture(gesture: StringName) -> void:
	village_gesture = gesture
	gesture_age = 0.0
	gesture_entry_pose.clear()
	for joint in rig.get_bone_count():
		gesture_entry_pose.append(rig.get_bone_pose(joint))

func _apply_village_gesture(delta: float) -> void:
	gesture_age += delta
	var duration := _core_clip(village_gesture).length
	if gesture_age >= duration:
		village_gesture = &""
		return
	var enter := smoothstep(0.0, GESTURE_BLEND, gesture_age)
	var leave := smoothstep(duration - GESTURE_BLEND, duration, gesture_age)
	for joint in rig.get_bone_count():
		var ambient := rig.get_bone_pose(joint)
		var gesture := _sample(village_gesture, joint, gesture_age)
		gesture.origin.x = ambient.origin.x
		gesture.origin.z = ambient.origin.z
		var pose := gesture_entry_pose[joint].interpolate_with(gesture, enter)
		rig.set_bone_pose(joint, pose.interpolate_with(ambient, leave))

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
	if not enabled or (paused and village_gesture == &""):return
	if movement.length_squared()>.01:target_heading=atan2(movement.x,movement.y)
	heading=lerp_angle(heading,target_heading,clampf(delta*14.0,0.0,1.0))
	pivot.rotation.y=heading
	var gathering := action=="gather"
	var working := gathering or action=="build"
	if walking or not action.is_empty() or movement.length_squared() >= .0001:
		village_gesture = &""
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
	elif village_gesture != &"":
		_apply_ambient_idle(idle_elapsed)
		_apply_village_gesture(delta)
	elif not walking and idle_elapsed > 0.0 and move_weight <= .001:
		_apply_ambient_idle(idle_elapsed)
	else:
		_apply_core_pose(&"idle",0.0,move_weight)
	rig.force_update_all_bone_transforms()
	work_block.visible=action=="build"

func tool_contact_world() -> Vector2:
	var point := gather_head.to_global(EDGE)
	return display.to_global(camera.unproject_position(point))
