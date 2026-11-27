extends HybridCharacter

const MODEL := "res://assets/characters/village_han/village_han_12k.glb"
const AXE := "res://assets/characters/village_han/village_han_axe.glb"
const MOTIONS := preload("res://assets/characters/village_han/village_han_core.res")
const SOCKET := Vector3(0,.16,0)
const EDGE := Vector3(0,.548,.232)
var village_model: Node3D
var axe_visual: Node3D
var tracks: Dictionary = {}
var idle_age := 0.0
var stride_phase := 0.0
var move_weight := 0.0
var run_weight := 0.0
var run_presentation := 0.0
var axe_hold := 0.0
var was_gathering := false
var axe_generation := 0
var right_hand := -1
var left_hand := -1

func build_villager() -> void:
	village_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	pivot.add_child(village_model)
	rig = village_model.find_children("*","Skeleton3D",true,false)[0]
	for player: AnimationPlayer in village_model.find_children("*","AnimationPlayer",true,false):
		player.active = false
	right_hand = rig.find_bone("RightHand")
	left_hand = rig.find_bone("LeftHand")
	for key: StringName in MOTIONS.get_animation_list():
		var clip: Animation = MOTIONS.get_animation(key)
		var by_bone: Dictionary = {}
		for index in clip.get_track_count():
			var bone := rig.find_bone(clip.track_get_path(index).get_subname(0))
			if not by_bone.has(bone):by_bone[bone]=[-1,-1,-1]
			by_bone[bone][clip.track_get_type(index)-Animation.TYPE_POSITION_3D]=index
		tracks[key] = by_bone
	axe_visual = Node3D.new()
	axe_visual.name = "VillageGatherStoneAxe"
	pivot.add_child(axe_visual)
	axe_visual.add_child((load(AXE) as PackedScene).instantiate())
	axe_visual.hide()
	_apply_core_pose(&"idle",0.0,0.0)
	rig.force_update_all_bone_transforms()
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

# The release follows the completed action, even if an onboarding popup pauses pose updates.
func on_village_activity_change(previous: String, next: String) -> void:
	if previous!="gather" and next!="gather":return
	axe_generation+=1
	if previous=="gather" and next!="gather":
		var generation := axe_generation
		get_tree().create_timer(.5).timeout.connect(func():
			if generation==axe_generation and is_instance_valid(axe_visual):
				axe_hold=0.0
				axe_visual.hide()
		, CONNECT_ONE_SHOT)

func animate(delta: float,movement: Vector2,_phase: float,walking: bool,action: String,action_time: float,paused: bool) -> void:
	if not enabled or paused:return
	if movement.length_squared()>.01:target_heading=atan2(movement.x,movement.y)
	heading=lerp_angle(heading,target_heading,clampf(delta*14.0,0.0,1.0))
	pivot.rotation.y=heading
	var gathering := action=="gather"
	var working := gathering or action=="build"
	move_weight=move_toward(move_weight,1.0 if walking and not working else 0.0,delta*5.0)
	run_weight=move_toward(run_weight,run_presentation if walking else 0.0,delta*5.0)
	if walking:stride_phase+=delta*lerpf(.96,1.56,run_weight)
	else:idle_age+=delta
	if working:
		# Synchronize the unchanged donor joint path to the existing resource contact cadence.
		var beat := fposmod(action_time,HeroMotion.CYCLE)/HeroMotion.CYCLE
		var age := lerpf(0.0,.58235,beat*2.0) if beat<.5 else lerpf(.58235,1.0,(beat-.5)*2.0)
		_apply_core_pose(&"gather",age,0.0)
	else:
		_apply_core_pose(&"idle",idle_age,move_weight)
	rig.force_update_all_bone_transforms()
	work_block.visible=action=="build"
	if gathering:
		_update_gather_axe(action_time)
		axe_hold=.5
		axe_visual.show()
	elif walking or working:
		axe_hold=0.0
		axe_visual.hide()
	else:
		if not was_gathering:axe_hold=maxf(0.0,axe_hold-delta)
		axe_visual.visible=axe_hold>.0001
	was_gathering=gathering

func _palm(bone:int,side:float)->Vector3:
	return rig.to_global(rig.get_bone_global_pose(bone)*Vector3(side*.8,9.6,-side*1.75))

func _update_gather_axe(seconds:float)->void:
	var right := _palm(right_hand,-1.0)
	var direction := (_palm(left_hand,1.0)-right).normalized()
	if direction.is_zero_approx():direction=Vector3.UP
	var forward := pivot.global_basis.z
	if direction.dot(forward)<-.97:direction=direction.lerp(forward,.17).normalized()
	var basis := Basis(Quaternion(Vector3.UP,direction))*Basis(Vector3.UP,PI-.16)
	var beat := fposmod(seconds,HeroMotion.CYCLE)/HeroMotion.CYCLE
	var aim := (pivot.to_global(Vector3(0,.25,.54))-right).normalized()
	var turn := Basis(Quaternion((basis*(EDGE-SOCKET)).normalized(),aim))*basis
	basis=basis.slerp(turn,smoothstep(.32,.50,beat)*(1.0-smoothstep(.52,.66,beat)))
	axe_visual.global_transform=Transform3D(basis,right-basis*SOCKET)

func tool_contact_world()->Vector2:
	return global_position+display.position+camera.unproject_position(axe_visual.to_global(EDGE))*display.scale