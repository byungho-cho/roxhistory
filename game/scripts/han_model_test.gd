extends "res://scripts/model_test.gd"

const HanModel = preload("res://battlefield_reset/han_motion/han_motion_viewer.gd")
const HanSkillImpact = preload("res://scripts/han_skill_impact.gd")
const CLIPS := [
	"retouch_idle", "retouch_listen", "retouch_talk", "retouch_angry", "retouch_cheer",
	"walk_native", "run_native", HanModel.ENTRY_CLIP, "retouch_ready",
	"retouch_basic_preview", "retouch_sp2", "retouch_chain", "retouch_hit", "retouch_heavy",
	"retouch_knockdown", "retouch_stand", "retouch_death", "retouch_flight",
]
const MOTION_RATES := {
	&"retouch_listen": 1.5, &"retouch_talk": 1.5, &"retouch_angry": 1.5, &"retouch_cheer": 1.5,
	&"walk_native": 1.5, &"retouch_travel_walk": 1.5, HanModel.ENTRY_CLIP: 1.5,
	&"retouch_basic_preview": 1.3, &"retouch_sp2": 1.75, &"retouch_chain": 1.75,
	&"retouch_knockdown": 1.5, &"retouch_stand": 2.0, &"retouch_death": 2.0, &"retouch_flight": 1.75,
}
const DRAW_OPENING_LENGTH := 1.0
const DRAW_OPENING_RATE := 1.5
const REPEATS := [0, 5, 6]
const WALK := 5
const RUN := 6
const DECELERATE := 7
const KNOCKDOWN := 14
const FALL_AND_RISE := 17
const FLIGHT_DISTANCE_MULTIPLIER := 3.0
# Contact frames in the 30 fps approved clips. The second basic starts 33 frames after the first.
const CONTACT_FRAMES := {
	&"retouch_basic_preview": [11, 44], &"retouch_sp2": [33], &"retouch_chain": [99],
}
const CONTACT_STYLES := {&"retouch_basic_preview": 1, &"retouch_sp2": 2, &"retouch_chain": 3}
const CONTACT_SECONDS := .38
const IMPACT_DRAW_SCALE := 1600.0 / 960.0

var han := HybridCharacter.new()
var model: HanModel
var floor_label: Label
var ground_dim: ColorRect
var effect_button: Button
var effects_enabled := true
var effect_layer: Control
var chain_flash_layer: Node2D
var chain_glow: GradientTexture2D
var effect_origin := Vector2.ZERO
var effect_contact := Vector2.ZERO
var effect_progress := 1.0
var effect_style := 0
var skill_frames: Array[Texture2D] = []
var chain_frames: Array[Texture2D] = []
var steps: Array[Dictionary] = []
var reel_duration := 0.0
var shown_motion := 0

func build_selectors() -> void:
	back_button.tooltip_text = ""
	for index in LAB_ROSTER.size():
		var ally: String = LAB_ROSTER[index]
		var item := icon_button(selectors, ally, Rect2(84 + index * 75, 0, 68, 68), _select_lab_ally.bind(ally), true, LAB_PORTRAITS.get(ally))
		item.name = "MotionSelect_" + ally
		item.tooltip_text = ""
		item.disabled = ally not in LAB_AVAILABLE
		item.modulate.a = .43 if item.disabled else 1.0
		if ally != "hangyeol":
			var border := item.get_theme_stylebox("normal") as StyleBoxFlat
			border.border_color = Color("8b8272")
		model_buttons[ally] = item

