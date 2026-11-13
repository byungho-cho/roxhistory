class_name SoundSettings
extends RefCounted

const CHANNELS := [
	["bgm", "배경음", "시작 화면 · 마을 · 사냥의 배경음악", [&"BGM"]],
	["sfx", "효과음", "메뉴 · 알림 · 채집 · 주변 환경 소리", [&"SFX", &"Environment"]],
	["combat", "전투음", "타격 · 기술 · 피격 등 전투 효과", [&"Combat"]],
]

static func apply(prefs: ConfigFile) -> void:
	var master: bool = prefs.get_value("app", "sound", true)
	for channel in CHANNELS:
		var level := clampf(float(prefs.get_value("app", channel[0] + "_volume", 100)), 0, 100)
		apply_channel(channel, master and prefs.get_value("app", channel[0], true), level)

static func apply_channel(channel: Array, enabled: bool, level: float) -> void:
	for bus in channel[3]:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index, (-0.91515 if bus == &"BGM" else 0.0) + linear_to_db(maxf(level / 100, .0001)))
		AudioServer.set_bus_mute(index, not enabled or level == 0)


static func open(app: Node) -> void:
	var scroll: ScrollContainer = app.show_modal("게임 설정","",[
		{"text":"확인","primary":true,"action":app.close_modal}],false,true,false,Vector2(610,465))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var master_row := HBoxContainer.new()
	list.add_child(master_row)
	add_description(app, master_row, "전체 사운드", "시작 화면의 스피커와 함께 켜고 꺼집니다.")
	var master_text: Label = app.label(master_row, "", 15, Color("49321e"))
	var master := speaker(app, master_row)
	var sliders: Array[HSlider] = []
	var switches: Array[DemoButton] = []
	var refresh := func():
		var master_on: bool = app.settings.get_value("app", "sound", true)
		master_text.text = "전체 켜짐" if master_on else "전체 꺼짐"
		app.update_speaker_icon(master, master_on)
		for i in CHANNELS.size():
			var key: String = CHANNELS[i][0]
			var on: bool = app.settings.get_value("app", key, true)
			sliders[i].editable = master_on and on
			switches[i].disabled = not master_on
			app.update_speaker_icon(switches[i], on)
	master.pressed.connect(func():
		if app.set_audio_preference("sound", not app.settings.get_value("app", "sound", true)):
			refresh.call())

	var knob := GradientTexture2D.new()
	knob.width = 17
	knob.height = 17
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(.5, .5)
	knob.fill_to = Vector2(1, .5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, .86, .94, 1])
	gradient.colors = PackedColorArray([Color("611113"), Color("611113"), Color("ffe3a7"), Color(1, .9, .7, 0)])
	knob.gradient = gradient
	for channel in CHANNELS:
		var key: String = channel[0]
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(.45, .28, .12, .06)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card.add_theme_stylebox_override("panel", card_style)
		list.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", -15)
		card.add_child(body)
		var header := HBoxContainer.new()
		body.add_child(header)
		add_description(app, header, channel[1], channel[2])
		var toggle := speaker(app, header)
		switches.append(toggle)
		toggle.pressed.connect(func():
			if app.set_audio_preference(key, not app.settings.get_value("app", key, true)):
				refresh.call())
		var controls := HBoxContainer.new()
		body.add_child(controls)
		var slider := HSlider.new()
		slider.custom_minimum_size.y = 40
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.max_value = 100
		slider.step = 1
		slider.value = clampi(int(app.settings.get_value("app", key + "_volume", 100)), 0, 100)
		for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
			slider.add_theme_icon_override(icon, knob)
		for style_name in ["slider", "grabber_area", "grabber_area_highlight"]:
			var track := StyleBoxFlat.new()
			track.bg_color = Color("ccae81") if style_name == "slider" else Color("ffe292")
			track.content_margin_top = 2
			track.content_margin_bottom = 2
			track.set_corner_radius_all(3)
			slider.add_theme_stylebox_override(style_name, track)
		controls.add_child(slider)
		sliders.append(slider)
		var amount: Label = app.label(controls, "%d%%" % slider.value, 15, Color("49321e"))
		amount.custom_minimum_size.x = 53
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slider.drag_started.connect(func(): slider.set_meta("dragging", true))
		slider.value_changed.connect(func(value: float):
			amount.text = "%d%%" % value
			if slider.get_meta("dragging", false):
				apply_channel(channel, true, value)
			else:
				app.set_audio_preference(key + "_volume", int(value)))
		slider.drag_ended.connect(func(changed: bool):
			slider.set_meta("dragging", false)
			if changed and not app.set_audio_preference(key + "_volume", int(slider.value)):
				apply(app.settings))

	refresh.call()

static func add_description(app: Node, row: HBoxContainer, title: String, description: String) -> void:
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	app.label(text, title, 17, Color("49321e"))
	var caption: Label = app.label(text, description, 13, Color("80613f"))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func speaker(app: Node, row: HBoxContainer) -> DemoButton:
	var toggle: DemoButton = app.button(row,"",func(): pass,false,"","")
	toggle.custom_minimum_size = Vector2(48,48)
	for state in ["normal","hover","pressed","disabled","focus"]:
		toggle.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.install_speaker_icon(toggle)
	var icon: TextureRect = toggle.get_meta("speaker_icon")
	icon.position = Vector2(7, 7)
	icon.size = Vector2(34, 34)
	return toggle
