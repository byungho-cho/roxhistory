extends Node

var model: GameState
var world: DemoWorld
var canvas: CanvasLayer
var ui: Control
var stage: Control
var overlay: Control
var joystick: DemoJoystick
var resources: Label
var objective: Label
var context: Label
var gather_button: DemoButton
var build_button: DemoButton
var task_bar: ProgressBar
var toast_label: Label
var toast_time := 0.0
var screen := ""
var modal := false
var task := ""
var task_target := ""
var application_active := true
var task_remaining := 0.0
var task_total := 0.0
var autosave := 0.0
var settings := ConfigFile.new()
var prefs_path := "user://preferences.cfg"
var test_mode := false
var safe := Vector2(24,18)
var w := 960.0
var h := 540.0
var rebuilding := false
var audio: AudioStreamPlayer

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	test_mode = "--test-ui" in OS.get_cmdline_user_args()
	if test_mode:
		prefs_path = "user://tests/preferences.cfg"
	settings.load(prefs_path)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(2646)
	for i in 1323:
		samples.encode_s16(i*2,int(sin(float(i)*TAU*660.0/22050.0)*3000*(1.0-float(i)/1323.0)))
	wav.data = samples
	audio.stream = wav
	model = GameState.new(SaveStore.new("user://tests/session" if test_mode else "user://"))
	model.changed.connect(update_hud)
	model.failed.connect(show_error)
	canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.theme = DemoArt.theme()
	canvas.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_layout)
	show_screen("onboarding" if not settings.get_value("app","welcomed",false) else "title")

func queue_layout() -> void:
	if rebuilding:
		return
	rebuilding = true
	call_deferred("relayout")