func _select_lab_ally(ally: String) -> void:
	if ally == "gahui":
		app.call_deferred("select_motion_lab_ally", ally)

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
	model.sample_han_clip(&"retouch_idle", 0.0)
	ground_dim = ColorRect.new()
	ground_dim.mouse_filter = MOUSE_FILTER_IGNORE
	ground_dim.color = Color(0, 0, 0, 0)
	field.add_child(ground_dim)
	# The dim layer affects the battlefield art while the character and controls stay clear.
	field.move_child(ground_dim, 1)
	ground_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toggles.position.x -= 180.0
	effect_button = switch_button("이펙트", 360.0, toggle_effects)
	effect_button.name = "MotionEffects"
	# Keep the status clear of the third switch.
	for item in [field.get_node("StatusBrush"), status, motion_status]:
		item.position.x -= 96.0
	effect_layer = Control.new()
	effect_layer.mouse_filter = MOUSE_FILTER_IGNORE
	effect_layer.draw.connect(_draw_effect)
	field.add_child(effect_layer)
	chain_flash_layer = Node2D.new()
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	chain_flash_layer.material = blend
	chain_flash_layer.draw.connect(_draw_chain_flash)
	effect_layer.add_child(chain_flash_layer)
	chain_glow = HanSkillImpact.make_contact_glow()
	skill_frames = HanSkillImpact.load_skill()
	chain_frames = HanSkillImpact.load_chain(192)
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
		motion_buttons[key] = item
	var full := button(motions, "전체 모션", Rect2(8 * 139, 64, 132, 57), play_motion.bind("full"))
	full.name = "HanAllMotions"
	motion_buttons.full = full
	configure_camera()
	play_motion("01")

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
	if index == DECELERATE:
		return "달리다 걷기"
	return "넉다운" if index == KNOCKDOWN else HanModel.TITLES[index]

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
		var clip := StringName(CLIPS[index])
		if route and index in [WALK, RUN]:
			clip = &"retouch_travel_walk" if index == WALK else &"retouch_travel_run"
		_append_step(index, clip, model.ap.get_animation(clip).length)
	render_frame()
	refresh()

func _append_step(index: int, clip: StringName, length: float) -> void:
	var motion_rate: float = MOTION_RATES.get(clip, 1.0)
	var opening_length := minf(length, DRAW_OPENING_LENGTH) if clip == &"retouch_ready" else 0.0
	var opening_span := opening_length / DRAW_OPENING_RATE
	var span := opening_span + (length - opening_length) / motion_rate
	var distance: float = 0.0 if steps.is_empty() else steps.back().to
	var end_distance := distance
	if route and clip == HanModel.ENTRY_CLIP:
		end_distance += model.entry_distance()
	elif route and (index == FALL_AND_RISE or index in [WALK, RUN]):
		end_distance += model.preview_travel(clip, length).z * (FLIGHT_DISTANCE_MULTIPLIER if index == FALL_AND_RISE else 1.0)
	steps.append({
		"index": index, "clip": clip, "length": length,
		"start": reel_duration, "until": reel_duration + span,
		"motion_rate": motion_rate, "opening_span": opening_span,
		"from": distance, "to": end_distance,
	})
	reel_duration += span

func _route_space(distance: float) -> Vector2:
	var world := han.pivot.basis.z * distance
	var projected := han.camera.unproject_position(world) - han.camera.unproject_position(Vector3.ZERO)
	return projected * han.display.scale * han.scale

func render_frame() -> void:
	if steps.is_empty():
		return
	var loop: bool = steps.size() == 1 and not route and steps[0].index in REPEATS
	var local_time := fposmod(age, reel_duration) if loop else age
	var step: Dictionary = steps.back()
	for candidate in steps:
		if local_time < candidate.until:
			step = candidate
			break
	var offset := clampf(local_time - step.start, 0.0, step.until - step.start)
	var opening_span: float = step.opening_span
	var clip_time := minf(step.length, minf(offset, opening_span) * DRAW_OPENING_RATE
		+ maxf(0.0, offset - opening_span) * step.motion_rate)
	var complete := not loop and age >= reel_duration
	var return_idle: bool = complete and (selection == "full" or step.index not in [KNOCKDOWN, 16])
	var distance: float = step.from
	var travel := model.preview_travel(step.clip, clip_time) if route or step.index == FALL_AND_RISE else Vector3.ZERO
	if route and step.index == DECELERATE:
		distance = lerpf(step.from, step.to, HanModel.entry_progress(clip_time))
	elif route:
		distance += travel.z * (FLIGHT_DISTANCE_MULTIPLIER if step.index == FALL_AND_RISE else 1.0)
	var center_offset: float = steps.back().to * .5 if selection == "08" else 0.0
	han.position = Vector2(field.size.x * .5, field.size.y * .55) + _route_space(distance - center_offset)
	floor_label.position = han.position + Vector2(-41, 17)
	han.pivot.position.y = travel.y
	_sample_effect(step.clip, clip_time, complete)
	if return_idle:
		var idle := &"retouch_guard" if step.index >= DECELERATE else &"retouch_idle"
		if step.index == DECELERATE:
			model.ready_from_entry = true
			model.show_battle_ready(age - reel_duration)
		else:
			model.sample_han_clip(idle, fposmod(age - reel_duration, model.ap.get_animation(idle).length))
	else:
		model.sample_han_clip(step.clip, clip_time)
	shown_motion = int(step.index) + 1
	var label := "대기" if return_idle else motion_title(step.index)
	motion_status.text = "%s · %s배속" % [label, rate]

