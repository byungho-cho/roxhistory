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
var build_lock_icon: TextureRect
var build_return_badge: TextureRect
var build_visual: ActionVisual
var gather_lock_icon: TextureRect
var tutorial: IntroTutorial
var village_alerts: AndroidVillageNotifications
var performance_diagnostics := PerformanceDiagnostics.new()
const PERFORMANCE_HUD:=preload("res://scripts/performance_hud.gd")
var performance_hud:PanelContainer
var debug_shortcut:DemoButton
var debug_shortcut_icon:TextureRect
const HUNT_SCREEN := preload("res://scripts/deer_hunt_screen.gd")
const INTRO_VIDEO_PATH := "res://assets/video/intro.ogv"
var hunt: HUNT_SCREEN
var hunt_preparing := false
var hunt_preparation_cancelled := false
var title_sound: DemoButton
var title_prompt: DemoButton
var intro_player: VideoStreamPlayer
var intro_stream: VideoStream
var intro_position := -1.0
var intro_stall := 0.0
var intro_preparing := false
var intro_leaving := false
var intro_cloud_layer: CanvasLayer
var intro_cloud: ColorRect
signal intro_world_prepared
var prepared_intro_world: DemoWorld
var preparing_intro_world := false
var intro_preload_paths: Array[String] = []
var intro_preloaded: Array[Resource] = []
var intro_preload_started := false
var intro_preload_total := 0
var title_loading: ProgressBar
var title_world_progress := 0.0
var title_load_generation := 0
var title_loader_started_at := 0
var intro_loading: Label
var intro_probe := OS.is_debug_build() and OS.has_feature("android")
var intro_cloud_tween: Tween
var transition_started_at := 0
var transition_prepare_ms := 0.0
var first_village_loading := false
var title_prompt_time := 0.0
var title_update_at := -60000
var title_cloud_seen := false
var title_reveal: Tween
var title_loader_first_frame := false
var title_initial_update_done := false
var title_update_in_flight := false
const TITLE_UPDATE_TIMEOUT := 4.0
const PATCH_DOWNLOAD_TIMEOUT := 30.0
var task_bar: ProgressBar
var toast_label: Label
var toast_time := 0.0
var screen := ""
var modal := false
var task := ""
const GATHER_SEARCH_RADIUS := 650.0
var pending_action:Dictionary={}
var dispatching_reserved_action:=false
var queued_action_indicator:QueuedActionIndicator
var build_kind:="hut"
var task_build_kind:="hut"
var choosing_plot:=false
var build_preview:BuildPreview
var menu_expanded:=true
var build_side:BuildSideMenu
var menu_toggle:DemoButton
var menu_backdrop:Panel
var menu_tween:Tween
var menu_animating:=false
var map_transition:ColorRect
var map_tween:Tween
var map_transition_active:=false
var village_entry:VillageEntry
var task_target := ""
var task_site := -1
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
var action_row: Control
var quest_expanded:=true
var quest_arrow:TextureRect
var quest_accent:ColorRect
var quest_detail:Control
var quest_wood:Label
var quest_stone:Label
var demolition_key:=""
var relocating_key:=""
var world_map:VillageWorldMap
var world_map_open:=false
var map_toggle:DemoButton
var family:FamilyArrival
var building_work_audio:BuildingWorkAudio
var building_workflow:BuildingWorkflow
var building_menu:BuildingMenu
var farm_tick:=0.0
var resident_panel:ResidentPanel

func camera_modal()->bool:
	return modal and is_instance_valid(overlay) and overlay.name=="CompactUpgradeOverlay"

func toggle_quest()->void:
	quest_expanded=not quest_expanded
	update_quest()

var quest_reward_count:Label

func update_quest()->void:
	if not is_instance_valid(objective):return
	var current:=FirstQuests.current(model.state)
	objective.text=FirstQuests.TITLES[current] if current>=0 else "첫 여정 완료"
	if is_instance_valid(quest_reward_count):
		var pending:=FirstQuests.pending(model.state).size()
		quest_reward_count.text=str(pending)
		quest_reward_count.get_parent().visible=pending>0
		quest_reward_count.get_parent().get_parent().visible=not model.state.get("quests_done",[]).is_empty()
	objective.size=Vector2(168,24)
	objective.get_parent().size=Vector2(240,84 if quest_expanded else 52)
	if is_instance_valid(quest_arrow):quest_arrow.rotation=0.0 if quest_expanded else PI
	if is_instance_valid(quest_accent):quest_accent.size.y=48 if quest_expanded else 18
	if is_instance_valid(quest_detail):
		quest_detail.visible=quest_expanded and current in [2,3,5,6]
		var kind:String={2:"chief",3:"hut",5:"chief",6:"farm"}.get(current,"chief")
		var cost:=model.building_cost(kind,2 if current==5 else 1)
		quest_wood.text="%d/%d"%[mini(int(model.state.wood),int(cost.wood)),int(cost.wood)]
		quest_stone.text="%d/%d"%[mini(int(model.state.stone),int(cost.stone)),int(cost.stone)]
		objective.get_parent().tooltip_text=FirstQuests.OBJECTIVES[current] if current>=0 else "첫 여정 완료"

func has_pending_rewards()->bool:
	for i in model.built_count():
		if model.reward_pending(i):return true
	return false

func _ready() -> void:
	if OS.has_feature("android"):Engine.max_fps=60
	gestures=WorldGestures.new(self);add_child(gestures)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	test_mode = "--test-ui" in OS.get_cmdline_user_args()
	if test_mode:
		prefs_path = "user://tests/preferences.cfg"
		performance_diagnostics.path = "user://tests/performance-diagnostics.jsonl"
	settings.load(prefs_path)
	audio = DemoSoundscape.new()
	add_child(audio)
	var save_directory:="user://tests/session" if test_mode else "user://"
	model = GameState.new(SaveStore.new(save_directory),true)
	if not test_mode:village_alerts=AndroidVillageNotifications.new(model)
	model.finish_loaded_jobs()
	model.changed.connect(update_hud)
	model.failed.connect(show_error)
	canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.theme = DemoArt.theme()
	canvas.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_layout)
	show_screen("title")

func queue_layout() -> void:
	if rebuilding or screen in ["hunt","intro"] or title_reveal or intro_leaving or village_entry_active():
		return
	rebuilding = true
	call_deferred("relayout")

