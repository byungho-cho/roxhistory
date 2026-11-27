extends "res://scripts/model_test.gd"

const HanModel = preload("res://battlefield_reset/han_motion/han_motion_viewer.gd")
const CLIPS := [
	["idle_02_11"], ["listen"], ["talk"], ["angry"], ["cheer"],
	["walk_native"], ["run_native"], ["decel"], ["meshy_draw222"],
	["clear_basic"], ["sp2"], ["sp3"], ["normal_179"], ["heavy_173"],
	["gahui_impact", "knock_190"], ["story_stand"], ["dead"], ["story_fly", "story_stand"],
]
const REPEATS := [0, 5, 6]

var han := HybridCharacter.new()
var model: HanModel
var floor_label: Label
var steps: Array[Dictionary] = []
var reel_duration := 0.0
var shown_motion := 0

func build_selectors() -> void:
	back_button.tooltip_text = "1대1 대결 테스트로 돌아가기"
	for link in back_button.pressed.get_connections():
		back_button.pressed.disconnect(link.callable)
	back_button.pressed.connect(_return_to_duel)
	model_buttons.hangyeol = icon_button(selectors, "hangyeol", Rect2(84, 0, 68, 68), play_motion.bind("01"))

func start_preview() -> void:
	name = "HanModelTest"
	battle = true
	running_button.hide()
	field.add_child(han)
	field.move_child(han, 1)
	han.set_enabled(true)
	han.viewport.size = Vector2i(960, 720)
	han.camera.size = 7.0
	model = HanModel.new()
	model.duel_binding = true
	han.add_child(model)
	if not model.bind_duel(han.pivot, null, han.camera):
		push_error("The approved Han model could not be started")
		return
	floor_label = text(field, "한결", Rect2(0, 0, 82, 36), 22)
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color("162e2a")
	badge.set_corner_radius_all(6)
	floor_label.add_theme_stylebox_override("normal", badge)
	for index in CLIPS.size():
		var key := "%02d" % (index + 1)
		var button_rect := Rect2((index % 10) * 139, floori(index / 10.0) * 64, 132, 57)
		var item := button(motions, HanModel.TITLES[index], button_rect, play_motion.bind(key))
		item.name = "HanMotion" + key
		item.add_theme_font_size_override("font_size", 17)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.tooltip_text = HanModel.TITLES[index]
		motion_buttons[key] = item
	var full := button(motions, "전체 모션", Rect2(8 * 139, 64, 132, 57), play_motion.bind("full"))
	full.name = "HanAllMotions"
	motion_buttons.full = full
	configure_camera()
	play_motion("01")

func _return_to_duel() -> void:
	app.call_deferred("return_to_one_on_one_lab")

func configure_camera() -> void:
	han.camera.position = Vector3(0, 7.45 if battle else 3.6, 6)
	han.camera.look_at(Vector3(0, 1.45, 0))
	var facing: Vector2 = Hunt.DEER_SLOT - Hunt.HUNTER_BATTLE_CENTER if battle else Vector2.DOWN
	han.pivot.rotation.y = Hunt.battlefield_ground_heading(han.camera, facing)
	han.display.position = -han.camera.unproject_position(Vector3.ZERO) * han.display.scale

func toggle_battle() -> void:
	battle = not battle
	configure_camera()
	render_frame()
	refresh()

func layout_actors() -> void:
	if not is_instance_valid(floor_label):
		return
	han.scale = Vector2.ONE * (.99 * field.size.x / 960.0)
	motions.position.y = field.size.y - 145
	render_frame()

func play_motion(id: String) -> void:
	if not motion_buttons.has(id):
		return
	selection = id
	age = 0.0
	shown_motion = 0
	steps.clear()
	reel_duration = 0.0
	var motion_ids := range(CLIPS.size()) if id == "full" else [id.to_int() - 1]
	for index in motion_ids:
		for clip: String in CLIPS[index]:
			var clip_length := model.ap.get_animation(clip).length
			var begin := 0.72 if clip in ["heavy_173", "knock_190"] else 0.0
			var finish := minf(clip_length, 1.78) if clip == "meshy_draw222" else clip_length
			var span := (finish - begin) * (2.0 if index in [5, 6] and (id == "full" or route) else 1.0)
			steps.append({"index": index, "clip": clip, "begin": begin, "length": finish - begin, "until": reel_duration + span})
			reel_duration += span
	render_frame()
	refresh()

func render_frame() -> void:
	if steps.is_empty():
		return
	var loop: bool = selection != "full" and not route and steps[0].index in REPEATS
	var local_time := fposmod(age, reel_duration) if loop else age
	var step_start := 0.0
	var step: Dictionary = steps.back()
	for candidate in steps:
		step = candidate
		if local_time < step.until or step == steps.back():
			break
		step_start = step.until
	var offset := clampf(local_time - step_start, 0.0, step.until - step_start)
	var complete: bool = not loop and age >= reel_duration
	var return_idle: bool = complete and (selection == "full" or step.index not in [14, 16])
	var traveled := Vector2.ZERO
	if route and step.index in [5, 6, 7] and not return_idle:
		var path_dir := Vector2(.82, -.36) if battle else Vector2(1, .28)
		traveled = path_dir * minf(1.0, offset / (step.until - step_start)) * field.size.x * .12
	han.position = Vector2(field.size.x * .5, field.size.y * .55) + traveled
	floor_label.position = han.position + Vector2(-41, 17)
	if return_idle:
		model.sample_han_clip("idle_02_11", fposmod(age - reel_duration, model.ap.get_animation("idle_02_11").length))
	else:
		var repeated: bool = step.until - step_start > step.length
		var clip_time := fposmod(offset, step.length) if repeated else offset
		model.sample_han_clip(step.clip, step.begin + clip_time, step.index in [5, 6, 8])
	shown_motion = int(step.index) + 1
	var label: String = "대기" if return_idle else HanModel.TITLES[step.index]
	motion_status.text = "%s · %s배속" % [label, rate]

func refresh() -> void:
	for id in motion_buttons:
		skin(motion_buttons[id], SILVER if id == "full" else BLUE if id == selection else GOLD)
	for value in speed_buttons:
		skin(speed_buttons[value], ROUND_GOLD if value == rate else ROUND_SILVER)
	show_switch(battle_button, battle)
	show_switch(route_button, route)
	status.text = "한결 · 전체 모션" if selection == "full" else "한결"
	motion_status.text = "%s · %s배속" % [HanModel.TITLES[maxi(0, shown_motion - 1)], rate]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_duel()
		return
	super(event)
