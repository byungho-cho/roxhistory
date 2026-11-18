extends Control

signal exited

const Trial := preload("res://scripts/parry_trial.gd")
const Hunt := preload("res://scripts/deer_hunt_screen.gd")
const LabAudio := preload("res://scripts/hunt_audio.gd")
const UramRig := preload("res://scripts/uram_lab_rig.gd")
const AppearanceComparison := preload("res://scripts/uram_appearance_comparison.gd")
const Res011Preview := preload("res://scripts/res011_lab_preview.gd")
const AllMotion := preload("res://scripts/lab_all_motion.gd")
const CHARACTERS := {"uram":"우람","hangyeol":"한결","saebom":"새봄","all":"모두"}
const PREVIEW_NAMES := {"hangyeol":"점프 찌르기 R03","saebom":"돌팔매"}
const URAM_STRIKE := preload("res://assets/audio/lab-uram-res009/strike-c.mp3")
const URAM_HURT := preload("res://assets/audio/lab-uram-res009/hurt-a.mp3")
const URAM_PARRY := preload("res://assets/audio/lab-uram-res009/parry-c.mp3")
const HURT_PREVIEW_CUE_S := .10
const STRIKE_CONTACT_RATIO := .50
const PARRY_CONTACT_RATIO := .29
const FULL_STRIKE_CONTACT_S := 236.0/60.0
const FULL_PARRY_CONTACT_S := 322.0/60.0
const MOTIONS := {"idle":"대기","walk":"걷기","run":"달리기","club_attack":"둔기 공격","hit_reaction":"피격","parry":"받아치기","full_motion":"합본"}
const LOOP_MOTIONS := ["idle","walk","run"]
const Art := preload("res://scripts/hunt_match_art.gd")
const SIZE := Vector2(960,540)
const URAM_PREVIEW_LABEL := "우람 · 자연색 1안 리터치"
const MOTION_RENDER_SCALE := .75
const RESULTS_SIZE := Vector2(1000,344)
const SCREEN_MARGIN := 24.0
const CONTROL_TARGET := 48.0
const GOLD_BUTTON := preload("res://assets/ui/d0026/common-gold-default.svg")
const SAPPHIRE_BUTTON := preload("res://assets/ui/d0026/common-sapphire-default.svg")
const CLOSE_ICON := preload("res://assets/ui/d0020/popup-close-charcoal.svg")
const RESULTS_ICON := preload("res://assets/ui/d0024/08-ui-rules-book.svg")
const HOMES := [Vector2(500,306), Vector2(535,272), Vector2(543,326)]
const BOAR_HOME := Vector2(665,236)
const CONTACT := Vector2(557,270)
const BRACE := Vector2(541,278)
const SKILLS := [
	preload("res://assets/ui/d0036/uram-parry.png"),
	preload("res://assets/ui/d0027/skill-stab-A.png"),
	preload("res://assets/ui/d0027/skill-cooperation-A.png")
]

