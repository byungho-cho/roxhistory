extends "res://scripts/model_test.gd"

const HanModel = preload("res://battlefield_reset/han_motion/han_motion_viewer.gd")
const CLIPS := [
	["idle_02_11"], ["listen"], ["talk"], ["angry"], ["cheer"],
	["walk_native"], ["run_native"], ["decel"], ["meshy_draw222"],
	["clear_basic"], ["sp2"], ["sp3"], ["normal_179"], ["heavy_173"],
	["knock_190"], ["story_stand"], ["dead"], ["story_fly", "story_stand"],
]
const REPEATS := [0, 5, 6]
const WALK := 5
const RUN := 6
const DECELERATE := 7
const CHAIN := 11
const KNOCKDOWN := 14
const FALL_AND_RISE := 17
const DECELERATE_DISTANCE := .36

var han := HybridCharacter.new()
var model: HanModel
var floor_label: Label
var ground_dim: ColorRect
var neutral_support := 0.0
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
	han.viewport.size = HanModel.MODEL_TEST_VIEW_SIZE
	han.camera.size = HanModel.MODEL_TEST_CAMERA_SIZE
	model = HanModel.new()
	model.duel_binding = true
	han.add_child(model)
	if not model.bind_duel(han.pivot, null, han.camera):
		push_error("The approved Han model could not be started")
		return
	model.sample_han_clip("idle_02_11", 0.0)
	neutral_support = model._story_support()
	ground_dim = ColorRect.new()
	ground_dim.mouse_filter = MOUSE_FILTER_IGNORE
	ground_dim.color = Color(0, 0, 0, 0)
	field.add_child(ground_dim)
	# The dim layer affects the battlefield art while the character and controls stay clear.
	field.move_child(ground_dim, 1)
	ground_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floor_label = text(field, "한결", Rect2(0, 0, 82, 36), 22)
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color("162e2a")
	badge.set_corner_radius_all(6)
	floor_label.add_theme_stylebox_override("normal", badge)
	for index in CLIPS.size():
		var key := "%02d" % (index + 1)
		var button_rect := Rect2((index % 10) * 139, floori(index / 10.0) * 64, 132, 57)
		var title: String = "날아감 · 착지\n일어서기" if index == 17 else motion_title(index)
		var item := button(motions, title, button_rect, play_motion.bind(key))
		item.name = "HanMotion" + key
		item.add_theme_font_size_override("font_size", 17)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.tooltip_text = motion_title(index)
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
	han.scale = Vector2.ONE * (HanModel.MODEL_TEST_SCALE * field.size.x / 960.0)
	motions.position.y = field.size.y - 145
	render_frame()

func motion_title(index: int) -> String:
	return "넉다운" if index == KNOCKDOWN else HanModel.TITLES[index]

func play_motion(id: String) -> void:
	if not motion_buttons.has(id):
		return
	selection = id
	age = 0.0
	shown_motion = 0
	steps.clear()
	reel_duration = 0.0
	var distance := 0.0
	var motion_ids := range(CLIPS.size()) if id == "full" else [id.to_int() - 1]
	for index in motion_ids:
		for clip: String in CLIPS[index]:
			var length := model.ap.get_animation(clip).length
			var begin := .72 if clip in ["heavy_173", "knock_190"] else 0.0
			var finish := minf(length, 1.78) if clip == "meshy_draw222" else length
			var repeated: bool = index in [WALK, RUN] and (id == "full" or route)
			var span := (finish - begin) * (2.0 if repeated else 1.0)
			if index == CHAIN:
				span = HanModel.cinematic_duration(length)
			elif clip == "story_fly":
				span = HanModel.STORY_FLY_SECONDS
			var end_distance := distance
			if route and index in [WALK, RUN]:
				end_distance += model.gait_distance(clip, span)
			elif route and index == DECELERATE:
				end_distance += DECELERATE_DISTANCE
			elif route and clip == "story_fly":
				end_distance -= HanModel.story_flight_retreat(1.0)
			steps.append({
				"index": index, "clip": clip, "begin": begin, "length": finish - begin,
				"start": reel_duration, "until": reel_duration + span, "repeated": repeated,
				"from": distance, "to": end_distance,
			})
			reel_duration += span
			distance = end_distance
	render_frame()
	refresh()