func relayout() -> void:
	if screen in ["hunt","intro"]:
		rebuilding = false
		return
	var guide_pages:Array[Dictionary]=[]
	var guide_actions:Array[Callable]=[]
	if overlay is CharacterGuide:
		guide_pages=overlay.remaining_pages()
		guide_actions=overlay.completions.duplicate()
	if gestures: gestures.clear()
	rebuilding = false
	if modal:
		close_modal()
	cancel_task()
	show_screen(screen)
	if not guide_pages.is_empty():
		show_character_guide(guide_pages[0].title,guide_pages[0].body)
		overlay.pages.assign(guide_pages.slice(1))
		overlay.completions=guide_actions

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func show_screen(next: String,spread_hud:=false) -> void:
	if screen=="title" and next!="title":
		get_node("/root/PatchBootstrap/Overlay").leave_title()
		if title_reveal:
			title_reveal.kill()
			title_reveal = null
	finish_village_entry()
	if menu_tween:menu_tween.kill()
	menu_animating=false
	if map_tween:map_tween.kill()
	map_transition_active=false
	world_map_open=false
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
	if screen not in ["play","region","title","hunt","intro"]:
		menu_background()
	match screen:
		"onboarding": onboarding()
		"title": title_screen()
		"intro": intro_screen()
		"region": region_screen()
		"chapter": ChapterSelection.new(self).open()
		"play": await play_hud(spread_hud)
		"hunt":
			hunt = HUNT_SCREEN.new()
			hunt.app = self
			stage.add_child(hunt)
			hunt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_panel=PanelContainer.new();toast_panel.z_index=45;stage.add_child(toast_panel)
	toast_panel.position=Vector2(w*.5-120,safe.y+(190 if w<h else 118) if screen=="play" else safe.y+8);toast_panel.size=Vector2(240,38)
	var toast_style:=StyleBoxFlat.new();toast_style.bg_color=Color(.13,.10,.07,.87);toast_style.set_corner_radius_all(19);toast_style.set_content_margin_all(8)
	toast_panel.add_theme_stylebox_override("panel",toast_style)
	toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_label=label(toast_panel,"",15,Color("fff0d0"));toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.visible=false
	if screen in ["onboarding","title"]:
		var info:=label(stage,"버전 "+str(ProjectSettings.get_setting("application/config/version"))+" · 생성일자 "+str(ProjectSettings.get_setting("application/config/build_date","")),12,Color("fff0d0"))
		info.position=Vector2(safe.x,h-safe.y-15);info.add_theme_constant_override("outline_size",3);info.add_theme_color_override("font_outline_color",Color("30271b"))
		if screen=="title":
			var version_button := button(stage,"",open_title_update)
			version_button.name = "VersionUpdate"
			version_button.custom_minimum_size = Vector2.ZERO
			version_button.position = Vector2(safe.x-4,h-safe.y-35)
			version_button.size = Vector2(310,40)
			for state in ["normal","hover","pressed","focus"]:
				version_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	sync_audio()
	if next != previous and not is_instance_valid(intro_cloud):
		var fade := ColorRect.new()
		fade.color = Color("302d26")
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(fade); fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade.modulate.a = 0.45
		var transition := create_tween()
		transition.tween_property(fade,"modulate:a",0.0,0.18 if previous=="chapter" and next=="region" else 0.28)
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
	var updates := get_node("/root/PatchBootstrap/Overlay")
	var title_art:=AtlasTexture.new()
	title_art.atlas=preload("res://assets/ui/title-hanbando/hanbando-start-background-v1.png")
	# The handoff image includes static controls along the lower edge.
	title_art.region=Rect2(0,0,title_art.atlas.get_width(),720)
	title_art.filter_clip=true
	var background:=picture(stage,title_art,Rect2(0,0,w,h))
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if not title_cloud_seen:
		title_reveal = stage.create_tween().set_parallel()
		for i in 2:
			var cloud := picture(stage,VillageEntry.BANK_A if i==0 else VillageEntry.BANK_B,Rect2(-w*.15,h*(.05 if i==0 else .45),w*1.3,h*.55))
			cloud.modulate.a = .85
			title_reveal.tween_property(cloud,"position:x",w*(.45 if i==0 else -.72),1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			title_reveal.tween_property(cloud,"modulate:a",0.0,1.25)
			title_reveal.finished.connect(cloud.queue_free)
		title_reveal.finished.connect(finish_title_reveal)
		if not application_active:title_reveal.pause()

	var logo_width:=minf(w*(.62 if w<h else .31),h*.61)
	var logo:=picture(stage,preload("res://assets/ui/title-hanbando/hanbando-upheaval-logo-v1.png"),Rect2((w-logo_width)*.5,safe.y+h*.022,logo_width,logo_width*.5))
	logo.name="HanbandoTitleLogo"
	var surface := button(stage,"",start_or_continue)
	surface.custom_minimum_size=Vector2.ZERO
	surface.size=Vector2(w,h)
	for state in ["normal","hover","pressed","focus"]:surface.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var start:=button(stage,"화면을 터치하여 시작",start_or_continue)
	title_prompt=start
	title_prompt_time=0
	style_start_prompt(start)
	install_title_loader(start)
	var config:=button(stage,"",pause_game)
	config.name="TitleSettings";config.custom_minimum_size=Vector2.ZERO;config.position=Vector2(w-safe.x-56,h-safe.y-56);config.size=Vector2(56,56)
	for state in ["normal","hover","pressed","focus"]:config.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	picture(config,preload("res://assets/ui/review-v037/settings-figma.png"),Rect2(4,4,48,48))
	config.set_meta("semantic_text","설정")
	title_sound = button(stage,"",toggle_sound)
	title_sound.name = "TitleSound"
	title_sound.custom_minimum_size = Vector2.ZERO
	title_sound.position = Vector2(w-safe.x-64,safe.y+2)
	title_sound.size = Vector2(56,56)
	for state in ["normal","hover","pressed","focus"]:
		title_sound.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	title_sound.expand_icon = true
	title_sound.add_theme_constant_override("icon_max_width",48)
	update_title_sound()
	var patch_status:=Label.new()
	patch_status.position=Vector2(safe.x,h-safe.y-37)
	patch_status.add_theme_color_override("font_color",Color("fff0d0"))
	stage.add_child(patch_status)
	patch_status.process_mode=Node.PROCESS_MODE_ALWAYS
	updates.check_status_changed.connect(patch_status.set_text)
	if not updates.popup.visibility_changed.is_connected(on_title_patch_popup_changed):
		updates.popup.visibility_changed.connect(on_title_patch_popup_changed)
	patch_status.text=updates.check_status
	if not updates.request.request_completed.is_connected(update_title_patch_action):
		updates.request.request_completed.connect(update_title_patch_action)
	if updates.has_signal("manifest_check_failed_to_start") and not updates.is_connected("manifest_check_failed_to_start",finish_title_update_check):
		updates.connect("manifest_check_failed_to_start",finish_title_update_check)
	call_deferred("check_title_update")

func on_title_patch_popup_changed() -> void:
	if not get_node("/root/PatchBootstrap/Overlay").popup.visible and title_update_in_flight:
		finish_title_update_check()
	refresh_title_start_prompt()

func open_title_update() -> void:
	if screen!="title" or not application_active or modal or title_input_blocked() or is_instance_valid(intro_cloud):return
	var updates := get_node("/root/PatchBootstrap/Overlay")
	if not updates.popup.visible:updates.show_popup()
	check_title_update(true)

func update_title_patch_action(_result:int,_code:int,_headers:PackedStringArray,_body:PackedByteArray) -> void:
	var updates := get_node("/root/PatchBootstrap/Overlay")
	if title_update_in_flight and (not updates.has_method("is_manifest_check_pending") or not updates.is_manifest_check_pending()):finish_title_update_check()
	if updates.has_method("begin_manifest_check"):return
	if updates.restart_pending or updates.downloading:return
	if updates.candidate.is_empty():
		if updates.popup.visible and updates.check_status.is_empty():
			updates.status.text = "이미 최신 버전입니다"
			updates.update_button.disabled = true
	else:
		var current := str(ProjectSettings.get_setting("application/config/version"))
		if updates.version_number(updates.candidate.version)<=updates.version_number(current):
			updates.update_button.disabled = true

func style_start_prompt(start: DemoButton) -> void:
	start.name="StartGame";start.custom_minimum_size=Vector2.ZERO
	start.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	start.anchor_top = 0.917
	start.anchor_bottom = 0.917
	start.offset_left=-180
	start.offset_right=180
	var center_offset := minf(0.0,h*.083-safe.y-32)
	start.offset_top=center_offset-32
	start.offset_bottom=center_offset+32
	for state in ["normal","hover","pressed","focus"]:start.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	start.add_theme_font_size_override("font_size",24)
	start.add_theme_color_override("font_color",Color("fff0d0"))
	start.add_theme_color_override("font_outline_color",Color("49321e"));start.add_theme_constant_override("outline_size",3)

func check_title_update(manual:=false) -> void:
	if screen!="title" or not application_active or modal or title_reveal or title_update_in_flight or is_instance_valid(intro_cloud):return
	if test_mode and not manual:return
	var updates := get_node("/root/PatchBootstrap/Overlay")
	if updates.downloading or updates.restart_pending:return
	if not manual and updates.popup.visible:return
	var now := Time.get_ticks_msec()
	if not manual and title_initial_update_done and now-title_update_at<5000:return
	title_update_at = now
	title_update_in_flight = true
	updates.title_active = true
	updates.checked_title = true
	var url := str(updates.RELEASE_ROOT)+"latest.json?check="+str(Time.get_unix_time_from_system())
	if updates.has_method("begin_manifest_check"):
		if not updates.begin_manifest_check(url):finish_title_update_check()
		return
	updates.candidate.clear()
	updates.update_button.disabled = true
	updates.status.text = "업데이트 확인 중…"
	updates.check_status = updates.status.text
	updates.request.cancel_request()
	updates.request.timeout = TITLE_UPDATE_TIMEOUT
	updates.request.download_file = ""
	updates.request.body_size_limit = 8192
	if updates.request.request(url) != OK:
		updates.show_failure()
		finish_title_update_check()

func finish_title_update_check() -> void:
	title_update_in_flight = false
	title_initial_update_done = true
	get_node("/root/PatchBootstrap/Overlay").request.timeout = PATCH_DOWNLOAD_TIMEOUT
	refresh_title_start_prompt()

func refresh_title_start_prompt() -> void:
	if screen!="title" or not is_instance_valid(title_prompt):return
	title_prompt.visible = not title_input_blocked()

func install_title_loader(start: Button) -> void:
	title_loading = ProgressBar.new()
	title_loading.name = "TitleLoading"
	title_loading.show_percentage = false
	title_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_loading.position = Vector2(w*.5-minf(w*.54,270.0)*.5,start.position.y+start.size.y*.5-4)
	title_loading.size = Vector2(minf(w*.54,270.0),8)
	title_loading.max_value = 1.0
	title_loading.step = 0.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(.12,.09,.06,.40)
	track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(.94,.80,.54,.66)
	fill.set_corner_radius_all(4)
	title_loading.add_theme_stylebox_override("background",track)
	title_loading.add_theme_stylebox_override("fill",fill)
	stage.add_child(title_loading)
	refresh_title_loading_visibility()

func finish_title_reveal() -> void:
	title_cloud_seen = true
	title_reveal = null
	if get_viewport().get_visible_rect().size != Vector2(w,h):
		queue_layout()
		return
	refresh_title_loading_visibility()
	call_deferred("check_title_update")

func refresh_title_loading_visibility() -> void:
	title_loading.visible = not title_reveal and title_needs_loading()
	refresh_title_start_prompt()
	title_loader_first_frame = title_loading.visible
	title_loader_started_at = Time.get_ticks_usec()

func title_input_blocked() -> bool:
	if screen!="title":return false
	var popup: Control = get_node("/root/PatchBootstrap/Overlay").popup
	return title_reveal!=null or (is_instance_valid(title_loading) and title_loading.visible) or (
		not test_mode and not title_initial_update_done) or popup.visible

func title_needs_loading() -> bool:
	return not is_instance_valid(world) and (not intro_preload_started or not intro_preload_paths.is_empty() or
		(not model.state.is_empty() and not is_instance_valid(prepared_intro_world)))

func advance_title_loading() -> void:
	if title_reveal or not is_instance_valid(title_loading) or not title_loading.visible or not application_active:return
	# Render the bar once before issuing requests or creating the hidden world.
	if title_loader_first_frame:
		title_loader_first_frame = false
		return
	preload_intro_assets()
	var assets_progress := 1.0-float(intro_preload_paths.size())/maxi(1,intro_preload_total)
	if not model.state.is_empty():
		title_loading.value = assets_progress*.32+title_world_progress*.68
		if intro_preload_paths.is_empty():prepare_intro_world()
	else:
		title_loading.value = assets_progress
	if not title_needs_loading():
		title_loading.hide()
		refresh_title_start_prompt()
		if intro_probe:print("ROX_INTRO_TIMING title_ready ms=",(Time.get_ticks_usec()-title_loader_started_at)/1000.0)

func start_or_continue()->void:
	if title_input_blocked() and not test_mode:return
	if modal or screen!="title" or not application_active or is_instance_valid(intro_cloud):return
	get_node("/root/PatchBootstrap/Overlay").leave_title()
	cover_intro(prepare_intro)
	for control in [title_prompt,stage.get_node_or_null("HanbandoTitleLogo")]:
		if is_instance_valid(control):
			control.create_tween().tween_property(control,"self_modulate:a",0.0,.24)

func prepare_intro() -> void:
	if ResourceLoader.exists(INTRO_VIDEO_PATH, "VideoStream"):
		intro_stream = load(INTRO_VIDEO_PATH) as VideoStream
	if intro_stream:
		intro_preparing = true
		show_screen("intro")
	else:
		leave_intro_under_cover()

func cover_intro(covered: Callable) -> void:
	if not is_instance_valid(intro_cloud):
		intro_cloud_layer = CanvasLayer.new()
		intro_cloud_layer.layer = 90
		add_child(intro_cloud_layer)
		intro_cloud = ColorRect.new()
		intro_cloud.name = "IntroCloudTransition"
		var clouds := ShaderMaterial.new()
		clouds.shader = preload("res://shaders/cloud_transition.gdshader")
		clouds.set_shader_parameter("coverage",0.0)
		clouds.set_shader_parameter("textured",true)
		clouds.set_shader_parameter("cloud_bank",VillageEntry.BANK_A)
		intro_cloud.material = clouds
		intro_cloud_layer.add_child(intro_cloud)
		intro_cloud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		intro_cloud.resized.connect(fit_intro_cloud)
		fit_intro_cloud()
		intro_loading = label(intro_cloud,"인트로 준비 중…",24,Color("49321e"))
		intro_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intro_loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		intro_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		intro_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		intro_loading.hide()
	intro_cloud.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_prepare_ms = 0.0
	animate_intro_cloud(1.0,.36,func():
		transition_started_at = Time.get_ticks_usec()
		covered.call())

func fit_intro_cloud() -> void:
	(intro_cloud.material as ShaderMaterial).set_shader_parameter(
		"aspect", intro_cloud.size.x / maxf(1.0,intro_cloud.size.y))

func animate_intro_cloud(target: float, duration: float, completed: Callable) -> void:
	if intro_cloud_tween:intro_cloud_tween.kill()
	var clouds := intro_cloud.material as ShaderMaterial
	var coverage := float(clouds.get_shader_parameter("coverage"))
	intro_cloud_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_cloud_tween.tween_method(func(value: float):clouds.set_shader_parameter("coverage",value),
		coverage,target,duration*absf(target-coverage))
	intro_cloud_tween.tween_callback(completed)
	if not application_active:intro_cloud_tween.pause()

func reveal_intro_destination() -> void:
	transition_prepare_ms = (Time.get_ticks_usec()-transition_started_at)/1000.0
	intro_loading.hide()
	if screen=="intro":
		intro_cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animate_intro_cloud(0.0,.44,func():
		intro_cloud_layer.queue_free()
		intro_cloud = null
		intro_leaving = false
		first_village_loading = false
		if screen=="play" and get_viewport().get_visible_rect().size!=Vector2(w,h):queue_layout())

func intro_screen() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_player = VideoStreamPlayer.new()
	intro_player.stream = intro_stream
	intro_player.expand = true
	intro_player.volume_db = 0.0 if settings.get_value("app","sound",true) else -80.0
	intro_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(intro_player)
	stage.resized.connect(fit_intro_video)
	var skip := button(stage,"화면을 터치하여 스킵",finish_intro)
	style_start_prompt(skip)
	skip.name = "SkipIntro"
	skip.offset_left = -116
	skip.offset_right = 116
	intro_position = -1.0
	intro_stall = 0.0
	intro_player.finished.connect(finish_intro)
	var texture := intro_player.get_video_texture()
	if texture:texture.changed.connect(intro_first_frame_ready,CONNECT_ONE_SHOT)
	intro_player.play()
	intro_player.paused = not application_active
	fit_intro_video()

func intro_first_frame_ready() -> void:
	if screen!="intro" or not intro_preparing:return
	intro_preparing = false
	intro_stall = 0.0
	fit_intro_video()
	reveal_intro_destination()

func fit_intro_video() -> void:
	if not is_instance_valid(intro_player):return
	var texture := intro_player.get_video_texture()
	var source_size := texture.get_size() if texture else Vector2.ZERO
	if source_size.x <= 0 or source_size.y <= 0:source_size = Vector2(16,9)
	intro_player.size = source_size * minf(stage.size.x/source_size.x,stage.size.y/source_size.y)
	intro_player.position = (stage.size-intro_player.size)*0.5

func finish_intro() -> void:
	if screen!="intro" or intro_leaving:return
	intro_leaving = true
	intro_preparing = false
	if is_instance_valid(intro_player):intro_player.paused = true
	cover_intro(leave_intro_under_cover)

func leave_intro_under_cover() -> void:
	var covered_at := Time.get_ticks_usec()
	if is_instance_valid(intro_player):intro_player.stop()
	intro_player = null
	intro_stream = null
	if not model.state.is_empty() and not is_instance_valid(world):
		if not is_instance_valid(prepared_intro_world):
			intro_loading.text = "마을 준비 중…"
			intro_loading.show()
			prepare_intro_world()
			await intro_world_prepared
		world = prepared_intro_world
		prepared_intro_world = null
		world.resume_staged_startup()
		world.feedback.sound_cue.connect(audio.cue)
		await get_tree().physics_frame
		world.refresh_residents()
		await get_tree().process_frame
	while not application_active:
		await get_tree().process_frame
	await continue_to_village()
	await get_tree().process_frame
	intro_probe_step("covered_to_first_frame",covered_at)
	reveal_intro_destination()

func preload_intro_assets() -> void:
	if is_instance_valid(world):return
	if not intro_preload_started:
		intro_preload_started = true
		var paths: Array[String] = ["res://assets/characters/meshy01/hero.glb"]
		for path in WorldAnimal.MODELS.values():paths.append(path)
		for path in paths:
			if ResourceLoader.load_threaded_request(path,"PackedScene")==OK:
				intro_preload_paths.append(path)
		intro_preload_total = intro_preload_paths.size()
	for index in range(intro_preload_paths.size()-1,-1,-1):
		var path := intro_preload_paths[index]
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				intro_preloaded.append(ResourceLoader.load_threaded_get(path))
				intro_preload_paths.remove_at(index)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				intro_preload_paths.remove_at(index)

func prepare_intro_world() -> void:
	if preparing_intro_world or is_instance_valid(prepared_intro_world) or is_instance_valid(world) or model.state.is_empty():
		return
	preparing_intro_world = true
	var generation := title_load_generation
	title_world_progress = 0.0
	var world_started := Time.get_ticks_usec()
	var assembling_world := DemoWorld.new(model)
	assembling_world.spread_startup = true
	assembling_world.startup_progress.connect(func(progress: float):title_world_progress = progress)
	assembling_world.hide()
	assembling_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(assembling_world)
	await assembling_world.startup_completed
	if generation!=title_load_generation:
		assembling_world.queue_free()
		preparing_intro_world = false
		return
	prepared_intro_world = assembling_world
	intro_preloaded.clear()
	preparing_intro_world = false
	intro_probe_step("world",world_started)
	intro_world_prepared.emit()

func intro_probe_step(phase: String, started: int) -> void:
	if intro_probe and (intro_leaving or screen in ["intro","title"]):
		print("ROX_INTRO_TIMING ",phase," ms=",(Time.get_ticks_usec()-started)/1000.0)

func continue_to_village() -> void:
	if model.state.is_empty():chapter_menu()
	else:await enter_game(false,true)

func toggle_sound() -> void:
	settings.set_value("app","sound",not settings.get_value("app","sound",true))
	if settings.save(prefs_path)!=OK:show_error("소리 설정을 저장하지 못했습니다.")
	else:
		sync_audio()
		update_title_sound()
		toast("소리 켜짐" if settings.get_value("app","sound",true) else "소리 꺼짐")

func update_title_sound() -> void:
	if not is_instance_valid(title_sound):return
	var enabled: bool = settings.get_value("app","sound",true)
	title_sound.icon = preload("res://assets/ui/v0158/sound-on.svg") if enabled else preload("res://assets/ui/v0158/sound-off.svg")
	title_sound.tooltip_text = "소리 끄기" if enabled else "소리 켜기"


func chapter_menu() -> void:
	if preparing_intro_world:await intro_world_prepared
	discard_prepared_intro_world()
	close_modal()
	show_screen("chapter")

func new_game_prompt() -> void:
	show_modal("새 여정 시작","새 여정을 시작하면 기존 진행이 교체됩니다. 소리 설정은 유지합니다.",[
		{"text":"돌아가기","action":close_modal},
		{"text":"새로 시작","action":chapter_menu,"primary":true}],false,false,false,Vector2.ZERO,true)

func discard_prepared_intro_world() -> void:
	title_load_generation += 1
	if is_instance_valid(prepared_intro_world):prepared_intro_world.queue_free()
	prepared_intro_world = null
	title_world_progress = 0.0

func full_reset() -> void:
	if preparing_intro_world:await intro_world_prepared
	if not model.store.erase_progress():show_error(model.store.message);return
	settings.clear()
	if settings.save(prefs_path)!=OK:show_error("설정 초기화를 저장하지 못했습니다.");return
	discard_prepared_intro_world()
	model.state.clear();cancel_task()
	if village_alerts:village_alerts.sync()
	if is_instance_valid(world):remove_child(world);world.queue_free();world=null
	close_modal();show_screen("title")

func region_screen() -> void:
	region_selection=RegionSelection.new(self,region_snapshot)
	stage.add_child(region_selection)

func request_first_village() -> void:
	if screen!="region" or is_instance_valid(intro_cloud) or not application_active:return
	if is_instance_valid(region_selection) and region_selection.selected!="amsa":
		toast("현재 데모는 암사동에서 시작할 수 있습니다.");return
	first_village_loading = true
	region_selection.cancel_input()
	cover_intro(start_region_under_cover)
	intro_loading.text = "마을 준비 중…"

func start_region_under_cover() -> void:
	intro_loading.show()
	# Present the loading notice before synchronous world creation.
	await get_tree().process_frame
	await get_tree().process_frame
	while not application_active:
		await get_tree().process_frame
	start_region()
	await get_tree().process_frame
	reveal_intro_destination()

func start_region() -> void:
	if is_instance_valid(region_selection) and region_selection.selected!="amsa":
		toast("현재 데모는 암사동에서 시작할 수 있습니다.");return
	if model.start_new():
		if is_instance_valid(world):
			remove_child(world)
			world.queue_free()
			world = null
		enter_game(true)

func enter_game(first_entry:=false,spread_hud:=false) -> void:
	if model.state.is_empty():
		return
	if village_alerts and VillageNotifications.EVENTS.any(func(event):return VillageNotifications.setting(model.state,event)):
		village_alerts.request_permission()
	if not is_instance_valid(world):
		var world_started := Time.get_ticks_usec()
		world = DemoWorld.new(model)
		add_child(world)
		intro_probe_step("world",world_started)
		world.feedback.sound_cue.connect(audio.cue)
	if not is_instance_valid(building_workflow):
		building_workflow=BuildingWorkflow.new(self);add_child(building_workflow)
	else:building_workflow.refresh_visual()
	if not is_instance_valid(building_work_audio):
		building_work_audio=BuildingWorkAudio.new(self);add_child(building_work_audio)
	if not is_instance_valid(navigation):
		navigation=AutoTravel.new(self);add_child(navigation)
	var hero_started := Time.get_ticks_usec()
	world.player.set_character_3d(true)
	world.player.camera.reset_smoothing()
	intro_probe_step("hero_3d",hero_started)
	await show_screen("play",spread_hud)
	if first_entry:
		gestures.clear()
		village_entry=VillageEntry.new(world.player,world.boundary_root.get_node_or_null("UnlockedPerimeter"),not first_village_loading)
		stage.modulate.a = 0.0
		village_entry.completed.connect(reveal_first_village_hud.bind(stage))
		ui.add_child(village_entry)

func reveal_first_village_hud(hud: Control) -> void:
	if is_instance_valid(hud):
		hud.create_tween().tween_property(hud,"modulate:a",1.0,.22)
	if get_viewport().get_visible_rect().size != Vector2(w,h):
		call_deferred("queue_layout")

func village_entry_active()->bool:
	return is_instance_valid(village_entry) and not village_entry.is_queued_for_deletion()

func finish_village_entry()->void:
	if village_entry_active():village_entry.finish()

func play_hud(spread:=false) -> void:
	var hud_started := Time.get_ticks_usec()
	performance_hud=PERFORMANCE_HUD.new()
	stage.add_child(performance_hud)
	performance_hud.position=Vector2(w-safe.x-193,safe.y+156)
	performance_hud.visible=PerformanceDiagnostics.hud_enabled(settings)
	performance_hud.update_sample(performance_diagnostics.latest)
	var quest_panel:=button(stage,"",toggle_quest);quest_panel.name="QuestPanel";quest_panel.z_index=40;quest_panel.custom_minimum_size=Vector2.ZERO
	quest_panel.position=Vector2(safe.x,safe.y+(112 if w<h else 59));quest_panel.size=Vector2(240,84)
	for state in ["normal","hover","pressed","focus"]:quest_panel.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var quest_bg:=picture(quest_panel,preload("res://assets/ui/v0158/quest-hud-paper.png"),Rect2(0,0,240,84))
	quest_bg.stretch_mode=TextureRect.STRETCH_SCALE;quest_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);quest_bg.modulate.a=.9
	quest_arrow=picture(quest_panel,preload("res://assets/ui/v0158/quest-hud-fold.png"),Rect2(206,16,24,24));quest_arrow.pivot_offset=Vector2(12,12)
	picture(quest_panel,DemoArt.facility_icon("chief",1),Rect2(10,16,28,28))
	objective=label(quest_panel,"",13,Color("49321e"));objective.position=Vector2(40,18.8);objective.size=Vector2(168,24);objective.clip_text=true
	quest_detail=Control.new();quest_detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;quest_panel.add_child(quest_detail)
	picture(quest_detail,DemoArt.icon("wood"),Rect2(40,40.4,24,24));picture(quest_detail,DemoArt.icon("stone"),Rect2(136,40.4,24,24))
	quest_wood=label(quest_detail,"",12,Color("49321e"));quest_wood.position=Vector2(68,40.4);quest_wood.size=Vector2(54,24)
	quest_stone=label(quest_detail,"",12,Color("49321e"));quest_stone.position=Vector2(164,40.4);quest_stone.size=Vector2(54,24)
	quest_panel.set_meta("semantic_text","퀘스트 상세 펼침·접힘")
	joystick=DemoJoystick.new();stage.add_child(joystick);joystick.position=Vector2(safe.x,h-safe.y-140);joystick.hide();joystick.set_process_input(false)
	var action_width:=64.0 if w/h>2.2 else 60.0
	var menu_width:=action_width*5+8*4+48
	menu_backdrop=Panel.new();menu_backdrop.name="MenuBackdrop";menu_backdrop.z_index=30;menu_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(menu_backdrop)
	var capsule:=StyleBoxFlat.new();capsule.bg_color=Color(.33,.25,.12,.83);capsule.border_color=Color(.83,.68,.38,.9);capsule.set_border_width_all(2);capsule.set_corner_radius_all(30);capsule.shadow_color=Color(0,0,0,.2);capsule.shadow_size=3;menu_backdrop.add_theme_stylebox_override("panel",capsule)
	action_row=Control.new();action_row.name="Actions";action_row.z_index=31;action_row.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(action_row)
	action_row.position=Vector2(w-safe.x-menu_width,h-safe.y-76);action_row.size=Vector2(menu_width,72)
	if w<h:action_row.position.y=h-safe.y-220
	debug_shortcut=button(stage,"",toggle_performance_debug)
	debug_shortcut.name="PerformanceDebugShortcut"
	debug_shortcut.custom_minimum_size=Vector2.ZERO
	debug_shortcut.size=Vector2(48,48)
	debug_shortcut.position=Vector2(w-safe.x-48,action_row.position.y-124)
	debug_shortcut.z_index=36
	debug_shortcut_icon=picture(debug_shortcut,preload("res://assets/ui/v0158/debug-bug.svg"),Rect2(9,9,30,30))
	update_debug_shortcut()
	for data in [["사냥","spear"],["채집","berries"],["제작","hammer"],["가방","bag"],["건설","hut"]]:
		var caption:String=data[0]
		var callback:Callable=open_hunt if caption=="사냥" else gather_action if caption=="채집" else construction_menu if caption=="건설" else inventory_summary if caption=="가방" else func():toast("아직 준비 중인 기능입니다")
		var b:=button(action_row,caption,callback,false,data[1]);b.custom_minimum_size=Vector2(action_width,72)
		b.set_meta("permanent_action",true)
		b.set_meta("auxiliary_action",caption!="건설")
		if caption=="사냥":b.name="HuntButton"
		if caption=="제작":b.disabled=true;b.hint_text=caption+"은 아직 준비 중입니다"
		b.icon=DemoArt.play_icon(data[1])
		if caption=="가방":b.name="InventoryButton"
		var action_style:=StyleBoxFlat.new();action_style.bg_color=Color.TRANSPARENT;action_style.set_content_margin_all(2)
		for state in ["normal","hover","pressed","disabled"]:b.add_theme_stylebox_override(state,action_style)
		var visual:=ActionVisual.new(b,b.icon);b.icon=null;b.add_child(visual)
		for color_name in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:b.add_theme_color_override(color_name,Color.TRANSPARENT)
		if caption=="채집":
			gather_button=b
			gather_lock_icon=picture(b,IntegratedMenuArt.lock_icon(),Rect2(3,37,23,23))
		if caption=="건설":
			build_button=b
			build_visual=visual
			build_return_badge=picture(b,preload("res://assets/ui/construction-side-v006/return-badge.svg"),Rect2(35,0,28,28))
			build_return_badge.hide()
			build_lock_icon=picture(b,IntegratedMenuArt.lock_icon(),Rect2(3,37,23,23))
			build_lock_icon.visible=first_construction_locked()
			b.disabled=build_lock_icon.visible
	menu_toggle=button(action_row,"‹",toggle_menu);menu_toggle.name="MenuToggle";menu_toggle.custom_minimum_size=Vector2(56,56);menu_toggle.size_flags_vertical=Control.SIZE_SHRINK_CENTER;menu_toggle.hint_text="보조 메뉴 펼침·접힘"
	menu_toggle.icon=null;menu_toggle.expand_icon=true;menu_toggle.add_theme_constant_override("icon_max_width",54)
	var circle:=StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","focus"]:menu_toggle.add_theme_stylebox_override(state,circle)
	menu_toggle.text="";menu_toggle.icon=null
	var toggle_visual:=MenuToggleVisual.new();toggle_visual.name="ToggleVisual";menu_toggle.add_child(toggle_visual)
	apply_menu_state()
	if spread:await get_tree().process_frame
	build_side=BuildSideMenu.new(self);stage.add_child(build_side)
	build_side.visibility_changed.connect(update_construction_row)
	tutorial=IntroTutorial.new(self);stage.add_child(tutorial)
	building_menu=BuildingMenu.new(self)
	queued_action_indicator=QueuedActionIndicator.new(self);stage.add_child(queued_action_indicator)
	build_preview=BuildPreview.new(self);world.add_child(build_preview)
	var dark:=DemoArt.panel(true)
	context_panel=PanelContainer.new();stage.add_child(context_panel);context_panel.position=Vector2(w*.5-145,h-safe.y-108);context_panel.size=Vector2(290,32);context_panel.add_theme_stylebox_override("panel",dark);context_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	context=label(context_panel,"",13,Color("fff0cd"));context.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	context_panel.hide()
	task_bar=ProgressBar.new();task_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;task_bar.show_percentage=false;task_bar.position=Vector2(w*.5-100,h-safe.y-120);task_bar.size=Vector2(200,7);stage.add_child(task_bar);task_bar.visible=false
	chrome=PlayChrome.new(self);chrome.z_index=30;stage.add_child(chrome);chrome.size=Vector2(w,h)
	resident_panel=ResidentPanel.new(self);stage.add_child(resident_panel)
	stage.add_child(ConstructionProgress.new(self))
	stage.add_child(ConstructionProgress.new(self,false,true))
	family=FamilyArrival.new(self);stage.add_child(family)
	var map_hit:=button(stage,"",recenter_map);map_hit.name="RecenterCamera";map_hit.custom_minimum_size=Vector2.ZERO;map_hit.position=Vector2(w-safe.x-100,safe.y+10);map_hit.size=Vector2(100,100)
	map_hit.hint_text="현재 위치로 지도 맞추기"
	for state in ["normal","hover","pressed"]:map_hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	intro_probe_step("hud_before_map",hud_started)
	var map_started := Time.get_ticks_usec()
	world_map = null
	if spread:await get_tree().process_frame
	intro_probe_step("hud_map",map_started)
	map_toggle=button(stage,"",toggle_world_map);map_toggle.icon=AssetCatalog.texture("UI-MAP");map_toggle.expand_icon=true;map_toggle.add_theme_constant_override("icon_max_width",48);map_toggle.custom_minimum_size=Vector2.ZERO;map_toggle.position=Vector2(w-safe.x-64,safe.y+90);map_toggle.size=Vector2(56,56);map_toggle.z_index=31
	for state in ["normal","hover","pressed","focus"]:map_toggle.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var settings_button:=button(stage,"",pause_game);settings_button.name="SettingsButton";settings_button.z_index=31
	settings_button.icon=load("res://assets/ui/review-v037/settings-figma.png");settings_button.expand_icon=true
	settings_button.custom_minimum_size=Vector2.ZERO;settings_button.position=Vector2(w-safe.x-36,safe.y-2);settings_button.size=Vector2(36,36)
	settings_button.add_theme_constant_override("icon_max_width",36)
	for state in ["normal","hover","pressed","focus"]:settings_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	quest_reward_count=QuestRewards.install_entry(self)
	stage.add_child(VillageRewardBoard.new(self))
	stage.add_child(BuildingUpgradeSigns.new(self))
	# GUI hit testing visits later siblings first; the menu only blocks through its buttons.
	stage.add_child(building_menu)
	world_map_open=false
	update_hud()
	intro_probe_step("hud_total",hud_started)