var app: Node
var canvas: Control
var field: Node2D
var uram_preview: UramRig
var motion_hurt_played := false
var motion_canvas: Control
var motion_status: Label
var motion_caption: Label
var motion_buttons: Dictionary = {}
var comparison_button: Button
var appearance_comparison: AppearanceComparison
var all_motion: AllMotion
var all_motion_buttons: Dictionary = {}
var mode_buttons: Dictionary = {}
var character_buttons: Dictionary = {}
var selected_character := "uram"
var model_preview: Res011Preview
var model_age := 0.0
var mode := ""
var motion_clip := ""
var motion_age := 0.0
var actors: Array[HybridCharacter] = []
var boar: TextureRect
var status: Label
var stars: Label
var damage: Label
var skill_buttons: Array[Button] = []
var card_buttons: Array[Button] = []
var result_summary: Label
var result_buttons: Array[Button] = []
var exit_button: Button
var results_button: Button
var retry_button: Button
var header_title: Label
var results_overlay: ColorRect
var round_done := false
var touch_id := -1
var touch_button: Button
var report_finger := -1
var report_drag_origin := 0.0
var report_scroll_origin := 0.0
var bars: Array[ProgressBar] = []
var enemy_bar: ProgressBar
var results: Panel
var report_box: TextEdit
var copied: Label
var trial: Trial
var reports: Array[String] = []
var rounds := 0
var frames := 0
var normal_at := -1
var followup_at: Array[int] = [-1,-1]
var damage_at := -1
var showing_result := false
var lab_audio: LabAudio
var feedback: Control
var guide_target := -1
var guide_at := 0
var warning_played := false
var impacts: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var ground := Art.picture(self,Hunt.CLEARING,Rect2())
	ground.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas = Art.layer(self,Vector2.ZERO)
	header_title = make_label("실험실 · 모델 테스트",Rect2(),20)
	header_title.reparent(self,false)
	exit_button = make_icon_button("","실험실 나가기",func(): exited.emit(),CLOSE_ICON)
	results_button = make_icon_button("","테스트 결과 열기",open_results,RESULTS_ICON)
	retry_button = make_icon_button("↻","재도전",retry_round)
	status = make_label("",Rect2(245,154,470,33),21)
	stars = make_label("✦  ✧  ✦",Rect2(576,164,90,25),21)
	stars.modulate = Color("ffe29b")
	field = Node2D.new()
	field.y_sort_enabled = true
	canvas.add_child(field)
	for i in 3:
		var hunter: HybridCharacter = Hunt.COMBAT_PREVIEW.new() if i == 0 else HybridCharacter.new()
		if i == 2: hunter.model_path = HybridCharacter.MESHY_HUNT_MODEL
		hunter.render_size_factor = .5
		field.add_child(hunter)
		hunter.camera.position.y = 7.05
		hunter.camera.look_at(Vector3(0,1.45,0))
		hunter.display.position = -hunter.camera.unproject_position(Vector3.ZERO)*hunter.display.scale
		hunter.scale = Vector2.ONE*.56
		hunter.position = HOMES[i]
		if i != 0: hunter.use_training_spear()
		hunter.set_enabled(true)
		actors.append(hunter)
	boar = Art.picture(canvas,preload("res://assets/ui/d0024/05-boar-settled-pose.png"),Rect2(0,0,94,70))
	boar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boar.pivot_offset = Vector2(47,66)
	enemy_bar = make_hp(Rect2(0,0,70,8),Color("c35c46"))
	damage = make_label("",Rect2(0,0,76,32),20)
	damage.modulate = Color("ffd494")
	var tray := Panel.new()
	tray.position = Vector2(328,438)
	tray.size = Vector2(304,100)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(tray)
	var names := ["우람","한결","새봄"]
	for i in 3:
		var x := 344.0+92.0*i
		var card := make_button("",Rect2(x,445,86,86),use_skill.bind(i))
		card.name = "SkillCard%d"%i
		for style in ["normal","hover","pressed","disabled","focus"]:
			card.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		Art.picture(card,Hunt.CARD_PORTRAITS[[1,0,2][i]],Rect2(0,0,86,86))
		card.enable_art_feedback()
		card_buttons.append(card)
		for orb in 3:
			Art.picture(canvas,Hunt.CHARGE_FULL,Rect2(x+14+21*orb,438,16,5))
		skill_buttons.append(make_button("",Rect2(x+9,367,68,68),use_skill.bind(i)))
		Art.picture(skill_buttons[i],SKILLS[i],Rect2(3,3,62,62))
		skill_buttons[i].tooltip_text = ["우람 받아치기","한결 찌르기","새봄 협동"][i]
		make_label(names[i],Rect2(x,506,86,23),14)
		bars.append(make_hp(Rect2(x+6,532,74,7),Color("76ac55")))
	lab_audio = LabAudio.new()
	add_child(lab_audio)
	lab_audio.streams["boar_warning"] = preload("res://assets/ui/d0024/06-sfx-boar-hoof.wav")
	lab_audio.streams["uram_strike"] = URAM_STRIKE
	lab_audio.streams["uram_hurt"] = URAM_HURT
	lab_audio.streams["uram_parry"] = URAM_PARRY
	feedback = Control.new()
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.z_index = 4
	canvas.add_child(feedback)
	feedback.draw.connect(draw_feedback)
	build_test_picker()
	build_results()
	resized.connect(fit)
	fit()
	canvas.hide()
	motion_canvas.hide()
	retry_button.hide()
	retry_button.disabled = true
	results_button.disabled = true
	for actor in actors: actor.set_enabled(false)

func build_test_picker() -> void:
	motion_canvas = Art.layer(self,Vector2.ZERO)
	motion_status = make_label("동작을 선택해 주세요",Rect2(230,162,500,42),24)
	motion_status.reparent(motion_canvas,false)
	motion_caption = make_label(URAM_PREVIEW_LABEL,Rect2(355,357,250,30),18)
	motion_caption.reparent(motion_canvas,false)
	comparison_button = make_button("외형 비교",Rect2(747,139,126,38),toggle_appearance_comparison)
	comparison_button.name = "UramAppearanceComparison"
	apply_game_button_art(comparison_button)
	comparison_button.reparent(motion_canvas,false)
	comparison_button.hide()
	var index := 0
	for key: String in MOTIONS:
		var control := make_button(MOTIONS[key],Rect2(150+96*index,444,90,42),select_motion.bind(key))
		control.toggle_mode = true
		apply_game_button_art(control)
		control.reparent(motion_canvas,false)
		motion_buttons[key] = control
		index+=1
	for key in ["parry","motion"]:
		var title := "전용 스킬 테스트" if key=="parry" else "모션 테스트"
		var control := make_button(title,Rect2(0,0,166,42),select_mode.bind(key))
		control.toggle_mode = true
		apply_game_button_art(control)
		control.reparent(self,false)
		mode_buttons[key]=control
	for key: String in CHARACTERS:
		var control := make_button(CHARACTERS[key],Rect2(0,0,91,40),select_character.bind(key))
		control.toggle_mode = true
		apply_game_button_art(control)
		control.set_pressed_no_signal(key==selected_character)
		control.reparent(self,false)
		character_buttons[key] = control

