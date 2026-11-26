extends RefCounted
## Drives only the flower deer already in the Gahui review world. Does not
## touch hunt rules, hit points, collision envelopes, animations or save data.
const ACTIONS := ["walk", "run", "attack", "skill", "death", "hit", "heavy_hit"]
const HOOVES := ["front_foot.R", "front_foot.L", "hind_foot.R", "hind_foot.L"]
const REAR_ACTIVE := 0.48
const REAR_PAUSE := 0.50
const RAM_PLANT := 0.095
const RAM_DRIVE_END := 0.42
const RAM_TRAVEL := 2.55
const MOVE_GAP := 1.45
# Re-time only the ram's hoof contacts; warning clips and the body strike stay native.
const RAM_FRONT_LIFT := 0.096
const RAM_FRONT_LAND := 0.438
const RAM_HIND_LIFT := 0.148
const RAM_HIND_LAND := 0.328
const HEAVY_HIT_TRAVEL := 0.58
const HEAVY_HIT_APEX := 0.18
const HEAVY_HIT_RECOVER := 0.74

var actor: RefCounted
var body: Node3D
var target: Node3D
var origin := Vector3.ZERO
var rest_yaw := 0.0
var visual_scale := Vector3.ONE
var heading := Vector3.FORWARD
var path_limit := 0.0
var stride_speed := 0.0
var death_floor := 0.0
var duration := 0.0
var active_action := ""
var neutral: Array[Transform3D] = []
var ram_takeoff: PackedVector3Array
var ram_landing: PackedVector3Array

func setup(deer_actor: RefCounted, deer_body: Node3D, facing_target: Node3D) -> void:
	actor = deer_actor
	body = deer_body
	target = facing_target
	origin = body.position
	rest_yaw = actor.preview.pivot.rotation.y
	visual_scale = actor.preview.pivot.scale

func play(action: String) -> bool:
	if action not in ACTIONS or not is_instance_valid(body) or actor == null:
		return false
	active_action = action
	body.position = origin
	var to_target := (body.get_parent() as Node3D).to_local(target.global_position) - origin
	to_target.y = 0.0
	var rest_heading := Vector3(sin(rest_yaw), 0.0, cos(rest_yaw))
	heading = to_target.normalized() if to_target.length_squared() > 0.0001 else rest_heading
	if action in ["attack", "hit", "heavy_hit"]:
		heading = rest_heading
	path_limit = maxf(0.0, to_target.length() - MOVE_GAP)
	actor.preview.pivot.rotation.y = rest_yaw if action in ["attack", "hit", "heavy_hit"] else atan2(heading.x, heading.z)
	neutral.clear()
	if action in ["attack", "hit", "heavy_hit"]:
		actor.play("idle")
		actor.sample(0.0, false)
		var sk: Skeleton3D = actor.preview.skeleton
		for i in sk.get_bone_count():
			neutral.append(sk.get_bone_pose(i))
	actor.play("hit" if action == "heavy_hit" else action)
	var span: float = actor.duration
	match action:
		"walk", "run":
			var clip: String = actor.clip_for(action)
			actor.preview.start(clip)
			var stride: Vector3 = actor.preview.cycle_stride
			stride.y = 0.0
			var basis: Basis = actor.preview.skeleton.global_basis
			stride_speed = (basis * stride).length() / maxf(0.01, span)
			duration = span * 2.0
		"attack", "hit":
			duration = span * 0.83
		"heavy_hit":
			duration = HEAVY_HIT_RECOVER
		"skill":
			duration = REAR_ACTIVE + REAR_PAUSE + float(actor.preview.length("req046_skill_execute"))
			prepare_ram_contacts()
		_:
			duration = span
	if action == "death":
		actor.sample(0.0, false)
		death_floor = _floor_delta()
	sample(0.0)
	return true

