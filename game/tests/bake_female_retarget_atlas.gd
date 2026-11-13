extends SceneTree
## Run with the graphical Godot binary to bake the original female mesh.
const FRAME := Vector2i(96, 120)
const TARGET := "res://assets/characters/residents/female.glb"
const OUTPUT := "res://assets/characters/residents/female-retarget-atlas.png"
const TRACKS := [["walk", 12, ""], ["wood", 8, ""], ["stone", 8, ""],
	["carry", 8, "wood"], ["carry", 8, "stone"], ["carry", 8, "grain"]]
const BONES := {"spine":"spine", "upper_arm.L":"armL", "upper_arm.R":"armR",
	"forearm.L":"forearmL", "forearm.R":"forearmR", "thigh.L":"thighL",
	"thigh.R":"thighR", "shin.L":"shinL", "shin.R":"shinR", "foot.L":"footL", "foot.R":"footR"}

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var source := load(HybridCharacter.MESHY_HUNT_MODEL).instantiate() as Node3D
	var player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var source_rig := source.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var target := HybridCharacter.new()
	target.model_path = TARGET
	target.render_size_factor = .5
	root.add_child(target)
	target.set_enabled(true)
	target.ambient_allowed = false
	var load_visual := ResidentLoadVisual.new()
	load_visual.bone_name = "spine"
	target.rig.add_child(load_visual)
	var axe := target.tool_3d
	var pick := axe.duplicate() as Node3D
	axe.get_parent().add_child(pick)
	var pick_head := pick.get_child(1) as MeshInstance3D
	pick_head.scale = Vector3(.96, .33, .55)
	pick_head.rotation.z = .55
	var atlas := Image.create_empty(FRAME.x * 8, FRAME.y * 26, false, Image.FORMAT_RGBA8)
	var row := 0
	for entry: Array in TRACKS:
		var animation := player.get_animation(entry[0])
		var frames: int = entry[1]
		var cargo: String = entry[2]
		load_visual.update_load({ "kind": cargo })
		if load_visual.prop:
			load_visual.prop.scale *= .69 if cargo == "wood" else .95
		var work: bool = entry[0] in ["wood", "stone"]
		for direction in 4:
			target.pivot.rotation.y = direction * TAU / 4.0
			for frame in frames:
				var fraction := float(frame) / frames
				target.apply_pose(fraction * TAU, 0.0)
				for track in animation.get_track_count():
					if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
						continue
					var source_name := String(animation.track_get_path(track).get_subname(0))
					if not BONES.has(source_name):
						continue
					var source_index := source_rig.find_bone(source_name)
					var target_index: int = target.bones[BONES[source_name]]
					var rest := source_rig.get_bone_rest(source_index).basis.get_rotation_quaternion()
					var axis := source_rig.get_bone_global_rest(source_index).basis.get_rotation_quaternion()
					var sample := animation.rotation_track_interpolate(track, fraction * animation.length)
					var delta := axis * rest.inverse() * sample * axis.inverse()
					var strength := .66 if work else .86
					delta = Quaternion.IDENTITY.slerp(delta, strength)
					target.rig.set_bone_pose_rotation(target_index,
						target.rotation_left[target_index] * delta * target.rotation_right[target_index])
				if work:
					# Drive the striking hand toward the target; keep the other arm near the torso.
					var stroke := sin(fraction * TAU)
					target.rotate_bone("armR", Vector3(-1.28 - .76 * stroke, 0, -.15))
					target.rotate_bone("forearmR", Vector3(-.58 - .32 * stroke, 0, 0))
					target.rotate_bone("armL", Vector3(-.18, 0, .09))
					target.rotate_bone("forearmL", Vector3(-.25, 0, 0))
				elif not cargo.is_empty():
					var swing := .14 * sin(fraction * TAU)
					target.rotate_bone("spine", Vector3(.12, 0, 0))
					target.rotate_bone("armL", Vector3(swing, 0, .07))
					target.rotate_bone("armR", Vector3(-swing, 0, -.07))
					target.rotate_bone("forearmL", Vector3(-.16, 0, 0))
					target.rotate_bone("forearmR", Vector3(-.16, 0, 0))
				axe.visible = entry[0] == "wood"
				pick.visible = entry[0] == "stone"
				target.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
				await process_frame
				await RenderingServer.frame_post_draw
				var pose := target.viewport.get_texture().get_image()
				pose.convert(Image.FORMAT_RGBA8)
				pose.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_LANCZOS)
				atlas.blit_rect(pose, Rect2i(Vector2i.ZERO, FRAME), Vector2i(direction + ((row + frame) / 26) * 4, (row + frame) % 26) * FRAME)
		row += frames
	source.free()
	quit(atlas.save_png(OUTPUT))