func toggle_world_map()->void:
	if modal or map_transition_active:return
	map_transition_active=true;gestures.clear()
	if is_instance_valid(world_map):world_map.clear_input()
	world.player.direction=Vector2.ZERO;world.player.presentation_paused=true
	map_transition=ColorRect.new();map_transition.name="MapCloudTransition"
	map_transition.mouse_filter=Control.MOUSE_FILTER_STOP;map_transition.z_index=20
	var clouds:=ShaderMaterial.new();clouds.shader=preload("res://shaders/cloud_transition.gdshader")
	clouds.set_shader_parameter("aspect",w/h);map_transition.material=clouds
	stage.add_child(map_transition);map_transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_tween=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	map_tween.tween_method(func(value:float):clouds.set_shader_parameter("coverage",value),0.0,1.0,.36)
	map_tween.tween_callback(switch_map_scene)
	map_tween.tween_method(func(value:float):clouds.set_shader_parameter("coverage",value),1.0,0.0,.44)
	map_tween.tween_callback(func():
		map_transition.queue_free();map_transition_active=false
		world.player.presentation_paused=modal or not application_active)

func switch_map_scene()->void:
	if not is_instance_valid(world_map):
		world_map = VillageWorldMap.new(self)
		stage.add_child(world_map)
		stage.move_child(world_map,0)
	chrome.clear_effects()
	world_map_open=not world_map_open
	gestures.clear()
	world_map.activate(world_map_open)
	world.visible=not world_map_open
	world.set_process_mode(Node.PROCESS_MODE_DISABLED if world_map_open else Node.PROCESS_MODE_INHERIT)
	action_row.visible=not world_map_open
	objective.get_parent().visible=not world_map_open
	family.bubble.visible=not world_map_open and model.family_available()
	map_toggle.icon=null if world_map_open else AssetCatalog.texture("UI-MAP")
	map_toggle.material=null
	var home_face=map_toggle.get_node_or_null("FigmaHomeFace")
	if not home_face:
		home_face=TextureRect.new();home_face.name="FigmaHomeFace";home_face.mouse_filter=Control.MOUSE_FILTER_IGNORE
		home_face.texture=load("res://assets/refactor-v035/map-button.png")
		home_face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;home_face.position=Vector2(4,4.5714);home_face.size=Vector2(48,46.8571)
		var material:=ShaderMaterial.new();material.shader=load("res://shaders/figma_home_toggle.gdshader")
		material.set_shader_parameter("background_tex",load("res://assets/ui/review-v037/home-background.svg"))
		material.set_shader_parameter("border_tex",load("res://assets/refactor-v035/map-button.png"))
		material.set_shader_parameter("mask_tex",load("res://assets/ui/review-v037/home-border-mask.svg"))
		home_face.material=material;map_toggle.add_child(home_face)
		var village_icon:=TextureRect.new();village_icon.name="VillagePicture"
		village_icon.texture=AssetCatalog.texture("WORLD-VILLAGE");village_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		village_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;village_icon.position=Vector2(0,2);village_icon.size=Vector2(48,43)
		village_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;home_face.add_child(village_icon)
	home_face.visible=world_map_open
	map_toggle.tooltip_text=""
	map_toggle.hint_text=""
	if world_map_open:
		world.player.direction=Vector2.ZERO
		cancel_build_preview()
		context_panel.hide();task_bar.hide()
	chrome.queue_redraw()

