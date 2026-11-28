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

func _check_motion_enhancements(view) -> void:
	if not view.route:
		view.toggle_route()
	for gait in ["06", "07"]:
		view.play_motion(gait)
		var start := _at(view, 0.0)
		var max_distance := 0.0
		for i in range(1, 61):
			max_distance = maxf(max_distance, _at(view, view.reel_duration * i / 60.0).distance_to(start))
		_check(max_distance > 100.0 and _at(view, view.reel_duration).distance_to(start) < 2.0,
			"Approved fixed-route %s advances, backs up and stops at the start" % gait)
	view.play_motion("08")
	var duration: float = view.reel_duration
	var start := _at(view, 0.0)
	var stop := _at(view, duration - .0001)
	var after := _at(view, duration + .4)
	_check(view.steps.size() == 1 and view.steps[0].clip == "meshy116_direct" and absf(duration - 2.3 / 1.5) < .001,
		"The motion test plays the full native 08 once at its tuned speed")
	_check(view.model.ap.current_animation == "retouch_guard", "08 returns to the approved battle-ready pose")
	var forward := start.direction_to(stop)
	var monotonic := start.distance_to(stop) > 65.0
	var previous := start
	for i in range(1, 121):
		var current := _at(view, duration * float(i) / 120.0)
		monotonic = monotonic and (current - previous).dot(forward) >= -.01
		previous = current
	_check(monotonic and stop.distance_to(after) < .03, "Fixed-route 08 follows the native forward root and holds its endpoint")
	view.play_motion("18")
	var takeoff := _at(view, 0.0)
	var flying := _at(view, 1.05)
	var landed := _at(view, view.reel_duration - .001)
	var held := _at(view, view.reel_duration + .4)
	_check(takeoff.distance_to(flying) > 4.0 and landed.distance_to(takeoff) > 70.0 and landed.distance_to(held) < .1,
		"Native flight retreats, lands and retains the standing anchor")
	view.play_motion("full")
	_check(view.steps.size() == 18 and view.steps[7].clip == "meshy116_direct" and view.steps[17].clip == "retouch_flight",
		"Full reel plays the 18 authored stages once each")
	view.toggle_route()
	view.play_motion("06")
	var walk_anchor := _at(view, .0)
	_check(walk_anchor.is_equal_approx(_at(view, .35)), "Route OFF keeps walking in place")
	view.play_motion("18")
	var free_start := _at(view, .0)
	_check(free_start.is_equal_approx(_at(view, 1.05)) and free_start.is_equal_approx(_at(view, view.reel_duration + .4)), "Route OFF keeps the ground anchor")
	view.play_motion("15")
	_check(view.motion_buttons["15"].text == "넉다운" and view.steps.size() == 1 and view.steps[0].clip == "retouch_knockdown", "Knockdown uses the corrected single clip")
	view.play_motion("12")
	_at(view, 2.1 / 1.75)
	_check(view.ground_dim.color.a > .49 and absf(view.model.ap.current_animation_position - 2.1) < .002,
		"Approved slow 3SP is sampled once with the existing dim")
	_at(view, view.reel_duration + .2)
	_check(is_zero_approx(view.ground_dim.color.a), "3SP dim clears when the motion ends")
	_check_default_han_rates(view)