func select_character(value: String) -> void:
	if not CHARACTERS.has(value): return
	for key in character_buttons:
		character_buttons[key].set_pressed_no_signal(key==value)
	if selected_character==value: return
	reset_test()
	selected_character=value
	mode_buttons.parry.visible = value!="all"
	if is_instance_valid(model_preview):
		model_preview.set_enabled(false)
		model_preview.queue_free()
		model_preview=null
	results_button.disabled = value!="uram" or reports.is_empty()
	fit()
	if value=="all": select_mode("motion")

func select_mode(value: String) -> void:
	if not mode_buttons.has(value): return
	if selected_character=="all" and value!="motion": return
	if mode==value:
		mode_buttons[value].set_pressed_no_signal(true)
		return
	reset_test()
	mode=value
	mode_buttons[value].set_pressed_no_signal(true)
	if selected_character=="all":
		open_all_motion()
		return
	if selected_character!="uram":
		start_model_review()
		return
	canvas.visible=mode=="parry"
	motion_canvas.visible=mode=="motion"
	motion_caption.text=URAM_PREVIEW_LABEL
	for control: Button in motion_buttons.values(): control.show()
	comparison_button.visible = mode=="motion"
	for i in range(1,actors.size()):
		actors[i].set_enabled(mode=="parry")
	place_uram_preview(mode=="motion")
	if mode=="parry":
		restart()
	else:
		uram_preview.show_pose("idle",0.0)
		motion_status.text="동작을 선택해 주세요"
		results_button.disabled=reports.is_empty()

func toggle_appearance_comparison() -> void:
	if mode!="motion" or selected_character!="uram": return
	if is_instance_valid(appearance_comparison):
		close_appearance_comparison()
		for control: Button in motion_buttons.values(): control.show()
		motion_status.show()
		motion_caption.show()
		uram_preview.set_enabled(true)
		if not motion_clip.is_empty():
			retry_button.disabled = false
			retry_button.show()
		results_button.disabled = reports.is_empty()
		return
	appearance_comparison = AppearanceComparison.new()
	appearance_comparison.name = "AppearanceComparison"
	motion_canvas.add_child(appearance_comparison)
	appearance_comparison.build()
	comparison_button.text = "외형 비교 닫기"
	for control: Button in motion_buttons.values(): control.hide()
	motion_status.hide()
	motion_caption.hide()
	uram_preview.set_enabled(false)
	lab_audio.update(false,false)
	retry_button.hide()
	results_button.disabled = true

func close_appearance_comparison() -> void:
	if not is_instance_valid(appearance_comparison): return
	appearance_comparison.hide()
	appearance_comparison.queue_free()
	appearance_comparison = null
	comparison_button.text = "외형 비교"

func reset_test() -> void:
	close_appearance_comparison()
	if is_instance_valid(all_motion):
		all_motion.hide()
		all_motion.queue_free()
		all_motion = null
		all_motion_buttons.clear()
	comparison_button.hide()
	motion_status.show()
	motion_caption.show()
	mode=""
	trial=null
	lab_audio.update(false,false)
	impacts.clear()
	close_results()
	motion_clip=""
	motion_age=0.0
	model_age=0.0
	retry_button.hide()
	retry_button.disabled=true
	for control: Button in mode_buttons.values(): control.set_pressed_no_signal(false)
	for control: Button in motion_buttons.values(): control.set_pressed_no_signal(false)
	canvas.hide()
	motion_canvas.hide()
	for actor in actors: actor.set_enabled(false)
	if is_instance_valid(uram_preview): uram_preview.set_enabled(false)
	if is_instance_valid(model_preview): model_preview.set_enabled(false)

func open_all_motion() -> void:
	motion_canvas.show()
	motion_status.hide()
	motion_caption.hide()
	for control: Button in motion_buttons.values(): control.hide()
	all_motion = AllMotion.new()
	all_motion.name = "AllMotionComparison"
	motion_canvas.add_child(all_motion)
	results_button.disabled = true
	for key in AllMotion.MOTIONS:
		var index := all_motion_buttons.size()
		var control := make_button(AllMotion.MOTIONS[key],Rect2(74+116*index,437,110,42),select_all_motion.bind(key))
		control.name = "AllMotion_"+key
		control.toggle_mode = true
		apply_game_button_art(control)
		control.reparent(all_motion,false)
		all_motion_buttons[key] = control
	fit()

func select_all_motion(key: String) -> void:
	if not is_instance_valid(all_motion): return
	all_motion.play(key)
	for id in all_motion_buttons:
		all_motion_buttons[id].set_pressed_no_signal(id==key)
	retry_button.disabled = false
	retry_button.show()

