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
	var stop := _at(view, duration - .0001)
	var after := _at(view, duration + .4)
	var chain: Array[String] = []
	for step in view.steps:
		chain.append(step.clip)
	_check(chain == ["run_native", "decel", "walk_native"] and absf(view.steps[1].length - .42) < .002,
		"08 plays run, the native Meshy bridge, then walk")
	var forward := start.direction_to(stop)
	var monotonic := start.distance_to(stop) > 65.0
	var previous := start
	for i in range(1, 121):
		var current := _at(view, duration * float(i) / 120.0)
		monotonic = monotonic and (current - previous).dot(forward) >= -.01
		previous = current
	var bridge_start: float = view.steps[1].start
	var walk_start: float = view.steps[2].start
	var no_stop := _at(view, bridge_start - .02).distance_to(_at(view, bridge_start + .02)) > 1.0 and _at(view, walk_start - .02).distance_to(_at(view, walk_start + .02)) > 1.0
	_check(monotonic and no_stop and stop.distance_to(after) < .03, "Fixed-route 08 advances through both joins, then holds the walk-out position")
	view.play_motion("18")
	var takeoff := _at(view, .0)
	var flying := _at(view, 1.05)
	var landing := _at(view, view.model.STORY_FLY_SECONDS - .001)
	var standing := _at(view, view.model.STORY_FLY_SECONDS + .5)
	var landed_idle := _at(view, view.reel_duration + .4)
	var original_travel: Vector2 = view._route_space(-view.model.story_flight_retreat(1.0))
	_check(takeoff.distance_to(flying) > 4.0 and (landing - takeoff).distance_to(original_travel * 3.0) < .1,
		"Fixed-route flight follows the arc and lands at three times the original distance")
	_check(standing.distance_to(landing) < .1 and landed_idle.distance_to(landing) < .1, "Flying, standing and idle share the landing anchor")
	view.play_motion("full")
	chain.clear()
	for step in view.steps:
		if step.clip in ["run_native", "decel", "walk_native"]:
			chain.append(step.clip)
	_check(chain == ["run_native", "decel", "walk_native"], "Full reel uses one unbroken gait transition without repeats")
	var flight_start: float = view.steps[-2].start
	var reel_takeoff := _at(view, flight_start)
	var reel_landing := _at(view, flight_start + view.model.STORY_FLY_SECONDS)
	_check((reel_landing - reel_takeoff).distance_to(original_travel * 3.0) < .1,
		"Full playback applies the same flight distance from its current position")
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

func _check_roster(screen: Node, prefix: String) -> void:
	var available := true
	for key in ["hangyeol", "uram", "saebom", "gahui", "bau"]:
		var item := _button(screen, prefix + key)
		available = available and is_instance_valid(item) and item.visible and item.disabled == (key not in ["hangyeol", "gahui"])
	_check(available, prefix + " exposes five heroes with just Han and Gahui enabled")
	await _press(_button(screen, prefix + "uram"), true)
	_check(app.parry_lab == screen, "Disabled hero leaves the active screen in place")

func _check_village_idle() -> void:
	var player = app.world.player
	var visual = player.hybrid
	_check(visual.tracks.get(&"quiet_idle", {}).size() >= 17 and absf(visual.QUIET_IDLE.length - 2.033333) < .001,
		"Approved Idle 09 is mapped onto the village rig at native length")
	var initial_position: Vector2 = player.position
	player.idle_elapsed = visual.FIRST_AMBIENT_IDLE - .10
	for i in 15:
		await physics_frame
	_check(player.position.distance_to(initial_position) < .01 and visual.ambient_idle_phase(player.idle_elapsed) >= 0.0,
		"Village idle reaches the existing stretch on the same footline")
	var move := InputEventKey.new()
	move.physical_keycode = KEY_D
	move.pressed = true
	Input.parse_input_event(move)
	for i in 12:
		await physics_frame
	_check(player.position.distance_to(initial_position) > 5.0 and is_zero_approx(player.idle_elapsed),
		"Movement interrupts the village idle immediately")
	var stop := move.duplicate() as InputEventKey
	stop.pressed = false
	Input.parse_input_event(stop)
	for i in 18:
		await physics_frame
	_check(player.motion_state == "idle" and player.idle_elapsed > .16 and visual.ambient_idle_phase(player.idle_elapsed) < 0.0,
		"Stopping resumes Idle 09 before the stretch")
	await _capture("00-village")

