extends Control

const NOTES := preload("res://patch_test/patch_notes.gd")
const INK := Color("47240e")

var version: String
var dismiss: Callable
var paper: FigmaSlice
var margins: MarginContainer
var scroll: ScrollContainer

func _init(current_version: String, close: Callable) -> void:
	version = current_version
	dismiss = close

func _ready() -> void:
	name = "UpdateNotesPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper = FigmaSlice.new("paper",32)
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(paper)
	margins = MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left","top","right","bottom"]:
		margins.add_theme_constant_override("margin_"+side,18)
	add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margins.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := text_label("업데이트 내역",24,FigmaArt.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	HudButtons.create_modal_close(header,dismiss,"UpdateNotesClose")
	scroll = DevelopmentSettingsScroll.new()
	scroll.name = "UpdateHistoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	for item in NOTES.recent_versions(version):
		var heading := text_label(item,19,FigmaArt.BODY)
		heading.name = "Version_"+item.replace(".","_")
		list.add_child(heading)
		for line: String in NOTES.rows(item):
			list.add_child(text_label("• "+line,16,FigmaArt.NOTO))
		var rule := ColorRect.new()
		rule.color = Color(.51,.32,.14,.24)
		rule.custom_minimum_size.y = 1
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(rule)
	resized.connect(fit)
	fit()

func text_label(value: String, point: int, font: Font) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",point)
	label.add_theme_color_override("font_color",INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func fit() -> void:
	var room := Rect2(Vector2.ZERO,size)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		if safe.has_area() and physical.x>0 and physical.y>0:
			room = Rect2(Vector2(safe.position)*size/physical,Vector2(safe.size)*size/physical)
	room = room.grow(-minf(12.0,minf(room.size.x,room.size.y)*.08))
	paper.position = room.position
	paper.size = room.size
	margins.position = room.position
	margins.size = room.size