func start_model_review() -> void:
	motion_canvas.show()
	for control: Button in motion_buttons.values(): control.hide()
	if not is_instance_valid(model_preview):
		model_preview = Res011Preview.new()
		model_preview.character = selected_character
		model_preview.render_size_factor = Res011Preview.MOTION_RENDER_FACTOR
		model_preview.position = Vector2(480,Res011Preview.MOTION_GROUND_Y)
		model_preview.scale = Vector2.ONE*Res011Preview.MOTION_DISPLAY_SCALE
		motion_canvas.add_child(model_preview)
		motion_canvas.move_child(model_preview,0)
	model_preview.set_enabled(true)
	motion_status.text = PREVIEW_NAMES[selected_character]+" · 1회"
	motion_caption.text = CHARACTERS[selected_character]
	model_age=0.0
	model_preview.sample(0.0)
	results_button.disabled=true
	retry_button.disabled=false
	retry_button.show()

func place_uram_preview(for_motion: bool) -> void:
	var holder: Node = motion_canvas if for_motion else field
	if not is_instance_valid(uram_preview):
		uram_preview = UramRig.new()
		uram_preview.use_retouch = true
		uram_preview.render_size_factor = .5
		holder.add_child(uram_preview)
		uram_preview.camera.position = actors[0].camera.position
		uram_preview.camera.look_at(Vector3(0,1.45,0))
		uram_preview.pivot.rotation.y = atan2(1,.28)
		uram_preview.scale = actors[0].scale*(1.35*1.5)
	elif uram_preview.get_parent()!=holder:
		uram_preview.reparent(holder,false)
	if for_motion: motion_canvas.move_child(uram_preview,0)
	uram_preview.position = Vector2(480,285) if for_motion else HOMES[0]
	fit_rig_view(uram_preview,for_motion)
	uram_preview.set_enabled(true)

func fit_rig_view(preview: UramRig, full_map: bool) -> void:
	var battle_size := actors[0].viewport.size
	var battle_zoom := actors[0].camera.size
	var battle_display_scale := actors[0].display.scale
	preview.camera.h_offset = 0.0
	preview.camera.v_offset = 0.0
	preview.viewport.size = Vector2i(SIZE*MOTION_RENDER_SCALE) if full_map else battle_size
	preview.camera.size = battle_zoom
	preview.display.scale = battle_display_scale
	if full_map:
		# The viewport covers the entire logical map at reduced render resolution.
		preview.camera.size *= SIZE.y / (battle_size.y * battle_display_scale.y * preview.scale.y)
		preview.display.scale = Vector2.ONE / (preview.scale*MOTION_RENDER_SCALE)
		var center := preview.camera.unproject_position(Vector3.ZERO)
		var anchor := preview.position * MOTION_RENDER_SCALE
		var units_per_pixel := preview.camera.size / preview.viewport.size.y
		preview.camera.h_offset = (center.x - anchor.x) * units_per_pixel
		preview.camera.v_offset = (anchor.y - center.y) * units_per_pixel
	preview.display.position = -preview.camera.unproject_position(Vector3.ZERO) * preview.display.scale

func select_motion(key: String) -> void:
	if mode!="motion": return
	for cue in ["uram_strike","uram_parry","uram_hurt"]:
		lab_audio.stop_cue(cue)
	motion_clip=key
	motion_age=0.0
	motion_hurt_played=false
	for item in motion_buttons: motion_buttons[item].set_pressed_no_signal(item==key)
	motion_status.text=MOTIONS[key]+(" · 반복" if key in LOOP_MOTIONS else " · 1회")
	retry_button.disabled=false
	retry_button.show()
	uram_preview.show_pose(key,0.0)

func advance_motion(delta: float) -> void:
	if motion_clip.is_empty(): return
	var before := motion_age
	motion_age+=delta
	var length := uram_preview.clip_length(motion_clip)
	# The live miss hits Hangeol, not Uram. Audition Uram's hurt only in his dedicated pose preview.
	if motion_clip=="hit_reaction" and not motion_hurt_played and motion_age>=HURT_PREVIEW_CUE_S:
		motion_hurt_played=true
		lab_audio.cue("uram_hurt")
	if motion_clip in LOOP_MOTIONS:
		uram_preview.show_pose(motion_clip,fposmod(motion_age,length))
	elif motion_age<length:
		uram_preview.show_pose(motion_clip,motion_age)
	else:
		uram_preview.show_pose("idle",fposmod(motion_age-length,uram_preview.clip_length("idle")))
	match motion_clip:
		"club_attack": preview_contact(before,length*STRIKE_CONTACT_RATIO,"uram_strike")
		"parry": preview_contact(before,length*PARRY_CONTACT_RATIO,"uram_parry")
		"full_motion":
			preview_contact(before,FULL_STRIKE_CONTACT_S,"uram_strike")
			preview_contact(before,FULL_PARRY_CONTACT_S,"uram_parry")