func _check_duel() -> void:
	var duel_button := _button(app, "DuelTestEntry")
	var lab_button := _button(app, "MotionLabEntry")
	var icon := "hunt-bow-stone-v001.png"
	var has_arrow := false
	for child in duel_button.get_children():
		has_arrow = has_arrow or (child is TextureRect and child.texture.resource_path.ends_with(icon))
	_check(duel_button.text.is_empty() and has_arrow and duel_button.size.is_equal_approx(lab_button.size) and absf(duel_button.size.x-duel_button.size.y)<.01,
		"Village hunting icon fits the same circle as the lab button")
	await _press(duel_button)
	var duel = app.parry_lab
	if not _check(is_instance_valid(duel) and duel.rules.ally_id == "hangyeol" and duel.rules.enemy_id == "forest", "Hunting button opens Han versus flower deer"):
		return
	_check(_button(duel, "HanMotionEntry") == null, "Duel omits the standalone motion shortcut")
	_check(duel.han_ultra.duel_model.scene_file_path.ends_with("Han-Battle-Ultra-Rigged-12k.glb"), "Duel uses the approved Han model")
	await _check_roster(duel, "DuelSelect_")
	_check_visible_duel_motion(duel)
	await _capture("01-han-duel")
	await _press(_button(duel, "DuelSelect_gahui"), true)
	await process_frame
	duel = app.parry_lab
	if not _check(duel.rules.ally_id == "gahui" and is_instance_valid(duel.gahui) and duel.gahui.rig_ready, "The same duel opens with live Gahui"):
		return
	duel.set_process(false)
	await _check_roster(duel, "DuelSelect_")
	for i in 174:
		duel.advance(1.0/60.0)
	_check(duel.rules.hp[1] < 100 and duel.rules.hp[0] < 100, "Both Gahui's auto shot and the deer's attack actually land")
	duel.rules.sp = 3.0
	duel._refresh()
	await _press(duel.skill_button, true)
	_check(duel.motion[0]=="skill" and is_equal_approx(duel.rules.sp,1.0), "Gahui's 2 SP action spends two")
	var before:int=duel.rules.hp[1]
	for i in 201:
		duel.advance(1.0/60.0)
	_check(duel.rules.hp[1] <= before-27, "All three approved water-arrow arrivals apply damage")
	duel.rules.hp[0]=30
	duel.rules.sp=3.0
	duel._react(0,"idle")
	duel._refresh()
	await _press(duel.chain_button, true)
	_check(duel.motion[0]=="chain" and is_zero_approx(duel.rules.sp), "Gahui's 3 SP heal spends three")
	for i in 59:
		duel.advance(1.0/60.0)
	_check(duel.duel_healed and duel.rules.hp[0] > 30, "Gahui heals on the authored release")
	await _capture("02-gahui-duel")
	duel.reset_round()
	_check(duel.rules.ally_id=="gahui" and duel.rules.hp==[100,100] and is_equal_approx(duel.rules.sp,1.0), "Duel reset keeps the selected ally")
	await _press(_button(duel, "DuelSelect_hangyeol"))
	await process_frame
	duel = app.parry_lab
	_check(duel.rules.ally_id=="hangyeol" and is_instance_valid(duel.han_ultra), "Duel switches back to Han")
	await _press(_button(duel, "DuelClose"))

func _check_motion_lab() -> void:
	await _press(_button(app, "MotionLabEntry"), true)
	await process_frame
	var view = app.parry_lab
	if not _check(is_instance_valid(view) and view.name == "HanModelTest", "Village flask opens the combined motion lab"):
		return
	await _check_roster(view, "MotionSelect_")
	var no_tips := true
	for item: Button in view.find_children("*", "Button", true, false):
		no_tips = no_tips and item.tooltip_text.is_empty()
	_check(no_tips, "All Han motion-lab buttons omit tooltips")
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
		var opening: String = "run_native" if key == "08" else view.CLIPS[i - 1][0]
		_check(view.selection == key and view.model.ap.get_current_animation() == opening and (key == "08" or view.shown_motion == i), "Individual motion " + key)
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
	await _press(_button(view, "MotionSelect_gahui"), true)
	await process_frame
	var lab = app.parry_lab
	if not _check(is_instance_valid(lab) and is_instance_valid(lab.get("gahui")) and lab.subject == 0, "The lab switches to Gahui motions"):
		return
	await _check_roster(lab, "MotionSelect_")
	_check(not is_instance_valid(lab.a.preview.pivot) and lab.drill_buttons.size() == 9, "Gahui motion buttons and solo rig remain available")
	await _press(lab.drill_buttons[3])
	_check(lab.selected_index == 3, "Gahui's basic motion can be played")
	await _capture("03-gahui-motion")
	await _press(_button(lab, "MotionSelect_hangyeol"))
	await process_frame
	view = app.parry_lab
	_check(view.name == "HanModelTest", "Lab switches back without entering a fight")
	await _press(view.back_button, true)

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
	_check(app.world.player.hybrid.scale.is_equal_approx(Vector2(3, 3)), "Village display scale is retained")
	var world_mode: int = app.world.process_mode
	await _check_village_idle()
	await _check_duel()
	_check(not is_instance_valid(app.parry_lab) and app.world.process_mode == world_mode, "Duel close restores the village")
	await _check_motion_lab()
	_check(not is_instance_valid(app.parry_lab) and app.world.process_mode == world_mode, "Lab close restores the village")
	app.queue_free()
	await process_frame
	print("LAB PATCH RESULTS ", checks - failures, "/", checks)
	quit(int(failures > 0))