func sample(seconds: float) -> bool:
	if active_action.is_empty():
		return false
	var age := clampf(seconds, 0.0, maxf(0.0, duration - 0.0001))
	var travelled := 0.0
	var native_age := age / 0.83 if active_action in ["attack", "hit"] else age
	match active_action:
		"walk", "run":
			travelled = minf(path_limit, age * stride_speed)
		"heavy_hit":
			native_age = minf(float(actor.duration) - .0001, age / duration * float(actor.duration))
			var retreat := smoothstep(0.0, HEAVY_HIT_APEX, age) * (1.0 - smoothstep(HEAVY_HIT_APEX, HEAVY_HIT_RECOVER, age))
			travelled = -HEAVY_HIT_TRAVEL * retreat if seconds < duration else 0.0
		"skill":
			var warning: float = actor.preview.length("req046_skill_anticipation")
			var execute_at := REAR_ACTIVE + REAR_PAUSE
			if age >= execute_at:
				var ram_age := age - execute_at
				native_age = warning + ram_age
				travelled = minf(path_limit, RAM_TRAVEL * smoothstep(RAM_PLANT, RAM_DRIVE_END, ram_age))
			elif age > REAR_ACTIVE:
				# The native lift and new brief pause end on the exact first
				# pose of the charge, so no freeze-frame or pose snap is added.
				native_age = lerpf(REAR_ACTIVE, warning, (age - REAR_ACTIVE) / REAR_PAUSE)
	body.position = origin + heading * travelled
	actor.sample(native_age, false)
	actor.preview.pivot.scale = visual_scale
	if not neutral.is_empty():
		var strength := 0.68 if active_action == "attack" else (0.82 if active_action == "heavy_hit" else 0.44)
		var phase := 0.0 if seconds >= duration else smoothstep(0.0, 0.08, age) * (1.0-smoothstep(duration-0.14, duration, age))
		var sk: Skeleton3D = actor.preview.skeleton
		for i in neutral.size():
			var bone_weight := strength * phase
			if active_action == "hit" and sk.get_bone_name(i) not in ["neck","head"]:
				bone_weight = 0.0
			var blended := neutral[i].interpolate_with(sk.get_bone_pose(i), bone_weight)
			sk.set_bone_pose_position(i, blended.origin)
			sk.set_bone_pose_rotation(i, blended.basis.get_rotation_quaternion())
			sk.set_bone_pose_scale(i, blended.basis.get_scale())
		if active_action == "hit" and seconds < duration:
			# Brief neck-only recoil, with the root and all hooves fixed.
			var tuck := smoothstep(0.0, 0.11, age) * (1.0 - smoothstep(0.11, 0.44, age))
			var neck := sk.find_bone("neck")
			if neck >= 0:
				sk.force_update_all_bone_transforms()
				var parent_basis := sk.get_bone_global_pose(sk.get_bone_parent(neck)).basis
				var world_to_neck_parent := (sk.global_basis * parent_basis).inverse()
				sk.set_bone_pose_position(neck, sk.get_bone_pose_position(neck) - world_to_neck_parent * heading * (0.09 * tuck))
	var offset := death_floor if active_action == "death" else _floor_delta()
	actor.preview.pivot.position.y += offset
	if active_action == "skill" and age > REAR_ACTIVE + REAR_PAUSE + RAM_FRONT_LIFT:
		plant_ram_feet(age - REAR_ACTIVE - REAR_PAUSE)
	return seconds >= duration


func world_hoof(sk: Skeleton3D, name: String) -> Vector3:
	return sk.to_global(sk.get_bone_global_pose(sk.find_bone(name)).origin)

func prepare_ram_contacts() -> void:
	var sk: Skeleton3D = actor.preview.skeleton
	var warning: float = actor.preview.length("req046_skill_anticipation")
	var execute: float = actor.preview.length("req046_skill_execute")
	ram_takeoff = PackedVector3Array()
	ram_landing = PackedVector3Array()
	body.position = origin
	actor.sample(warning + RAM_FRONT_LIFT, false)
	actor.preview.pivot.position.y += _floor_delta()
	for hoof: String in HOOVES:
		ram_takeoff.append(world_hoof(sk, hoof))
	body.position = origin + heading * minf(path_limit, RAM_TRAVEL)
	actor.sample(warning + execute - 0.0001, false)
	actor.preview.pivot.position.y += _floor_delta()
	for hoof: String in HOOVES:
		ram_landing.append(world_hoof(sk, hoof))
	body.position = origin

