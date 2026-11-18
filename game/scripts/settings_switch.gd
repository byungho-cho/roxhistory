class_name SettingsSwitch
extends DemoButton

const ON_KNOB := preload("res://assets/ui/d0052/switch-knob-on.svg")
const OFF_KNOB := preload("res://assets/ui/d0052/switch-knob-off.svg")
var knob: TextureRect
var enabled_state := false
var compact := false

func _ready() -> void:
	custom_minimum_size = Vector2(102,28 if compact else 44)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_font_override("font",FigmaArt.BODY)
	add_theme_font_size_override("font_size",15)
	knob = TextureRect.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knob.size = Vector2.ONE*(20 if compact else 24)
	add_child(knob)
	resized.connect(position_knob)
	show_state(enabled_state)

func show_state(enabled: bool) -> void:
	enabled_state = enabled
	text = "ON" if enabled else "OFF"
	alignment = HORIZONTAL_ALIGNMENT_LEFT if enabled else HORIZONTAL_ALIGNMENT_RIGHT
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("a3dd26") if enabled else Color("202225")
	skin.border_color = Color("659419") if enabled else Color("45484b")
	skin.shadow_color = Color(0,0,0,.16)
	skin.shadow_size = 2
	skin.shadow_offset = Vector2(0,1)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(15)
	skin.expand_margin_top = 0 if compact else -7
	skin.expand_margin_bottom = skin.expand_margin_top
	skin.content_margin_left = 22
	skin.content_margin_right = 18
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		add_theme_stylebox_override(state,skin)
		add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",Color("1f2d08") if enabled else Color("fff4dd"))
	if not is_instance_valid(knob): return
	knob.texture = ON_KNOB if enabled else OFF_KNOB
	position_knob()

func position_knob() -> void:
	knob.position = Vector2(size.x-knob.size.x-7 if enabled_state else 5,(size.y-knob.size.y)*.5)