func toggle_effects() -> void:
	effects_enabled = not effects_enabled
	render_frame()
	show_switch(effect_button, effects_enabled)

func _sample_effect(clip: StringName, clip_time: float, complete: bool) -> void:
	effect_progress = 1.0
	var active := effects_enabled and not complete
	ground_dim.color.a = HanModel.cinematic_dim_alpha(clip_time) if active and clip == &"retouch_chain" else 0.0
	if active and CONTACT_FRAMES.has(clip):
		var style: int = CONTACT_STYLES[clip]
		var duration := _impact_duration(style)
		for frame: int in CONTACT_FRAMES.get(clip, []):
			var contact_time := frame / 30.0
			if clip_time < contact_time or clip_time >= contact_time + duration:
				continue
			model.sample_han_clip(clip, contact_time)
			var weapon := model.approved_weapon
			effect_origin = _project_effect(weapon.global_position)
			effect_contact = _project_effect(weapon.to_global(HanModel.APPROVED_BLADE_TIP))
			effect_style = style
			effect_progress = (clip_time - contact_time) / duration
			break
	effect_layer.queue_redraw()
	chain_flash_layer.queue_redraw()

func _project_effect(point: Vector3) -> Vector2:
	return han.position + (han.display.position + han.camera.unproject_position(point) * han.display.scale) * han.scale

func _impact_duration(style: int) -> float:
	match style:
		2: return HanSkillImpact.SKILL_SECONDS
		3: return HanSkillImpact.CHAIN_SECONDS
	return CONTACT_SECONDS

func _draw_effect() -> void:
	if effect_progress >= 1.0:
		return
	var elapsed := effect_progress * _impact_duration(effect_style)
	if effect_style == 2 and not skill_frames.is_empty():
		HanSkillImpact.draw_skill(effect_layer, skill_frames, effect_contact, effect_origin.angle_to_point(effect_contact) + .57, elapsed, IMPACT_DRAW_SCALE)
	elif effect_style == 3 and not chain_frames.is_empty():
		HanSkillImpact.draw_chain(effect_layer, chain_frames, effect_contact, elapsed, IMPACT_DRAW_SCALE)
	else:
		HanModel.draw_contact_effect(effect_layer, effect_origin, effect_contact, effect_style, effect_progress)

func _draw_chain_flash() -> void:
	if effect_progress < 1.0 and effect_style == 3 and not chain_frames.is_empty():
		HanSkillImpact.draw_chain_flash(chain_flash_layer, chain_glow, effect_contact, effect_progress * HanSkillImpact.CHAIN_SECONDS, IMPACT_DRAW_SCALE)

func refresh() -> void:
	for id in motion_buttons:
		skin(motion_buttons[id], SILVER if id == "full" else BLUE if id == selection else GOLD)
	for value in speed_buttons:
		skin(speed_buttons[value], ROUND_GOLD if value == rate else ROUND_SILVER)
	show_switch(battle_button, battle)
	show_switch(route_button, route)
	show_switch(effect_button, effects_enabled)
	status.text = "한결 · 전체 모션" if selection == "full" else "한결"
	motion_status.text = "%s · %s배속" % [motion_title(maxi(0, shown_motion - 1)), rate]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exited.emit()
		return
	super(event)