func preview_contact(before: float, at: float, cue: String) -> void:
	if before < at and motion_age >= at:
		lab_audio.cue(cue)

func fit() -> void:
	var region := Rect2(Vector2.ZERO,size)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		if safe.has_area() and physical.x > 0 and physical.y > 0:
			region = Rect2(Vector2(safe.position)*size/physical,Vector2(safe.size)*size/physical)
	var factor := minf(region.size.x/SIZE.x,region.size.y/SIZE.y)
	canvas.scale = Vector2.ONE*factor
	canvas.position = region.position+(region.size-SIZE*factor)*.5
	motion_canvas.scale = canvas.scale
	motion_canvas.position = canvas.position
	var left := region.position.x+SCREEN_MARGIN
	var right := region.end.x-CONTROL_TARGET-SCREEN_MARGIN
	var top := region.position.y+SCREEN_MARGIN
	exit_button.position = Vector2(left,top)
	results_button.position = Vector2(right,top)
	retry_button.position = Vector2(right,region.end.y-CONTROL_TARGET-SCREEN_MARGIN)
	var middle := region.get_center().x
	for index in character_buttons.size():
		character_buttons[CHARACTERS.keys()[index]].position=Vector2(middle-196+100*index,top+43)
	mode_buttons.parry.position=Vector2(middle-172,top+88)
	mode_buttons.motion.position=Vector2(middle-83 if selected_character=="all" else middle+6,top+88)
	var title_width := maxf(0,2.0*minf(size.x*.5-left-CONTROL_TARGET,right-size.x*.5))
	header_title.add_theme_font_size_override("font_size",clampi(int(title_width/10),11,20))
	header_title.size = Vector2(title_width,CONTROL_TARGET)
	header_title.position = Vector2((size.x-title_width)*.5,top)
	var popup_factor := minf(factor,(region.size.x-SCREEN_MARGIN*2.0)/RESULTS_SIZE.x)
	results.scale = Vector2.ONE*popup_factor
	results.position = region.get_center()-RESULTS_SIZE*popup_factor*.5

func make_icon_button(symbol: String, description: String, action: Callable, icon: Texture2D = null) -> Button:
	var item := make_button(symbol,Rect2(Vector2.ZERO,Vector2.ONE*CONTROL_TARGET),action)
	item.reparent(self,false)
	item.tooltip_text = description
	item.add_theme_font_size_override("font_size",22)
	apply_game_button_art(item)
	if icon:
		item.icon = icon
		item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_theme_constant_override("icon_max_width",23)
		var ink := Color("654522") if icon == RESULTS_ICON else Color.WHITE
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:
			var property: String = "icon_normal_color" if state=="normal" else "icon_"+state+"_color"
			item.add_theme_color_override(property,Color(ink,.55) if state=="disabled" else ink)
	return item

func apply_game_button_art(item: Button) -> void:
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var selected: bool = state in ["pressed","hover_pressed"] and item.toggle_mode
		var skin := StyleBoxTexture.new()
		skin.texture = SAPPHIRE_BUTTON if selected else GOLD_BUTTON
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			skin.set_texture_margin(side,7)
		skin.modulate_color = Color(.76,.69,.55,.7) if state=="disabled" else Color.WHITE
		item.add_theme_stylebox_override(state,skin)
		var ink := Color("fff3d0") if selected else Color("502c12")
		item.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",ink)

func make_label(value: String, rect: Rect2, px: int) -> Label:
	var item: Label = app.label(canvas,value,px,Color("fff3d0"))
	item.position = rect.position
	item.size = rect.size
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.add_theme_color_override("font_outline_color",Color("262019"))
	item.add_theme_constant_override("outline_size",5)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func make_button(value: String, rect: Rect2, action: Callable) -> Button:
	var item := DemoButton.new()
	item.text = value
	item.position = rect.position
	item.size = rect.size
	item.focus_mode = Control.FOCUS_NONE
	item.pivot_offset = rect.size*.5
	item.pressed.connect(action)
	canvas.add_child(item)
	return item

func make_hp(rect: Rect2, tint: Color) -> ProgressBar:
	var item := ProgressBar.new()
	item.position = rect.position
	item.size = rect.size
	item.show_percentage = false
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(3)
	item.add_theme_stylebox_override("fill",fill)
	canvas.add_child(item)
	return item

