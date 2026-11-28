extends SceneTree
## Run with the game project and pass the RES-053 source directory and atlas output path after --.

const FRAME := Vector2i(112, 104)
const FLOOR := Vector2i(56, 89)
const COLUMNS := 8
const SAMPLES := 32
const PRACTICE_SECONDS := 2.2
const SPEAR_SCALE := 1.5
const JOINTS := {
	"spine":"Spine", "head":"Head", "armL":"LeftArm", "armR":"RightArm",
	"forearmL":"LeftForeArm", "forearmR":"RightForeArm", "handL":"LeftHand", "handR":"RightHand",
}

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var legacy := HybridCharacter.new()
	legacy.model_path = "res://assets/characters/residents/sturdy_male.glb"
	root.add_child(legacy)
	legacy.set_enabled(true)
	legacy.use_training_spear()
	legacy.hide()
	legacy.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Match the resident atlas camera, lighting, and logical pixels per metre.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 280)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var source_world := legacy.viewport.get_child(0)
	for child in source_world.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			world.add_child(child.duplicate())
	var camera := (legacy.camera.duplicate() as Camera3D)
	camera.size = 3.0 * viewport.size.y / 200.0
	world.add_child(camera)
	var crop := Rect2i(Vector2i(camera.unproject_position(Vector3.ZERO).round()) - FLOOR * 2, FRAME * 2)
	var atlas := Image.create_empty(FRAME.x * COLUMNS, FRAME.y * SAMPLES * 2 / COLUMNS, false, Image.FORMAT_RGBA8)
	for index in 2:
		var facing := "right" if index == 0 else "left"
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(args[0].path_join("Resident-Man-01-11.glb"), state)
		if error != OK:
			quit(error)
			return
		var model := doc.generate_scene(state) as Node3D
		world.add_child(model)
		var travel := model.get_node("Travel") as Node3D
		var player := model.get_node("AnimationPlayer") as AnimationPlayer
		var rig := model.find_child("Skeleton3D", true, false) as Skeleton3D
		for joint: String in JOINTS.values():
			if rig.find_bone(joint) < 0:
				push_error("Missing resident training joint " + joint)
				quit(4)
				return
		var axe := travel.get_node("StoneAxe") as Node3D
		var spear := legacy.tool_3d.duplicate() as Node3D
		travel.add_child(spear)
		player.play("01_Idle_9")
		player.advance(0)
		player.pause()
		for sample in SAMPLES:
			var time := sample * PRACTICE_SECONDS / SAMPLES
			player.seek(0.0, true)
			travel.position = Vector3.ZERO
			axe.hide()
			model.rotation.y = PI / 2.0 if index == 0 else -PI / 2.0
			legacy.clock = 0.0
			legacy.work_kind = "training"
			legacy.action_blend = 1.0
			legacy.animate(0.0, Vector2.DOWN, 0.0, false, "training", time, false)
			accent_strike(legacy, time)
			for joint: String in JOINTS:
				copy_rotation(legacy, rig, joint)
			rig.force_update_all_bone_transforms()
			var hand_index := rig.find_bone("RightHand")
			var hand_pose := rig.global_transform * rig.get_bone_global_pose(hand_index)
			var hand_rest := rig.get_bone_global_rest(hand_index).basis.orthonormalized()
			var old_rest := legacy.rig.get_bone_global_rest(legacy.bones.handR).basis.orthonormalized()
			var rotation := hand_pose.basis.orthonormalized() * hand_rest.inverse() * old_rest
			var local_hand := travel.global_transform.affine_inverse() * Transform3D(rotation, hand_pose.origin)
			# Keep the grip at the hand as the shaft and point grow together.
			var tool_basis := local_hand.basis.orthonormalized().scaled(Vector3.ONE * .67 * SPEAR_SCALE)
			spear.transform = Transform3D(tool_basis, local_hand.origin) * legacy.tool_3d.transform
			spear.show()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image().get_region(crop)
			image.convert(Image.FORMAT_RGBA8)
			image.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_LANCZOS)
			var bounds := image.get_used_rect()
			if bounds.size.x < 10 or bounds.position.x < 1 or bounds.end.x >= FRAME.x - 1 or bounds.position.y < 1 or bounds.end.y >= FRAME.y - 1:
				push_error("Clipped or empty training frame %s %d %s" % [facing, sample, bounds])
				quit(3)
				return
			var tile := index * SAMPLES + sample
			atlas.blit_rect(image, Rect2i(Vector2i.ZERO, FRAME), Vector2i(tile % COLUMNS, tile / COLUMNS) * FRAME)
		print("TRAINING BAKE male facing ", facing, " ", SAMPLES, " complete frames, spear scale ", SPEAR_SCALE)
		model.free()
	quit(atlas.save_png(args[1]))

func accent_strike(legacy: HybridCharacter, time: float) -> void:
	var phase := time * TAU / PRACTICE_SECONDS
	var extension := pow(maxf(0.0, sin(phase)), 2.0)
	if extension <= .0001:
		return
	# Lean into the strike with the lead shoulder and open the weapon arm.
	# The offsets fade back to the existing ready pose without moving the feet.
	legacy.rotate_bone("spine", Vector3(.03 + .31 * extension, -.15 + .34 * extension, -.08 * extension))
	legacy.rotate_bone("armR", Vector3(-1.1 + .58 * extension, .04 * extension, -.15 - .12 * extension))
	legacy.rotate_bone("forearmR", Vector3(-1.0 + 1.08 * extension, 0, 0))
	legacy.rotate_bone("armL", Vector3(-.7 - .25 * extension, 0, .2 + .17 * extension))
	legacy.rotate_bone("forearmL", Vector3(-.9 - .18 * extension, 0, 0))
	legacy.rotate_bone("head", Vector3(-.05 - .18 * extension, .1, 0))

func copy_rotation(legacy: HybridCharacter, target: Skeleton3D, joint: String) -> void:
	var source: int = legacy.bones[joint]
	var dest := target.find_bone(JOINTS[joint])
	var old_rest := legacy.rig.get_bone_rest(source).basis.get_rotation_quaternion()
	var old_axis := legacy.rig.get_bone_global_rest(source).basis.get_rotation_quaternion()
	var new_rest := target.get_bone_rest(dest).basis.get_rotation_quaternion()
	var new_axis := target.get_bone_global_rest(dest).basis.get_rotation_quaternion()
	var delta := old_axis * old_rest.inverse() * legacy.rig.get_bone_pose_rotation(source) * old_axis.inverse()
	target.set_bone_pose_rotation(dest, new_rest * new_axis.inverse() * delta * new_axis)