func recenter_map()->void:
	if world_map_open:
		world_map.center=Vector2.ZERO;world_map.clear_input();world_map.queue_redraw()
	else:world.player.resume_camera()
	chrome.queue_redraw()

func update_construction_row()->void:
	apply_menu_state()
	if build_side.visible:build_side.refresh()

func toggle_menu()->void:
	if menu_animating:return
	if is_instance_valid(build_side):build_side.hide()
	if is_instance_valid(gestures):gestures.clear()
	menu_expanded=not menu_expanded
	apply_menu_state(true)

func apply_menu_state(animated:bool=false)->void:
	if not is_instance_valid(action_row):return
	if menu_tween:menu_tween.kill()
	var button_width:=64.0 if w/h>2.2 else 60.0
	var stride:=button_width+8
	var width:=stride*5+56
	action_row.size=Vector2(width,77);action_row.position.x=w-safe.x-width
	menu_animating=animated
	if animated:
		menu_tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		menu_tween.finished.connect(func():menu_animating=false)
	for i in 5:
		var child:Control=action_row.get_child(i)
		var auxiliary:bool=child.get_meta("auxiliary_action",false)
		var construction_open:=is_instance_valid(build_side) and build_side.visible
		var shown:=not auxiliary or (menu_expanded and not construction_open)
		var target:=Vector2(stride*i if menu_expanded else stride*4,0)
		child.size=Vector2(button_width,77)
		child.mouse_filter=Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
		if shown:child.show()
		if animated:
			menu_tween.tween_property(child,"position",target,.22)
			menu_tween.tween_property(child,"modulate:a",1.0 if shown else 0.0,.18)
			if not shown:menu_tween.tween_callback(child.hide).set_delay(.22)
		else:
			child.position=target;child.modulate.a=1.0 if shown else 0.0;child.visible=shown
	menu_toggle.text=""
	menu_toggle.icon=null
	menu_toggle.get_node("ToggleVisual").expanded=menu_expanded
	menu_toggle.get_node("ToggleVisual").queue_redraw()
	menu_toggle.hint_text="접기" if menu_expanded else "메뉴 펼치기"
	menu_toggle.size=Vector2(56,56);menu_toggle.position=Vector2(stride*5,10)
	menu_toggle.pivot_offset=menu_toggle.size*.5
	menu_toggle.rotation=0.0
	menu_toggle.visible=not (is_instance_valid(build_side) and build_side.visible)
	build_return_badge.visible=not menu_toggle.visible
	build_visual.pedestal.self_modulate=Color(1.25,1.08,.72) if build_return_badge.visible else Color.WHITE
	if not menu_toggle.visible:build_button.position.x=width-button_width
	menu_backdrop.hide()

