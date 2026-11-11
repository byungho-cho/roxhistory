extends Control

const INK := Color("49321e")
const MUTED := Color("917957")
const PAPER_SIZE := Vector2(500,310)
const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const GOLD := preload("res://assets/ui/hunting-combat/png/popup/continue-button-background.png")
const METAL := preload("res://assets/ui/hunting-combat/png/popup/exit-button-background.png")

var paper: Control
var heading: Label
var body: Label
var hint: Label
var version_row: HBoxContainer
var version_before: Label
var version_after: Label
var progress_bar: ProgressBar
var progress_text: Label
var close_button: Button
var update_button: Button
var primary_art: NinePatchRect
var secondary_art: NinePatchRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper = Control.new()
	paper.size = PAPER_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var background := FigmaSlice.new("paper",32)
	background.size = PAPER_SIZE
	paper.add_child(background)
	heading = label(Rect2(26,24,448,42),24,900)
	body = label(Rect2(26,73,448,48),13,400)
	hint = label(Rect2(26,188,448,28),11,500)
	for y in [133,175]:
		var line := ColorRect.new()
		line.color = Color(.54,.39,.20,.20)
		line.position = Vector2(26,y)
		line.size = Vector2(448,1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_to_group("patch_version_rule")
		paper.add_child(line)
	version_row = HBoxContainer.new()
	version_row.position = Vector2(26,134)
	version_row.size = Vector2(448,40)
	version_row.alignment = BoxContainer.ALIGNMENT_CENTER
	version_row.add_theme_constant_override("separation",9)
	version_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(version_row)
	version_before = make_label(16,400,MUTED)
	version_after = make_label(17,700,INK)
	version_row.add_child(version_before)
	version_row.add_child(version_after)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(46,141)
	progress_bar.size = Vector2(408,26)
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("68462d")
	track.border_color = Color("9b6b34")
	track.set_border_width_all(2)
	track.set_corner_radius_all(7)
	progress_bar.add_theme_stylebox_override("background",track)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("ffde59"),Color("ffbd13"),Color("d99004")])
	ramp.offsets = PackedFloat32Array([0,.47,1])
	var gradient := GradientTexture2D.new()
	gradient.gradient = ramp
	gradient.fill_to = Vector2(0,1)
	var fill := StyleBoxTexture.new()
	fill.texture = gradient
	fill.set_expand_margin_all(-2)
	progress_bar.add_theme_stylebox_override("fill",fill)
	paper.add_child(progress_bar)
	progress_text = make_label(17,700,Color("fff5d9"))
	progress_text.add_theme_color_override("font_outline_color",Color("4c2d16"))
	progress_text.add_theme_constant_override("outline_size",4)
	progress_bar.add_child(progress_text)
	progress_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_button = make_button()
	update_button = make_button()
	secondary_art = button_art(close_button,METAL)
	primary_art = button_art(update_button,GOLD)
	resized.connect(fit_paper)
	fit_paper()

func fit_paper() -> void:
	var available := get_viewport_rect().size
	var inset := Vector2.ZERO
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		if physical.x>0 and physical.y>0 and safe.has_area():
			inset = Vector2(maxi(safe.position.x,int(physical.x)-safe.end.x),maxi(safe.position.y,int(physical.y)-safe.end.y))*available/physical
	var factor := clampf(minf((available.x-inset.x*2-16)/PAPER_SIZE.x,(available.y-inset.y*2-16)/PAPER_SIZE.y),.1,1.0)
	custom_minimum_size = PAPER_SIZE*factor
	paper.scale = Vector2.ONE*factor
	paper.position.y = clampf((available.y-inset.y*2-PAPER_SIZE.y*factor)*.5-8,0,20)

func make_label(font_size: int, weight: int, ink: Color) -> Label:
	var text := Label.new()
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):float(weight)}
	text.add_theme_font_override("font",font)
	text.add_theme_font_size_override("font_size",font_size)
	text.add_theme_color_override("font_color",ink)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return text

func label(rect: Rect2, font_size: int, weight: int) -> Label:
	var text := make_label(font_size,weight,INK)
	text.position = rect.position
	text.size = rect.size
	paper.add_child(text)
	return text

func make_button() -> Button:
	var button := Button.new()
	button.add_theme_color_override("font_color",Color.TRANSPARENT)
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	paper.add_child(button)
	return button

func button_art(button: Button, texture: Texture2D) -> NinePatchRect:
	var art := NinePatchRect.new()
	art.texture = texture
	art.position = Vector2(-1.5,0)
	art.scale = Vector2.ONE*.5
	art.patch_margin_left = 24
	art.patch_margin_right = 24
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	var text := make_label(18,700,INK if texture==GOLD else Color("f3f5f6"))
	text.name = "Caption"
	button.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art

func set_action(button: Button, art: NinePatchRect, value: String, x: float, width: float) -> void:
	button.visible = not value.is_empty()
	button.position = Vector2(x,232)
	button.size = Vector2(width,52)
	button.tooltip_text = value
	art.size = Vector2(width*2+6,110)
	button.get_node("Caption").text = value

func render(title: String, description: String, note: String, current: String, next: String, downloading: bool,
		secondary: String, primary: String, single_width: float = 195.0) -> void:
	heading.text = title
	body.text = description
	hint.text = note
	version_row.visible = not next.is_empty()
	version_before.text = current
	version_after.text = next
	for child in paper.get_children():
		if child.is_in_group("patch_version_rule"):child.visible = version_row.visible
	progress_bar.visible = downloading
	var both := not secondary.is_empty() and not primary.is_empty()
	set_action(close_button,secondary_art,secondary,64 if both else (500-single_width)*.5,180 if both else single_width)
	set_action(update_button,primary_art,primary,256 if both else (500-single_width)*.5,180 if both else single_width)
