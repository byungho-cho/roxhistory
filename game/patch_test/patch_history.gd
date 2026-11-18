extends Control

const NOTES := preload("res://patch_test/patch_notes.gd")
const HISTORY_SCROLL := preload("res://patch_test/history_scroll.gd")
const INK := Color("47240e")
const VERSION_INK := Color("183d65")

var version: String
var dismiss: Callable
var fit_ratio: float
var paper: TextureRect
var margins: MarginContainer
var scroll: ScrollContainer

func _init(current_version: String, close: Callable, panel_ratio := 1.0) -> void:
	version = current_version
	dismiss = close
	fit_ratio = panel_ratio

func _ready() -> void:
	name = "UpdateNotesPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper = TextureRect.new()
	paper.texture = SharedPopupArt.shell("wood","l")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(paper)
	margins = MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left","top","right","bottom"]:
		margins.add_theme_constant_override("margin_"+side,30 if side in ["left","right"] else 24)
	add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margins.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := text_label("업데이트 내역",26,FigmaArt.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	SharedPopupArt.close_icon(HudButtons.create_modal_close(header,dismiss,"UpdateNotesClose"))
	var divider := TextureRect.new()
	divider.texture = SharedPopupArt.WOOD_DIVIDER
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.custom_minimum_size.y = 4
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(divider)
	scroll = HISTORY_SCROLL.new()
	scroll.name = "UpdateHistoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	SharedPopupArt.style_scroll(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	var bold := FontVariation.new()
	bold.base_font = FigmaArt.NOTO
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700.0}
	for item in NOTES.recent_versions(version):
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation",4)
		list.add_child(section)
		var heading := text_label(item,21,FigmaArt.BODY)
		heading.add_theme_color_override("font_color",VERSION_INK)
		heading.name = "Version_"+item.replace(".","_")
		section.add_child(heading)
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left",16)
		section.add_child(indent)
		var bullets := VBoxContainer.new()
		bullets.add_theme_constant_override("separation",3)
		indent.add_child(bullets)
		for line: String in NOTES.rows(item):
			var bullet := text_label("• "+line,18,bold)
			bullet.add_theme_constant_override("line_spacing",1)
			bullets.add_child(bullet)
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
	var panel_size := room.size * fit_ratio
	room = Rect2(room.get_center() - panel_size * .5,panel_size)
	paper.position = room.position
	paper.size = room.size
	margins.position = room.position
	margins.size = room.size