func plant_ram_feet(ram_age: float) -> void:
	var sk: Skeleton3D = actor.preview.skeleton
	for i in HOOVES.size():
		var hind := i >= 2
		var lift := (RAM_HIND_LIFT if hind else RAM_FRONT_LIFT) + (0.010 if i % 2 == 1 else 0.0)
		var land := (RAM_HIND_LAND if hind else RAM_FRONT_LAND) + (0.014 if i % 2 == 1 else 0.0)
		var phase := clampf((ram_age - lift) / (land - lift), 0.0, 1.0)
		var step := smoothstep(0.0, 1.0, phase)
		var wanted := ram_takeoff[i].lerp(ram_landing[i], step)
		wanted.y += (0.26 if hind else 0.22) * pow(sin(phase * PI), 1.25)
		var blend := smoothstep(RAM_FRONT_LIFT, RAM_FRONT_LIFT + .020, ram_age)
		solve_hoof(sk, sk.find_bone(HOOVES[i]), sk.to_local(world_hoof(sk, HOOVES[i]).lerp(wanted,blend)))

func solve_hoof(sk: Skeleton3D, hoof: int, goal: Vector3) -> void:
	var shin := sk.get_bone_parent(hoof)
	var upper := sk.get_bone_parent(shin)
	var a := sk.get_bone_global_pose(upper)
	var b := sk.get_bone_global_pose(shin)
	var c := sk.get_bone_global_pose(hoof)
	var ab := b.origin - a.origin
	var bc := c.origin - b.origin
	var first := ab.length()
	var second := bc.length()
	if first < 0.0001 or second < 0.0001: return
	var dir := (goal - a.origin).normalized()
	var reach := clampf(goal.distance_to(a.origin), absf(first - second) + .0001, first + second - .0001)
	var axial := (first * first - second * second + reach * reach) / (2.0 * reach)
	var pole := ab.slide(dir).normalized()
	if pole.length_squared() < 0.001: pole = Vector3(0,0,1).slide(dir).normalized()
	var knee := a.origin + dir * axial + pole * sqrt(maxf(first * first - axial * axial,0.0))
	var solved := a.origin + dir * reach
	var tilt := Basis(Quaternion(ab.normalized(), (knee - a.origin).normalized()))
	sk.set_bone_global_pose(upper, Transform3D(tilt * a.basis, a.origin))
	var shin_pose := sk.get_bone_global_pose(shin)
	var current_foot := sk.get_bone_global_pose(hoof)
	var lower := Basis(Quaternion((current_foot.origin - shin_pose.origin).normalized(),(solved - knee).normalized()))
	sk.set_bone_global_pose(shin, Transform3D(lower*shin_pose.basis, shin_pose.origin))
	var final_hoof := sk.get_bone_global_pose(hoof)
	sk.set_bone_global_pose(hoof, Transform3D(c.basis,final_hoof.origin))

func reset() -> void:
	active_action = ""
	duration = 0.0
	if not is_instance_valid(body) or actor == null:
		return
	body.position = origin
	actor.preview.pivot.rotation.y = rest_yaw
	actor.play("idle")
	actor.sample(0.0, false)
	actor.preview.pivot.position.y += _floor_delta()

func _floor_delta() -> float:
	var sk: Skeleton3D = actor.preview.skeleton
	sk.force_update_all_bone_transforms()
	var bottom := INF
	for hoof: String in HOOVES:
		var id := sk.find_bone(hoof)
		if id >= 0:
			bottom = minf(bottom, sk.to_global(sk.get_bone_global_pose(id).origin).y)
	return body.global_position.y - bottom if is_finite(bottom) else 0.0
