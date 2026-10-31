extends Node

var model: GameState
var world: DemoWorld
var canvas: CanvasLayer
var ui: Control
var stage: Control
var overlay: Control
var joystick: DemoJoystick
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
var gather_approach:=false
var approach_elapsed:=0.0
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
var audio: DemoSoundscape
var context_panel: PanelContainer
var toast_panel: PanelContainer
var gestures: WorldGestures
var chrome: PlayChrome

func _ready() -> void:
	gestures=WorldGestures.new(self);add_child(gestures)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	test_mode = "--test-ui" in OS.get_cmdline_user_args()
	if test_mode:
		prefs_path = "user://tests/preferences.cfg"
	settings.load(prefs_path)
	audio = DemoSoundscape.new()
	add_child(audio)
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
	if gestures: gestures.clear()
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
	var previous := screen
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
		if next != "play": world.feedback.clear_transients()
		world.visible = screen == "play"
		world.set_process_mode(Node.PROCESS_MODE_INHERIT if screen == "play" else Node.PROCESS_MODE_DISABLED)
	if screen != "play":
		menu_background(screen == "region")
	match screen:
		"onboarding": onboarding()
		"title": title_screen()
		"region": region_screen()
		"play": play_hud()
	var notice_rect := Rect2(safe.x+76,safe.y+56,minf(300,w-safe.x*2-420),48) if screen == "play" else Rect2(safe.x,h-160,minf(480,w*0.48),76)
	toast_panel = box(stage,notice_rect)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = label(toast_panel,"",17,Color("fff3d6"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.visible = false
	sync_audio()
	if next != previous:
		var fade := ColorRect.new()
		fade.color = Color("302d26")
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(fade); fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade.modulate.a = 0.45
		var transition := create_tween()
		transition.tween_property(fade,"modulate:a",0.0,0.28)
		transition.tween_callback(fade.queue_free)
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
		audio.cue("ui"))
	b.unavailable.connect(func(reason: String): toast(reason,2.5))
	parent.add_child(b)
	return b

func back_button(callback: Callable) -> DemoButton:
	var b := button(stage,"",callback)
	b.position = safe
	b.custom_minimum_size = Vector2(56,56)
	b.size = Vector2(56,56)
	var style := DemoArt.panel(true)
	style.bg_color = Color(0.15,0.15,0.15,0.8)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal",style)
	b.icon = preload("res://assets/figma/fac42.svg")
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width",30)
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

func design_rect(x: float,y: float,width: float,height: float) -> Rect2:
	var factor:=minf(w/1600.0,h/900.0)
	return Rect2((Vector2(w,h)-Vector2(1600,900)*factor)/2+Vector2(x,y)*factor,Vector2(width,height)*factor)

func design_label(parent: Node,text: String,rect: Rect2,font_size: int,color:=Color("eeeeee"),center:=false) -> Label:
	var l:=label(parent,text,font_size,color)
	l.position=rect.position;l.size=rect.size
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return l

func design_button(parent: Node,text: String,rect: Rect2,callback: Callable,primary:=false,key:="") -> DemoButton:
	var b:=button(parent,text,callback,primary,key)
	b.custom_minimum_size=Vector2.ZERO;b.position=rect.position;b.size=rect.size
	b.add_theme_stylebox_override("normal",DesignSkin.style("gold" if primary else "ivory"))
	b.add_theme_stylebox_override("hover",DesignSkin.style("gold"))
	b.add_theme_stylebox_override("pressed",DesignSkin.style("pressed"))
	b.add_theme_color_override("font_color",Color("49321e"))
	b.add_theme_color_override("font_hover_color",Color("49321e"))
	b.add_theme_color_override("font_pressed_color",Color("49321e"))
	b.add_theme_font_size_override("font_size",maxi(14,int(rect.size.y*.28)))
	b.add_theme_constant_override("icon_max_width",int(rect.size.y*.58))
	b.expand_icon=false
	if not key.is_empty():
		var tex:=b.icon
		b.icon=null
		var font_color:=Color("49321e")
		var font:=DemoArt.theme().default_font
		var fs:=maxi(14,int(rect.size.y*.28))
		var iw:=rect.size.y*.54
		var tw:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		var x: float=(rect.size.x-iw-(8+tw if text!="" else 0))/2
		picture(b,tex,Rect2(x,(rect.size.y-iw)/2,iw,iw))
		if text!="":
			b.add_theme_color_override("font_color",Color.TRANSPARENT)
			b.add_theme_color_override("font_hover_color",Color.TRANSPARENT)
			b.add_theme_color_override("font_pressed_color",Color.TRANSPARENT)
			b.add_theme_color_override("font_disabled_color",Color.TRANSPARENT)
			design_label(b,text,Rect2(x+iw+8,0,tw,rect.size.y),fs,font_color)
	return b

func design_panel(rect: Rect2,dark:=true) -> Control:
	var p:=Panel.new();stage.add_child(p);p.position=rect.position;p.size=rect.size
	p.add_theme_stylebox_override("panel",DesignSkin.style("dark" if dark else "ivory"))
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return p

func onboarding() -> void:
	var k:=minf(w/1600,h/900)
	design_label(stage,"RoxHistory",design_rect(54,28,400,64),int(48*k),Color("fff0d2"))
	var panel:=design_panel(design_rect(300,154,1000,626));panel.clip_contents=true
	var pattern:=picture(panel,preload("res://assets/figma/2a735.svg"),Rect2(Vector2.ZERO,panel.size));pattern.stretch_mode=TextureRect.STRETCH_SCALE
	for item in [["4c704",Rect2(-25,-23,338,371),38.27],["02422",Rect2(669,-47,331,385),-30.52],["f1627",Rect2(40,56,903,541),0.0],["75484",Rect2(158,118,641,139),0.0]]:
		var r: Rect2=item[1];var pic:=picture(panel,load("res://assets/figma/"+item[0]+".svg"),Rect2(r.position*k,r.size*k));pic.modulate.a=.29;pic.rotation=deg_to_rad(item[2]);pic.pivot_offset=pic.size*.5
	picture(stage,DemoArt.icon("hut"),design_rect(747,196,106,97))
	design_label(stage,"나의 첫 역사",design_rect(342,309,916,32),int(21*k),Color("bbbbbb"),true)
	design_label(stage,"당신의 여정이 시작됩니다",design_rect(342,357,916,64),int(48*k),Color("eeeeee"),true)
	design_label(stage,"강가의 작은 터전에서\n나만의 이야기를 만들어 보세요.",design_rect(342,437,916,80),int(26*k),Color("eeeeee"),true)
	design_label(stage,"어떤 소리로 시작할까요?",design_rect(342,550,916,32),int(21*k),Color("bbbbbb"),true)
	design_button(stage,"소리 없이 시작",design_rect(342,598,448,88),func():welcome(false),false,"horn")
	design_button(stage,"소리 켜고 시작",design_rect(810,598,448,88),func():welcome(true),true,"horn")
	design_label(stage,"소리 설정은 게임 안에서 언제든 바꿀 수 있습니다.",design_rect(342,702,916,32),int(21*k),Color("bbbbbb"),true)

func welcome(sound: bool) -> void:
	settings.set_value("app","welcomed",true)
	settings.set_value("app","sound",sound)
	if settings.save(prefs_path) != OK:
		show_error("첫 실행 설정을 저장하지 못했습니다. 저장 공간을 확인해 주세요.")
		return
	show_screen("title")

func title_screen() -> void:
	var k:=minf(w/1600,h/900)
	var title:=design_label(stage,"RoxHistory",design_rect(68,65,600,96),int(88*k),Color("fff0d0"));title.add_theme_constant_override("outline_size",3);title.add_theme_color_override("font_outline_color",Color("49321e"))
	design_label(stage,"작은 불씨에서 시작되는 우리의 역사",design_rect(78,175,970,48),int(34*k),Color("ffedc7"))
	design_panel(design_rect(1082,300,440,430))
	picture(stage,DemoArt.icon("scroll"),design_rect(1108,326,58,53))
	design_label(stage,"당신의 여정",design_rect(1178,334,260,36),int(25*k))
	var continue_btn:=design_button(stage,"이어서 하기",design_rect(1108,401,388,90),enter_game,true,"hut");continue_btn.disabled=model.state.is_empty();continue_btn.hint_text="먼저 새 여정을 시작해 주세요."
	design_button(stage,"새로 시작",design_rect(1108,513,388,82),new_game_prompt,false,"spear")
	design_button(stage,"장 선택",design_rect(1108,617,388,82),chapter_menu,false,"compass")
	var horn:=design_button(stage,"",design_rect(1445,44,88,88),toggle_sound,false,"horn");horn.tooltip_text="소리 켜기 / 끄기";horn.add_theme_stylebox_override("normal",DesignSkin.round_style("ivory"))
	design_panel(design_rect(76,744,360,78),false)
	picture(stage,DemoArt.icon("hut"),design_rect(95,760,50,46))
	design_label(stage,"1장 · 선사시대의 첫 불씨",design_rect(157,767,270,32),int(21*k),Color("49321e"))

func toggle_sound() -> void:
	settings.set_value("app","sound",not settings.get_value("app","sound",false))
	if settings.save(prefs_path)!=OK:show_error("소리 설정을 저장하지 못했습니다.")
	else:sync_audio();toast("소리 켜짐" if settings.get_value("app","sound",false) else "소리 꺼짐")

func chapter_menu() -> void:
	show_modal("장 선택","1장 · 선사시대의 첫 불씨\n암사동 강변에서 첫 보금자리를 지어 보세요.\n\n다음 장은 준비 중입니다.",[{"text":"돌아가기","action":close_modal},{"text":"1장 선택","primary":true,"action":func():close_modal();new_game_prompt()}])

func new_game_prompt() -> void:
	if not model.state.is_empty() or model.store.blocked:
		show_modal("새 여정을 시작할까요?","현재 진행을 초기화합니다. 기존 저장 파일은 별도 보존됩니다.",[
			{"text":"돌아가기","action":close_modal},{"text":"초기화하고 시작","action":func(): close_modal(); show_screen("region"),"primary":true}])
	else:
		show_screen("region")

func region_screen() -> void:
	var k:=minf(w/1600,h/900)
	back_button(func():show_screen("title"))
	design_label(stage,"첫 터전을 고르세요",design_rect(148,32,1220,64),int(48*k),Color("fff1d5"))
	design_label(stage,"시대와 삶의 흔적을 따라 여정을 시작합니다",design_rect(148,100,1220,32),int(21*k),Color("ebd1a7"))
	design_button(stage,"",design_rect(1472,32,88,88),show_about,false,"bag")
	# Preserve established map anchors; visual extents are 80% of v0.1.8.
	for item in [["전곡리","구석기",Vector2(w*.37,h*.25),Vector2(215,72),false],["암사동","신석기",Vector2(w*.25,h*.48),Vector2(230,88),true],["동삼동","신석기",Vector2(w*.49-215*.4,h*.73),Vector2(215,72),false]]:
		var selected: bool=item[4]
		var b:=design_button(stage,item[0]+"\n"+item[1],Rect2(item[2],item[3]*.8),func():toast("암사동을 선택했습니다." if selected else "이 지역은 준비 중입니다."),selected,"hut")
		b.add_theme_font_size_override("font_size",16)
		if not selected:
			b.add_theme_stylebox_override("normal",DesignSkin.style("dark"))
			for child in b.get_children():
				if child is Label:child.add_theme_color_override("font_color",Color("eeeeee"))
	design_panel(design_rect(1140,173,402,630))
	var pattern:=picture(stage,preload("res://assets/figma/ba95c.svg"),design_rect(1140,173,402,630));pattern.stretch_mode=TextureRect.STRETCH_SCALE
	picture(stage,DemoArt.icon("hut"),design_rect(1267,201,148,135))
	design_label(stage,"암사동",design_rect(1168,354,346,64),int(48*k),Color("eeeeee"),true)
	design_label(stage,"신석기 · 강변의 생활",design_rect(1168,436,346,32),int(21*k),Color("bbbbbb"),true)
	design_label(stage,"강가에 터를 잡고\n마을의 첫 불씨를 피우세요.",design_rect(1168,506,346,80),int(26*k),Color("eeeeee"),true)
	for i in 3:picture(stage,DemoArt.icon(["wood","stone","berries"][i]),design_rect(1217+i*90,604,68,62))
	design_button(stage,"이곳에서 시작",design_rect(1168,684,346,86),start_region,true,"compass")

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
		world.feedback.sound_cue.connect(audio.cue)
	world.player.set_character_3d(true)
	world.player.camera.reset_smoothing()
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
	var back:=back_button(pause_game);back.position=Vector2(safe.x,h-safe.y-56);back.visible=false
	var quest_panel:=design_button(stage,"",Rect2(w-safe.x-192,safe.y+120,192,78),focus_objective,false,"")
	quest_panel.name="QuestPanel"
	picture(quest_panel,DemoArt.icon("hut"),Rect2(10,8,22,20))
	objective=label(quest_panel,"",14,Color("49321e"));objective.position=Vector2(14,10);objective.size=Vector2(166,58)
	joystick=DemoJoystick.new();stage.add_child(joystick);joystick.position=Vector2(safe.x+14,h-safe.y-154)
	var row:=HBoxContainer.new();row.name="Actions";row.add_theme_constant_override("separation",10);stage.add_child(row)
	row.position=Vector2(w*.5-163,h-safe.y-72);row.size=Vector2(326,72)
	for data in [["사냥","spear"],["채집","berries"],["제작","hammer"],["건설","hut"]]:
		var caption: String=data[0]
		var callback: Callable=gather_action if caption=="채집" else build_action if caption=="건설" else func():show_modal(caption+" 준비 중","이번 데모에서는 나무와 돌을 모아 움막을 지을 수 있습니다.",[{"text":"돌아가기","action":close_modal}])
		var b:=design_button(row,caption,Rect2(0,0,74,72),callback,caption=="채집","")
		b.custom_minimum_size=Vector2(74,72);b.expand_icon=true;b.icon=DemoArt.icon(data[1]);b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width",38);b.add_theme_font_size_override("font_size",14)
		if caption=="채집":gather_button=b
		elif caption=="건설":build_button=b
		else:b.modulate=Color(.85,.85,.85,1);b.tooltip_text="준비 중"
	var journal:=design_button(stage,"",Rect2(w-safe.x-140,h-safe.y-62,56,56),quest_details,false,"scroll");journal.name="JournalButton"
	var bag:=design_button(stage,"",Rect2(w-safe.x-64,h-safe.y-66,62,62),inventory_summary,false,"bag");bag.name="InventoryButton"
	for b in [journal,bag]:b.add_theme_stylebox_override("normal",DesignSkin.round_style("dark"))
	context_panel=box(stage,Rect2(safe.x+76,safe.y+106,minf(300,w-safe.x*2-420),48));context_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;context_panel.visible=false
	context=label(context_panel,"",15,Color("fff0d1"));context.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;context.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	task_bar=ProgressBar.new();task_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;task_bar.show_percentage=false;task_bar.position=Vector2(w*.5-145,h-safe.y-89);task_bar.size=Vector2(290,8);stage.add_child(task_bar);task_bar.visible=false
	chrome=PlayChrome.new(self);stage.add_child(chrome);chrome.size=Vector2(w,h)
	var portrait_hit:=design_button(stage,"",Rect2(safe.x,safe.y+26,62,62),pause_game,false,"");portrait_hit.name="PortraitPause"
	for state in ["normal","hover","pressed"]:portrait_hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	portrait_hit.tooltip_text="일시 정지 · 소리 설정"
	update_hud()

func inventory_summary() -> void:
	show_modal("가진 재료","나무 %d개 · 돌 %d개\n완료 기념 씨앗 %d개"%[model.state.wood,model.state.stone,model.state.tokens],[{"text":"돌아가기","action":close_modal}])

func update_hud() -> void:
	if screen != "play" or not is_instance_valid(chrome) or model.state.is_empty():
		return
	if model.state.built:
		var goal_panel:Control=objective.get_parent()
		goal_panel.custom_minimum_size=Vector2(178,48)
		goal_panel.size=Vector2(178,48);goal_panel.position.x=w-safe.x-178
		objective.position=Vector2(36,8);objective.size=Vector2(136,32)
		objective.text = "보금자리 완성 ✓" if model.state.reward_claimed else "완성 · 보상 받기"
	else:
		var c := DemoConfig.get_data()
		objective.text = "       움막을 지어라.\n돌 %d/%d개 · 나무 %d/%d개" % [mini(model.state.stone,c.stone_cost),c.stone_cost,mini(model.state.wood,c.wood_cost),c.wood_cost]

func _process(delta: float) -> void:
	if is_instance_valid(toast_panel): toast_panel.visible = toast_time > 0 and toast_label.text != ""
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0 and is_instance_valid(toast_label): toast_label.text = ""
	if screen != "play" or not is_instance_valid(world):
		return
	var river_distance:=INF
	for i in world.SHORE.size()-1:
		var closest:=Geometry2D.get_closest_point_to_segment(world.player.position,world.SHORE[i],world.SHORE[i+1])
		river_distance=minf(river_distance,world.player.position.distance_to(closest))
	audio.river_proximity=1.0-smoothstep(80,720,river_distance)
	context_panel.visible = context.text != "" and not modal and not toast_panel.visible
	var direction := Vector2.ZERO
	if not modal and application_active and not gestures.blocked:
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
		elif gather_approach:
			approach_elapsed+=delta
			if world.player.position.distance_to(world.player.work_destination)<3:
				gather_approach=false;world.player.work_destination=Vector2.INF
				world.player.face_target(world.art_nodes[task_target].position)
				world.player.set_activity("gather");task_bar.visible=true
				context.text="채집 중… 이동하면 멈춥니다"
			elif approach_elapsed>1.5:
				cancel_task();toast("자원 옆의 빈 공간으로 이동해 주세요")
		else:
			task_remaining -= delta
			world.feedback.update_work(task_total-task_remaining,task_total)
			task_bar.value = (1.0-task_remaining/task_total)*100
			if task_remaining <= 0: finish_task()
	var near := world.nearest()
	var working_hint := "채집 중… 이동하면 멈춥니다" if task=="gather" else "보금자리 건설 중…"
	gather_button.hint_text=working_hint if task!="" else ("자원 가까이 이동해 주세요" if near.is_empty() else "작업을 마친 뒤 사용할 수 있어요")
	build_button.hint_text=working_hint if task!="" else ("완성된 보금자리입니다" if model.state.built else ("나무 1개와 돌 1개가 필요해요" if not model.can_build() else "금빛 건설 터 안으로 이동해 주세요"))
	gather_button.set_working(task=="gather");build_button.set_working(task=="build")
	var build_ready: bool=model.can_build() and world.near_site()
	if build_button.get_meta("ready",false)!=build_ready:
		build_button.set_meta("ready",build_ready)
		build_button.add_theme_stylebox_override("normal",DemoArt.button_style(build_ready))
	gather_button.text="채집 중" if task=="gather" else "채집"
	build_button.text="건설 중" if task=="build" else "건설"
	gather_button.disabled = modal or task != "" or near.is_empty()
	build_button.disabled = modal or task != "" or model.state.built or not world.near_site() or not model.can_build()
	if task == "":
		context.text = ""
		if world.near_site() and not model.state.built:
			context.text = "보금자리 터 · 건설 가능" if model.can_build() else "보금자리 터 · 나무와 돌을 모아 주세요"
		elif not model.state.built and world.player.position.distance_to(world.site.position) < 150:
			context.text = "보금자리 터 아래쪽 입구로 이동해 주세요"
		elif model.can_build():
			context.text = "재료 준비 완료 · 금빛 터에서 건설"
		elif not near.is_empty():
			var ready: bool = model.state[near.kind] >= (DemoConfig.get_data().wood_cost if near.kind == "wood" else DemoConfig.get_data().stone_cost)
			context.text = ("나무 준비 완료 · 돌을 찾아보세요" if near.kind == "wood" else "돌 준비 완료 · 나무를 찾아보세요") if ready and not model.state.built else ("나무" if near.kind == "wood" else "돌")+" · 채집 버튼을 누르세요"
	autosave += delta
	if autosave >= 8 and not modal and task == "":
		autosave = 0
		model.save_position(world.player.position)

func gather_action() -> void:
	if modal or gestures.blocked or task != "" or screen != "play": return
	var n := world.nearest()
	if n.is_empty(): return
	task = "gather"
	world.player.face_target(DemoConfig.point(n.position))
	var target_point:=DemoConfig.point(n.position)
	var stand: Vector2=world.gather_stand(target_point,n.kind)
	if not stand.is_finite():
		cancel_task();toast("자원 옆의 빈 공간으로 이동해 주세요");return
	gather_approach=world.player.position.distance_to(stand)>4
	approach_elapsed=0
	world.player.work_destination=stand if gather_approach else Vector2.INF
	world.player.set_activity("" if gather_approach else "gather")
	task_target = n.id
	world.feedback.begin("gather",n.id)
	task_total = float(DemoConfig.get_data().gather_seconds)
	task_remaining = task_total
	task_bar.visible = not gather_approach
	context.text = "자원 옆에 자리 잡는 중" if gather_approach else "채집 중… 이동하면 멈춥니다"

func build_action() -> void:
	if modal or gestures.blocked or task != "" or model.state.built or not world.near_site(): return
	var c := DemoConfig.get_data()
	if not model.can_build():
		toast("자원이 부족합니다. 나무 %d · 돌 %d가 필요해요." % [c.wood_cost,c.stone_cost])
		return
	show_modal("첫 보금자리 건설","나무 %d · 돌 %d를 사용해 이곳에 움집을 짓습니다." % [c.wood_cost,c.stone_cost],[
		{"text":"돌아가기","action":close_modal},{"text":"건설 시작","primary":true,"action":func():
			close_modal()
			task = "build"
			world.feedback.begin("build")
			world.player.face_target(world.site.position)
			world.player.set_activity("build")
			task_total = float(DemoConfig.get_data().build_seconds)
			task_remaining = task_total
			task_bar.visible = true
			toast("",0)
			context.text = "보금자리 건설 중…"}])

func finish_task() -> void:
	var kind := task
	var target := task_target
	cancel_task()
	if kind == "gather":
		if model.gather(target,world.player.position):
			world.feedback.gathered(target)
			var resource_kind: String="wood" if target.begins_with("wood") else "stone"
			chrome.gained(resource_kind,world.art_nodes[target].position+Vector2(0,-70))
			toast("",0)

	elif kind == "build" and model.build(world.player.position):
		world.feedback.built()
		completion()

func cancel_task() -> void:
	if is_instance_valid(audio): audio.stop_work()
	task = ""
	task_target = ""
	gather_approach=false;approach_elapsed=0
	if is_instance_valid(world):
		world.player.work_destination=Vector2.INF
		world.player.set_activity("")
		world.feedback.cancel()
	if is_instance_valid(task_bar): task_bar.visible = false

func completion() -> void:
	if model.state.reward_claimed: return
	var reward: int = DemoConfig.get_data().reward
	show_modal("첫 보금자리 완성!","강변에 첫 보금자리가 생겼어요!\n씨앗 %d개를 받아 여정을 이어가세요." % reward,[
		{"text":"보상 받고 계속하기","primary":true,"action":func():
			if model.claim_reward():
				close_modal(); world.feedback.rewarded(); toast("보금자리 완성 · 저장됨",2)}],true)

func focus_objective() -> void:
	if gestures.blocked or modal: return
	if model.state.built:
		quest_details();return
	var point:=world.objectives.focus_point()
	var screen_point: Vector2=world.get_global_transform_with_canvas()*point
	if not Rect2(Vector2(80,90),Vector2(w-160,h-190)).has_point(screen_point): world.player.guide_to(point+Vector2(0,-35))

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
		{"text":"안내·소리","action":show_about}])