func relayout() -> void:
	rebuilding = false
	if modal:
		close_modal()
	cancel_task()
	show_screen(screen)

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func show_screen(next: String) -> void:
	if is_instance_valid(joystick):
		joystick.clear()
	clear_children(ui)
	overlay = null
	modal = false
	screen = next
	w = get_viewport().get_visible_rect().size.x
	h = get_viewport().get_visible_rect().size.y
	safe = Vector2(24,18)
	if OS.has_feature("android"):
		var area := DisplayServer.get_display_safe_area()
		var physical := DisplayServer.screen_get_size()
		if physical.x > 0 and physical.y > 0:
			safe.x = maxf(24,maxf(area.position.x,physical.x-area.end.x)*w/physical.x)
			safe.y = maxf(18,maxf(area.position.y,physical.y-area.end.y)*h/physical.y)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(world):
		world.visible = screen == "play"
		world.set_process_mode(Node.PROCESS_MODE_INHERIT if screen == "play" else Node.PROCESS_MODE_DISABLED)
	if screen != "play":
		menu_background(screen == "region")
	match screen:
		"onboarding": onboarding()
		"title": title_screen()
		"region": region_screen()
		"play": play_hud()
	toast_label = label(stage,"",18,Color("fff3d6"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.position = Vector2(w*0.18,h-178)
	toast_label.size = Vector2(w*0.64,65)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_color_override("font_outline_color",Color("30251c"))
	toast_label.add_theme_constant_override("outline_size",8)
	if screen == "title" and not model.store.message.is_empty():
		toast(model.store.message,8)

func box(parent: Node, rect: Rect2, dark: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",DemoArt.panel(dark))
	parent.add_child(p)
	p.position = rect.position
	p.size = rect.size
	return p

func column(parent: Node, spacing: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",spacing)
	parent.add_child(v)
	return v

func label(parent: Node, text: String, font_size: int = 20, color: Color = Color("49321e")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func paragraph(parent: Node, text: String, font_size: int = 19, color: Color = Color("eee5d5")) -> Label:
	var l := label(parent,text,font_size,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func button(parent: Node, text: String, callback: Callable, primary: bool = false, icon_key: String = "") -> DemoButton:
	var b := DemoButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(80,68)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal",DemoArt.button_style(true))
	if not icon_key.is_empty():
		b.icon = DemoArt.icon(icon_key)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",42)
		b.add_theme_constant_override("h_separation",8)
	b.pressed.connect(callback)
	b.pressed.connect(func():
		if settings.get_value("app","sound",false): audio.play())
	parent.add_child(b)
	return b

func back_button(callback: Callable) -> DemoButton:
	var b := button(stage,"",callback)
	b.position = safe
	b.size = Vector2(68,68)
	var style := DemoArt.panel(true)
	style.bg_color = Color(0.15,0.15,0.15,0.8)
	style.set_corner_radius_all(34)
	b.add_theme_stylebox_override("normal",style)
	b.icon = preload("res://assets/figma/fac42.svg")
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width",36)
	return b

func picture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	t.position = rect.position
	t.size = rect.size
	return t

func menu_background(map: bool = false) -> void:
	var b := picture(stage,preload("res://assets/figma/3eebe.png") if map else preload("res://assets/figma/98398.png"),Rect2(0,0,w,h))
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.22)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	shade.size = Vector2(w,h)

func onboarding() -> void:
	label(stage,"RoxHistory",30,Color("fff0d1")).position = safe
	var panel := box(stage,Rect2(w*0.17,80,w*0.66,h-122))
	var v := column(panel,10)
	var icon := TextureRect.new()
	icon.texture = DemoArt.icon("hut")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size.y = 65
	v.add_child(icon)
	var heading := label(v,"당신의 여정이 시작됩니다",28,Color("fff1d6"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := paragraph(v,"강가의 작은 터전에서\n나만의 이야기를 만들어 보세요.",20)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	v.add_child(row)
	for sound in [false,true]:
		var b := button(row,"소리 켜고 시작" if sound else "소리 없이 시작",func(): welcome(sound),sound,"horn")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paragraph(v,"소리 설정은 게임 안에서 바꿀 수 있습니다.",15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func welcome(sound: bool) -> void:
	settings.set_value("app","welcomed",true)
	settings.set_value("app","sound",sound)
	if settings.save(prefs_path) != OK:
		show_error("첫 실행 설정을 저장하지 못했습니다. 저장 공간을 확인해 주세요.")
		return
	show_screen("title")

func title_screen() -> void:
	label(stage,"RoxHistory",52,Color("fff0d1")).position = Vector2(safe.x+10,40)
	label(stage,"작은 불씨에서 시작되는 우리의 역사",21,Color("fff0d1")).position = Vector2(safe.x+14,110)
	var p := box(stage,Rect2(w-350-safe.x,h*0.32,350,h*0.57))
	var v := column(p,10)
	label(v,"당신의 여정",21,Color("eee5d5"))
	var continue_btn := button(v,"이어서 하기",enter_game,true,"hut")
	continue_btn.disabled = model.state.is_empty()
	button(v,"새로 시작",new_game_prompt,false,"compass")
	button(v,"데모 안내",show_about,false,"scroll")
	label(stage,"1장 · 선사시대의 첫 불씨   |   v0.1.3-hybrid",17,Color("fff0d1")).position = Vector2(safe.x+10,h-safe.y-30)

func new_game_prompt() -> void:
	if not model.state.is_empty() or model.store.blocked:
		show_modal("새 여정을 시작할까요?","현재 진행을 초기화합니다. 기존 저장 파일은 별도 보존됩니다.",[
			{"text":"돌아가기","action":close_modal},{"text":"초기화하고 시작","action":func(): close_modal(); show_screen("region"),"primary":true}])
	else:
		show_screen("region")

func region_screen() -> void:
	back_button(func(): show_screen("title"))
	label(stage,"첫 터전을 고르세요",34,Color("fff0d1")).position = Vector2(safe.x+90,safe.y+5)
	label(stage,"신석기 · 암사동 강변",18,Color("fff0d1")).position = Vector2(safe.x+92,safe.y+52)
	var amsa := button(stage,"암사동\n신석기 · 선택됨",func(): toast("암사동을 선택했습니다."),true,"hut")
	amsa.position = Vector2(w*0.25,h*0.48)
	amsa.size = Vector2(230,88)
	for row in [["전곡리 · 준비 중",Vector2(w*0.37,h*0.25)],["동삼동 · 준비 중",Vector2(w*0.49,h*0.73)]]:
		var b := button(stage,row[0],func(): toast("후속 데모에서 만나요."),false,"hut")
		b.position = row[1]
		b.size = Vector2(215,72)
	var p := box(stage,Rect2(w-286-safe.x,115,286,h-150))
	var v := column(p,12)
	var art := TextureRect.new()
	art.texture = DemoArt.icon("hut")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size.y = 92
	v.add_child(art)
	label(v,"암사동",32,Color("fff1d6"))
	paragraph(v,"신석기 · 강변의 생활\n나무와 돌을 모아 첫 보금자리를 지어 보세요.",18).size_flags_vertical = Control.SIZE_EXPAND_FILL
	button(v,"이곳에서 시작",start_region,true,"compass")
	label(stage,"현대 해안선 참고 · 지형과 표식은 구성용 이미지",14,Color("fff0d1")).position = Vector2(safe.x,h-36)

func start_region() -> void:
	if model.start_new():
		if is_instance_valid(world):
			remove_child(world)
			world.queue_free()
			world = null
		enter_game()

func enter_game() -> void:
	if model.state.is_empty():
		return
	if not is_instance_valid(world):
		world = DemoWorld.new(model)
		add_child(world)
	world.player.set_character_3d(false if test_mode else settings.get_value("app","character_3d",true))
	show_screen("play")
	if not model.state.intro_seen:
		var c := DemoConfig.get_data()
		show_modal("첫 보금자리","이 강변에서 새 삶을 시작해 보세요.\n\n왼쪽 조이스틱: 이동\n반짝이는 자원 가까이에서 채집\n나무 %d · 돌 %d를 모아 금빛 원에서 건설\n\n진행은 자동 저장됩니다." % [c.wood_cost,c.stone_cost],[
			{"text":"여정 시작","primary":true,"action":func():
				var next := model.state.duplicate(true)
				next.intro_seen = true
				if model.commit(next): close_modal()}])
	elif model.state.built and not model.state.reward_claimed:
		completion()

func play_hud() -> void:
	back_button(pause_game)
	var location_title := label(stage,"암사동 · 첫 보금자리",21,Color("fff0d1"))
	location_title.position = Vector2(safe.x+86,safe.y)
	location_title.add_theme_color_override("font_outline_color",Color("30291e"))
	location_title.add_theme_constant_override("outline_size",7)
	var res_panel := box(stage,Rect2(w-350-safe.x,safe.y,350,58),false)
	resources = label(res_panel,"",18)
	resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var quest_panel := box(stage,Rect2(w-288-safe.x,94,288,100),false)
	objective = paragraph(quest_panel,"",18,Color("49321e"))
	joystick = DemoJoystick.new()
	stage.add_child(joystick)
	joystick.position = Vector2(safe.x+14,h-safe.y-154)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	stage.add_child(row)
	row.position = Vector2(w-400-safe.x,h-safe.y-90)
	row.size = Vector2(400,82)
	gather_button = button(row,"채집",gather_action,true,"wood")
	gather_button.custom_minimum_size = Vector2(126,82)
	build_button = button(row,"건설",build_action,false,"hut")
	build_button.custom_minimum_size = Vector2(126,82)
	var journal := button(row,"임무",quest_details,false,"scroll")
	journal.custom_minimum_size = Vector2(124,82)
	context = label(stage,"",18,Color("fff0d1"))
	context.position = Vector2(w*0.28,h-158)
	context.size = Vector2(w*0.48,38)
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context.add_theme_color_override("font_outline_color",Color("352717"))
	context.add_theme_constant_override("outline_size",6)
	task_bar = ProgressBar.new()
	task_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_bar.show_percentage = false
	task_bar.position = Vector2(w*0.33,h-115)
	task_bar.size = Vector2(w*0.26,12)
	stage.add_child(task_bar)
	task_bar.visible = false
	update_hud()

func update_hud() -> void:
	if screen != "play" or not is_instance_valid(resources) or model.state.is_empty():
		return
	resources.text = "나무 %d   돌 %d   씨앗 %d" % [model.state.wood,model.state.stone,model.state.tokens]
	if model.state.built:
		objective.text = "첫 보금자리 · 완료\n"+("보상을 받았습니다." if model.state.reward_claimed else "보상을 받아 주세요.")
	else:
		var c := DemoConfig.get_data()
		objective.text = "첫 보금자리\n나무 %d/%d  ·  돌 %d/%d" % [mini(model.state.wood,c.wood_cost),c.wood_cost,mini(model.state.stone,c.stone_cost),c.stone_cost]

func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0 and is_instance_valid(toast_label): toast_label.text = ""
	if screen != "play" or not is_instance_valid(world):
		return
	var direction := Vector2.ZERO
	if not modal and application_active:
		if is_instance_valid(joystick): direction = joystick.value
		var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if keyboard.length() > 0: direction = keyboard.normalized()
	world.player.direction = direction
	world.player.presentation_paused = modal or not application_active
	if task != "":
		var cancel := modal
		if task == "gather":
			var n := world.nearest()
			cancel = cancel or str(n.get("id","")) != task_target or direction.length() > 0.12
		else:
			cancel = cancel or not world.near_site() or direction.length() > 0.12
		if cancel:
			cancel_task()
			toast("작업 범위를 벗어나 멈췄습니다.")
		else:
			task_remaining -= delta
			task_bar.value = (1.0-task_remaining/task_total)*100
			if task_remaining <= 0: finish_task()
	var near := world.nearest()
	gather_button.disabled = modal or task != "" or near.is_empty()
	build_button.disabled = modal or task != "" or model.state.built or not world.near_site()
	if task == "":
		context.text = ""
		if world.near_site() and not model.state.built:
			context.text = "보금자리 터 · 건설 가능" if model.can_build() else "보금자리 터 · 나무와 돌을 모아 주세요"
		elif not model.state.built and world.player.position.distance_to(world.site.position) < 150:
			context.text = "보금자리 터 아래쪽 입구로 이동해 주세요"
		elif not near.is_empty():
			context.text = ("나무" if near.kind == "wood" else "돌")+" · 채집 버튼을 누르세요"
	autosave += delta
	if autosave >= 8 and not modal and task == "":
		autosave = 0
		model.save_position(world.player.position)

func gather_action() -> void:
	if modal or task != "" or screen != "play": return
	var n := world.nearest()
	if n.is_empty(): return
	task = "gather"
	world.player.face_target(DemoConfig.point(n.position))
	world.player.set_activity("gather")
	task_target = n.id
	task_total = float(DemoConfig.get_data().gather_seconds)
	task_remaining = task_total
	task_bar.visible = true
	context.text = "채집 중… 범위를 벗어나면 멈춥니다"

func build_action() -> void:
	if modal or task != "" or model.state.built or not world.near_site(): return
	var c := DemoConfig.get_data()
	if not model.can_build():
		toast("자원이 부족합니다. 나무 %d · 돌 %d가 필요해요." % [c.wood_cost,c.stone_cost])
		return
	show_modal("첫 보금자리 건설","나무 %d · 돌 %d를 사용해 이곳에 움집을 짓습니다." % [c.wood_cost,c.stone_cost],[
		{"text":"돌아가기","action":close_modal},{"text":"건설 시작","primary":true,"action":func():
			close_modal()
			task = "build"
			world.player.face_target(world.site.position)
			world.player.set_activity("build")
			task_total = float(DemoConfig.get_data().build_seconds)
			task_remaining = task_total
			task_bar.visible = true
			context.text = "보금자리 건설 중…"}])

func finish_task() -> void:
	var kind := task
	var target := task_target
	cancel_task()
	if kind == "gather":
		if model.gather(target,world.player.position):
			var resource := "나무" if target.begins_with("wood") else "돌"
			toast("%s +%d · 저장 완료" % [resource,DemoConfig.get_data().gather_yield])
			if model.can_build(): toast("재료가 모였어요! 금빛 원으로 돌아가 건설해 주세요.",5)
	elif kind == "build" and model.build(world.player.position):
		completion()

func cancel_task() -> void:
	task = ""
	task_target = ""
	if is_instance_valid(world): world.player.set_activity("")
	if is_instance_valid(task_bar): task_bar.visible = false

func completion() -> void:
	if model.state.reward_claimed: return
	var reward: int = DemoConfig.get_data().reward
	show_modal("첫 보금자리 완성!","강변에 나의 첫 움집이 생겼습니다.\n완료 보상: 씨앗 %d개\n\n저장 후 앱을 종료하고 이어하기를 확인해 보세요." % reward,[
		{"text":"보상 받고 계속하기","primary":true,"action":func():
			if model.claim_reward(): close_modal(); toast("보상 저장 완료",5)}])

func quest_details() -> void:
	if model.state.built and not model.state.reward_claimed:
		completion()
		return
	var c := DemoConfig.get_data()
	var text := "완료한 임무입니다. 씨앗 %d개를 보유하고 있습니다." % model.state.tokens
	if not model.state.reward_claimed:
		text = "① 반짝이는 자원 가까이 이동\n② 나무 %d · 돌 %d 채집\n③ 금빛 원 안에서 건설\n④ 보상 받기" % [c.wood_cost,c.stone_cost]
	show_modal("첫 보금자리",text,[{"text":"돌아가기","action":close_modal}])

func pause_game() -> void:
	cancel_task()
	model.save_position(world.player.position)
	show_modal("잠시 쉬어 가기","암사동 · 첫 보금자리\n진행은 기기에 자동 저장됩니다.",[
		{"text":"계속하기","primary":true,"action":close_modal},
		{"text":"시작 화면","action":func(): close_modal(); show_screen("title")},
		{"text":"2D로 비교" if world.player.use_3d else "3D로 비교","action":toggle_character},
		{"text":"안내·소리","action":show_about}])

func toggle_character() -> void:
	var enabled: bool = not world.player.use_3d
	world.player.set_character_3d(enabled)
	settings.set_value("app","character_3d",enabled)
	if settings.save(prefs_path) != OK: show_error("비교 설정을 저장하지 못했습니다.")
	else: close_modal()

func show_about() -> void:
	var c := DemoConfig.get_data()
	var sound: bool = settings.get_value("app","sound",false)
	show_modal("RoxHistory · v0.1.3-hybrid",c.history.fact+"\n\n"+c.history.fiction+"\n\n이 데모의 소리는 조작 효과음만 제공합니다. 씨앗은 완료 기념 보상입니다.",[
		{"text":"소리 끄기" if sound else "소리 켜기","action":func():
			settings.set_value("app","sound",not sound)
			if settings.save(prefs_path) != OK: show_error("소리 설정을 저장하지 못했습니다.")
			else: show_about()},
		{"text":"돌아가기","primary":true,"action":close_modal}])

func show_modal(title: String, body: String, actions: Array) -> void:
	if is_instance_valid(joystick): joystick.clear()
	cancel_task()
	if is_instance_valid(world):
		world.player.direction = Vector2.ZERO
		world.player.presentation_paused = true
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
	modal = true
	overlay = Control.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var width := minf(680,w-safe.x*2)
	var height := minf(h-safe.y*2,500)
	var p := box(overlay,Rect2((w-width)/2,(h-height)/2,width,height))
	var v := column(p,12)
	label(v,title,28,Color("fff1d6"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var text := paragraph(scroll,body,20)
	text.custom_minimum_size.x = width-60
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	v.add_child(row)
	for a in actions:
		var b := button(row,a.text,a.action,a.get("primary",false))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",17)

func close_modal() -> void:
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
	overlay = null
	modal = false
	if is_instance_valid(joystick): joystick.clear()
	if is_instance_valid(world): world.player.presentation_paused = not application_active

func toast(message: String, seconds: float = 3.0) -> void:
	if is_instance_valid(toast_label): toast_label.text = message
	toast_time = seconds

func show_error(message: String) -> void:
	call_deferred("display_error",message)

func display_error(message: String) -> void:
	cancel_task()
	show_modal("저장 확인",message+"\n저장 공간을 확인한 뒤 다시 시도해 주세요.",[{"text":"확인","action":close_modal}])

func go_back() -> void:
	if modal:
		close_modal()
	elif screen == "play": pause_game()
	elif screen == "region": show_screen("title")
	else:
		show_modal("여정을 나갈까요?","앱을 종료합니다.",[{"text":"돌아가기","action":close_modal},{"text":"종료","action":func(): get_tree().quit()}])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and screen == "play" and not modal:
		if event.physical_keycode == KEY_E: gather_action()
		elif event.physical_keycode == KEY_B: build_action()

func _notification(what: int) -> void:
	# Synthetic tests issue PAUSED/RESUMED explicitly; desktop focus is external.
	if test_mode and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_active = false
		if is_instance_valid(joystick): joystick.clear()
		cancel_task()
		if is_instance_valid(world) and screen == "play":
			world.player.direction = Vector2.ZERO
			world.player.presentation_paused = true
			model.save_position(world.player.position)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_active = true
		if is_instance_valid(world): world.player.presentation_paused = modal
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(world): model.save_position(world.player.position)
		get_tree().quit()