func build_results() -> void:
	results_overlay = ColorRect.new()
	results_overlay.color = Color(0,0,0,.48)
	results_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(results_overlay)
	results_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	results_overlay.hide()
	results = Panel.new()
	results.size = RESULTS_SIZE
	results.z_index = 5
	var background := StyleBoxFlat.new()
	background.bg_color = Color("30271e")
	background.border_color = Color("ae8b56")
	background.set_border_width_all(2)
	background.set_corner_radius_all(12)
	results.add_theme_stylebox_override("panel",background)
	results_overlay.add_child(results)
	var content := SharedPopupArt.content_rect(RESULTS_SIZE)
	var heading := make_label("우람 받아치기 · 테스트 결과",Rect2(content.position,Vector2(content.size.x,32)),22)
	heading.reparent(results,false)
	report_box = TextEdit.new()
	report_box.position = Vector2(content.position.x,98)
	report_box.size = Vector2(content.size.x,144)
	report_box.editable = false
	report_box.add_theme_font_size_override("font_size",13)
	report_box.add_theme_color_override("font_readonly_color",Color("f2e5cf"))
	result_summary = make_label("",Rect2(content.position.x,62,content.size.x,34),18)
	result_summary.reparent(results,false)
	report_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	results.add_child(report_box)
	copied = make_label("",Rect2(content.position.x,245,content.size.x,23),14)
	copied.reparent(results,false)
	result_buttons.append(make_button("테스트 결과 복사",Rect2(content.end-Vector2(356,44),Vector2(206,44)),copy_report))
	result_buttons.append(make_button("닫기",Rect2(content.end-Vector2(138,44),Vector2(138,44)),close_results))

	for button in result_buttons:
		apply_game_button_art(button)
		button.reparent(results,false)

