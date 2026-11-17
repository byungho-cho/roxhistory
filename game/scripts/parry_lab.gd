extends Control

signal exited

const Trial := preload("res://scripts/parry_trial.gd")
const Hunt := preload("res://scripts/deer_hunt_screen.gd")
const LabAudio := preload("res://scripts/hunt_audio.gd")
const Art := preload("res://scripts/hunt_match_art.gd")
const SIZE := Vector2(960,540)
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
var actors: Array[HybridCharacter] = []
var boar: TextureRect
var shield: Polygon2D
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
	header_title = make_label("실험실 · 우람 받아치기",Rect2(),20)
	header_title.reparent(self,false)
	exit_button = make_icon_button("×","실험실 나가기",func(): exited.emit())
	results_button = make_icon_button("▤","테스트 결과 열기",open_results)
	retry_button = make_icon_button("↻","재도전",retry_round)
	status = make_label("",Rect2(245,73,470,33),21)
	stars = make_label("✦  ✧  ✦",Rect2(576,164,90,25),21)
	stars.modulate = Color("ffe29b")
	var field := Node2D.new()
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
	var uram := actors[0] as Hunt.COMBAT_PREVIEW
	uram.spear.hide()
	shield = Polygon2D.new()
	shield.polygon = PackedVector2Array([Vector2(-21,-20),Vector2(0,-29),Vector2(21,-20),Vector2(16,10),Vector2(0,24),Vector2(-16,10)])
	shield.color = Color("835934")
	uram.add_child(shield)
	var rim := Line2D.new()
	rim.points = shield.polygon
	rim.closed = true
	rim.width = 4
	rim.default_color = Color("d2a156")
	shield.add_child(rim)
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
	feedback = Control.new()
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.z_index = 4
	canvas.add_child(feedback)
	feedback.draw.connect(draw_feedback)
	build_results()
	resized.connect(fit)
	fit()
	restart()

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
	const TARGET := 48.0
	const MARGIN := 4.0
	var left := region.position.x+MARGIN
	var right := region.end.x-TARGET-MARGIN
	var top := region.position.y+MARGIN
	exit_button.position = Vector2(left,top)
	results_button.position = Vector2(right,top)
	retry_button.position = Vector2(right,region.end.y-TARGET-MARGIN)
	var title_width := maxf(0,2.0*minf(size.x*.5-left-TARGET,right-size.x*.5))
	header_title.add_theme_font_size_override("font_size",clampi(int(title_width/10),11,20))
	header_title.size = Vector2(title_width,TARGET)
	header_title.position = Vector2((size.x-title_width)*.5,top)
	results.scale = Vector2.ONE*factor
	results.position = region.get_center()-results.size*factor*.5

func make_icon_button(symbol: String, description: String, action: Callable) -> Button:
	var item := make_button(symbol,Rect2(0,0,48,48),action)
	item.reparent(self,false)
	item.tooltip_text = description
	item.add_theme_font_size_override("font_size",22)
	return item

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
	results.position = Vector2(123,98)
	results.size = Vector2(714,344)
	results.z_index = 5
	var background := StyleBoxFlat.new()
	background.bg_color = Color("30271e")
	background.border_color = Color("ae8b56")
	background.set_border_width_all(2)
	background.set_corner_radius_all(12)
	results.add_theme_stylebox_override("panel",background)
	results_overlay.add_child(results)
	var heading := make_label("우람 받아치기 · 테스트 결과",Rect2(15,12,684,32),22)
	heading.reparent(results,false)
	report_box = TextEdit.new()
	report_box.position = Vector2(24,83)
	report_box.size = Vector2(666,174)
	report_box.editable = false
	report_box.add_theme_font_size_override("font_size",9)
	report_box.add_theme_color_override("font_readonly_color",Color("f2e5cf"))
	result_summary = make_label("",Rect2(24,44,666,34),18)
	result_summary.reparent(results,false)
	report_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	results.add_child(report_box)
	copied = make_label("",Rect2(24,258,666,23),14)
	copied.reparent(results,false)
	result_buttons.append(make_button("테스트 결과 복사",Rect2(24,284,206,34),copy_report))
	result_buttons.append(make_button("닫기",Rect2(552,284,138,34),close_results))

	for button in result_buttons: button.reparent(results,false)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_id >= 0: return
			var buttons: Array = result_buttons if showing_result else card_buttons + skill_buttons + [exit_button,results_button,retry_button]
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

func open_results() -> void:
	if reports.is_empty(): return
	copied.text = ""
	showing_result = true
	results_overlay.show()

func close_results() -> void:
	showing_result = false
	results_overlay.hide()

func retry_round() -> void:
	if round_done and not showing_result: restart()

func restart() -> void:
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
	retry_button.hide()
	results_button.disabled = reports.is_empty()
	close_results()
	status.show()
	refresh(trial.start)

func use_skill(index: int) -> void:
	if showing_result or round_done: return
	var now := Time.get_ticks_msec()
	var previous_hp := trial.boar_hp
	var previous_party_hp := trial.party_hp
	advance_trial(now)
	if index == 0:
		var had_normal := trial.normal_defense
		var previous_input := trial.input
		if trial.party_hp < previous_party_hp:
			show_damage(now,trial.party_hp-previous_party_hp,true)
		trial.parry(now)
		if previous_input < 0 and trial.outcome == "성공": mark_contact("parry",now)
		if not had_normal and trial.normal_defense: normal_at = now
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
	lab_audio.cue({"parry":"S11","spear":"S16","cooperation":"S20"}[kind])

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

func _process(_delta: float) -> void:
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
	var clip := "Hit_Reaction" if (reacting and success) or defending else "Combat_Idle"
	uram.show_combat_pose(Vector2(1,.28),clip,clampf(float(now-normal_at)/380.0,0,1) if defending else brace_age if reacting else fposmod(now*.001,1.8)/1.8)
	shield.visible = reacting or defending
	shield.position = Vector2(40-36*sin(minf(brace_age*3.4,1)*PI*.5),-62)
	shield.rotation = -.22*sin(brace_age*PI)
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
