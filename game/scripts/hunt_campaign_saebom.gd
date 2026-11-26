extends RefCounted
## Pose the approved display rig from the combat actor without replacing hit or movement anchors.

const KNIFE := preload("res://scripts/duel_saebom_stone_knife.gd")
const MODEL := "res://assets/characters/campaign/saebom-short-hide.glb"
const BONES := {
	"hips": "Hips", "spine": "Spine02", "chest": "Spine", "head": "Head",
	"upper.R": "RightArm", "lower.R": "RightForeArm", "hand.R": "RightHand",
	"upper.L": "LeftArm", "lower.L": "LeftForeArm", "hand.L": "LeftHand",
	"thigh.R": "RightUpLeg", "shin.R": "RightLeg", "foot.R": "RightFoot",
	"thigh.L": "LeftUpLeg", "shin.L": "LeftLeg", "foot.L": "LeftFoot",
}

var view: HybridCharacter
var donor: Skeleton3D
var rig: Skeleton3D
var model: Node3D
var tracks: Array[Dictionary] = []
var mount: Vector3
var donor_floor: float
var donor_hips: int
var hips: int
var feet: Array[int]
var head: int
var head_front: int
var shoulders: Array[int]
var elbow: int
var wrist: int
var chest: int

func _init(actor_view: HybridCharacter) -> void:
	view = actor_view
	donor = view.skeleton
	var scene := load(MODEL) as PackedScene
	model = scene.instantiate() as Node3D
	model.name = "CampaignSaebomShortHide"
	var source_meshes := view.pivot.find_children("*", "MeshInstance3D", true, false)
	view.pivot.add_child(model)
	for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		player.active = false
	rig = model.find_children("*", "Skeleton3D", true, false)[0]
	rig.reset_bone_poses()
	head = rig.find_bone("Head")
	head_front = rig.find_bone("headfront")
	chest = rig.find_bone("Spine")
	hips = rig.find_bone("Hips")
	donor_hips = donor.find_bone("hips")
	feet = [rig.find_bone("LeftFoot"), rig.find_bone("RightFoot")]
	shoulders = [rig.find_bone("RightArm"), rig.find_bone("LeftArm")]
	elbow = rig.find_bone("RightForeArm")
	wrist = rig.find_bone("RightHand")
	var axes := (rig.get_bone_global_rest(head_front).origin - rig.get_bone_global_rest(head).origin).slide(Vector3.UP)
	model.rotation.y = -atan2(axes.x, axes.z)
	model.force_update_transform()
	var stock := _foot_center(donor, donor.find_bone("foot.L"), donor.find_bone("foot.R"))
	var fresh := _foot_center(rig, feet[0], feet[1])
	var height := _world_bone(donor, donor.find_bone("head")).y - stock.y
	model.scale *= height / (_world_bone(rig, head).y - fresh.y)
	model.force_update_transform()
	model.position = view.pivot.to_local(stock) - view.pivot.to_local(_foot_center(rig, feet[0], feet[1]))
	mount = model.position
	donor_floor = view.pivot.to_local(stock).y

	for bone in rig.get_bone_count():
		var donor_name: Variant = BONES.find_key(String(rig.get_bone_name(bone)))
		if donor_name == null:
			continue
		var source := donor.find_bone(donor_name)
		tracks.append({
			"bone": bone, "source": source, "parent": rig.get_bone_parent(bone),
			"inverse_donor_rest": _rotation(donor.get_bone_global_rest(source)).inverse(),
			"rest": _rotation(rig.get_bone_global_rest(bone)),
		})
	for mesh: MeshInstance3D in source_meshes:
		mesh.layers = 0

static func _rotation(transform: Transform3D) -> Quaternion:
	return transform.basis.orthonormalized().get_rotation_quaternion()

static func _world_bone(skeleton: Skeleton3D, index: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)

static func _foot_center(skeleton: Skeleton3D, left: int, right: int) -> Vector3:
	var a := _world_bone(skeleton, left)
	var b := _world_bone(skeleton, right)
	return Vector3((a.x + b.x) * .5, minf(a.y, b.y), (a.z + b.z) * .5)

