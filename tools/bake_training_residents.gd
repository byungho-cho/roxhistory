extends SceneTree
## Run with the game project and pass the RES-053 source directory and atlas output path after --.

const FRAME := Vector2i(112, 104)
const FLOOR := Vector2i(56, 89)
const COLUMNS := 8
const SAMPLES := 32
const PRACTICE_SECONDS := 2.2
const SPEAR_SCALE := 1.5
const SHAFT_LENGTH := 1.15
const SHAFT_BELOW_GRIP := .10
const HAND_SPACING := .175
const PALM_OFFSETS := [Vector3(-.091, -.021, .001), Vector3(.091, -.0246, .001)]
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
	await process_frame
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
		var shaft := spear.get_child(0) as MeshInstance3D
		var spearhead := spear.get_child(1) as MeshInstance3D
		var shaft_center := SHAFT_LENGTH * (.5 - SHAFT_BELOW_GRIP)
		spearhead.position.z += shaft_center - shaft.position.z
		shaft.position.z = shaft_center
		var character_mesh := model.find_child("char1", true, false) as MeshInstance3D
		if not character_mesh or character_mesh.mesh.get_blend_shape_name(0) != &"Gather_Grip":
			push_error("Missing the resident's authored grip shape")
			quit(4)
			return
		player.play("01_Idle_9")
		player.advance(0)
		player.pause()
		var largest_grip_error := 0.0
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
			for shape in character_mesh.mesh.get_blend_shape_count():
				character_mesh.set_blend_shape_value(shape, 1.0 if shape == 0 else 0.0)
			var grip_error := pose_two_handed_strike(rig, travel, spear, time)
			if grip_error > .003:
				push_error("An open grip in frame %s %d: %f" % [facing, sample, grip_error])
				quit(5)
				return
			largest_grip_error = maxf(largest_grip_error, grip_error)
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
		print("TRAINING BAKE ", facing, " ", SAMPLES, " frames, maximum palm separation ", largest_grip_error)
		model.free()
	quit(atlas.save_png(args[1]))

func pose_two_handed_strike(rig: Skeleton3D, travel: Node3D, spear: Node3D, time: float) -> float:
	var rig_to_travel := travel.global_transform.affine_inverse() * rig.global_transform
	var right_shoulder := rig_to_travel * rig.get_bone_global_pose(rig.find_bone("RightArm")).origin
	var left_shoulder := rig_to_travel * rig.get_bone_global_pose(rig.find_bone("LeftArm")).origin
	var shoulder_center := (right_shoulder + left_shoulder) * .5
	var extension := pow(maxf(0.0, sin(time * TAU / PRACTICE_SECONDS)), 2.0)
	var angle := deg_to_rad(lerpf(-28.0, 72.0, extension))
	var axis := Vector3(-.12, cos(angle), sin(angle)).normalized()
	var grip := shoulder_center + Vector3(-.055, lerpf(-.25, -.16, extension), lerpf(.145, .17, extension))
	var right := solve_grip(rig, rig_to_travel, "Right", grip, axis, 0)
	var left := solve_grip(rig, rig_to_travel, "Left", grip + axis * HAND_SPACING, axis, 1)
	for attempt in 8:
		var excess := maxf(right.error, left.error)
		if excess <= .0005:
			break
		grip = grip.move_toward(shoulder_center + Vector3(0, -.19, .06), excess + .005)
		right = solve_grip(rig, rig_to_travel, "Right", grip, axis, 0)
		left = solve_grip(rig, rig_to_travel, "Left", grip + axis * HAND_SPACING, axis, 1)
	var to_rig := rig_to_travel.affine_inverse()
	for arm in [right, left]:
		rig.set_bone_global_pose(arm.upper, to_rig * arm.upper_pose)
		rig.set_bone_global_pose(arm.forearm, to_rig * arm.forearm_pose)
		rig.set_bone_global_pose(arm.hand, to_rig * arm.hand_pose)
	rig.force_update_all_bone_transforms()
	var cross_axis := Vector3.RIGHT.slide(axis).normalized()
	spear.transform = Transform3D(Basis(cross_axis, axis.cross(cross_axis), axis).scaled(Vector3.ONE * .67 * SPEAR_SCALE), grip)
	var right_palm := palm_position(rig, rig_to_travel, right.hand, right.socket)
	var left_palm := palm_position(rig, rig_to_travel, left.hand, left.socket)
	return maxf(right_palm.distance_to(grip), left_palm.distance_to(grip + axis * HAND_SPACING))

