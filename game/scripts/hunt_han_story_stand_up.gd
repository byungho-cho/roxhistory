extends RefCounted
## Chapter 1-3 presentation after contact and the authored slide. The ground anchor stays fixed.

const STAND_UP: Animation = preload("res://assets/characters/res050/han-stand-up7.res")
var actor
var view: HybridCharacter
var skeleton: Skeleton3D
var tracks: Array[Dictionary] = []
var hips: int
var feet: Array[int]
var idle_hips: Vector3
var idle_floor: float
var ground: Vector2
var down: Vector2
var age := 0.0

func _init(fighter, anchor: Vector2) -> void:
	actor = fighter
	view = actor.preview
	skeleton = view.skeleton
	ground = anchor
	down = view.position
	hips = skeleton.find_bone("hips")
	feet = [skeleton.find_bone("foot.L"), skeleton.find_bone("foot.R")]
	for track in STAND_UP.get_track_count():
		var bone := skeleton.find_bone(STAND_UP.track_get_path(track).get_subname(0))
		if bone >= 0:
			tracks.append({"index": track, "bone": bone, "down": skeleton.get_bone_pose_rotation(bone)})
	actor.resident_sample("idle", .3)
	skeleton.force_update_all_bone_transforms()
	idle_hips = skeleton.get_bone_pose_position(hips)
	idle_floor = _support_height()
	for track in tracks:
		track.idle = skeleton.get_bone_pose_rotation(track.bone)

func _support_height() -> float:
	return minf(skeleton.get_bone_global_pose(feet[0]).origin.y, skeleton.get_bone_global_pose(feet[1]).origin.y)

func sample(delta: float) -> bool:
	age = minf(STAND_UP.length, age + maxf(delta, 0.0))
	actor.resident_sample("idle", .3)
	var enter := smoothstep(0.0, .30, age)
	var exit := smoothstep(STAND_UP.length - .36, STAND_UP.length, age)
	var steady := smoothstep(.08, .42, age) * (1.0 - smoothstep(1.62, 2.02, age))
	for track in tracks:
		var rotation := STAND_UP.rotation_track_interpolate(track.index, age)
		var start: Quaternion = track.down
		var idle: Quaternion = track.idle
		var blended := start.slerp(rotation, enter).slerp(idle, exit)
		var name := skeleton.get_bone_name(track.bone)
		if name in ["neck", "head"]:
			var limit := deg_to_rad(15.0 if name == "neck" else 20.0)
			var distance := idle.angle_to(blended)
			if distance > limit:
				blended = blended.slerp(idle.slerp(blended, limit / distance), steady)
		skeleton.set_bone_pose_rotation(track.bone, blended)
	skeleton.set_bone_pose_position(hips, idle_hips)
	skeleton.force_update_all_bone_transforms()
	var height := clampf(idle_floor - _support_height(), -.50, .50) * enter * (1.0 - exit)
	skeleton.set_bone_pose_position(hips, idle_hips + Vector3.UP * height)
	skeleton.force_update_all_bone_transforms()
	view.position = down.lerp(ground, enter)
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return age >= STAND_UP.length