func _check_default_han_rates(view) -> void:
	var expected := [1.0, 1.5, 1.5, 1.5, 1.5, 1.5, 1.0, 1.5, 1.0,
		1.3, 1.75, 1.75, 1.0, 1.0, 1.5, 2.0, 2.0, 1.75]
	var durations: Array[float] = []
	var pose_times_match: bool = view.rate == 1.0
	for index in expected.size():
		view.play_motion("%02d" % (index + 1))
		view.advance(.4)
		var target: float = .6 if index == 8 else .4 * expected[index]
		pose_times_match = pose_times_match and absf(view.model.ap.current_animation_position - target) < .002
		durations.append(view.reel_duration)
	_check(pose_times_match, "The selected 1x setting plays all 18 individual motions at their expected base speeds")

	view.play_motion("09")
	_at(view, 2.0 / 3.0)
	var boundary: float = view.model.ap.current_animation_position
	_at(view, 2.0 / 3.0 + .25)
	_check(absf(boundary - 1.0) < .002 and absf(view.model.ap.current_animation_position - 1.25) < .002,
		"Weapon draw uses 1.5x for its first source second and resumes at native speed")

	view.play_motion("full")
	var reel_matches := true
	for index in expected.size():
		var step: Dictionary = view.steps[index]
		reel_matches = reel_matches and absf(step.until - step.start - durations[index]) < .002
		_at(view, step.start + .4)
		var target: float = .6 if index == 8 else .4 * expected[index]
		reel_matches = reel_matches and absf(view.model.ap.current_animation_position - target) < .002
	_check(reel_matches, "The full reel uses the same tuned timeline as the individual buttons")

	view.play_motion("11")
	view.set_rate(2.0)
	view.advance(.2)
	_check(absf(view.model.ap.current_animation_position - .7) < .002, "The right speed rail multiplies the tuned base speed")
	view.set_rate(1.0)

func _check_visible_duel_motion(duel) -> void:
	var model = duel.han_ultra
	if not _check(is_instance_valid(model), "Duel uses a live animated Han rig"):
		return
	var shared = duel.shared_world
	var base_scale: float = model.model_test_projection_ratio(shared.camera, shared.display.scale.y)
	_check(is_equal_approx(model.model_display_scale / base_scale, 1.5), "Han's 1v1 rig is 1.5 times its former visible size")
	var deer_ratio: float = duel.b.preview.pivot.scale.y / shared.deer_simulation_transform.basis.get_scale().y
	_check(is_equal_approx(deer_ratio, 1.5) and is_equal_approx(shared.hurt_capsule(1).radius, .36), "Deer display grows while the hurt volume stays at its existing size")
	var mesh: MeshInstance3D = model.grip_mesh
	var arm: int = model.rig.find_bone("RightArm")
	var first_run: Quaternion = model.rig.get_bone_pose_rotation(arm)
	var run_changed := false
	var always_visible := true
	var deer_hp: int = duel.rules.hp[1]
	var phases: Array[StringName] = []
	var native_rate := true
	for frame in 280:
		duel.advance(1.0 / 60.0)
		always_visible = always_visible and mesh.is_visible_in_tree() and model.approved_weapon.is_visible_in_tree()
		var phase: StringName = model.ap.current_animation
		if phases.is_empty() or phases.back() != phase:
			phases.append(phase)
		if duel.approach_active:
			native_rate = native_rate and phase == &"meshy116_direct" and absf(model.ap.current_animation_position - duel.visual_clock) < .001
			run_changed = run_changed or first_run.angle_to(model.rig.get_bone_pose_rotation(arm)) > .2
	_check(always_visible and not duel.a.preview.has_meta("han_presentation_proxy"), "The approved character and stoneblade stay visible")
	_check(native_rate and run_changed and phases.slice(0, 3) == [&"meshy116_direct", &"retouch_guard", &"retouch_basic"],
		"Duel plays the native entrance once, then ready then the approved attack")
	_check(duel.rules.hp[1] < deer_hp, "Approved presentation leaves real 1v1 contact active")
	duel.reset_round()
	_check(mesh.is_visible_in_tree() and model.ap.current_animation == "meshy116_direct", "Reset restarts the native clip on the live rig")
	_check(is_equal_approx(duel.b.preview.pivot.scale.y, 1.5), "Duel reset applies the enlargement once")

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

