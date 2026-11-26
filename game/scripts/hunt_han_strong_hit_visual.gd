extends RefCounted
## Han display-only motions. A separate rig presents the approved poses;
## the native actor still owns the collision, skill clocks and VFX anchors.
const Timing = preload("res://scripts/motion_timing.gd")
const HEAVY: Animation = preload("res://assets/characters/han-meshy-motion/heavy-hit.res")
const BASIC: Animation = preload("res://assets/characters/han-meshy-motion/basic-first-accelerated.res")
const IDLE: Animation = preload("res://assets/characters/han-meshy-motion/battle-idle10.res")
const START := &"han_strong_hit_visual_at"
const RETREAT := NodePath("PreviewRetreat")
const PROXY := &"han_presentation_proxy"
const MOTIONS := {
	"walk": preload("res://assets/characters/han-meshy-motion/walk.res"),
	"run": preload("res://assets/characters/han-meshy-motion/run.res"),
	"skill": preload("res://assets/characters/han-meshy-motion/2sp.res"),
	"chain": preload("res://assets/characters/han-meshy-motion/3sp.res"),
	"guard": preload("res://assets/characters/han-meshy-motion/guard.res"),
}
const TIMING_NAMES := {"skill":"req047_ground_thrust","chain":"jump_spear_auto_r03","guard":"spear_guard"}

static func _render_rig(view: HybridCharacter) -> Dictionary:
	if not is_instance_valid(view) or not is_instance_valid(view.pivot) or not is_instance_valid(view.skeleton):
		return {}
	var current: Dictionary = view.get_meta(PROXY, {}) if view.has_meta(PROXY) else {}
	if is_instance_valid(current.get("pivot")) and not current.pivot.is_queued_for_deletion():
		if current.pivot.get_parent() != view.pivot.get_parent():
			current.pivot.reparent(view.pivot.get_parent(), false)
		return current
	var pivot := view.pivot.duplicate(0) as Node3D
	pivot.name = "HanApprovedPresentation"
	var rigs := pivot.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		pivot.free()
		return {}
	for mixer: AnimationMixer in pivot.find_children("*", "AnimationMixer", true, false):
		mixer.active = false
	view.pivot.get_parent().add_child(pivot)
	pivot.hide()
	# The proxy can be a sibling in the 1:1 shared viewport. Dispose it
	# even when a different hero is chosen or the scene shuts down.
	view.tree_exiting.connect(pivot.queue_free, CONNECT_ONE_SHOT)
	var source_meshes := view.pivot.find_children("*", "MeshInstance3D", true, false)
	var visible_meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in source_meshes:
		if mesh.visible:
			visible_meshes.append(mesh)
	current = {"pivot":pivot,"sk":rigs[0],"visible_meshes":visible_meshes,"active":false}
	view.set_meta(PROXY,current)
	return current

static func restore(view: HybridCharacter) -> void:
	if not is_instance_valid(view) or not view.has_meta(PROXY):
		return
	var rig: Dictionary = view.get_meta(PROXY)
	if not bool(rig.get("active", false)):
		return
	for mesh in rig.visible_meshes:
		if is_instance_valid(mesh):
			mesh.show()
	if is_instance_valid(rig.pivot):
		rig.pivot.hide()
	rig.active = false

static func _draw(view: HybridCharacter, clip: Animation, at: float, weight: float) -> void:
	if weight <= .0001 or not view.pivot.is_visible_in_tree():
		restore(view)
		return
	var rig := _render_rig(view)
	if rig.is_empty():
		return
	var pivot: Node3D = rig.pivot
	var skeleton: Skeleton3D = rig.sk
	var original: Skeleton3D = view.skeleton
	pivot.transform = view.pivot.transform
	for bone in skeleton.get_bone_count():
		var source := original.find_bone(skeleton.get_bone_name(bone))
		if source >= 0:
			skeleton.set_bone_pose_position(bone, original.get_bone_pose_position(source))
			skeleton.set_bone_pose_rotation(bone, original.get_bone_pose_rotation(source))
			skeleton.set_bone_pose_scale(bone, original.get_bone_pose_scale(source))
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if path == RETREAT:
			pivot.position += pivot.basis * clip.position_track_interpolate(track, at) * weight
		elif path.get_subname_count() == 1:
			var bone := skeleton.find_bone(path.get_subname(0))
			if bone < 0:
				continue
			match clip.track_get_type(track):
				Animation.TYPE_ROTATION_3D:
					var current := skeleton.get_bone_pose_rotation(bone)
					skeleton.set_bone_pose_rotation(bone, current.slerp(clip.rotation_track_interpolate(track, at), weight))
				Animation.TYPE_POSITION_3D:
					var current := skeleton.get_bone_pose_position(bone)
					skeleton.set_bone_pose_position(bone, current.lerp(clip.position_track_interpolate(track, at), weight))
	# Use the existing live body/camera position, not the authored planar
	# animation root, to preserve the collision-tested movement path.
	var root := skeleton.find_bone("root")
	if root >= 0:
		var raw := skeleton.get_bone_pose_position(root)
		var native_root := original.get_bone_pose_position(original.find_bone("root"))
		skeleton.set_bone_pose_position(root, Vector3(native_root.x,raw.y,native_root.z))
	skeleton.force_update_all_bone_transforms()
	for mesh in rig.visible_meshes:
		if is_instance_valid(mesh):
			mesh.hide()
	pivot.show()
	rig.active = true
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

static func _heavy(view: HybridCharacter, age: float) -> void:
	var weight := smoothstep(0.0, .035, age) * (1.0 - smoothstep(1.13, HEAVY.length, age))
	_draw(view, HEAVY, age, weight)

static func basic(view: HybridCharacter, age: float) -> void:
	_draw(view, BASIC, clampf(age, 0.0, BASIC.length), 1.0)

static func combat_idle(view: HybridCharacter, age: float) -> void:
	_draw(view, IDLE, fposmod(age, IDLE.length), 1.0)

static func display(unit: Dictionary, now: float, allow_combat: bool = false) -> void:
	var view: HybridCharacter = unit.actor.preview
	if not unit.has(START):
		if allow_combat and unit.move=="attack" and int(unit.hp)>0:
			basic(view, float(unit.age))
		elif allow_combat and unit.move=="idle" and int(unit.hp)>0:
			combat_idle(view, now)
		else:
			restore(view)
		return
	var age := now - float(unit[START])
	if age < 0.0 or age >= HEAVY.length or int(unit.hp) <= 0 or unit.move not in ["hit", "idle"]:
		unit.erase(START)
		restore(view)
		return
	_heavy(view, age)

static func duel(view: HybridCharacter, key: String, age: float, strong_age: float) -> bool:
	if strong_age >= 0.0 and strong_age < HEAVY.length and key in ["idle","hit"]:
		_heavy(view, strong_age)
		return true
	if key=="attack":
		basic(view, age)
		return false
	if key=="idle":
		combat_idle(view, age)
		return false
	var clip: Animation = MOTIONS.get(key)
	if clip == null:
		restore(view)
		return false
	var at := fposmod(age, clip.length) if key in ["walk","run"] else Timing.sample("hangyeol", TIMING_NAMES[key], age, clip.length)
	_draw(view, clip, at, 1.0)
	return false
