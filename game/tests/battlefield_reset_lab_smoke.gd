extends SceneTree
## Exercises the normal village flask and both lab navigation buttons.

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	checks += 1
	print(what, ": ", ok)
	if not ok:
		failures += 1

func _button(parent: Node, key: String) -> Button:
	return parent.find_child(key, true, false) as Button

func _run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.application_active = true
	_check(app.model.start_new({}, true), "New isolated profile")
	await app.enter_game()
	await process_frame
	if app.modal:
		app.close_modal()
	var flask := _button(app, "DuelTestEntry")
	_check(is_instance_valid(flask) and flask.is_visible_in_tree(), "Village flask is visible")
	_check(_button(app, "ModelTestEntry") == null, "Extra model-test entry is absent")
	if is_instance_valid(flask):
		var previous_world_mode: int = app.world.process_mode
		flask.pressed.emit()
		await process_frame
		await process_frame
		var gahui = app.parry_lab
		_check(is_instance_valid(gahui) and is_instance_valid(gahui.get("gahui")), "Flask opens working Gahui lab")
		if is_instance_valid(gahui):
			var one := _button(gahui, "OneOnOneEntry")
			_check(is_instance_valid(one) and one.is_visible_in_tree(), "Gahui lab links to Han 1:1")
			if is_instance_valid(one):
				one.pressed.emit()
				await process_frame
				await process_frame
				var lab = app.parry_lab
				_check(is_instance_valid(lab) and lab != gahui and lab.rules.ally_id == "hangyeol" and lab.rules.enemy_id == "forest", "Han/flower deer fixed matchup")
				if is_instance_valid(lab):
					for key in ["DuelTestAll", "SaebomDistanceFar", "SaebomDistanceNear", "Select_uram", "Select_saebom", "Select_stag", "Select_adult"]:
						_check(_button(lab, key) == null, key + " is absent")
					_check(is_instance_valid(_button(lab, "DuelPause")) and is_instance_valid(_button(lab, "DuelReset")) and is_instance_valid(lab.skill_button) and is_instance_valid(lab.chain_button), "Existing shared combat controls still exist")
					lab.set_process(false)
					for i in 360:
						lab.advance(1.0 / 120.0)
						if lab.rules.hp[1] < lab.rules.full_hp(1):
							break
					_check(lab.rules.hp[1] < lab.rules.full_hp(1), "Han reaches and damages the deer")
					var back := _button(lab, "GahuiMotionEntry")
					_check(is_instance_valid(back) and back.is_visible_in_tree(), "Han lab links back to Gahui")
					if is_instance_valid(back):
						back.pressed.emit()
						await process_frame
						await process_frame
						_check(is_instance_valid(app.parry_lab) and is_instance_valid(app.parry_lab.get("gahui")), "Gahui lab reopens")
					app.go_back()
					await process_frame
					_check(not is_instance_valid(app.parry_lab) and app.screen == "play" and not app.modal and app.world.process_mode == previous_world_mode, "Closing restores the village")
	app.queue_free()
	await process_frame
	print("Clean battlefield labs: ", checks, " checks; ", failures, " failures")
	quit(int(failures > 0))