func inventory_summary() -> void:
	var body:="나무 %d개 · 돌 %d개\n곡식 %d개 · 구리 %d개 (수입 규칙 미정)"%[model.state.wood,model.state.stone,model.state.get("grain",model.state.tokens),model.state.get("copper",0)]
	body+="\n저장 한도 · 목재 %d / 석재 %d / 곡식 %d"%[ResourceStorage.capacity(model,"wood"),ResourceStorage.capacity(model,"stone"),ResourceStorage.capacity(model,"grain")]
	var stock:=0
	for cycle in model.state.get("farm_cycles",{}).values():stock+=int(cycle.stock)
	if stock>0:body+="\n농장 보관 곡식 %d개"%stock
	var held:={"wood":0,"stone":0,"grain":0}
	for cargo in model.state.get("held_cargo",[]):held[cargo.kind]+=int(cargo.amount)
	if not model.state.get("held_cargo",[]).is_empty():body+="\n별도 보관: 목재 %d · 석재 %d · 곡식 %d (처리 규칙 대기)"%[held.wood,held.stone,held.grain]
	show_modal("가진 재료",body,[{"text":"돌아가기","action":close_modal}],false,true)

func update_hud() -> void:
	if screen!="play" or not is_instance_valid(objective) or model.state.is_empty():return
	update_quest()

func show_pending_quest_guide()->void:
	if village_entry_active() or modal or choosing_plot or not task.is_empty() or not application_active:return
	var current:=FirstQuests.current(model.state)
	if current<0 or current>FirstQuests.INTRO_KINDS.size():return
	if FirstQuests.intro_reward_ready(model.state,current):
		var body:="화면을 눌러 보상으로 %s %d개를 받으세요."%[FirstQuests.INTRO_RESOURCES[current],FirstQuests.INTRO_AMOUNT]
		show_character_guide(FirstQuests.INTRO_SUCCESSES[current],body,claim_intro_reward.bind(current))
		return
	if model.mark_quest_guide(current):
		var title:String=FirstQuests.INTRO_GUIDES[current] if current<FirstQuests.INTRO_KINDS.size() else FirstQuests.TITLES[current]
		show_character_guide(title,FirstQuests.OBJECTIVES[current])

func claim_intro_reward(index:int)->void:
	if not model.claim_quest_reward(index):return
	if model.state.get("guided_intro",false):world.player.release_tutorial_camera()
	var kind:String=FirstQuests.INTRO_KINDS[index] if index!=2 else "tokens"
	for i in 5:
		chrome.gained(kind,world.player.position+Vector2((i-2)*10,-52),i*.055)

func first_construction_locked()->bool:
	return model.chief_level()==0 and model.pending_construction_count("chief")==0 and FirstQuests.current(model.state) in [0,1]