func solve_grip(rig: Skeleton3D, to_actor: Transform3D, label: String, grip: Vector3, shaft: Vector3, palm_index: int) -> Dictionary:
	var upper := rig.find_bone(label + "Arm")
	var forearm := rig.find_bone(label + "ForeArm")
	var hand := rig.find_bone(label + "Hand")
	var a := to_actor * rig.get_bone_global_pose(upper)
	var b := to_actor * rig.get_bone_global_pose(forearm)
	var c := to_actor * rig.get_bone_global_pose(hand)
	var side := -1.0 if palm_index == 0 else 1.0
	var ab := b.origin - a.origin
	var bc := c.origin - b.origin
	var upper_length := ab.length()
	var forearm_length := bc.length()
	var rest_hand := rig.get_bone_global_rest(hand).basis.orthonormalized()
	var socket: Vector3 = rest_hand.inverse() * PALM_OFFSETS[palm_index]
	var palm_bind := direction_frame(Vector3.BACK, Vector3.RIGHT * side).inverse() * rest_hand
	var neutral := (grip - a.origin).slide(shaft).normalized()
	if neutral.is_zero_approx():
		neutral = Vector3.DOWN.slide(shaft).normalized()
	var best := {}
	var best_score := INF
	for roll in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		var hand_dir := neutral.rotated(shaft, deg_to_rad(roll))
		var wrist_basis := direction_frame(shaft, hand_dir) * palm_bind
		var wrist_goal := grip - wrist_basis * socket
		var distance := wrist_goal.distance_to(a.origin)
		var aim := (wrist_goal - a.origin).normalized()
		var reach := clampf(distance, absf(upper_length - forearm_length) + .001, upper_length + forearm_length - .002)
		var wrist := a.origin + aim * reach
		var pole := Vector3(.55 * side, -.85, -.16).slide(aim).normalized()
		var along := (upper_length * upper_length - forearm_length * forearm_length + reach * reach) / (2.0 * reach)
		var elbow := a.origin + aim * along + pole * sqrt(maxf(0.0, upper_length * upper_length - along * along))
		var solved_upper := (elbow - a.origin).normalized()
		var solved_forearm := (wrist - elbow).normalized()
		var error := absf(distance - reach)
		var score := solved_forearm.angle_to(hand_dir) + error * 44.0 + absf(roll) * .0008
		if score < best_score:
			best_score = score
			best = {
				"upper": upper, "forearm": forearm, "hand": hand, "socket": socket, "error": error,
				"upper_pose": Transform3D(Basis(Quaternion(ab.normalized(), solved_upper)) * a.basis, a.origin),
				"forearm_pose": Transform3D(Basis(Quaternion(bc.normalized(), solved_forearm)) * b.basis, elbow),
				"hand_pose": Transform3D(wrist_basis.scaled(c.basis.get_scale()), wrist),
			}
	return best

func direction_frame(primary: Vector3, transverse: Vector3) -> Basis:
	var second := transverse.slide(primary).normalized()
	return Basis(primary, second, primary.cross(second))

func palm_position(rig: Skeleton3D, to_actor: Transform3D, hand: int, socket: Vector3) -> Vector3:
	var pose := to_actor * rig.get_bone_global_pose(hand)
	return pose.origin + pose.basis.orthonormalized() * socket

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
