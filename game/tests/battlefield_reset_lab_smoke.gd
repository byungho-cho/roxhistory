extends SceneTree

var app
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures += 1
	return ok

func _button(parent: Node, key: String) -> Button:
	return parent.find_child(key, true, false) as Button

func _press(button: Button, use_touch := false) -> void:
	if not is_instance_valid(button):
		return
	var point := button.get_global_rect().get_center()
	for down in [true, false]:
		if use_touch:
			var touch := InputEventScreenTouch.new()
			touch.position = point
			touch.pressed = down
			root.push_input(touch, true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.global_position = point
			event.pressed = down
			root.push_input(event, true)
		await process_frame

func _capture(filename: String) -> void:
	var capture_dir := OS.get_environment("ROX_HAN_CAPTURE")
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png")) == OK, "capture " + filename)

func _at(view, time: float) -> Vector2:
	view.age = time
	view.render_frame()
	return view.han.position

func _check_planted_toe(view, motion_id: String, from_phase: float, to_phase: float) -> void:
	view.play_motion(motion_id)
	var rig: Skeleton3D = view.model.rig
	var toe := rig.find_bone("LeftToeBase")
	var cycle: float = view.steps[0].length
	var camera: Camera3D = view.han.camera
	var scale: Vector2 = view.han.display.scale * view.han.scale
	var start := _at(view, cycle * from_phase)
	var toe_start := start + camera.unproject_position(rig.to_global(rig.get_bone_global_pose(toe).origin)) * scale
	var end := _at(view, cycle * to_phase)
	var toe_end := end + camera.unproject_position(rig.to_global(rig.get_bone_global_pose(toe).origin)) * scale
	var travel := start.distance_to(end)
	_check(travel > 4.0 and absf((toe_end - toe_start).dot(start.direction_to(end))) < travel * .15,
		"Fixed-route %s advances while the planted toe stays put" % ("walk" if motion_id == "06" else "run"))

func _check_motion_enhancements(view) -> void:
	if not view.route:
		view.toggle_route()
	_check_planted_toe(view, "06", .40, .60)
	_check_planted_toe(view, "07", .38, .47)
	view.play_motion("08")
	var duration: float = view.reel_duration
	var start := _at(view, .0)
	var middle := _at(view, duration * .5)
	var stop := _at(view, duration - .0001)
	var after := _at(view, duration + .4)
	_check(start.distance_to(middle) > middle.distance_to(stop) * 2.5 and stop.distance_to(after) < .03, "Deceleration slows and retains the stopped position")
	view.play_motion("18")
	var takeoff := _at(view, .0)
	var flying := _at(view, 1.05)
	var landing := _at(view, view.model.STORY_FLY_SECONDS - .001)
	var standing := _at(view, view.model.STORY_FLY_SECONDS + .5)
	var landed_idle := _at(view, view.reel_duration + .4)
	_check(takeoff.distance_to(flying) > 4.0 and takeoff.distance_to(landing) > 25.0, "Fixed-route flight travels through an arc")
	_check(standing.distance_to(landing) < .1 and landed_idle.distance_to(landing) < .1, "Flying, standing and idle share the landing anchor")
	view.toggle_route()
	view.play_motion("06")
	var walk_anchor := _at(view, .0)
	_check(walk_anchor.is_equal_approx(_at(view, .35)), "Route OFF keeps walking in place")
	view.play_motion("18")
	var free_start := _at(view, .0)
	_check(free_start.is_equal_approx(_at(view, 1.05)) and free_start.is_equal_approx(_at(view, view.reel_duration + .4)), "Route OFF keeps the same ground anchor")
	view.play_motion("15")
	_check(view.motion_buttons["15"].text == "넉다운" and view.steps.size() == 1 and view.steps[0].clip == "knock_190", "Knockdown uses a single approved clip")
	view.play_motion("12")
	_at(view, 2.1)
	_check(view.ground_dim.color.a > .49 and view.model.ap.current_animation_position < 1.0, "3SP restores the dim and original slow timing")
	_at(view, view.reel_duration + .2)
	_check(is_zero_approx(view.ground_dim.color.a), "3SP dim clears when the motion ends")

func _check_visible_duel_motion(duel) -> void:
	var model = duel.han_ultra
	if not is_instance_valid(model):
		_check(false, "Duel uses a live animated Han rig")
		return
	var mesh: MeshInstance3D = model.grip_mesh
	var arm: int = model.rig.find_bone("RightArm")
	var first_run := Quaternion.IDENTITY
	var first_attack := Quaternion.IDENTITY
	var run_samples := 0
	var attack_samples := 0
	var run_changed := false
	var attack_changed := false
	var always_visible := true
	var deer_hp: int = duel.rules.hp[1]
	for frame in 138:
		duel.advance(1.0 / 60.0)
		always_visible = always_visible and mesh.is_visible_in_tree() and model.blade.is_visible_in_tree()
		var pose: Quaternion = model.rig.get_bone_pose_rotation(arm)
		match duel.motion[0]:
			"run":
				if run_samples == 0:
					first_run = pose
				run_samples += 1
				run_changed = run_changed or first_run.angle_to(pose) > .2
			"attack":
				if attack_samples == 0:
					first_attack = pose
				attack_samples += 1
				attack_changed = attack_changed or first_attack.angle_to(pose) > .2
	_check(always_visible and not duel.a.preview.has_meta("han_presentation_proxy"), "The live model stays visible instead of a frozen proxy")
	_check(run_changed and attack_changed and duel.rules.hp[1] < deer_hp, "Displayed run and basic attack advance through real combat")
	duel.reset_round()
	_check(mesh.is_visible_in_tree(), "Reset keeps the live Han rig visible")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test-ui"):
		quit(90)
		return
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.application_active = true
	_check(app.model.start_new({}, true), "New isolated profile")
	await app.enter_game()
	await process_frame
	if app.modal:
		app.close_modal()
	_check(app.world.player.hybrid.scale.is_equal_approx(Vector2(3, 3)), "Village Han is 1.5 times the 342 presentation size")
	var world_mode: int = app.world.process_mode
	var duel_button := _button(app, "DuelTestEntry")
	var gahui_button := _button(app, "GahuiLabEntry")
	if _check(is_instance_valid(duel_button) and duel_button.is_visible_in_tree() and duel_button.text == "테스트", "Village portal uses the text-only label"):
		await _press(duel_button)
		var duel = app.parry_lab
		if _check(is_instance_valid(duel) and duel.rules.ally_id == "hangyeol" and duel.rules.enemy_id == "forest", "Village portal opens Han versus flower deer"):
			_check(is_instance_valid(duel.han_ultra) and duel.han_ultra.duel_model.scene_file_path.ends_with("Han-Battle-Ultra-Rigged-12k.glb"), "Duel uses the same Han model")
			if is_instance_valid(duel.han_ultra):
				var world = duel.shared_world
				var projected: float = world.camera.unproject_position(Vector3.UP).distance_to(world.camera.unproject_position(Vector3.ZERO))
				var actual: float = projected * world.display.scale.y * duel.han_ultra.model_display_scale
				var expected: float = 720.0 / 7.0 * (.46 / 1.5) * 1.58 / sqrt(2.0)
				_check(absf(actual - expected) < .02, "Duel Han matches the model-test projection")
				var donor_hidden := true
				for donor: MeshInstance3D in duel.han_ultra.donor_meshes:
					donor_hidden = donor_hidden and not donor.is_visible_in_tree()
				_check(donor_hidden, "The duel does not render the older donor model")
			_check_visible_duel_motion(duel)
			await _capture("01-duel")
			await _press(_button(duel, "HanMotionEntry"), true)
			await process_frame
			var view = app.parry_lab
			if _check(is_instance_valid(view) and view.name == "HanModelTest", "Duel opens the model-only test"):
				_check(view.model.duel_model.scene_file_path.ends_with("Han-Battle-Ultra-Rigged-12k.glb"), "New Han rig is loaded")
				_check(view.motion_buttons.size() == 19 and view.actors.is_empty(), "18 motions plus full playback, with a single Han rig")
				var motion_rects: Array[Rect2] = []
				var separate := true
				for control: Button in view.motion_buttons.values():
					var bounds := control.get_global_rect()
					for previous in motion_rects:
						separate = separate and not previous.intersects(bounds)
					motion_rects.append(bounds)
				_check(separate, "All 19 controls have separate touch areas")
				await _capture("02-han-model-test")
				for i in range(1, 19):
					var key := "%02d" % i
					await _press(_button(view, "HanMotion" + key), i % 2 == 0)
					_check(view.selection == key and view.shown_motion == i and view.model.ap.get_current_animation() == view.CLIPS[i - 1][0], "Individual motion " + key)
				await _press(_button(view, "HanAllMotions"), true)
				var observed := {}
				var start := 0.0
				for step: Dictionary in view.steps:
					view.age = (start + float(step.until)) * 0.5
					view.render_frame()
					observed[view.shown_motion] = view.model.ap.get_current_animation() == step.clip
					start = float(step.until)
				_check(observed.size() == 18 and not (false in observed.values()), "One sequence contains all 18 approved motions in order")
				view.age = view.reel_duration + 0.5
				view.render_frame()
				_check(view.model.ap.get_current_animation() == "idle_02_11", "Full motion returns to idle")
				_check_motion_enhancements(view)
				await _press(view.back_button, true)
				await process_frame
				duel = app.parry_lab
				_check(is_instance_valid(duel) and _button(duel, "HanMotionEntry") != null, "Model back returns to the duel")
			if is_instance_valid(duel):
				await _press(_button(duel, "DuelClose"))
		_check(not is_instance_valid(app.parry_lab) and app.world.process_mode == world_mode, "Duel close restores the village")
	if _check(is_instance_valid(gahui_button) and gahui_button.is_visible_in_tree(), "Separate village flask is available"):
		await _press(gahui_button)
		await process_frame
		var lab = app.parry_lab
		if _check(is_instance_valid(lab) and is_instance_valid(lab.get("gahui")) and lab.subject == 0, "Gahui starts as the active ally"):
			_check(not is_instance_valid(lab.a.preview.pivot) and _button(lab, "HanMotionEntry") == null and _button(lab, "OneOnOneEntry") == null, "Gahui lab contains no Han visual or duel controls")
			_check(_button(lab, "GahuiRunToWalk").visible and lab.drill_buttons[0].visible, "Gahui motions remain available")
			await _capture("03-gahui")
		app.go_back()
		await process_frame
		_check(not is_instance_valid(app.parry_lab) and app.world.process_mode == world_mode, "Gahui closes back to the village")
	app.queue_free()
	await process_frame
	print("LAB PATCH RESULTS ", checks - failures, "/", checks)
	quit(int(failures > 0))