func _check_han_duel_skills(duel) -> void:
	duel.set_process(false)
	for key in ["skill", "chain"]:
		duel.reset_round()
		for frame in 150:
			if not duel.approach_active:
				break
			duel.advance(1.0 / 60.0)
		await _press(_button(duel, "DuelTestCharge"), true)
		await _press(duel.skill_button if key == "skill" else duel.chain_button, true)
		var cost := 2 if key == "skill" else 3
		_check(duel.motion[0] == key and is_equal_approx(duel.rules.sp, 3.0 - cost), "Han's 1v1 %dSP button spends the original cost" % cost)
		var impact := false
		for frame in 120:
			duel.advance(1.0 / 60.0)
			for event: Dictionary in duel.fx:
				impact = impact or (event.name == "han_chain_impact" if key == "chain" else event.get("han_2sp_authored", false))
			if impact:
				break
		var damage := 27 if key == "skill" else 38
		_check(impact and duel.rules.hp[1] == 100 - damage, "Han's 1v1 %dSP impact uses the existing effect and damage" % cost)
	duel.reset_round()

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
	await _check_han_duel_skills(duel)
	await _capture("01-han-duel")
	await _press(_button(duel, "DuelSelect_gahui"), true)
	await process_frame
	duel = app.parry_lab
	if not _check(duel.rules.ally_id == "gahui" and is_instance_valid(duel.gahui) and duel.gahui.rig_ready, "The same duel opens with live Gahui"):
		return
	_check(_gahui_has_size(duel, 1.5), "Gahui and deer use the enlarged 1v1 view")
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

func _gahui_has_size(screen, multiplier: float) -> bool:
	var model: Node3D = screen.gahui.models[0]
	var body_mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var height: float = body_mesh.mesh.get_aabb().size.y * model.scale.y
	var deer_scale: float = screen.b.preview.pivot.scale.y if screen.test_ally == "gahui" else screen.flower_driver._calibration.basis.get_scale().y
	return is_equal_approx(height / screen.Gahui.DISPLAY_HEIGHT, multiplier) and is_equal_approx(deer_scale, 1.5 if screen.test_ally == "gahui" else 1.8)

func _check_effect_toggle(view) -> void:
	var button: Button = _button(view, "MotionEffects")
	if not _check(is_instance_valid(button) and view.effects_enabled, "Motion effects start enabled"):
		return
	_check(view.skill_frames.size() == 11 and view.skill_frames[0].resource_path.contains("duel-2sp-authored"), "Motion test loads the existing 1v1 2SP effect frames")
	_check(view.chain_frames.size() == 21 and view.chain_frames[0].resource_path.contains("han_chain_impact"), "Motion test loads the existing 1v1 3SP effect frames")
	var bounds := button.get_global_rect()
	_check(root.get_visible_rect().encloses(bounds) and not bounds.intersects(view.route_button.get_global_rect()), "Effect toggle fits the game and has its own touch area")
	view.set_process(false)
	for key in ["10", "11", "12"]:
		await _press(view.motion_buttons[key], true)
		var step: Dictionary = view.steps[0]
		for cue: Dictionary in view.CONTACT_CUES[step.clip]:
			var frame: int = cue.frame
			var source_time := frame / 30.0
			view.age = (source_time - .01) / step.motion_rate
			view.render_frame()
			_check(view.effect_progress == 1.0, "Effect waits until the contact frame %s/%s" % [key, frame])
			view.age = (source_time + .02) / step.motion_rate
			view.render_frame()
			_check(view.effect_progress < .1 and view.effect_contact.is_finite(), "Effect begins on the retimed contact frame %s/%s" % [key, frame])
	await _press(view.motion_buttons["12"], false)
	view.age = 2.0 / float(view.steps[0].motion_rate)
	view.render_frame()
	var before: float = view.model.ap.current_animation_position
	_check(view.ground_dim.color.a > .2, "3SP preserves the approved dim")
	await _press(button, true)
	_check(not view.effects_enabled and view.ground_dim.color.a == 0.0 and view.effect_progress == 1.0, "Native touch switches off outstanding effects immediately")
	_check(is_equal_approx(view.model.ap.current_animation_position, before), "Effect switch does not restart or retime the motion")
	await _press(view.motion_buttons.full, true)
	var chain: Dictionary = view.steps[11]
	view.age = chain.start + 3.32 / chain.motion_rate
	view.render_frame()
	_check(view.shown_motion == 12 and view.effect_progress == 1.0, "Full playback suppresses the same effect when off")
	await _press(button)
	_check(view.effects_enabled and view.effect_progress < .1, "Full playback enables the same effect on its original frame")
	await _press(button, true)
	_check(view.effect_progress == 1.0, "Switch off clears an active contact burst immediately")
	await _press(button)
	view.set_process(true)