func _input(event: InputEvent) -> void:
	if showing_result and scroll_report(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_id >= 0: return
			var buttons: Array = result_buttons if showing_result else [exit_button,results_button,retry_button] + character_buttons.values() + mode_buttons.values()
			if not showing_result:
				if mode=="parry": buttons.append_array(card_buttons+skill_buttons)
				elif mode=="motion":
					buttons.append(comparison_button)
					buttons.append_array(motion_buttons.values())
					buttons.append_array(all_motion_buttons.values())
			for button in buttons:
				if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
					touch_id = event.index
					touch_button = button
					get_viewport().set_input_as_handled()
					break
		elif event.index == touch_id:
			var button := touch_button
			touch_id = -1
			touch_button = null
			get_viewport().set_input_as_handled()
			if not event.canceled and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
	elif event is InputEventScreenDrag and event.index == touch_id:
		if is_instance_valid(touch_button) and not touch_button.get_global_rect().has_point(event.position):
			touch_button = null
		get_viewport().set_input_as_handled()

func scroll_report(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and report_finger == -1 and report_box.get_global_rect().has_point(event.position):
			report_finger = event.index
			report_drag_origin = event.position.y
			report_scroll_origin = report_box.get_v_scroll_bar().value
			return true
		if not event.pressed and event.index == report_finger:
			report_finger = -1
			return true
	elif event is InputEventScreenDrag and event.index == report_finger:
		var line_height := report_box.get_line_height()*results.scale.y
		report_box.get_v_scroll_bar().value = report_scroll_origin+(report_drag_origin-event.position.y)/line_height
		return true
	return false

func open_results() -> void:
	if reports.is_empty(): return
	copied.text = ""
	showing_result = true
	results_overlay.show()

func close_results() -> void:
	report_finger = -1
	showing_result = false
	results_overlay.hide()

func retry_round() -> void:
	if showing_result: return
	if is_instance_valid(all_motion):
		if not all_motion.selection.is_empty(): select_all_motion(all_motion.selection)
		return
	if selected_character!="uram":
		if not mode.is_empty(): start_model_review()
		return
	if mode=="parry": restart()
	elif mode=="motion" and not motion_clip.is_empty(): select_motion(motion_clip)

func restart() -> void:
	lab_audio.update(false,false)
	lab_audio.recent.clear()
	lab_audio.update(app.audio.enabled,not app.application_active)
	rounds += 1
	frames = 0
	normal_at = -1
	followup_at = [-1,-1]
	damage_at = -1
	warning_played = false
	guide_target = -1
	impacts.clear()
	trial = Trial.new(Time.get_ticks_msec())
	round_done = false
	retry_button.disabled = false
	retry_button.show()
	results_button.disabled = reports.is_empty()
	close_results()
	status.show()
	skill_buttons[0].show()
	refresh(trial.start)

func use_skill(index: int) -> void:
	if mode!="parry" or trial==null or showing_result or round_done: return
	var now := Time.get_ticks_msec()
	var previous_hp := trial.boar_hp
	var previous_party_hp := trial.party_hp
	advance_trial(now)
	if index == 0:
		var had_normal := trial.normal_defense
		var pre_strike_hp := trial.boar_hp
		var previous_input := trial.input
		if trial.party_hp < previous_party_hp:
			show_damage(now,trial.party_hp-previous_party_hp,true)
		trial.parry(now)
		if previous_input < 0 and trial.outcome == "성공": mark_contact("parry",now)
		if not had_normal and trial.normal_defense:
			normal_at = now
			if trial.boar_hp < pre_strike_hp: lab_audio.cue("uram_strike")
		if previous_input < 0 and trial.input >= 0:
			refresh(now)
			trial.feedback_ms = Time.get_ticks_msec()-now
	elif trial.use_followup(index-1,now):
		followup_at[index-1] = now
		if index == 2: mark_contact("cooperation",now)
	if trial.boar_hp < previous_hp:
		show_damage(now,trial.boar_hp-previous_hp,false)
	refresh(now)

func advance_trial(now: int) -> void:
	var previous_hit := trial.hangeul_hit
	trial.advance(now)
	if not warning_played and now >= trial.warning:
		warning_played = true
		lab_audio.cue("boar_warning")
	if previous_hit < 0 and trial.hangeul_hit >= 0: mark_contact("spear",now)

func mark_contact(kind: String, now: int) -> void:
	impacts.append({"kind":kind,"at":boar.position+Vector2(46,48),"start":now})
	lab_audio.cue({"parry":"uram_parry","spear":"S16","cooperation":"S20"}[kind])

func set_guide(target: int, now: int) -> void:
	if guide_target == target: return
	guide_target = target
	guide_at = now

func draw_feedback() -> void:
	if round_done or trial == null: return
	var now := Time.get_ticks_msec()
	if guide_target > 0:
		var rect := Rect2(card_buttons[guide_target].position,card_buttons[guide_target].size).grow(3)
		feedback.draw_rect(rect,Color("eac47c"),false,1.6,true)
		var progress := clampf(float(now-guide_at)/370.0,0.0,1.0)
		if progress < 1.0 and not app.reduced_ui_motion():
			var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
			var edge := floori(progress*4.0)
			var tail: Vector2 = corners[edge].lerp(corners[(edge+1)%4],fposmod(progress*4.0,1.0))
			feedback.draw_circle(tail,4.0,Color(1,.86,.49,1.0-progress*.65),true,-1,true)
	for impact in impacts:
		var progress := clampf(float(now-int(impact.start))/250.0,0,1)
		if progress >= 1.0: continue
		var at: Vector2 = impact.at
		var texture: Texture2D = Hunt.BASIC_HIT if impact.kind == "spear" else Hunt.HEAVY_HIT if impact.kind == "parry" else Hunt.GROUND_PULSE
		var extent := Vector2.ONE*lerpf(28.0,55.0,progress)
		if impact.kind == "spear":
			var from: Vector2 = actors[1].position+Vector2(14,-21)
			feedback.draw_line(from.lerp(at,progress*.65),at,Color(1,.9,.62,1.0-progress),2.5,true)
		if impact.kind == "cooperation": extent *= Vector2(1.0,.59)
		feedback.draw_texture_rect(texture,Rect2(at-extent*.5,extent),false,Color(1,1,1,1.0-progress))

func show_damage(now: int, amount: int, ally: bool) -> void:
	damage_at = now
	damage.text = str(amount)
	damage.position = (HOMES[1] if ally else boar.position+Vector2(47,12))-Vector2(38,52)

func _process(delta: float) -> void:
	if is_instance_valid(all_motion):
		if app.application_active: all_motion.advance(delta)
		return
	if selected_character!="uram":
		if is_instance_valid(model_preview) and app.application_active and model_age<model_preview.duration():
			model_age=minf(model_age+delta,model_preview.duration())
			model_preview.sample(model_age)
		return
	if mode=="motion":
		if is_instance_valid(appearance_comparison): return
		lab_audio.update(app.audio.enabled,not app.application_active)
		advance_motion(delta)
		return
	if round_done or trial == null: return
	frames += 1
	lab_audio.update(app.audio.enabled,not app.application_active)
	var now := Time.get_ticks_msec()
	impacts=impacts.filter(func(impact):return now-int(impact.start)<250)
	var previous_hp := trial.party_hp
	var previous_boar_hp := trial.boar_hp
	advance_trial(now)
	if trial.boar_hp < previous_boar_hp:
		show_damage(now,trial.boar_hp-previous_boar_hp,false)
	if trial.party_hp < previous_hp:
		show_damage(now,trial.party_hp-previous_hp,true)
	refresh(now)
	if trial.finished(now): end_round()

func refresh(now: int) -> void:
	var stun := trial.stun_end > now
	var success := trial.stun_end >= 0
	var charge_start := trial.impact-Trial.CHARGE_MS
	var motion_time := mini(now,trial.input) if success else now
	var charge := clampf(float(motion_time-charge_start)/Trial.CHARGE_MS,0,1)
	var retreat := clampf(float(now-(trial.impact+160))/400.0,0,1) if not success else 0.0
	var boar_at := BOAR_HOME.lerp(CONTACT,charge).lerp(BOAR_HOME,retreat)
	boar.position = boar_at-Vector2(47,66)
	var crouch := smoothstep(0.0,300.0,float(now-trial.warning))*(1.0-smoothstep(0.0,160.0,float(now-charge_start)))
	boar.scale = Vector2(1.0+crouch*.055,1.0-crouch*.14)
	boar.self_modulate = Color(1.0+crouch*.21,1.0-crouch*.10,1.0-crouch*.19)
	boar.rotation = sin(now*.025)*.08 if stun else 0.0
	enemy_bar.position = boar_at-Vector2(35,74)
	enemy_bar.value = trial.boar_hp
	stars.visible = stun
	stars.position = boar_at-Vector2(45,101)+Vector2(sin(now*.012)*9,cos(now*.012)*3)
	var reacting := trial.input >= 0 and now-trial.input < 480
	var defending := normal_at >= 0 and now-normal_at < 380
	var brace_age := clampf(float(now-trial.input)/480.0,0,1) if reacting else 0.0
	var stepped := smoothstep(.18,.55,brace_age)
	var recovery := 1.0-smoothstep(.65,1.0,brace_age)
	var stop := CONTACT.lerp(boar_at,.65)-Vector2(18,-4)
	var uram := actors[0] as Hunt.COMBAT_PREVIEW
	uram.position = HOMES[0].lerp(stop-Vector2(19*stepped,0),recovery) if success and reacting else HOMES[0]
	uram_preview.position = uram.position
	var rig_clip := "parry" if reacting and success else "club_attack" if defending else "idle"
	var rig_time := brace_age*uram_preview.clip_length("parry") if rig_clip=="parry" else (now-normal_at)*.001 if rig_clip=="club_attack" else fposmod(now*.001,uram_preview.clip_length("idle"))
	uram_preview.show_pose(rig_clip,rig_time)
	for i in range(1,3):
		var age: int = now-followup_at[i-1]
		var attacking := followup_at[i-1] >= 0 and age < 450
		var movement := Vector2.RIGHT if attacking else Vector2.ZERO
		var beat := sin(clampf(float(age)/450,0,1)*PI)
		actors[i].position = HOMES[i]+Vector2(27,-7)*beat if attacking else HOMES[i]
		actors[i].animate(1.0/60.0,movement,now*.001,false,"hunt" if attacking else "",age*.001,false)
		bars[i].value = trial.party_hp if i == 1 else 100
	bars[0].value = 100
	skill_buttons[0].disabled = trial.input >= 0 or not trial.outcome.is_empty() or (now < trial.warning and trial.normal_defense)
	card_buttons[0].disabled = skill_buttons[0].disabled
	card_buttons[0].modulate = Color(1.35,1.23,.78) if trial.parry_window(now) else Color.WHITE
	skill_buttons[0].modulate = card_buttons[0].modulate
	for i in [1,2]:
		var ready := trial.can_followup(i-1,now)
		skill_buttons[i].disabled = not ready
		skill_buttons[i].visible = ready
		card_buttons[i].disabled = not ready
		card_buttons[i].modulate = Color.WHITE
		skill_buttons[i].scale = Vector2.ONE
	var target := -1
	if trial.can_followup(0,now): target = 1
	elif trial.hangeul_hit >= 0 and trial.can_followup(1,now): target = 2
	set_guide(target,now)
	feedback.queue_redraw()
	damage.visible = damage_at >= 0 and now-damage_at < 480
	if now < trial.warning:
		status.text = "일반 방어 · 반격" if defending else "멧돼지의 돌진 예고를 기다리세요"
	elif trial.outcome.is_empty():
		status.text = "한결을 향해 돌진!" if now >= charge_start else "멧돼지가 한결을 노립니다"
	else:
		status.text = trial.outcome + (" · 스턴" if stun else "")

func end_round() -> void:
	if round_done: return
	var now := Time.get_ticks_msec()
	var elapsed := maxi(1,now-trial.start)
	reports.append(trial.report(rounds,roundi(frames*1000.0/elapsed),now))
	round_done = true
	results_button.disabled = false
	retry_button.show()
	for button in card_buttons + skill_buttons:
		button.disabled = true
	for button in skill_buttons: button.hide()
	guide_target = -1
	impacts.clear()
	lab_audio.update(false,false)
	feedback.queue_redraw()
	var commit := str(ProjectSettings.get_setting('roxhistory/update/source_commit',''))
	if commit.is_empty(): commit = "개발 소스"
	report_box.text = "RoxHistory %s | %s | 우람 받아치기 ON\n검수 판정: 예상 충돌 %d~%dms 전 · 스턴 %dms · 새봄 2초\n기준 e977b2c\n%s" % [
		ProjectSettings.get_setting("application/config/version"),commit,-Trial.EARLIEST_MS,-Trial.LATEST_MS,Trial.STUN_MS,"\n".join(reports)]
	result_summary.text = trial.outcome if not trial.outcome.is_empty() else "중간 종료"
	copied.text = ""
	status.text = result_summary.text

func copy_report() -> void:
	DisplayServer.clipboard_set(report_box.text)
	if DisplayServer.clipboard_get().replace("\r\n","\n") == report_box.text:
		copied.text = "복사했습니다."
	else:
		report_box.grab_focus()
		report_box.select_all()
		copied.text = "복사를 확인할 수 없습니다. 위 텍스트를 직접 복사하세요."