func _route_space(distance: float) -> Vector2:
	var world := han.pivot.basis.z * distance
	var projected := han.camera.unproject_position(world) - han.camera.unproject_position(Vector3.ZERO)
	return projected * han.display.scale * han.scale

func render_frame() -> void:
	if steps.is_empty():
		return
	var loop: bool = selection != "full" and not route and steps[0].index in REPEATS
	var local_time := fposmod(age, reel_duration) if loop else age
	var step: Dictionary = steps.back()
	for candidate in steps:
		if local_time < candidate.until:
			step = candidate
			break
	var offset := clampf(local_time - step.start, 0.0, step.until - step.start)
	var complete := not loop and age >= reel_duration
	var return_idle: bool = complete and (selection == "full" or step.index not in [KNOCKDOWN, 16])
	var progress := offset / maxf(.001, step.until - step.start)
	if step.index == DECELERATE:
		progress = 1.0 - (1.0 - progress) * (1.0 - progress)
	elif step.clip == "story_fly":
		progress = HanModel.story_flight_retreat(HanModel.story_flight_clock(offset)) / HanModel.story_flight_retreat(1.0)
	var distance := lerpf(step.from, step.to, progress)
	if route and step.index in [WALK, RUN]:
		distance = step.from + model.gait_distance(step.clip, offset)
	han.position = Vector2(field.size.x * .5, field.size.y * .55) + _route_space(distance)
	floor_label.position = han.position + Vector2(-41, 17)
	han.pivot.position.y = 0.0
	ground_dim.color.a = HanModel.cinematic_dim_alpha(offset) if step.index == CHAIN and not return_idle else 0.0
	if return_idle:
		var idle_length := model.ap.get_animation("idle_02_11").length
		model.sample_han_clip("idle_02_11", fposmod(age - reel_duration, idle_length))
	else:
		_sample_step(step, offset)
	shown_motion = int(step.index) + 1
	var label := "대기" if return_idle else motion_title(step.index)
	motion_status.text = "%s · %s배속" % [label, rate]

func _sample_step(step: Dictionary, time: float) -> void:
	var clip_time := fposmod(time, step.length) if step.repeated else time
	if step.index == CHAIN:
		clip_time = HanModel.cinematic_motion_time(time)
	elif step.clip == "story_fly":
		var motion_time := HanModel.story_flight_clock(time)
		clip_time = .16 + minf(motion_time, .58) * 1.20
	model.sample_han_clip(step.clip, step.begin + clip_time, step.index in [WALK, RUN, DECELERATE, 8])
	if step.clip == "story_fly":
		var motion_time := HanModel.story_flight_clock(time)
		var lift := HanModel.story_flight_height(motion_time) - .20 * smoothstep(.43, .60, motion_time)
		han.pivot.position.y = clampf(neutral_support + lift - model._story_support(), -.9, 1.05)
	elif step.index == FALL_AND_RISE and step.clip == "story_stand":
		var floor_blend := .23 * (1.0 - smoothstep(.2, 1.24, time))
		han.pivot.position.y = clampf(neutral_support - model._story_support() - floor_blend, -.9, .9)

func refresh() -> void:
	for id in motion_buttons:
		skin(motion_buttons[id], SILVER if id == "full" else BLUE if id == selection else GOLD)
	for value in speed_buttons:
		skin(speed_buttons[value], ROUND_GOLD if value == rate else ROUND_SILVER)
	show_switch(battle_button, battle)
	show_switch(route_button, route)
	status.text = "한결 · 전체 모션" if selection == "full" else "한결"
	motion_status.text = "%s · %s배속" % [motion_title(maxi(0, shown_motion - 1)), rate]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_duel()
		return
	super(event)
