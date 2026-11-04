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
const GATHER_SEARCH_RADIUS := 650.0
var pending_action:Dictionary={}
var choosing_plot:=false
var build_preview:BuildPreview
var menu_expanded:=true
var menu_toggle:DemoButton
var menu_backdrop:Panel
var task_target := ""
var task_site := -1
var cancel_site_button:DemoButton
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
var region_selection: RegionSelection
var region_snapshot := {}
var navigation: AutoTravel
var action_row: HBoxContainer
var quest_expanded:=true
var quest_arrow:Label
var quest_accent:ColorRect
var demolition_key:=""

func toggle_quest()->void:
	quest_expanded=not quest_expanded
	update_quest()

func update_quest()->void:
	if not is_instance_valid(objective):return
	var count:=model.built_count()
	objective.text=("움막을 지어라 · %d/3채"%count) if count<3 else "정착지 완성 · 3/3채"
	if quest_expanded:
		objective.text+=("\n나무 %d/1 · 돌 %d/1"%[mini(model.state.wood,1),mini(model.state.stone,1)]) if count<3 else ("\n건물 위 씨앗을 받아 주세요" if has_pending_rewards() else "\n씨앗 보상을 모두 받았어요")
	objective.size=Vector2(153,48 if quest_expanded else 28)
	objective.get_parent().size=Vector2(202,58 if quest_expanded else 38)
	if is_instance_valid(quest_arrow):quest_arrow.text="⌃" if quest_expanded else "⌄"
	if is_instance_valid(quest_accent):quest_accent.size.y=38 if quest_expanded else 18

func has_pending_rewards()->bool:
	for i in model.built_count():
		if model.reward_pending(i):return true
	return false

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
	cancel_build_preview()
	var layout_size:=Vector2i(540,960) if get_window().size.x<get_window().size.y else Vector2i(960,540)
	if get_window().content_scale_size!=layout_size:get_window().content_scale_size=layout_size
	var previous := screen
	region_snapshot=region_selection.snapshot() if next=="region" and screen=="region" and is_instance_valid(region_selection) else {}
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
	if screen not in ["play","region"]:
		menu_background()
	match screen:
		"onboarding": onboarding()
		"title": title_screen()
		"region": region_screen()
		"play": play_hud()
	toast_panel=PanelContainer.new();stage.add_child(toast_panel)
	toast_panel.position=Vector2(w*.5-120,safe.y+(190 if w<h else 118) if screen=="play" else safe.y+8);toast_panel.size=Vector2(240,38)
	var toast_style:=StyleBoxFlat.new();toast_style.bg_color=Color(.13,.10,.07,.87);toast_style.set_corner_radius_all(19);toast_style.set_content_margin_all(8)
	toast_panel.add_theme_stylebox_override("panel",toast_style)
	toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_label=label(toast_panel,"",15,Color("fff0d0"));toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.visible=false
	if screen in ["onboarding","title"]:
		var info:=label(stage,"버전 "+str(ProjectSettings.get_setting("application/config/version"))+" · 생성일자 "+str(ProjectSettings.get_setting("application/config/build_date","")),12,Color("fff0d0"))
		info.position=Vector2(safe.x,h-safe.y-15);info.add_theme_constant_override("outline_size",3);info.add_theme_color_override("font_outline_color",Color("30271b"))
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
	var p := FigmaPanelContainer.new()
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