func _process(delta: float) -> void:
	performance_diagnostics.tick(self,delta)
	if screen=="intro":
		if application_active and not intro_leaving and is_instance_valid(intro_player):
			var position := intro_player.stream_position
			intro_stall = intro_stall+delta if intro_preparing or is_equal_approx(position,intro_position) else 0.0
			intro_position = position
			if not intro_player.is_playing() or intro_stall>=3.0:finish_intro()
			elif intro_preparing:intro_loading.visible = intro_stall>=1.0
		return
	if screen=="title" and application_active and is_instance_valid(title_prompt):
		advance_title_loading()
		if not title_initial_update_done or Time.get_ticks_msec()-title_update_at>=60000:check_title_update()
		refresh_title_start_prompt()
		title_prompt_time=fposmod(title_prompt_time+delta,3.0)
		title_prompt.modulate.a=.87+.13*cos(title_prompt_time*TAU/3.0)
	if is_instance_valid(toast_panel): toast_panel.visible = toast_time > 0 and toast_label.text != ""
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0 and is_instance_valid(toast_label): toast_label.text = ""
	if is_instance_valid(world):world.simulation_paused=not application_active or world_map_open or map_transition_active
	if screen != "play" or world_map_open or map_transition_active or is_instance_valid(intro_cloud) or village_entry_active() or not is_instance_valid(world):
		return
	show_pending_quest_guide()
	if application_active:
		farm_tick+=delta
		if farm_tick>=1.0:
			FarmProduction.tick(model,farm_tick);farm_tick=0.0
	var river_distance:=INF
	for i in world.SHORE.size()-1:
		var closest:=Geometry2D.get_closest_point_to_segment(world.player.position,world.SHORE[i],world.SHORE[i+1])
		river_distance=minf(river_distance,world.player.position.distance_to(closest))
	audio.river_proximity=1.0-smoothstep(80,720,river_distance)
	context_panel.visible = false # Passive lower hints are replaced by world markers/HUD states.
	var direction := Vector2.ZERO
	if not modal and application_active and not gestures.blocked and not tutorial.active():
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
				world.player.set_activity("gather");task_bar.visible=false
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
	build_button.hint_text=working_hint if task!="" else ("완성된 보금자리입니다" if (model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES) else (model.building_requirement("hut") if not model.can_build() else "움집을 선택하고 건설할 부지를 골라 주세요"))
	gather_button.set_working(task=="gather");build_button.set_working(task=="build")
	gather_button.text="채집"
	build_button.text="건설"
	gather_button.disabled = modal or tutorial.active()
	gather_lock_icon.visible=tutorial.active()
	build_lock_icon.visible=first_construction_locked()
	build_button.disabled = modal or build_lock_icon.visible
	if build_lock_icon.visible:build_button.hint_text="목재·석재 채집 보상을 받으면 건설할 수 있어요"
	style_action_state(gather_button)
	style_action_state(build_button)
	if task == "":
		context.text = ""
		if world.near_site() and not (model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES):
			context.text = "보금자리 터 · 건설 가능" if model.can_build() else "보금자리 터 · 나무와 돌을 모아 주세요"
		elif not (model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES) and world.player.position.distance_to(world.site.position) < 150:
			context.text = "보금자리 터 아래쪽 입구로 이동해 주세요"
		elif model.can_build():
			context.text = "재료 준비 완료 · 금빛 터에서 건설"
		elif not near.is_empty():
			var ready: bool = model.state[near.kind] >= (DemoConfig.get_data().wood_cost if near.kind == "wood" else DemoConfig.get_data().stone_cost)
			context.text = ("나무 준비 완료 · 돌을 찾아보세요" if near.kind == "wood" else "돌 준비 완료 · 나무를 찾아보세요") if ready and not (model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES) else ("나무" if near.kind == "wood" else "돌")+" · 채집 버튼을 누르세요"
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
	if not n.is_empty() and ResourceStorage.room(model,n.kind)<=0:toast("%s 저장 공간이 가득 찼어요"%("목재" if n.kind=="wood" else "석재"));return
	if not n.is_empty() and not model.gather_available(n.id,"hero"):
		toast("다른 채집자가 선택한 대상이에요");return
	if n.is_empty():
		var candidates:=model.nodes().filter(func(c):return model.gather_available(c.id,"hero") and not world.exhausted(c) and world.player.position.distance_to(DemoConfig.point(c.position))<=GATHER_SEARCH_RADIUS)
		candidates.sort_custom(func(a,b):return world.player.position.distance_squared_to(DemoConfig.point(a.position))<world.player.position.distance_squared_to(DemoConfig.point(b.position)))
		for candidate in candidates:
			if navigation.start("gather",candidate.id,world.gather_stand(DemoConfig.point(candidate.position),candidate.kind),0,[],true):return
		toast("주변에 접근 가능한 채집물이 없어요");return
	if world.player.position.distance_to(DemoConfig.point(n.position))>float(DemoConfig.get_data().interact_radius):
		navigation.start("gather",n.id,world.gather_stand(DemoConfig.point(n.position),n.kind));return
	navigation.cancel()
	if not model.claim_gather(n.id,"hero"):return
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
	task_bar.visible = false
	context.text = "자원 옆에 자리 잡는 중" if gather_approach else "채집 중… 이동하면 멈춥니다"

func construction_menu()->void:
	if menu_animating or build_side.transition:return
	if modal or gestures.blocked or first_construction_locked():return
	if is_instance_valid(building_menu):building_menu.close()
	cancel_build_preview()
	if model.chief_level()==0:
		if model.pending_construction_count("chief")>0:
			build_side.select_kind("chief")
		else:
			start_first_chief_placement()
		return
	build_side.toggle_animated()

func start_first_chief_placement()->void:
	if screen!="play" or not is_instance_valid(world) or model.chief_level()>0 or model.pending_construction_count("chief")>0:return
	build_side.hide()
	build_kind="chief"
	choosing_plot=true
	if tutorial.active():
		if not tutorial.choose_plot():
			choosing_plot=false
			toast("건설 가능한 부지를 찾지 못했어요. 다시 시도해 주세요")
		return
	var center:=Vector2(w*.5,h*.55)
	var at:Vector2=world.get_global_transform_with_canvas().affine_inverse()*center
	build_preview.select_position(at,build_kind)

func cancel_build_preview()->void:
	if choosing_plot and is_instance_valid(world) and task!="build":world.clear_site()
	choosing_plot=false
	if is_instance_valid(build_preview):build_preview.clear()
	if is_instance_valid(world):world.show_candidates=false;world.queue_redraw()

func confirm_build_preview()->void:
	if not is_instance_valid(build_preview) or not build_preview.active() or not application_active or modal:return
	var reason:String=build_preview.block_reason()
	if not reason.is_empty():toast(reason);return
	var at:Vector2=build_preview.placement_position
	var key:String=build_preview.moving_key
	if not key.is_empty():
		if not relocating_key.is_empty():return
		var original:Sprite2D=world.building_sprite(key)
		var snapshot:=Sprite2D.new();snapshot.texture=original.texture;snapshot.centered=original.centered;snapshot.offset=original.offset
		snapshot.transform=original.global_transform
		var from:=model.building_position(key)
		build_preview.restore_source()
		if model.move_building(key,at):
			world.evacuate_animals(at,build_preview.kind)
			cancel_build_preview();relocating_key=key
			world.add_child(RelocationEffect.new(self,key,snapshot,from,at))
		else:
			snapshot.free();toast("위치가 변경되었어요. 다시 확인해 주세요")
		return
	if not can_build_selected():return
	if model.begin_construction(build_kind,at):
		world.evacuate_animals(at,build_kind)
		cancel_build_preview()
		toast("건설을 시작했어요")
	else:toast("건설 조건이 변경되었어요. 다시 확인해 주세요")

func start_building_move(key:String)->void:
	if not relocating_key.is_empty():return
	if modal or not application_active or world_map_open:return
	var found:=model.lookup_building(key)
	if found.is_empty():return
	cancel_task();build_side.hide();building_menu.close()
	build_kind=str(found.get("kind","hut"));choosing_plot=true
	build_preview.select_position(model.building_position(key),build_kind,key)

func reserve_action(request:Dictionary)->void:
	if request.get("kind","")=="gather" and not str(request.get("id","")).is_empty():
		if not model.claim_gather(str(request.id),"hero-pending"):
			toast("다른 채집자가 선택한 대상이에요");return
	else:model.release_gather("hero-pending")
	pending_action=request.duplicate(true)
	if is_instance_valid(queued_action_indicator):queued_action_indicator.reserve(request)

func run_reserved_action()->void:
	var request:=pending_action.duplicate(true)
	if request.is_empty():return
	var receipt_generation:int=queued_action_indicator.dispatch()
	pending_action.clear()
	model.release_gather("hero-pending")
	dispatching_reserved_action=true
	match str(request.kind):
		"move":navigation.start("move","",request.at)
		"family":navigation.start("family","first",FamilyArrival.MEETING)
		"gather":gather_action(str(request.get("id","")))
		"build":
			build_kind=str(request.get("building","hut"))
			if world.select_site(int(request.id)):build_action()
			else:toast("예약한 건설 부지를 사용할 수 없어요")

	dispatching_reserved_action=false
	queued_action_indicator.observe_dispatch(receipt_generation)

func build_action() -> void:
	if modal or gestures.blocked:return
	if world.selected_site<0:toast("건설할 위치를 선택해 주세요");return
	if not can_build_selected():return
	build_preview.select_position(DemoConfig.BUILD_SITES[world.selected_site],build_kind)
	confirm_build_preview()

func finish_task() -> void:
	var kind:=task
	var target:=task_target
	cancel_task(false)
	if kind=="gather":
		if model.gather(target,world.player.position):
			world.feedback.gathered(target)
			var resource_kind:String="wood" if target.begins_with("wood") else "stone"
			chrome.gained(resource_kind,world.art_nodes[target].position+Vector2(0,-70))
			toast("",0)
	elif kind=="family":family.finish()
	call_deferred("run_reserved_action")

func cancel_task(clear_reservation:bool=true,preserve_receipt:bool=false) -> void:
	if model:model.release_gather("hero")
	if clear_reservation:
		if model:model.release_gather("hero-pending")
		pending_action.clear()
		if is_instance_valid(queued_action_indicator) and not dispatching_reserved_action and not preserve_receipt:queued_action_indicator.clear_receipt()
		cancel_build_preview()
	if is_instance_valid(navigation):navigation.cancel()
	if is_instance_valid(audio): audio.stop_work()
	task = ""
	if model:model.construction_busy=false
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

func request_building_menu(screen_point:Vector2)->void:
	if is_instance_valid(building_menu):building_menu.show_at(screen_point)

func request_demolition(screen_point:Vector2)->void:
	if modal or not application_active or screen!="play":return
	var at:=world.get_global_transform_with_canvas().affine_inverse()*screen_point
	for i in model.built_count():
		if world.reward_hit(i,at):show_demolition_confirmation(model.home_key(i));return

func show_demolition_confirmation(key:String)->void:
	if modal or not application_active or screen!="play":return
	var quote:=model.demolition_quote(key)
	if quote.is_empty():toast("현재 철거할 수 없는 건물이에요");return
	var found:=model.lookup_building(key)
	show_modal("건물을 철거할까요?","반환: 나무 %d개 · 돌 %d개"%[quote.wood,quote.stone]+("\n수용 인원이 줄어 주민 %d명이 무작위로 떠나며 배정이 해제됩니다. 운반 짐은 즉시 마을 자원에 반환합니다."%int(quote.departures) if int(quote.departures)>0 else ""),[{"text":"취소","action":close_modal},{"text":"철거","action":func():confirm_demolition(key)}],false,true,false,Vector2(480,380),true)
	demolition_key=key

