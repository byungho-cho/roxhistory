class_name DevelopmentSettings
extends RefCounted

# Add future options here; rows share the same scrollable list and touch sizes.
static func entries(app:Node)->Array[Dictionary]:
	return [
		{"id":"UnlimitedBuilders","title":"건설자 무제한","kind":"toggle",
			"value":app.model.debug_unlimited_builders,"read":func():return app.model.debug_unlimited_builders,
			"changed":func(enabled:bool):app.model.debug_unlimited_builders=enabled},
		{"id":"FastBuild","title":"건설·업그레이드 10배속","kind":"toggle",
			"value":app.model.debug_fast_build,"read":func():return app.model.debug_fast_build,
			"changed":func(enabled:bool):app.model.set_debug_fast_build(enabled)},
		{"id":"ShowBoundary","title":"빨간 마을 경계선","kind":"toggle",
			"value":app.model.debug_show_boundary,"read":func():return app.model.debug_show_boundary,
			"changed":func(enabled:bool):app.model.set_debug_show_boundary(enabled)},
		{"id":"FullReset","title":"게임 초기화","kind":"action",
			"button":"초기화","action":app.confirm_development_reset}
	]

static func open(app:Node)->void:
	var scroll:ScrollContainer=app.show_modal("개발 설정","",[
		{"text":"돌아가기","action":app.pause_game}],false,true,false,Vector2(460,430))
	scroll.name="DevelopmentSettingsScroll"
	scroll.follow_focus=true
	populate(app,scroll,entries(app))

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
		style.set_content_margin_all(10)
		panel.add_theme_stylebox_override("panel",style)
		list.add_child(panel)
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		panel.add_child(row)
		var title:Label=app.label(row,setting.title,20)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if setting.kind=="toggle":
			var toggle:=DevelopmentSettingToggle.new()
			toggle.name=setting.id+"Toggle"
			toggle.custom_minimum_size=Vector2(116,52)
			toggle.set_pressed_no_signal(setting.value)
			toggle.text="ON" if setting.value else "OFF"
			for color in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
				toggle.add_theme_color_override(color,Color("49321e"))
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
			action.custom_minimum_size=Vector2(116,52)
			action.focus_mode=Control.FOCUS_ALL
