extends SceneTree

var total := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func ck(ok: bool, desc: String) -> void:
	total += 1
	if not ok: failed += 1
	print(("PASS " if ok else "FAIL ") + desc)

func frames(n: int) -> void:
	for i in n: await process_frame

func touch(at: Vector2, pressed: bool, finger := 0, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func drag(at: Vector2, finger := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	root.push_input(event, true)

func tap(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	touch(at, true)
	await process_frame
	touch(at, false)
	await frames(7)

func find_slider(parent: Node) -> HSlider:
	for child in parent.get_children():
		if child is HSlider: return child
		var found := find_slider(child)
		if found: return found
	return null

func render_image(name: String) -> void:
	var path := OS.get_environment("QA_T43")
	if path.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	ck(screenshot.save_png(path.path_join(name)) == OK, "native screenshot " + name)

func wait_hunt(app: Node, stage_id: int) -> Control:
	app.hunt_stage = stage_id
	app.show_screen("hunt_select")
	await frames(8)
	app.prepare_selected_hunt()
	var until := Time.get_ticks_msec() + 30000
	while app.screen != "hunt" and Time.get_ticks_msec() < until: await process_frame
	if app.screen != "hunt": return null
	var hunt: Control = app.hunt
	for i in 90:
		if hunt.arrival_finished: break
		await process_frame
	return hunt

func direct(app: Node) -> bool:
	return app.modal and is_instance_valid(app.overlay) and app.overlay.find_child("SoundSettingsScroll",true,false) != null and app.overlay.find_child("RunningVersionNotes",true,false) == null

func run() -> void:
	var safe := OS.get_environment("APPDATA").replace("\\","/").to_lower()
	if not safe.contains("hunt-sound-qa") or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(safe+"/"): quit(90);return
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	app.model.start_new({},true)
	app.application_active = true
	app.model.state.hunt_cleared = 12
	var hunt := await wait_hunt(app,2)
	if not is_instance_valid(hunt): quit(91);return
	var icon: DemoButton = hunt.find_child("HuntPreparationSound",true,false)
	if not is_instance_valid(icon): quit(92);return
	ck(hunt.arrival_finished and hunt.placement_grid.visible and icon.is_visible_in_tree(), "1-3 real preparation with sound gear")
	var window := Rect2(Vector2.ZERO, hunt.size)
	var simulated := Rect2(Vector2(51,15),window.size-Vector2(119,37))
	hunt._fit_hunt_chrome(simulated)
	var hitbox := icon.get_global_rect()
	ck(simulated.encloses(hitbox) and hitbox.end.x > simulated.end.x - 30 and hitbox.position.y < simulated.position.y + 22, "top-right inside asymmetric safe insets")
	hunt.fit_layout()
	var seats: Array = hunt.assigned_cells.duplicate()
	var selection: int = hunt.selected_hunter
	var pan: Vector2 = hunt.pan
	var zoom: float = hunt.zoom
	await render_image("RoxHistory-Hunt-Preparation-Sound-Gear.png")
	var pos := icon.get_global_rect().get_center()
	touch(pos,true,5)
	touch(pos,false,5,true)
	await frames(4)
	ck(not app.modal, "canceled gear touch opens nothing")
	await tap(icon)
	ck(direct(app) and app.screen == "hunt", "native touch opens existing sound popup directly")
	ck(not hunt.running and hunt.transition_elapsed < 0 and hunt.preparation.visible, "opening does not start fight or change preparation")
	if not direct(app): quit(93);return
	await render_image("RoxHistory-Hunt-Sound-Settings-Direct.png")
	var slider := find_slider(app.overlay.find_child("SoundSettingsScroll",true,false))
	ck(is_instance_valid(slider) and slider.editable, "existing BGM slider available")
	if not is_instance_valid(slider): quit(94);return
	var box := slider.get_global_rect()
	var amount := Vector2(box.position.x+box.size.x*.43,box.get_center().y)
	touch(amount,true)
	touch(amount,false)
	await frames(4)
	var value: float = slider.value
	var persisted := ConfigFile.new()
	ck(value > 35 and value < 50 and int(app.settings.get_value("app","bgm_volume",0)) == int(value), "native slider touch applies BGM")
	ck(persisted.load(app.prefs_path) == OK and int(persisted.get_value("app","bgm_volume",0)) == int(value), "slider value persisted to actual isolated preferences")
	var body: Vector2 = hunt.battlefield.get_global_transform()*hunt.ALLY_CELLS[seats[0]]
	touch(body-Vector2(0,20),true,2)
	drag(body+Vector2(85,20),2)
	touch(body+Vector2(85,20),false,2)
	await frames(7)
	ck(hunt.assigned_cells == seats and hunt.selected_hunter == selection and hunt.drag_pointer == -2 and hunt.pan.is_equal_approx(pan) and is_equal_approx(hunt.zoom,zoom) and not hunt.running, "modal prevents formation drag, zoom and battle")
	if not direct(app): await tap(icon)
	var back: Control = app.overlay.find_child("SoundSettingsBack",true,false)
	await tap(back)
	ck(not app.modal and app.screen == "hunt" and app.hunt == hunt and hunt.assigned_cells == seats, "popup back arrow returns to same formation and no general menu")
	await tap(icon)
	var close: Control = app.overlay.find_child("ModalClose",true,false)
	await tap(close)
	ck(not app.modal and app.hunt == hunt and hunt.assigned_cells == seats, "popup X returns to same formation")
	await tap(icon)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await frames(7)
	ck(not app.modal and app.hunt == hunt and not hunt.exit_popup and hunt.assigned_cells == seats, "Escape closes only the sound popup")
	await tap(icon)
	ck(int(find_slider(app.overlay.find_child("SoundSettingsScroll",true,false)).value) == int(value), "reopening reads saved volume")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(7)
	ck(not app.modal and app.hunt == hunt and not hunt.exit_popup and hunt.assigned_cells == seats, "Android back closes only the sound popup")
	await tap(icon)
	var start: Control = hunt.find_child("StartBattle",true,false)
	await tap(start)
	ck(not hunt.running and hunt.transition_elapsed < 0 and hunt.assigned_cells == seats, "tap behind the popup is not forwarded to StartBattle")
	if app.modal: app.close_modal(); await frames(7)
	await tap(start)
	ck(hunt.transition_elapsed >= 0 and not icon.is_visible_in_tree() and not app.modal, "gear disappears as VS begins")
	var n := 0
	while hunt.transition_elapsed >= 0 and n < 120:
		await process_frame
		n += 1
	ck(hunt.running and not icon.is_visible_in_tree(), "gear is absent in combat")
	hunt = await wait_hunt(app,0)
	if not is_instance_valid(hunt): quit(95);return
	icon = hunt.find_child("HuntPreparationSound",true,false)
	ck(icon.is_visible_in_tree() and hunt.chapter_one_solo, "same gear on actual 1-1 preparation")
	app.show_screen("hunt_select")
	await frames(5)
	app.show_game_settings()
	await frames(7)
	app.show_sound_settings()
	await frames(7)
	ck(direct(app), "existing general settings sound entry still uses same modal")
	var legacy_back: Callable = app.overlay.get_meta("back_action")
	ck(legacy_back.get_method() == &"show_game_settings", "general settings keeps its existing back route")
	back = app.overlay.find_child("SoundSettingsBack",true,false)
	back.pressed.emit()
	await frames(7)
	ck(app.modal and app.overlay.find_child("RunningVersionNotes",true,false) != null, "general settings callback still returns to general settings")
	print("HUNT_SOUND ", total, " checks, ", failed, " failures")
	quit(failed)