func show_about() -> void:
	var c := DemoConfig.get_data()
	var sound: bool = settings.get_value("app","sound",false)
	show_modal("RoxHistory · v"+str(ProjectSettings.get_setting("application/config/version")),c.history.fact+"\n\n"+c.history.fiction+"\n\n강물·바람과 채집·건설 효과음을 제공합니다. 씨앗은 완료 기념 보상입니다.",[
		{"text":"소리 끄기" if sound else "소리 켜기","action":func():
			settings.set_value("app","sound",not sound)
			if settings.save(prefs_path) != OK: show_error("소리 설정을 저장하지 못했습니다.")
			else: sync_audio(); show_about()},
		{"text":"돌아가기","primary":true,"action":close_modal}])

func show_modal(title: String, body: String, actions: Array, compact: bool = false) -> void:
	if gestures: gestures.clear()
	if is_instance_valid(joystick): joystick.clear()
	cancel_task()
	if is_instance_valid(world):
		world.player.direction = Vector2.ZERO
		world.player.presentation_paused = true
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
	modal = true
	sync_audio()
	overlay = Control.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.18 if compact else 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var width := minf(390 if compact else 680,w-safe.x*2)
	var height := minf(h-safe.y*2,290 if compact else 500)
	var at := Vector2(w-safe.x-width,safe.y) if compact else Vector2((w-width)/2,(h-height)/2)
	var p := box(overlay,Rect2(at,Vector2(width,height)))
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
	sync_audio()

func sync_audio() -> void:
	if is_instance_valid(audio): audio.configure(settings.get_value("app","sound",false),application_active,screen == "play",modal)

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
		if gestures: gestures.clear()
		if is_instance_valid(chrome): chrome.clear_effects()
		application_active = false
		sync_audio()
		if is_instance_valid(world): world.feedback.clear_transients()
		if is_instance_valid(joystick): joystick.clear()
		cancel_task()
		if is_instance_valid(world) and screen == "play":
			world.player.direction = Vector2.ZERO
			world.player.presentation_paused = true
			model.save_position(world.player.position)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_active = true
		sync_audio()
		if is_instance_valid(world): world.player.presentation_paused = modal
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(world): model.save_position(world.player.position)
		get_tree().quit()
