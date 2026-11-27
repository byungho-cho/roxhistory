extends SceneTree
## Covers the restored campaign and the one-stage limit across a real process restart.

var app
var failed := 0
var checked := 0
var capture_dir := OS.get_environment("ROX_RESTORE_CAPTURE")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checked += 1
	if not ok:
		failed += 1
	print(("PASS " if ok else "FAIL ") + label)
	return ok

func until(condition: Callable, timeout_ms := 25000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()

func button(id: String) -> Button:
	return app.find_child(id, true, false) as Button

func click(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var point := item.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func capture(file: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(file + ".png")) == OK, "capture " + file)

func open_selection() -> bool:
	if is_instance_valid(button("HuntButton")) and not button("HuntButton").is_visible_in_tree():
		await click(button("MenuToggle"))
		await until(func(): return button("HuntButton").is_visible_in_tree())
	await click(button("HuntButton"))
	return await until(func():
		var selection = app.find_child("HuntStageSelection", true, false)
		return is_instance_valid(selection) and selection.entry_finished and is_instance_valid(button("PrepareHunt")))

func check_stage_gate() -> void:
	var first := button("HuntStage0")
	var second := button("HuntStage1")
	check(is_instance_valid(first) and not first.disabled and is_instance_valid(second) and second.disabled, "stage selection admits 1-1 and disables 1-2")
	await click(second)
	check(app.hunt_stage == 0 and not app.hunt_stage_is_unlocked(1), "clicking 1-2 cannot reseat selection")
	app._prepare_hunt_stage(1)
	await process_frame
	check(app.screen == "hunt_select" and not app.hunt_preparing, "preparation guard rejects a direct 1-2 request")

func enter_battle() -> bool:
	await click(button("PrepareHunt"))
	if not check(await until(func(): return app.screen == "hunt" and is_instance_valid(app.hunt) and app.hunt.arrival_finished), "actual 336 preparation opens"):
		return false
	check(app.hunt.stage_one_one and app.hunt.prep_ally_count == 1 and app.hunt.deer.visible, "1-1 preparation shows Han and deer")
	await capture("01-hunt-preparation")
	await click(button("StartBattle"))
	if not check(await until(func(): return app.hunt.running), "normal VS completes into production combat"):
		return false
	check(app.hunt._uses_independent_first_hunt() and app.hunt.rules.party_hp[0] > 0 and app.hunt.rules.party_hp[1] == 0 and app.hunt.rules.party_hp[2] == 0, "actual 1-1 combat uses solo Han")
	check(await until(func(): return app.hunt.solo_deploy_clock < 0), "combatants close the deployed gap")
	return true

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("CAMPAIGN RESTORE ", checked - failed, "/", checked)
	quit(int(failed > 0))

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-ui"):
		quit(90)
		return
	var reopening := OS.get_environment("ROX_RESTORE_PHASE") == "reopen"
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.application_active = true
	if reopening:
		check(app.model.state.get("hunt_ch1_completed", {}) == {"ch1-01": true} and app.model.state.get("hunt_cleared") == 1, "first win persists across a fresh process")
		check(app.model.state.get("wood") == 37 and app.model.state.get("stone") == 23, "existing village resources are retained")
	else:
		check(app.model.start_new({}, true), "create isolated village fixture")
		var state: Dictionary = app.model.state.duplicate(true)
		state.wood = 37
		state.stone = 23
		check(app.model.commit(state), "save existing village resources")
	await app.enter_game()
	await process_frame
	if app.modal:
		app.close_modal()
	if not check(await open_selection(), "village hunting opens restored stage selection"):
		await finish()
		return
	await check_stage_gate()
	if reopening:
		await capture("05-relaunch-still-locked")
		await finish()
		return
	if not await enter_battle():
		await finish()
		return
	await capture("02-real-1-1-combat")
	var hunt = app.hunt
	# Supply the final damage through the actual rules to exercise the result path deterministically.
	hunt.rules.damage_deer(hunt.rules.deer_hp)
	check(await until(func(): return hunt.result_shown and hunt.rules.outcome == "win"), "production rules lead to the victory result")
	check(is_instance_valid(button("ResultStageSelect")) and not is_instance_valid(button("ResultNextStage")), "victory offers stage selection and no next stage")
	var details = app.find_child("ResultDetails", true, false)
	var misleading: Array = details.get_children().filter(func(child): return child is Label and child.text.contains("다음 단계 해금")) if is_instance_valid(details) else []
	check(is_instance_valid(details) and misleading.is_empty(), "victory never claims that a locked stage was unlocked")
	check(app.model.state.get("hunt_ch1_completed", {}) == {"ch1-01": true} and app.model.state.get("hunt_cleared") == 1, "first victory records only 1-1")
	await until(func(): return is_instance_valid(button("ResultStageSelect")) and button("ResultStageSelect").is_visible_in_tree())
	await create_timer(1.2).timeout
	await capture("03-success")
	await click(button("ResultStageSelect"))
	if not check(await until(func(): return app.screen == "hunt_select" and is_instance_valid(button("PrepareHunt"))), "success returns to stage selection"):
		await finish()
		return
	await check_stage_gate()
	if not await enter_battle():
		await finish()
		return
	hunt = app.hunt
	hunt.rules.party_hp[0] = 1
	hunt.rules.resolve_independent_prey_basic(0)
	check(await until(func(): return hunt.result_shown), "production rules lead to the defeat result")
	check(hunt.rules.outcome == "loss" and is_instance_valid(button("ResultRetry")), "defeat offers a retry")
	await until(func(): return is_instance_valid(button("ResultRetry")) and button("ResultRetry").is_visible_in_tree())
	await create_timer(1.2).timeout
	await capture("04-failure")
	await click(button("ResultRetry"))
	check(await until(func(): return app.screen == "hunt" and app.hunt != hunt and app.hunt.arrival_finished), "failure retry restores 1-1 preparation")
	check(app.hunt.stage_one_one and not app.hunt_stage_is_unlocked(1), "retry cannot unlock a later stage")
	await click(button("ExitHunt"))
	check(await until(func(): return app.screen == "hunt_select"), "preparation back returns to the selection")
	app.go_back()
	check(await until(func(): return app.screen == "play"), "stage selection back returns to the village")
	await finish()
