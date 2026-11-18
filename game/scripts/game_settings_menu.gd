extends RefCounted

const BUG := preload("res://assets/ui/settings-v141/development.svg")

static func open(app: Node) -> void:
	var scroll: ScrollContainer = app.show_modal("게임 설정", "", [], false, true, false, Vector2(610, 400))
	var column := scroll.get_parent()
	var header: HBoxContainer = column.get_node("ModalHeader")
	var old_close := header.get_node("ModalClose")
	header.remove_child(old_close)
	old_close.queue_free()
	if OS.is_debug_build() or app.test_mode or ProjectSettings.get_setting("roxhistory/development/settings_entry", false):
		icon_button(app, header, BUG, "DevelopmentSettings", app.show_development_settings, "debug_click")
	var close := HudButtons.create_modal_close(header,app.close_modal,"SettingsClose")
	SharedPopupArt.close_icon(close)
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
			style.bg_color = Color({"normal":"efe0ba", "hover":"efe0ba", "pressed":"e4c17d", "disabled":"e9ddc4", "focus":"f8df9a"}[state])
			style.border_color = Color("ab7939") if state=="focus" else Color("d5bd8b")
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
		row.set_process(false)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var version := String(ProjectSettings.get_setting("application/config/version"))
	var notes: DemoButton = app.button(footer, "", app.show_version_notes.bind(version))
	notes.name = "RunningVersionNotes"
	notes.set_meta("semantic_text", version)
	notes.custom_minimum_size = Vector2(78,48)
	for state in ["normal","hover","pressed","focus"]:
		notes.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var bold := FontVariation.new()
	bold.base_font = FigmaArt.NOTO
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700.0}
	var version_label: Label = app.label(notes,version,20,Color("41280e"))
	version_label.name = "VersionLabel"
	version_label.add_theme_font_override("font",bold)
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	version_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	version_label.offset_bottom = -1.0
	var apk_gap := Control.new()
	apk_gap.custom_minimum_size.x = 8
	apk_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(apk_gap)
	var patch_dialog := preload("res://patch_test/patch_dialog.gd")
	var apk_link: DemoButton = app.button(footer,"",func():
		app.toast(patch_dialog.copy_full_apk_link(version)))
	apk_link.name = "SettingsFullApkLink"
	apk_link.custom_minimum_size = Vector2(112,48)
	for state in ["normal","hover","pressed","focus"]:
		apk_link.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var apk_label: Label = app.label(apk_link,"APK 링크 복사",15,Color("183d65"))
	apk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apk_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	apk_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apk_label.offset_bottom = -1.0
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	var home: DemoButton = app.button(footer, "시작 화면", func(): app.close_modal(); app.show_screen("title"), true)
	home.size_flags_horizontal = Control.SIZE_SHRINK_END
	home.custom_minimum_size = Vector2(137, SharedPopupArt.WOOD_ACTION_HEIGHT)
	SharedPopupArt.button_style(home,"wood","gold")

static func detail_header(app: Node, scroll: ScrollContainer, back_id: String) -> void:
	var header: HBoxContainer = scroll.get_parent().get_node("ModalHeader")
	var back: DemoButton = app.button(header,"",app.show_game_settings)
	back.name=back_id
	back.tooltip_text="뒤로가기"
	back.custom_minimum_size=Vector2.ONE*48
	for state in ["normal","hover","pressed","focus"]:
		back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(back,preload("res://assets/ui/d0024/08-ui-back-button.png"),Rect2(0,0,38,38))
	header.move_child(back,0)
	var close := header.get_node("ModalClose") as Button
	if close.pressed.is_connected(app.close_modal): close.pressed.disconnect(app.close_modal)
	close.pressed.connect(app.show_game_settings)
	app.overlay.set_meta("back_action",app.show_game_settings)

static func icon_button(app: Node, header: Control, texture: Texture2D, id: String, action: Callable, cue := "ui") -> void:
	var control: DemoButton = app.button(header, "", action, false, "", cue)
	control.name = id
	var diameter := 48.0
	control.custom_minimum_size = Vector2.ONE*diameter
	for state in ["normal","hover","pressed","focus"]:
		control.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	app.picture(control, texture, Rect2((diameter-32.0)*.5,0,32,32))