func confirm_demolition(key:String)->void:
	if not application_active or not modal or demolition_key!=key:return
	var quote:=model.demolition_quote(key)
	if quote.is_empty():close_modal();return
	var at:=model.building_position(key)
	var prior:Sprite2D=world.building_sprite(key)
	var ghost:Sprite2D
	var ghost_transform:=Transform2D.IDENTITY
	if is_instance_valid(prior):
		ghost=Sprite2D.new();ghost.texture=prior.texture;ghost.material=prior.material
		ghost.centered=prior.centered;ghost.offset=prior.offset;ghost_transform=prior.global_transform
	if model.demolish(key):
		close_modal()
		if is_instance_valid(ghost):
			var effect:=DemolitionEffect.new(ghost)
			world.add_child(effect);effect.position=at
			effect.add_child(ghost);ghost.global_transform=ghost_transform
		world.feedback.sound_cue.emit("demolish")
		toast("나무 %d개 · 돌 %d개 반환"%[quote.wood,quote.stone],2)
	elif is_instance_valid(ghost):ghost.free()

func claim_home(index:int) -> void:
	if model.claim_reward(index):
		world.feedback.rewarded()
		for i in 6:chrome.gained("tokens",world.reward_marker_rect(index).get_center()+Vector2((i-3)*8,0),i*.055)

func world_tap(screen_point:Vector2) -> void:
	if menu_animating and action_row.get_global_rect().has_point(screen_point):return
	if camera_modal():close_modal();return
	if world_map_open or modal or gestures.blocked:return
	var at:Vector2=world.get_global_transform_with_canvas().affine_inverse()*screen_point
	if not relocating_key.is_empty() and building_menu.hit_key(at)==relocating_key:return
	if is_instance_valid(tutorial) and tutorial.active():return
	if choosing_plot:
		build_preview.select_position(at,build_kind,build_preview.moving_key)
		return
	if world.visitor_hit(at):
		family.request()
		return
	for i in model.built_count():
		if model.reward_pending(i) and (world.reward_marker_rect(i).grow(6).has_point(at) or building_menu.hit_key(at)==model.home_key(i)):claim_home(i);return
	if is_instance_valid(building_menu):
		if building_menu.show_at(screen_point):return
		if building_menu.visible:building_menu.close();return
	for n in model.nodes():
		if world.exhausted(n):continue
		var point:=DemoConfig.point(n.position)
		if world.resource_hit(n,at):
			if world.exhausted(n):toast("이 자원은 모두 채집했어요");return
			if not task.is_empty():
				navigation.start("gather",n.id,world.gather_stand(point,n.kind));return
			navigation.cancel()
			if world.player.position.distance_to(point)<=float(DemoConfig.get_data().interact_radius):gather_action(n.id)
			else:navigation.start("gather",n.id,world.gather_stand(point,n.kind))
			return
	# Building images own their taps even after their reward has been claimed.
	for prop in world.environment_props:
		if prop.kind=="hut" and prop.visible and Rect2(prop.position-Vector2(170,245),Vector2(340,260)).has_point(at):return
	cancel_build_preview()
	navigation.start("move","",at)

func focus_objective() -> void:
	if gestures.blocked or modal: return
	if (model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES):
		quest_details();return
	var point:=world.objectives.focus_point()
	var screen_point: Vector2=world.get_global_transform_with_canvas()*point
	if not Rect2(Vector2(80,90),Vector2(w-160,h-190)).has_point(screen_point): world.player.guide_to(point+Vector2(0,-35))

func quest_details() -> void:
	QuestScreen.new(self).open()

func pause_game() -> void:
	cancel_task()
	if is_instance_valid(world):model.save_position(world.player.position)
	show_modal("설정","암사동 · 첫 보금자리\n진행은 기기에 자동 저장됩니다.",[
		{"text":"계속하기","primary":true,"action":close_modal},
		{"text":"시작 화면","action":func(): close_modal(); show_screen("title")},
		{"text":"안내·소리","action":show_about},
		{"text":"알림 설정","action":show_notification_settings},
		{"text":"개발 설정","action":show_development_settings}])
	enable_settings_backdrop()

func show_development_settings()->void:
	DevelopmentSettings.open(self)
	enable_settings_backdrop()

func debug_shortcut_visible() -> bool:
	return settings.get_value("development","performance_shortcut",true)

func set_debug_shortcut_visible(enabled:bool) -> void:
	var previous:=debug_shortcut_visible()
	settings.set_value("development","performance_shortcut",enabled)
	if settings.save(prefs_path)!=OK:
		settings.set_value("development","performance_shortcut",previous)
		show_error("디버그 버튼 표시 설정을 저장하지 못했습니다.")
	update_debug_shortcut()

func update_debug_shortcut() -> void:
	if not is_instance_valid(debug_shortcut):return
	var active:=PerformanceDiagnostics.enabled(settings) or PerformanceDiagnostics.hud_enabled(settings)
	debug_shortcut.visible=debug_shortcut_visible()
	debug_shortcut.tooltip_text="성능 로그·HUD 끄기" if active else "성능 로그·HUD 켜기"
	debug_shortcut.set_meta("semantic_text",debug_shortcut.tooltip_text)
	debug_shortcut_icon.modulate=Color("92eea8") if active else Color("a2a6ad")

func toggle_performance_debug() -> void:
	if modal or world_map_open or map_transition_active:return
	var old_logs:=PerformanceDiagnostics.enabled(settings)
	var old_hud:=PerformanceDiagnostics.hud_enabled(settings)
	var enabled:=not (old_logs or old_hud)
	settings.set_value("development","performance_diagnostics",enabled)
	settings.set_value("development","performance_hud",enabled)
	if settings.save(prefs_path)!=OK:
		settings.set_value("development","performance_diagnostics",old_logs)
		settings.set_value("development","performance_hud",old_hud)
		show_error("성능 진단 설정을 저장하지 못했습니다.")
		return
	if is_instance_valid(performance_hud):performance_hud.visible=enabled
	update_debug_shortcut()

func set_performance_hud(enabled:bool)->void:
	var previous:=PerformanceDiagnostics.hud_enabled(settings)
	settings.set_value("development","performance_hud",enabled)
	if settings.save(prefs_path)!=OK:
		settings.set_value("development","performance_hud",previous)
		show_error("성능 HUD 설정을 저장하지 못했습니다.")
		return
	if is_instance_valid(performance_hud):performance_hud.visible=enabled
	update_debug_shortcut()

func confirm_delete_performance_logs() -> void:
	var logs:=PerformanceDiagnostics.log_summary()
	show_modal("진단 로그를 삭제할까요?","%d개 · %s를 삭제합니다. 기록이 켜져 있으면 새 로그가 다시 쌓입니다."%[logs.count,String.humanize_size(logs.bytes)],[
		{"text":"취소","action":show_development_settings},
		{"text":"삭제","action":delete_performance_logs}],false,true,false,Vector2.ZERO,true)

func delete_performance_logs() -> void:
	var failed:=performance_diagnostics.delete_logs()
	show_development_settings()
	if failed>0:toast("로그 %d개를 삭제하지 못했습니다."%failed)

func export_performance_logs()->void:
	var zip:=performance_diagnostics.export_zip()
	if zip.is_empty():
		show_error("내보낼 진단 기록이 없거나 ZIP을 만들지 못했습니다.")
		return
	var destination:=ProjectSettings.globalize_path(zip)
	if OS.has_feature("android"):
		if not village_alerts or not village_alerts.save_diagnostic_zip(destination,zip.get_file()):
			show_error("다운로드 폴더에 저장하지 못했습니다. 최신 APK와 Android 10 이상이 필요합니다.")
			return
		destination="다운로드/"+zip.get_file()
	show_modal("진단 기록 저장 완료",destination,[{"text":"확인","action":show_development_settings}])

func set_performance_diagnostics(enabled:bool)->void:
	var previous:=PerformanceDiagnostics.enabled(settings)
	settings.set_value("development","performance_diagnostics",enabled)
	if settings.save(prefs_path)!=OK:
		settings.set_value("development","performance_diagnostics",previous)
		show_error("성능 진단 설정을 저장하지 못했습니다.")
	update_debug_shortcut()

func confirm_progress_reset()->void:
	show_modal("진행을 초기화할까요?","진행과 자원을 지우고 소리 설정은 유지합니다. 삭제한 진행은 되돌릴 수 없습니다.",[
		{"text":"취소","action":show_development_settings},{"text":"초기화","action":reset_progress}],false,true,false,Vector2.ZERO,true)
func reset_progress()->void:
	if not model.store.erase_progress():show_error(model.store.message);return
	cancel_task();model.state.clear()
	if village_alerts:village_alerts.sync()
	if is_instance_valid(world):remove_child(world);world.queue_free();world=null
	close_modal();show_screen("title")

func confirm_development_reset()->void:
	show_modal("게임을 초기화할까요?","진행·자원·소리 설정을 모두 삭제하고 첫 실행 안내로 돌아갑니다.\n삭제한 데이터는 되돌릴 수 없습니다.",[
		{"text":"취소","action":show_development_settings},
		{"text":"완전 초기화","action":full_reset}],false,true,false,Vector2.ZERO,true)
	enable_settings_backdrop()

func show_about() -> void:
	var c := DemoConfig.get_data()
	var sound: bool = settings.get_value("app","sound",true)
	show_modal("RoxHistory · v"+str(ProjectSettings.get_setting("application/config/version")),c.history.fact+"\n\n"+c.history.fiction+"\n\n지역 선택 음악과 자연음, 채집·건설 효과음을 제공합니다. 곡식은 농장에서 생산합니다. 구리 화폐 수입 규칙은 준비 중입니다.",[
		{"text":"소리 끄기" if sound else "소리 켜기","action":func():
			settings.set_value("app","sound",not sound)
			if settings.save(prefs_path) != OK: show_error("소리 설정을 저장하지 못했습니다.")
			else: sync_audio(); show_about()},
		{"text":"돌아가기","primary":true,"action":close_modal}])
	enable_settings_backdrop()

