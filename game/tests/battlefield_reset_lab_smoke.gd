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
	_check(app.world.player.hybrid.scale.is_equal_approx(Vector2(2, 2)), "Only the village Han visual is scaled twofold")
	var world_mode: int = app.world.process_mode
	var duel_button := _button(app, "DuelTestEntry")
	var gahui_button := _button(app, "GahuiLabEntry")
	if _check(is_instance_valid(duel_button) and duel_button.is_visible_in_tree(), "Village portrait button is available"):
		await _press(duel_button)
		var duel = app.parry_lab
		if _check(is_instance_valid(duel) and duel.rules.ally_id == "hangyeol" and duel.rules.enemy_id == "forest", "Village portal opens Han versus flower deer"):
			await _capture("01-duel")
			await _press(_button(duel, "HanMotionEntry"), true)
			await process_frame
			var view = app.parry_lab
			if _check(is_instance_valid(view) and view.name == "HanModelTest", "Duel opens the model-only test"):
				_check(view.model.duel_model.scene_file_path.ends_with("Han-Battle-Ultra-Rigged-12k.glb"), "New Han rig is loaded")
				_check(view.motion_buttons.size() == 19 and view.actors.is_empty(), "18 motions plus full playback, with a single Han rig")
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