func sync(move: String, age: float, duration: float, close_basic := false, close_skill := false, spin_clock := -1.0) -> void:
	donor.force_update_all_bone_transforms()
	rig.reset_bone_poses()
	for track in tracks:
		var rotation: Quaternion = _rotation(donor.get_bone_global_pose(track.source)) * track.inverse_donor_rest * track.rest
		if int(track.parent) >= 0:
			rotation = _rotation(rig.get_bone_global_pose(track.parent)).inverse() * rotation
		rig.set_bone_pose_rotation(track.bone, rotation.normalized())
		rig.force_update_all_bone_transforms()
	var hip_rise := donor.get_bone_pose_position(donor_hips).y - donor.get_bone_rest(donor_hips).origin.y
	rig.set_bone_pose_position(hips, rig.get_bone_rest(hips).origin + Vector3.UP * clampf(hip_rise, -.22, .22))
	rig.force_update_all_bone_transforms()
	model.position = mount
	model.force_update_transform()
	if move != "death" and not (spin_clock >= .67 and spin_clock < 1.43):
		var floor := view.pivot.to_local(_foot_center(rig, feet[0], feet[1])).y
		model.position.y += clampf(donor_floor - floor, -.14, .14)
		model.force_update_transform()
	if close_basic:
		var t := age / maxf(.01, duration) * .70
		_raise_knife(smoothstep(.13, .285, t) * (1.0 - smoothstep(.36, .59, t)), -.045)
	elif close_skill:
		_pose_close_combo(age)
	elif spin_clock >= 0.0:
		_lift_spinning_head(spin_clock)
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _steer(bone: int, from: Vector3, to: Vector3) -> void:
	if minf(from.length_squared(), to.length_squared()) < .00001:
		return
	var turn := Quaternion(from.normalized(), to.normalized())
	var basis := (rig.global_basis * rig.get_bone_global_pose(bone).basis).orthonormalized().get_rotation_quaternion()
	rig.set_bone_pose_rotation(bone, (rig.get_bone_pose_rotation(bone) * basis.inverse() * turn * basis).normalized())
	rig.force_update_all_bone_transforms()

func _raise_knife(weight: float, lift: float) -> void:
	if weight <= .001:
		return
	var shoulder := _world_bone(rig, shoulders[0])
	var joint := _world_bone(rig, elbow)
	var hand := _world_bone(rig, wrist)
	var forward := view.pivot.global_basis.z.slide(Vector3.UP).normalized()
	var outward := (shoulder - _world_bone(rig, shoulders[1])).slide(Vector3.UP).normalized()
	var length_a := shoulder.distance_to(joint)
	var length_b := joint.distance_to(hand)
	var goal := hand.lerp(shoulder + forward * (length_a + length_b) * .90 + outward * .061 + Vector3.UP * lift, weight)
	var direction := shoulder.direction_to(goal)
	var pole := (Vector3.DOWN * .82 + outward * .48).slide(direction).normalized()
	var reach := clampf(shoulder.distance_to(goal), absf(length_a - length_b) + .003, length_a + length_b - .003)
	var along := (reach * reach + length_a * length_a - length_b * length_b) / (2.0 * reach)
	var bend := direction * along + pole * sqrt(maxf(0.0, length_a * length_a - along * along))
	_steer(shoulders[0], joint - shoulder, bend)
	joint = _world_bone(rig, elbow)
	_steer(elbow, _world_bone(rig, wrist) - joint, shoulder + direction * reach - joint)
	var look := _world_bone(rig, head_front) - _world_bone(rig, head)
	_steer(head, look, look.normalized().lerp((forward + Vector3.UP * .055).normalized(), weight * .88))

func _pose_close_combo(age: float) -> void:
	var weight := 0.0
	var lift := -.045
	for i in KNIFE.contacts.size():
		var beat: float = KNIFE.contacts[i]
		weight = maxf(weight, smoothstep(beat - .112, beat - .025, age) * (1.0 - smoothstep(beat + .022, beat + .10, age)))
		if i < 3 and age >= beat - .115 and age <= beat + .085:
			lift = lerpf(-.22, .135, smoothstep(beat - .105, beat + .024, age))
	_raise_knife(weight, lift)

func _lift_spinning_head(clock: float) -> void:
	var weight := smoothstep(.67, .86, clock) * (1.0 - smoothstep(1.15, 1.43, clock))
	if weight <= .001:
		return
	var direction := (_world_bone(rig, head_front) - _world_bone(rig, head)).normalized()
	var up := Vector3.UP.slide(direction).normalized()
	_steer(head, direction, direction.rotated(direction.cross(up).normalized(), deg_to_rad(11.0) * weight))

func palm() -> Vector2:
	var hand := _world_bone(rig, wrist)
	return KNIFE.project(view, hand + (_world_bone(rig, elbow).direction_to(hand)) * .038)

func forward_screen() -> Vector2:
	var origin := _world_bone(rig, wrist)
	return (KNIFE.project(view, origin + view.pivot.global_basis.z) - KNIFE.project(view, origin)).normalized()

func wing_projection() -> Transform2D:
	var back := _world_bone(rig, chest) - view.pivot.global_basis.z.normalized() * .15 + Vector3.UP * .075
	var anchor := KNIFE.project(view, back)
	var down := KNIFE.project(view, back + Vector3.DOWN) - anchor
	var lateral := KNIFE.project(view, back + view.pivot.global_basis.x.normalized()) - anchor
	var unit := maxf(.001, down.length())
	var x := lateral / unit * 1.5
	x.y = clampf(x.y * .34, -absf(x.x) * .36, absf(x.x) * .36)
	var y := down / unit * 1.5
	return Transform2D(-x if x.cross(y) < 0.0 else x, y, anchor)

func near_wing_side(plane: Transform2D) -> float:
	var lateral := view.pivot.global_basis.x.normalized()
	var origin := _world_bone(rig, chest)
	if (KNIFE.project(view, origin + lateral) - KNIFE.project(view, origin)).dot(plane.x) < 0.0:
		lateral = -lateral
	return 1.0 if lateral.dot(view.camera.global_basis.z) > 0.0 else -1.0