func _check_motion_sounds(view) -> void:
	view.set_process(false)
	await _press(view.motion_buttons["10"], true)
	var player: AudioStreamPlayer = view.combat_players[&"han_basic"]
	var first: float = view.sound_timeline[0].at
	var second: float = view.sound_timeline[1].at
	_check(view.sound_timeline.size() == 2 and player.bus == &"Combat" and player.stream is AudioStream, "Basic attack has two cues routed to the Combat settings")
	view.advance(first - .01)
	_check(view.next_sound == 0 and not player.playing, "Basic attack stays silent before contact")
	view.advance(.02)
	_check(view.next_sound == 1 and player.playing and view.effect_progress < .1, "First basic sound plays in the same frame as its effect")
	view.render_frame()
	view.render_frame()
	_check(view.next_sound == 1, "Redrawing a frame never repeats the sound")
	view.advance(second - view.age + .01)
	_check(view.next_sound == 2 and player.playing and view.effect_progress < .1, "Second basic strike plays exactly one more sound")
	await _press(view.effect_button, true)
	_check(not player.playing, "Turning effects off also stops active combat sounds")
	await _press(view.motion_buttons["11"], true)
	view.advance(float(view.sound_timeline[0].at) + .01)
	var skill: AudioStreamPlayer = view.combat_players[&"han_skill"]
	_check(view.next_sound == 1 and not skill.playing, "Moving past a cue with effects off stays silent")
	await _press(view.effect_button, true)
	view.advance(.01)
	_check(not skill.playing, "Turning effects on does not replay a discarded cue")
	await _press(view.motion_buttons["13"], true)
	var hit: AudioStreamPlayer = view.combat_players[&"ally_hit"]
	_check(view.next_sound == 1 and hit.playing and view.effect_style == 0, "Normal hit has one sound and flash at the first reaction frame")
	await _press(view.motion_buttons.full, true)
	_check(not hit.playing and view.sound_timeline.size() == 10, "Switching to the full reel stops the old cue and schedules all ten contacts")
	view.set_rate(2.0)
	first = view.sound_timeline[0].at
	view.advance(first / 2.0 + .005)
	_check(view.next_sound == 1 and player.playing and view.effect_progress < .1, "Full reel uses the same contacts with the playback multiplier")
	view.set_rate(1.0)
	await _press(view.motion_buttons["01"], true)
	view.set_process(true)

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
	_check(is_equal_approx(view.han.display.scale.y, view.HanModel.MODEL_TEST_DISPLAY_FACTOR * 1.5), "Han motion lab magnifies only the rendered character")
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
		var opening := String(view.CLIPS[i - 1])
		_check(view.selection == key and view.model.ap.get_current_animation() == opening and view.shown_motion == i, "Individual motion " + key)
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
	_check(view.model.ap.get_current_animation() == "retouch_guard", "Full motion returns to battle-ready idle")
	_check_motion_enhancements(view)
	await _check_effect_toggle(view)
	await _check_motion_sounds(view)
	await _press(_button(view, "MotionSelect_gahui"), true)
	await process_frame
	var lab = app.parry_lab
	if not _check(is_instance_valid(lab) and is_instance_valid(lab.get("gahui")) and lab.subject == 0, "The lab switches to Gahui motions"):
		return
	_check(_gahui_has_size(lab, 2.25), "Gahui motion lab enlarges Gahui and the deer from their own prior sizes")
	lab._select_subject(2)
	_check(is_equal_approx(lab.stag_actor.preview.pivot.scale.y, 1.8), "Mountain deer drill keeps the same 1.5x enlargement")
	lab._select_subject(0)
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
	_check(app.world.player.hybrid.scale.is_equal_approx(Vector2(2, 2)), "Village Han uses the calibrated display scale")
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