func show_modal(title: String, body: String, actions: Array, compact: bool = false, preserve_work:bool=false, brief:bool=false, panel_size:Vector2=Vector2.ZERO,confirmation:bool=false) -> ScrollContainer:
	if is_instance_valid(region_selection):region_selection.cancel_input()
	if gestures: gestures.clear()
	if is_instance_valid(joystick): joystick.clear()
	if not preserve_work:cancel_task()
	if is_instance_valid(world):
		world.player.direction = Vector2.ZERO
		world.player.presentation_paused = true
	if is_instance_valid(overlay):
		if overlay.has_meta("restore_stage_visibility") and is_instance_valid(stage):stage.visible=overlay.get_meta("restore_stage_visibility")
		retire_modal(overlay)
	modal = true
	sync_audio()
	overlay = Control.new();overlay.z_index=50
	overlay.set_meta("fade_modal",true)
	overlay.modulate.a = 0.0
	ui.add_child(overlay)
	overlay.create_tween().tween_property(overlay,"modulate:a",1.0,.15)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dismiss:Callable=actions[0].action if confirmation and actions.size()>1 else close_modal
	var displayed_actions:Array=[actions[-1]] if confirmation and not actions.is_empty() else actions
	var shade := ModalBackdrop.new();shade.name="ModalBackdrop";shade.dismiss=dismiss
	shade.color = Color(0,0,0,0.18 if compact else 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var width := minf(300 if brief else 390 if compact else 680,w-safe.x*2)
	var height := minf(h-safe.y*2,166 if brief else 290 if compact else 500)
	if panel_size!=Vector2.ZERO:
		width=minf(panel_size.x,w-safe.x*2)
		height=minf(panel_size.y,h-safe.y*2)
	var at := Vector2(w-safe.x-width,safe.y) if compact and not brief else Vector2((w-width)/2,(h-height)/2)
	var p := box(overlay,Rect2(at,Vector2(width,height)))
	var v := column(p,8 if brief else 12)
	var header:=HBoxContainer.new();header.name="ModalHeader";header.add_theme_constant_override("separation",10);v.add_child(header)
	var modal_title:=label(header,title,20 if brief else 28,Color("47240e"));modal_title.add_theme_font_override("font",FigmaArt.TITLE);modal_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;modal_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	HudButtons.create(header,false,dismiss,"ModalClose")
	var scroll:ScrollContainer = DevelopmentSettingsScroll.new() if title in ["개발 설정","전체 주민 배분","일 선택"] or title.ends_with(" · 주민 배정") else ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	if not body.is_empty():
		var text := paragraph(scroll,body,16 if brief else 20)
		text.custom_minimum_size.x = width-60
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	v.add_child(row)
	row.name="ModalActions"
	for a in displayed_actions:
		var b := button(row,a.text,a.action,a.get("primary",false))
		b.disabled=a.get("disabled",false)
		if brief:b.custom_minimum_size=Vector2(80,44)
		if confirmation:b.custom_minimum_size.y=58
		for state in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for color_key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:b.add_theme_color_override(color_key,Color("47240e"))
		b.add_theme_font_override("font",FigmaArt.BODY)
		var skin:=FigmaSlice.new("gold",42);skin.name="FigmaSkin";skin.show_behind_parent=true;b.add_child(skin);skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",17)
	return scroll

func show_character_guide(title:String,body:String,after:Callable=Callable())->void:
	if overlay is CharacterGuide:
		overlay.enqueue(title,body,after)
		return
	# Informational overlay: no save mutation, reward or action cancellation.
	close_modal()
	if gestures:gestures.clear()
	if is_instance_valid(world):
		world.player.direction=Vector2.ZERO
		world.player.presentation_paused=true
	modal=true;toast_time=0
	overlay=CharacterGuide.new(self,title,body);overlay.z_index=50;ui.add_child(overlay);sync_audio()
	if after.is_valid():overlay.completions.append(after)

func close_modal() -> void:
	if is_instance_valid(building_workflow):building_workflow.confirmation_target=-1
	demolition_key=""
	if is_instance_valid(overlay):
		if overlay.has_meta("restore_stage_visibility") and is_instance_valid(stage):stage.visible=overlay.get_meta("restore_stage_visibility")
		retire_modal(overlay)
	overlay = null
	modal = false
	if is_instance_valid(joystick): joystick.clear()
	if is_instance_valid(world): world.player.presentation_paused = not application_active
	sync_audio()

func retire_modal(closing: Control) -> void:
	if closing.has_meta("fade_modal"):
		closing.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		closing.process_mode = Node.PROCESS_MODE_DISABLED
		closing.z_index = 49
		var fade := closing.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(closing,"modulate:a",0.0,.12)
		fade.tween_callback(closing.queue_free)
	else:
		ui.remove_child(closing)
		closing.queue_free()

func sync_audio() -> void:
	if is_instance_valid(audio): audio.configure(settings.get_value("app","sound",true),application_active,screen == "play",modal,screen == "region",screen == "title")

func toast(message: String, seconds: float = 3.0) -> void:
	if is_instance_valid(toast_label): toast_label.text = message
	toast_time = seconds

func show_error(message: String) -> void:
	call_deferred("display_error",message)

func display_error(message: String) -> void:
	cancel_task()
	show_modal("저장 확인",message+"\n저장 공간을 확인한 뒤 다시 시도해 주세요.",[{"text":"확인","action":close_modal}])

func open_hunt() -> void:
	if hunt_preparing or screen!="play" or modal or world_map_open or map_transition_active or village_entry_active() or tutorial.active():
		return
	cancel_task()
	gestures.clear()
	world.player.direction = Vector2.ZERO
	hunt_preparing = true
	hunt_preparation_cancelled = false
	toast("사냥터 준비 중…")
	var paths := ["res://assets/characters/meshy01/hero.glb","res://assets/characters/residents/sturdy_male.glb",
		"res://assets/characters/residents/female.glb",WorldAnimal.MODELS.deer]
	var pending: Array[String] = []
	var warmed: Array[Resource] = []
	for path: String in paths:
		if ResourceLoader.load_threaded_request(path,"PackedScene")==OK:pending.append(path)
	while not pending.is_empty():
		await get_tree().process_frame
		for index in range(pending.size()-1,-1,-1):
			var path := pending[index]
			match ResourceLoader.load_threaded_get_status(path):
				ResourceLoader.THREAD_LOAD_LOADED:
					warmed.append(ResourceLoader.load_threaded_get(path))
					pending.remove_at(index)
				ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					pending.remove_at(index)
	while not application_active and not hunt_preparation_cancelled:
		await get_tree().process_frame
	hunt_preparing = false
	if not hunt_preparation_cancelled and screen=="play" and not modal and not world_map_open:
		toast_time = 0.0
		show_screen("hunt")


func close_hunt() -> void:
	if screen!="hunt":return
	hunt = null
	show_screen("play")

func go_back() -> void:
	if hunt_preparing:
		hunt_preparation_cancelled = true
		toast_time = 0.0
		return
	if title_input_blocked():return
	if screen=="intro":
		finish_intro()
	elif is_instance_valid(intro_cloud):
		return
	elif screen=="hunt":
		hunt.request_exit()
	elif village_entry_active():
		finish_village_entry()
	elif overlay is CharacterGuide:
		overlay.advance()
	elif modal:
		close_modal()
	elif screen == "play":
		show_modal("게임을 종료할까요?","진행은 기기에 저장됩니다.",[
			{"text":"취소","action":close_modal},
			{"text":"종료","action":func():
				if is_instance_valid(world) and not model.save_position(world.player.position):return
				get_tree().quit()}],false,true,false,Vector2.ZERO,true)
	elif screen == "region": show_screen("title")
	else:
		show_modal("여정을 나갈까요?","앱을 종료합니다.",[{"text":"돌아가기","action":close_modal},{"text":"종료","action":func(): get_tree().quit()}],false,false,false,Vector2.ZERO,true)

func _input(event: InputEvent) -> void:
	if title_input_blocked() and not get_node("/root/PatchBootstrap/Overlay").popup.visible and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event.is_action("ui_accept") or event.is_action("ui_cancel")):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if map_transition_active or (is_instance_valid(intro_cloud) and screen!="intro"):return
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and screen == "play" and not world_map_open and not modal and not tutorial.active():
		if event.physical_keycode == KEY_E: gather_action()
		elif event.physical_keycode == KEY_B: construction_menu()

func _notification(what: int) -> void:
	# Synthetic tests issue PAUSED/RESUMED explicitly; desktop focus is external.
	if test_mode and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		finish_village_entry()
		var was_demolition:=not demolition_key.is_empty()
		if was_demolition:close_modal()
		if is_instance_valid(region_selection):region_selection.cancel_input()
		if gestures: gestures.clear()
		if is_instance_valid(chrome): chrome.clear_effects()
		application_active = false
		if title_reveal:title_reveal.pause()
		if intro_cloud_tween and intro_cloud_tween.is_valid():intro_cloud_tween.pause()
		if is_instance_valid(intro_player):intro_player.paused = true
		sync_audio()
		if is_instance_valid(world): world.feedback.clear_transients()
		if is_instance_valid(joystick): joystick.clear()
		if not overlay is CharacterGuide:cancel_task()
		if is_instance_valid(world) and screen == "play":
			world.player.direction = Vector2.ZERO
			world.player.presentation_paused = true
			if not was_demolition:model.save_position(world.player.position)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_active = true
		if title_reveal:title_reveal.play()
		if screen=="title":call_deferred("check_title_update")
		if intro_cloud_tween and intro_cloud_tween.is_valid():intro_cloud_tween.play()
		if is_instance_valid(intro_player) and not intro_leaving:intro_player.paused = false
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
	# Authored art supplies all borders, shadows and nameplates. No proximity halo.
	for variant in ["normal","hover","pressed","disabled"]:control.add_theme_stylebox_override(variant,StyleBoxEmpty.new())

func can_build_selected()->bool:
	var reason:String=building_workflow.build_block_reason(build_kind)
	if not reason.is_empty():toast(reason);return false
	return true

func enable_settings_backdrop()->void:
	if not is_instance_valid(overlay) or overlay.get_child_count()==0:return
	var shade:Control=overlay.get_child(0)
	if not shade is ModalBackdrop:
		shade.gui_input.connect(func(event:InputEvent):
			if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT):
				get_viewport().set_input_as_handled()
				close_modal())

func show_notification_settings()->void:
	var scroll:=show_modal("알림 설정","",[],false,true)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",14);scroll.add_child(list)
	var titles:={"construction":"건축 완료","upgrade":"업그레이드 완료","arrival":"새 주민 도착"}
	for event in VillageNotifications.EVENTS:
		var row:=HBoxContainer.new();list.add_child(row)
		var text:=label(row,titles[event],21);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var setting:Variant=VillageNotifications.setting(model.state,event)
		var target:String=event
		var toggle:=button(row,"ON" if setting else "OFF",func():
			if VillageNotifications.set_enabled(model,target,not setting):
				if not setting and village_alerts:village_alerts.request_permission()
				show_notification_settings())
		toggle.custom_minimum_size=Vector2(100,48)
	var note:=label(list,"Android 알림은 기기의 알림 권한과 무음 설정을 따릅니다.",17);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