func paragraph(parent: Node, text: String, font_size: int = 19, color: Color = Color("47240e")) -> Label:
	var l := label(parent,text,font_size,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func button(parent: Node, text: String, callback: Callable, primary: bool = false, icon_key: String = "") -> DemoButton:
	var b := DemoButton.new()
	b.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	for state in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	b.icon = FigmaArt.texture("back")
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width",56)
	return b

func picture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	for state in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var skin:=FigmaSlice.new("gold",minf(w/1600,h/900)*72)
	skin.name="FigmaSkin";skin.show_behind_parent=true;b.add_child(skin);b.move_child(skin,0);skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_theme_font_override("font",FigmaArt.BODY)
	b.add_theme_color_override("font_color",Color("49321e"))
	b.add_theme_color_override("font_hover_color",Color("49321e"))
	b.add_theme_color_override("font_pressed_color",Color("49321e"))
	b.add_theme_color_override("font_disabled_color",Color("49321e"))
	b.add_theme_font_size_override("font_size",maxi(14,int(rect.size.y*.28)))
	b.add_theme_constant_override("icon_max_width",int(rect.size.y*.58))
	b.expand_icon=false
	if not key.is_empty():
		var tex:=b.icon
		b.icon=null
		var font_color:=Color("49321e")
		var font:Font=FigmaArt.BODY
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
			var caption:=design_label(b,text,Rect2(x+iw+8,0,tw,rect.size.y),fs,font_color)
			caption.add_theme_font_override("font",FigmaArt.BODY)
	return b

func design_panel(rect: Rect2,dark:=true) -> Control:
	var p:=Panel.new();stage.add_child(p);p.position=rect.position;p.size=rect.size
	p.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var skin:=FigmaSlice.new("paper",24*minf(w/1600,h/900));p.add_child(skin);skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return p

func onboarding() -> void:
	var k:=minf(w/1600,h/900)
	design_label(stage,"RoxHistory",design_rect(54,28,400,64),int(48*k),Color("fff0d2"))
	var panel:=design_panel(design_rect(300,154,1000,626));panel.clip_contents=true
	picture(stage,DemoArt.icon("hut"),design_rect(747,196,106,97))
	design_label(stage,"나의 첫 역사",design_rect(342,309,916,32),int(21*k),Color("47240e"),true)
	var welcome_title:=design_label(stage,"당신의 여정이 시작됩니다",design_rect(342,357,916,64),int(44*k),Color("47240e"),true)
	welcome_title.add_theme_font_override("font",FigmaArt.TITLE)
	design_label(stage,"강가의 작은 터전에서\n나만의 이야기를 만들어 보세요.",design_rect(342,437,916,80),int(26*k),Color("47240e"),true)
	design_label(stage,"어떤 소리로 시작할까요?",design_rect(342,550,916,32),int(21*k),Color("47240e"),true)
	design_button(stage,"소리 없이 시작",design_rect(342,598,448,88),func():welcome(false),false,"horn")
	design_button(stage,"소리 켜고 시작",design_rect(810,598,448,88),func():welcome(true),true,"horn")
	design_label(stage,"소리 설정은 게임 안에서 언제든 바꿀 수 있습니다.",design_rect(342,702,916,32),int(21*k),Color("47240e"),true)

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
	design_label(stage,"당신의 여정",design_rect(1178,334,260,36),int(25*k),Color("47240e"))
	var continue_btn:=design_button(stage,"이어서 하기",design_rect(1108,401,388,90),enter_game,true,"hut");continue_btn.disabled=model.state.is_empty();continue_btn.hint_text="먼저 새 여정을 시작해 주세요."
	design_button(stage,"새로 시작",design_rect(1108,513,388,82),new_game_prompt,false,"spear")
	design_button(stage,"장 선택",design_rect(1108,617,388,82),chapter_menu,false,"compass")
	var horn:=design_button(stage,"",design_rect(1313,20,220,220),toggle_sound,false,"horn")
	horn.name="SoundToggle";horn.set_meta("semantic_text","소리 켜기 / 끄기")
	horn.get_node("FigmaSkin").hide()
	for state in ["normal","hover","pressed","disabled","focus"]:horn.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for child in horn.get_children():
		if child is TextureRect:
			child.size=Vector2.ONE*176*.54*2*.7*minf(w/1600,h/900)
			child.position=(horn.size-child.size)*.5
			var cast:=child.duplicate();cast.name="HornShadow";cast.position+=Vector2(1,3);cast.modulate=Color(0.12,0.07,0.02,.35);horn.add_child(cast);horn.move_child(cast,child.get_index())
	horn.enable_art_feedback()
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
	show_modal("새 여정 시작","새로 시작은 진행만 초기화하고 소리 설정을 유지합니다.\n\n완전 초기화는 진행·씨앗·설정을 모두 지우고 첫 실행 안내로 돌아갑니다.",[
		{"text":"돌아가기","action":close_modal},
		{"text":"새로 시작","action":func():close_modal();show_screen("region"),"primary":true},
		{"text":"완전 초기화","action":full_reset}])

func full_reset() -> void:
	if not model.store.erase_progress():show_error(model.store.message);return
	settings.clear()
	if settings.save(prefs_path)!=OK:show_error("설정 초기화를 저장하지 못했습니다.");return
	model.state.clear();cancel_task()
	if is_instance_valid(world):remove_child(world);world.queue_free();world=null
	close_modal();show_screen("onboarding")

func region_screen() -> void:
	region_selection=RegionSelection.new(self,region_snapshot)
	stage.add_child(region_selection)

func start_region() -> void:
	if is_instance_valid(region_selection) and region_selection.selected!="amsa":
		toast("현재 데모는 암사동에서 시작할 수 있습니다.");return
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
	if not is_instance_valid(navigation):
		navigation=AutoTravel.new(self);add_child(navigation)
	world.player.set_character_3d(true)
	world.player.camera.reset_smoothing()
	show_screen("play")
	# Old intro_seen is retained in saves; entry now goes directly to play.


func play_hud() -> void:
	var quest_panel:=button(stage,"",toggle_quest);quest_panel.name="QuestPanel";quest_panel.custom_minimum_size=Vector2.ZERO
	quest_panel.position=Vector2(safe.x,safe.y+(112 if w<h else 59));quest_panel.size=Vector2(202,58)
	var dark:=StyleBoxFlat.new();dark.bg_color=Color(.12,.16,.13,.73);dark.set_corner_radius_all(10);dark.set_content_margin_all(6)
	for state in ["normal","hover","pressed"]:quest_panel.add_theme_stylebox_override(state,dark)
	dark.border_color=Color(.94,.79,.48,.12);dark.set_border_width_all(1)
	quest_accent=ColorRect.new();quest_accent.color=Color(.95,.73,.34,.7);quest_accent.position=Vector2(0,12);quest_accent.size=Vector2(2,64);quest_accent.mouse_filter=Control.MOUSE_FILTER_IGNORE;quest_panel.add_child(quest_accent)
	quest_arrow=label(quest_panel,"⌃",16,Color("fff0cd"));quest_arrow.position=Vector2(183,5)
	picture(quest_panel,DemoArt.icon("hut"),Rect2(8,7,22,22))
	objective=label(quest_panel,"",12,Color("fff0cd"));objective.position=Vector2(34,6);objective.size=Vector2(153,48)
	quest_panel.set_meta("semantic_text","퀘스트 상세 펼침·접힘")
	joystick=DemoJoystick.new();stage.add_child(joystick);joystick.position=Vector2(safe.x,h-safe.y-140)
	var action_width:=64.0 if w/h>2.2 else 60.0
	var menu_width:=action_width*5+8*4+48
	menu_backdrop=Panel.new();menu_backdrop.name="MenuBackdrop";menu_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(menu_backdrop)
	var capsule:=StyleBoxFlat.new();capsule.bg_color=Color(.33,.25,.12,.83);capsule.border_color=Color(.83,.68,.38,.9);capsule.set_border_width_all(2);capsule.set_corner_radius_all(30);capsule.shadow_color=Color(0,0,0,.2);capsule.shadow_size=3;menu_backdrop.add_theme_stylebox_override("panel",capsule)
	action_row=HBoxContainer.new();action_row.name="Actions";action_row.add_theme_constant_override("separation",8);stage.add_child(action_row)
	action_row.position=Vector2(w-safe.x-menu_width,h-safe.y-76);action_row.size=Vector2(menu_width,72)
	if w<h:action_row.position.y=h-safe.y-220
	for data in [["채집","berries"],["제작","hammer"],["건설","hut"],["임무","scroll"],["가방","bag"]]:
		var caption:String=data[0]
		var callback:Callable=gather_action if caption=="채집" else construction_menu if caption=="건설" else quest_details if caption=="임무" else inventory_summary if caption=="가방" else func():toast("아직 준비 중인 기능입니다")
		var b:=button(action_row,caption,callback,false,data[1]);b.custom_minimum_size=Vector2(action_width,72)
		b.set_meta("permanent_action",false)
		b.set_meta("auxiliary_action",caption!="건설")
		if caption=="제작":b.disabled=true;b.hint_text="제작은 아직 준비 중입니다"
		b.icon=DemoArt.play_icon(data[1])
		if caption=="임무":b.name="JournalButton"
		if caption=="가방":b.name="InventoryButton"
		var action_style:=StyleBoxFlat.new();action_style.bg_color=Color.TRANSPARENT;action_style.set_content_margin_all(2)
		for state in ["normal","hover","pressed","disabled"]:b.add_theme_stylebox_override(state,action_style)
		var stone:=picture(b,preload("res://assets/ui/brush/action-stone-base@2x.png"),Rect2(0,28,action_width,action_width*88.0/128.0))
		stone.name="ApprovedStonePedestal";stone.show_behind_parent=true
		b.add_theme_font_size_override("font_size",13)
		b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.add_theme_constant_override("icon_max_width",46)
		b.add_theme_color_override("font_color",Color("fff0cd"));b.add_theme_color_override("font_disabled_color",Color("c0b299"))
		if caption=="채집":gather_button=b
		if caption=="건설":build_button=b
	action_row.move_child(build_button,action_row.get_child_count()-1)
	menu_toggle=button(action_row,"‹",toggle_menu);menu_toggle.name="MenuToggle";menu_toggle.custom_minimum_size=Vector2(44,72);menu_toggle.hint_text="보조 메뉴 펼침·접힘"
	menu_toggle.icon=DemoArt.play_icon("expand");menu_toggle.expand_icon=true;menu_toggle.add_theme_constant_override("icon_max_width",40)
	for state in ["normal","hover","pressed"]:menu_toggle.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	apply_menu_state()
	build_preview=BuildPreview.new(self);world.add_child(build_preview)
	cancel_site_button=button(stage,"부지 선택 취소",cancel_build_preview)
	cancel_site_button.name="CancelBuildSite";cancel_site_button.custom_minimum_size=Vector2.ZERO
	cancel_site_button.position=Vector2(w-safe.x-140,h-safe.y-(270 if w<h else 126));cancel_site_button.size=Vector2(140,44)
	cancel_site_button.add_theme_font_size_override("font_size",13)
	var cancel_skin:=StyleBoxFlat.new();cancel_skin.bg_color=Color(.10,.12,.10,.78);cancel_skin.border_color=Color(.8,.65,.39,.5);cancel_skin.set_border_width_all(1);cancel_skin.set_corner_radius_all(10)
	for state in ["normal","hover","pressed"]:cancel_site_button.add_theme_stylebox_override(state,cancel_skin)
	context_panel=PanelContainer.new();stage.add_child(context_panel);context_panel.position=Vector2(w*.5-145,h-safe.y-108);context_panel.size=Vector2(290,32);context_panel.add_theme_stylebox_override("panel",dark);context_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	context=label(context_panel,"",13,Color("fff0cd"));context.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	task_bar=ProgressBar.new();task_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;task_bar.show_percentage=false;task_bar.position=Vector2(w*.5-100,h-safe.y-120);task_bar.size=Vector2(200,7);stage.add_child(task_bar);task_bar.visible=false
	chrome=PlayChrome.new(self);stage.add_child(chrome);chrome.size=Vector2(w,h)
	stage.add_child(ConstructionProgress.new(self))
	var map_hit:=button(stage,"",func():world.player.resume_camera());map_hit.name="RecenterCamera";map_hit.custom_minimum_size=Vector2.ZERO;map_hit.position=Vector2(w-safe.x-100,safe.y);map_hit.size=Vector2(100,100)
	for state in ["normal","hover","pressed"]:map_hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var portrait_hit:=button(stage,"",pause_game);portrait_hit.name="PortraitPause";portrait_hit.custom_minimum_size=Vector2.ZERO;portrait_hit.position=safe;portrait_hit.size=Vector2(58,58)
	for state in ["normal","hover","pressed"]:portrait_hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	update_hud()

func toggle_menu()->void:
	menu_expanded=not menu_expanded
	apply_menu_state()

func apply_menu_state()->void:
	if not is_instance_valid(action_row):return
	for child in action_row.get_children():
		if child.get_meta("auxiliary_action",false):child.visible=menu_expanded
	menu_toggle.text=""
	menu_toggle.icon=DemoArt.play_icon("expand") if menu_expanded else DemoArt.play_icon("menu")
	menu_toggle.hint_text="접기" if menu_expanded else "메뉴 펼치기"
	var width:float=(64.0 if w/h>2.2 else 60.0)*(5 if menu_expanded else 1)+8*(5 if menu_expanded else 1)+44
	action_row.size.x=width;action_row.position.x=w-safe.x-width
	menu_backdrop.position=action_row.position+Vector2(-8,17);menu_backdrop.size=Vector2(width+16,56)

func inventory_summary() -> void:
	show_modal("가진 재료","나무 %d개 · 돌 %d개\n완료 기념 씨앗 %d개"%[model.state.wood,model.state.stone,model.state.tokens],[{"text":"돌아가기","action":close_modal}],false,true)

func update_hud() -> void:
	if screen!="play" or not is_instance_valid(objective) or model.state.is_empty():return
	update_quest()

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
	context_panel.visible = false # Passive lower hints are replaced by world markers/HUD states.
	var direction := Vector2.ZERO
	if not modal and application_active and not gestures.blocked:
		if is_instance_valid(joystick): direction = joystick.value
		var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if keyboard.length() > 0: direction = keyboard.normalized()
	if direction.length()>0.12 and is_instance_valid(navigation):
		cancel_task() # Explicit user choice: manual input cancels work and the one reservation.
		if world.player.manual_camera:world.player.resume_camera()
	world.player.direction = direction
	world.player.presentation_paused = modal or not application_active
	if task != "" and not modal and application_active:
		var cancel := false
		if task == "gather":
			var n := world.nearest()
			cancel = cancel or str(n.get("id","")) != task_target or direction.length() > 0.12
		else:
			cancel = direction.length() > 0.12
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
	cancel_site_button.visible=choosing_plot and not modal and model.built_count()<DemoConfig.HOME_GOAL
	var near := world.nearest()
	var working_hint := "채집 중… 이동하면 멈춥니다" if task=="gather" else "보금자리 건설 중…"
	gather_button.hint_text=working_hint if task!="" else ("자원 가까이 이동해 주세요" if near.is_empty() else "작업을 마친 뒤 사용할 수 있어요")
	build_button.hint_text=working_hint if task!="" else ("완성된 보금자리입니다" if (model.built_count()>=DemoConfig.HOME_GOAL) else ("나무 1개와 돌 1개가 필요해요" if not model.can_build() else "움집을 선택하고 건설할 부지를 골라 주세요"))
	gather_button.set_working(task=="gather");build_button.set_working(task=="build")
	gather_button.text="채집 중" if task=="gather" else "채집"
	build_button.text="건설 중" if task=="build" else "건설"
	gather_button.disabled = modal
	build_button.disabled = modal or (model.built_count()>=DemoConfig.HOME_GOAL)
	style_action_state(gather_button)
	style_action_state(build_button)
	if task == "":
		context.text = ""
		if world.near_site() and not (model.built_count()>=DemoConfig.HOME_GOAL):
			context.text = "보금자리 터 · 건설 가능" if model.can_build() else "보금자리 터 · 나무와 돌을 모아 주세요"
		elif not (model.built_count()>=DemoConfig.HOME_GOAL) and world.player.position.distance_to(world.site.position) < 150:
			context.text = "보금자리 터 아래쪽 입구로 이동해 주세요"
		elif model.can_build():
			context.text = "재료 준비 완료 · 금빛 터에서 건설"
		elif not near.is_empty():
			var ready: bool = model.state[near.kind] >= (DemoConfig.get_data().wood_cost if near.kind == "wood" else DemoConfig.get_data().stone_cost)
			context.text = ("나무 준비 완료 · 돌을 찾아보세요" if near.kind == "wood" else "돌 준비 완료 · 나무를 찾아보세요") if ready and not (model.built_count()>=DemoConfig.HOME_GOAL) else ("나무" if near.kind == "wood" else "돌")+" · 채집 버튼을 누르세요"
	autosave += delta
	if autosave >= 8 and not modal and task == "":
		autosave = 0
		model.save_position(world.player.position)

func gather_action(selected_id:String="") -> void:
	if modal or gestures.blocked or screen != "play": return
	if task!="":
		reserve_action({"kind":"gather","id":selected_id})
		return
	var n := world.nearest()
	if selected_id!="":
		n={}
		for candidate in model.nodes():
			if candidate.id==selected_id and not world.exhausted(candidate):n=candidate;break
		if n.is_empty():toast("예약한 채집 대상이 사라졌어요");return
	if n.is_empty():
		var candidates:=model.nodes().filter(func(c):return not world.exhausted(c) and world.player.position.distance_to(DemoConfig.point(c.position))<=GATHER_SEARCH_RADIUS)
		candidates.sort_custom(func(a,b):return world.player.position.distance_squared_to(DemoConfig.point(a.position))<world.player.position.distance_squared_to(DemoConfig.point(b.position)))
		for candidate in candidates:
			if navigation.start("gather",candidate.id,world.gather_stand(DemoConfig.point(candidate.position),candidate.kind),0,[],true):return
		toast("주변에 접근 가능한 채집물이 없어요");return
	if world.player.position.distance_to(DemoConfig.point(n.position))>float(DemoConfig.get_data().interact_radius):
		navigation.start("gather",n.id,world.gather_stand(DemoConfig.point(n.position),n.kind));return
	navigation.cancel()
	task = "gather"
	world.player.face_target(DemoConfig.point(n.position))
	var target_point:=DemoConfig.point(n.position)
	# Already inside the accepted interaction radius: keep the player's feet planted.
	gather_approach=false;approach_elapsed=0
	world.player.work_destination=Vector2.INF
	world.player.set_activity("gather")
	task_target = n.id
	world.feedback.begin("gather",n.id)
	task_total = float(DemoConfig.get_data().gather_seconds)
	task_remaining = task_total
	task_bar.visible = not gather_approach
	context.text = "자원 옆에 자리 잡는 중" if gather_approach else "채집 중… 이동하면 멈춥니다"

func construction_menu()->void:
	if modal or gestures.blocked:return
	cancel_build_preview()
	show_modal("건설","움집 · 나무 1개 + 돌 1개",[{"text":"취소","action":close_modal},{"text":"움집 선택","action":func():close_modal();choosing_plot=true;world.show_candidates=true;world.queue_redraw();toast("원형 부지를 선택해 주세요",2)}],true,true,true)

func cancel_build_preview()->void:
	if choosing_plot and is_instance_valid(world) and task!="build":world.clear_site()
	choosing_plot=false
	if is_instance_valid(build_preview):build_preview.clear()
	if is_instance_valid(world):world.show_candidates=false;world.queue_redraw()

func confirm_build_preview()->void:
	if not is_instance_valid(build_preview) or build_preview.site_id<0 or not application_active or modal:return
	var id:=build_preview.site_id
	if not world.site_available(id):cancel_build_preview();toast("이 부지는 지금 사용할 수 없어요");return
	if not model.can_build():toast("나무 1개와 돌 1개가 필요해요");return
	cancel_build_preview()
	if task!="":reserve_action({"kind":"build","id":id});return
	if world.select_site(id):build_action()

func reserve_action(request:Dictionary)->void:
	pending_action=request.duplicate(true)
	toast("현재 작업 후 실행할 행동을 예약했어요",1.5)

func run_reserved_action()->void:
	var request:=pending_action.duplicate(true)
	pending_action.clear()
	if request.is_empty():return
	match str(request.kind):
		"move":navigation.start("move","",request.at)
		"gather":gather_action(str(request.get("id","")))
		"build":
			if world.select_site(int(request.id)):build_action()
			else:toast("예약한 건설 부지를 사용할 수 없어요")

func build_action() -> void:
	if modal or gestures.blocked or task!="" or model.built_count()>=3:return
	if world.selected_site<0:toast("건설할 원형 부지를 먼저 선택해 주세요");return
	if not model.can_build():toast("나무 1개와 돌 1개가 필요해요");return
	if not world.site_available(world.selected_site):toast("이 부지에 장애물이 있어요. 다른 부지를 선택해 주세요");return
	navigation.cancel();choosing_plot=false;world.show_candidates=false;world.queue_redraw()
	task_site=world.selected_site
	task="build";world.feedback.begin("build");world.player.set_activity("")
	task_total=float(DemoConfig.get_data().build_seconds);task_remaining=task_total;task_bar.visible=false;toast("",0)

func finish_task() -> void:
	var kind := task
	var target := task_target
	var built_at:=world.site.position
	var built_site:=task_site
	var site_valid:=world.site_available(built_site) if kind=="build" else true
	cancel_task(false)
	if kind == "gather":
		if model.gather(target,world.player.position):
			world.feedback.gathered(target)
			var resource_kind: String="wood" if target.begins_with("wood") else "stone"
			chrome.gained(resource_kind,world.art_nodes[target].position+Vector2(0,-70))
			toast("",0)

	elif kind == "build" and site_valid and model.build(world.player.position,built_site):
		world.feedback.built(built_at)
	elif kind=="build" and not site_valid:toast("부지가 막혀 건설을 멈췄습니다. 재료는 사용하지 않았어요")
	call_deferred("run_reserved_action")

func cancel_task(clear_reservation:bool=true) -> void:
	if clear_reservation:
		pending_action.clear()
		cancel_build_preview()
	if is_instance_valid(navigation):navigation.cancel()
	if is_instance_valid(audio): audio.stop_work()
	task = ""
	task_target = ""
	task_site = -1
	gather_approach=false;approach_elapsed=0
	if is_instance_valid(world):
		world.player.work_destination=Vector2.INF
		world.player.set_activity("")
		world.feedback.cancel()
	if is_instance_valid(task_bar): task_bar.visible = false

func completion() -> void:
	pass # The building's reward marker is the completion affordance.

func request_demolition(screen_point:Vector2)->void:
	if modal or not application_active or screen!="play":return
	var at:Vector2=world.get_global_transform_with_canvas().affine_inverse()*screen_point
	for i in model.built_count():
		if not world.reward_hit(i,at):continue
		if model.reward_pending(i):toast("건물을 눌러 씨앗을 먼저 받아 주세요");return
		var key:=model.home_key(i)
		var quote:=model.demolition_quote(key)
		show_modal("이 움집을 철거할까요?","반환: 나무 %d개 · 돌 %d개"%[quote.wood,quote.stone],[{"text":"취소","action":close_modal},{"text":"철거","action":func():confirm_demolition(key)}],true,true,true)
		demolition_key=key
		var shade:=overlay.get_child(0)
		shade.gui_input.connect(func(event:InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_modal())
		return

func confirm_demolition(key:String)->void:
	if not application_active or not modal or demolition_key!=key:return
	var quote:=model.demolition_quote(key)
	if quote.is_empty():close_modal();return
	var at:=model.home_position(int(quote.index))
	var prior:Sprite2D=world.homes[int(quote.index)].sprite
	var ghost:=Sprite2D.new();ghost.texture=prior.texture;ghost.material=prior.material
	var ghost_transform:=prior.global_transform
	if model.demolish(key):
		close_modal()
		world.add_child(ghost);ghost.global_transform=ghost_transform;ghost.z_index=2
		var fade:=ghost.create_tween().set_parallel(true)
		fade.tween_property(ghost,"modulate:a",0.0,.32)
		fade.tween_property(ghost,"position:y",ghost.position.y+8,.32)
		fade.chain().tween_callback(ghost.queue_free)
		for i in 16:
			var angle:=TAU*i/16.0
			world.feedback.particles.append({"p":at+Vector2(cos(angle)*105,sin(angle)*22-24),"v":Vector2(cos(angle)*28,-22-absf(sin(angle))*18),"age":0.0,"life":.85,"color":Color(.72,.61,.43,.34),"size":12.0+i%4*3,"material":"dust","spin":0.0})
		world.feedback.sound_cue.emit("build")
		toast("나무 %d개 · 돌 %d개 반환"%[quote.wood,quote.stone],2)
	else:ghost.free()

func claim_home(index:int) -> void:
	if model.claim_reward(index):
		world.feedback.rewarded()
		for i in 6:chrome.gained("tokens",world.reward_marker_rect(index).get_center()+Vector2((i-3)*8,0),i*.055)

func world_tap(screen_point:Vector2) -> void:
	if modal or gestures.blocked:return
	var at:Vector2=world.get_global_transform_with_canvas().affine_inverse()*screen_point
	for i in model.built_count():
		if model.reward_pending(i) and world.reward_hit(i,at):claim_home(i);return
	for n in model.nodes():
		if world.exhausted(n):continue
		var point:=DemoConfig.point(n.position)
		if Rect2(point-Vector2(60,70),Vector2(120,90)).has_point(at):
			if world.exhausted(n):toast("이 자원은 모두 채집했어요");return
			if not task.is_empty():
				navigation.start("gather",n.id,world.gather_stand(point,n.kind));return
			navigation.cancel()
			if world.player.position.distance_to(point)<=float(DemoConfig.get_data().interact_radius):gather_action(n.id)
			else:navigation.start("gather",n.id,world.gather_stand(point,n.kind))
			return
	var site_id:=world.site_at(at) if choosing_plot else -1
	if site_id>=0:
		if not world.site_available(site_id):toast("이 부지는 지금 사용할 수 없어요");return
		build_preview.select(site_id)
		return
	# Building images own their taps even after their reward has been claimed.
	for prop in world.environment_props:
		if prop.kind=="hut" and prop.visible and Rect2(prop.position-Vector2(170,245),Vector2(340,260)).has_point(at):return
	cancel_build_preview()
	navigation.start("move","",at)

func focus_objective() -> void:
	if gestures.blocked or modal: return
	if (model.built_count()>=DemoConfig.HOME_GOAL):
		quest_details();return
	var point:=world.objectives.focus_point()
	var screen_point: Vector2=world.get_global_transform_with_canvas()*point
	if not Rect2(Vector2(80,90),Vector2(w-160,h-190)).has_point(screen_point): world.player.guide_to(point+Vector2(0,-35))

func quest_details() -> void:
	show_modal("정착지를 만들어요","기존 움집 한 채에 새 움집 세 채를 더 지어 주세요.\n\n진행 %d/3 · 건설마다 나무 1개 + 돌 1개\n자원을 누르면 자동 이동하여 채집합니다.\n건설 → 움집 선택 후 부지를 고르고 미리보기에서 확인하면 건설합니다.\n%s"%[model.built_count(),("미수령 건물을 누르면 씨앗 10개를 받습니다." if has_pending_rewards() else "모든 완료 보상을 받았습니다." if model.built_count()>=3 else "건설 완료 후 건물에서 씨앗을 받을 수 있습니다.")],[{"text":"돌아가기","action":close_modal}],false,true)

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
	show_modal("RoxHistory · v"+str(ProjectSettings.get_setting("application/config/version")),c.history.fact+"\n\n"+c.history.fiction+"\n\n지역 선택 음악과 자연음, 채집·건설 효과음을 제공합니다. 씨앗은 완료 기념 보상입니다.",[
		{"text":"소리 끄기" if sound else "소리 켜기","action":func():
			settings.set_value("app","sound",not sound)
			if settings.save(prefs_path) != OK: show_error("소리 설정을 저장하지 못했습니다.")
			else: sync_audio(); show_about()},
		{"text":"돌아가기","primary":true,"action":close_modal}])

func show_modal(title: String, body: String, actions: Array, compact: bool = false, preserve_work:bool=false, brief:bool=false) -> void:
	if is_instance_valid(region_selection):region_selection.cancel_input()
	if gestures: gestures.clear()
	if is_instance_valid(joystick): joystick.clear()
	if not preserve_work:cancel_task()
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
	var width := minf(300 if brief else 390 if compact else 680,w-safe.x*2)
	var height := minf(h-safe.y*2,166 if brief else 290 if compact else 500)
	var at := Vector2(w-safe.x-width,safe.y) if compact and not brief else Vector2((w-width)/2,(h-height)/2)
	var p := box(overlay,Rect2(at,Vector2(width,height)))
	var v := column(p,8 if brief else 12)
	var modal_title:=label(v,title,20 if brief else 28,Color("47240e"));modal_title.add_theme_font_override("font",FigmaArt.TITLE)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var text := paragraph(scroll,body,16 if brief else 20)
	text.custom_minimum_size.x = width-60
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	v.add_child(row)
	for a in actions:
		var b := button(row,a.text,a.action,a.get("primary",false))
		if brief:b.custom_minimum_size=Vector2(80,44)
		for state in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for color_key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:b.add_theme_color_override(color_key,Color("47240e"))
		b.add_theme_font_override("font",FigmaArt.BODY)
		var skin:=FigmaSlice.new("gold",42);skin.name="FigmaSkin";skin.show_behind_parent=true;b.add_child(skin);skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",17)

func close_modal() -> void:
	demolition_key=""
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
	overlay = null
	modal = false
	if is_instance_valid(joystick): joystick.clear()
	if is_instance_valid(world): world.player.presentation_paused = not application_active
	sync_audio()

func sync_audio() -> void:
	if is_instance_valid(audio): audio.configure(settings.get_value("app","sound",false),application_active,screen == "play",modal,screen == "region",screen == "title")

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
		elif event.physical_keycode == KEY_B: construction_menu()

func _notification(what: int) -> void:
	# Synthetic tests issue PAUSED/RESUMED explicitly; desktop focus is external.
	if test_mode and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var was_demolition:=not demolition_key.is_empty()
		if was_demolition:close_modal()
		if is_instance_valid(region_selection):region_selection.cancel_input()
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
			if not was_demolition:model.save_position(world.player.position)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_active = true
		sync_audio()
		if is_instance_valid(world): world.player.presentation_paused = modal
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(world): model.save_position(world.player.position)
		get_tree().quit()

# Available actions use the selected option-3 gold pedestal; unavailable actions
# remain readable and retain DemoButton's reason-on-tap behavior.
func style_action_state(control:DemoButton)->void:
	var state:="working" if control.working else "unavailable" if control.disabled else "ready"
	if control.get_meta("action_state","")==state:return
	control.set_meta("action_state",state)
	var plate:=StyleBoxFlat.new();plate.set_corner_radius_all(5);plate.set_border_width_all(1)
	plate.bg_color=Color("70532c") if state=="working" else Color("68451d") if state=="ready" else Color(.16,.13,.09,.82)
	plate.border_color=Color("ffe4a0") if state=="ready" else Color("d3ad67") if state=="working" else Color(.57,.49,.36,.55)
	plate.shadow_color=Color(1,.72,.23,.38) if state=="ready" else Color(0,0,0,.22)
	plate.shadow_size=7 if state=="ready" else 2
	# The authored stone includes its nameplate; only a subtle halo is dynamic.
	var halo:=StyleBoxFlat.new();halo.set_corner_radius_all(12);halo.set_content_margin_all(2)
	halo.bg_color=Color(1,.72,.18,.12) if state=="ready" else Color(.9,.65,.2,.07) if state=="working" else Color.TRANSPARENT
	halo.shadow_color=Color(1,.75,.28,.16) if state=="ready" else Color.TRANSPARENT;halo.shadow_size=5
	for variant in ["normal","hover","pressed","disabled"]:control.add_theme_stylebox_override(variant,halo)
