extends RefCounted

const BUG := preload("res://assets/ui/settings-v141/development.svg")
const CLOSE := preload("res://assets/ui/settings-v141/close.svg")

static func open(app: Node) -> void:
	var scroll: ScrollContainer = app.show_modal("게임 설정", "", [], false, true, false, Vector2(610, 400))
	var column := scroll.get_parent()
	var header: HBoxContainer = column.get_node("ModalHeader")
	var old_close := header.get_node("ModalClose")
	header.remove_child(old_close)
	old_close.queue_free()
	if OS.is_debug_build() or app.test_mode or ProjectSettings.get_setting("roxhistory/development/settings_entry", false):
		icon_button(app, header, BUG, "DevelopmentSettings", app.show_development_settings, "debug_click")
	icon_button(app, header, CLOSE, "SettingsClose", app.close_modal)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for item in [
		["사운드 설정", "배경음 · 효과음 · 전투음의 음량과 켜짐 설정", app.show_sound_settings],
		["알림 설정", "받고 싶은 게임 알림을 설정합니다.", app.show_notification_settings],
		["게임 안내", "게임 이용 방법과 도움말을 확인합니다.", app.show_about],
	]:
		var row: DemoButton = app.button(list, "", item[2])
		row.custom_minimum_size = Vector2(0, 57)
		row.set_meta("semantic_text", item[0])
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color({"normal":"efe0ba", "hover":"f8df9a", "pressed":"e4c17d", "disabled":"e9ddc4", "focus":"f8df9a"}[state])
			style.border_color = Color("ab7939") if state in ["hover", "pressed", "focus"] else Color("d5bd8b")
			style.set_border_width_all(1)
			style.set_corner_radius_all(7)
			row.add_theme_stylebox_override(state, style)
		row.set_meta("integrated_art", true)
		var text := VBoxContainer.new()
		row.add_child(text)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.offset_left = 15
		text.offset_top = 8
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		app.label(text, item[0], 17, Color("49321e")).mouse_filter = Control.MOUSE_FILTER_IGNORE
		app.label(text, item[1], 12, Color("80613f")).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var arrow: Label = app.label(row, "›", 23, Color("80613f"))
		arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		arrow.position.x -= 20
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.enable_art_feedback()
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(info)
	var version := String(ProjectSettings.get_setting("application/config/version"))
	app.label(info, version, 11, Color("80613f"))
	var home: DemoButton = app.button(footer, "시작 화면", func(): app.close_modal(); app.show_screen("title"), true)
	home.custom_minimum_size = Vector2(136, 48)
	for state in ["normal","hover","pressed","focus"]:
		home.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var skin := FigmaSlice.new("gold", 42)
	skin.show_behind_parent = true
	home.add_child(skin)
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func icon_button(app: Node, header: Control, texture: Texture2D, id: String, action: Callable, cue := "ui") -> void:
	var control: DemoButton = app.button(header, "", action, false, "", cue)
	control.name = id
	control.custom_minimum_size = Vector2(48, 48)
	for state in ["normal","hover","pressed","focus"]:
		control.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	app.picture(control, texture, Rect2(8, 8, 32, 32))
