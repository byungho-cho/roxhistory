class_name DevelopmentSettings
extends RefCounted

# Add future options here; rows share the same scrollable list and touch sizes.
static func entries(app:Node)->Array[Dictionary]:
	var logs:=PerformanceDiagnostics.log_summary()
	return [
		{"id":"PerformanceShortcut","title":"마을에 디버그 버튼 표시","kind":"toggle",
			"value":app.debug_shortcut_visible(),"read":app.debug_shortcut_visible,
			"changed":app.set_debug_shortcut_visible},
		{"id":"PerformanceDiagnostics","title":"발열·성능 진단 기록 · 기기에만 저장","kind":"toggle",
			"value":PerformanceDiagnostics.enabled(app.settings),
			"read":func():return PerformanceDiagnostics.enabled(app.settings),
			"changed":app.set_performance_diagnostics},
		{"id":"PerformanceHud","title":"성능 HUD","kind":"toggle",
			"value":PerformanceDiagnostics.hud_enabled(app.settings),
			"read":func():return PerformanceDiagnostics.hud_enabled(app.settings),
			"changed":app.set_performance_hud},
		{"id":"FemaleResidentTrial","title":"여성 주민 1명 · 새 외형 시험","kind":"toggle",
			"value":app.female_resident_trial_enabled(),"read":app.female_resident_trial_enabled,
			"changed":app.set_female_resident_trial},
		{"id":"PerformanceExport","title":"진단 기록 ZIP 내보내기","kind":"action",
			"button":"내보내기","action":app.export_performance_logs},
		{"id":"PerformanceDelete","title":"진단 로그 %d개 · %s"%[logs.count,String.humanize_size(logs.bytes)],"kind":"action",
			"button":"삭제","action":app.confirm_delete_performance_logs,"disabled":logs.count==0},
		{"id":"UnlimitedBuildings","title":"건축물 개수 제한 해제","kind":"toggle",
			"value":app.model.debug_unlimited_buildings,"read":func():return app.model.debug_unlimited_buildings,
			"changed":func(enabled:bool):app.model.debug_unlimited_buildings=enabled},
		{"id":"UnlimitedBuilders","title":"건설자 무제한","kind":"toggle",
			"value":app.model.debug_unlimited_builders,"read":func():return app.model.debug_unlimited_builders,
			"changed":func(enabled:bool):app.model.debug_unlimited_builders=enabled},
		{"id":"FastBuild","title":"건설·업그레이드 모두 5초","kind":"toggle",
			"value":app.model.debug_fast_build,"read":func():return app.model.debug_fast_build,
			"changed":func(enabled:bool):app.model.set_debug_fast_build(enabled)},
		{"id":"ShowBoundary","title":"빨간 마을 경계선","kind":"toggle",
			"value":app.model.debug_show_boundary,"read":func():return app.model.debug_show_boundary,
			"changed":func(enabled:bool):app.model.set_debug_show_boundary(enabled)},
		{"id":"FillResources","title":"자원 채우기 · 자원바를 눌러 100개 추가","kind":"toggle",
			"value":app.model.debug_resource_refill,"read":func():return app.model.debug_resource_refill,
			"changed":func(enabled:bool):app.model.set_debug_resource_refill(enabled)},
		{"id":"ResetProgress","title":"진행 초기화 · 소리 설정 유지","kind":"action",
			"button":"초기화","action":app.confirm_progress_reset},
		{"id":"FullReset","title":"완전 초기화","kind":"action",
			"button":"초기화","action":app.confirm_development_reset}
	]

static func open(app:Node)->void:
	var scroll:ScrollContainer=app.show_modal("개발 설정","",[
		{"text":"돌아가기","action":app.pause_game}],false,true,false,Vector2(460,430))
	scroll.name="DevelopmentSettingsScroll"
	scroll.follow_focus=true
	populate(app,scroll,entries(app))
	var padding:=Control.new();padding.custom_minimum_size=Vector2(1,8)
	scroll.get_node("SettingsList").add_child(padding)

static func populate(app:Node,scroll:ScrollContainer,settings:Array[Dictionary])->void:
	var list:=VBoxContainer.new()
	list.name="SettingsList"
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	for setting in settings:
		var panel:=PanelContainer.new()
		panel.name=setting.id+"Row"
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("7c54241a")
		style.set_corner_radius_all(8)
		style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel",style)
		list.add_child(panel)
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		panel.add_child(row)
		var title:Label=app.label(row,setting.title,18)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if setting.kind=="toggle":
			var toggle:=DevelopmentSettingToggle.new()
			toggle.name=setting.id+"Toggle"
			toggle.custom_minimum_size=Vector2(104,44)
			var toggle_skin:=StyleBoxFlat.new();toggle_skin.bg_color=Color("59432d");toggle_skin.border_color=Color("b69a60");toggle_skin.set_border_width_all(1);toggle_skin.set_corner_radius_all(9);toggle_skin.content_margin_left=8;toggle_skin.content_margin_right=8;toggle_skin.content_margin_top=4;toggle_skin.content_margin_bottom=4
			for variant in ["normal","hover","pressed","hover_pressed","focus"]:toggle.add_theme_stylebox_override(variant,toggle_skin)
			toggle.add_theme_font_size_override("font_size",18)
			toggle.set_pressed_no_signal(setting.value)
			toggle.text="ON" if setting.value else "OFF"
			for color in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
				toggle.add_theme_color_override(color,Color("fff2d3"))
			toggle.toggled.connect(func(enabled:bool):
				setting.changed.call(enabled)
				var actual:bool=setting.read.call() if setting.has("read") else enabled
				toggle.set_pressed_no_signal(actual)
				toggle.text="ON" if actual else "OFF"
				app.audio.cue("ui"))
			row.add_child(toggle)
		else:
			var action:DemoButton=app.button(row,setting.button,setting.action)
			action.name=setting.id+"Button"
			action.custom_minimum_size=Vector2(104,44)
			action.focus_mode=Control.FOCUS_ALL
			action.disabled=setting.get("disabled",false)
