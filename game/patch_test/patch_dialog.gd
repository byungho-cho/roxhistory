extends Control

const INK := Color("49321e")
const MUTED := Color("917957")
const PAPER_SIZE := Vector2(500,356)
const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const GOLD := preload("res://assets/ui/d0049/button-wood-gold.png")
const METAL := preload("res://assets/ui/d0049/button-wood-gray.png")
const PATCH_NOTES := preload("res://patch_test/patch_notes.gd")

var native_touch_buttons := false
var center_actions := true
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
var notes_button: Button
var apk_link_button: Button
var notes_panel: Control
var notes_version := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper = Control.new()
	paper.size = PAPER_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_STOP if native_touch_buttons else Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var background := TextureRect.new()
	background.texture = SharedPopupArt.shell("wood","s")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = PAPER_SIZE
	paper.add_child(background)
	var content := SharedPopupArt.content_rect(PAPER_SIZE)
	heading = label(Rect2(content.position,Vector2(content.size.x,42)),24,900)
	body = label(Rect2(content.position.x,73,content.size.x,48),13,400)
	hint = label(Rect2(content.position.x,188,content.size.x,28),11,500)
	for y in [133,175]:
		var line := ColorRect.new()
		line.color = Color(.54,.39,.20,.20)
		line.position = Vector2(content.position.x,y)
		line.size = Vector2(content.size.x,1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_to_group("patch_version_rule")
		paper.add_child(line)
	version_row = HBoxContainer.new()
	version_row.position = Vector2(content.position.x,134)
	version_row.size = Vector2(content.size.x,40)
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
	notes_button = make_button()
	notes_button.name = "UpdateNotesButton"
	notes_button.position = Vector2(content.end.x-40,content.position.y)
	notes_button.size = Vector2(40,42)
	var question := make_label(22,700,INK)
	question.text = "?"
	notes_button.add_child(question)
	question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notes_button.pressed.connect(show_notes)
	apk_link_button = make_button()
	apk_link_button.name = "FullApkLink"
	apk_link_button.visible = not OS.has_feature("rox_windows_patch")
	apk_link_button.position = Vector2(content.position.x,216)
	apk_link_button.size = Vector2(content.size.x,44)
	var apk_caption := make_label(14,700,Color("183d65"))
	apk_link_button.add_child(apk_caption)
	apk_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var version := full_apk_version()
	var caption := "전체 APK v%s · 링크 복사" % version
	apk_caption.text = caption
	apk_link_button.pressed.connect(func(): apk_caption.text = copy_full_apk_link(version))
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			close_notes()
			apk_caption.text = caption)
	resized.connect(fit_paper)
	fit_paper()

static func full_apk_version() -> String:
	# A PCK-only version need not have a matching APK release.
	return str(ProjectSettings.get_setting("roxhistory/distribution/full_apk_version",ProjectSettings.get_setting("application/config/version")))

static func full_apk_url(version: String) -> String:
	return "https://github.com/byungho-cho/roxhistory/releases/download/v%s/Roxhistory_%s.apk" % [version,version]

static func copy_full_apk_link(version: String) -> String:
	var url := full_apk_url(version)
	DisplayServer.clipboard_set(url)
	return "APK 링크 복사 완료" if DisplayServer.clipboard_get() == url else "APK 링크 복사 확인 불가"

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
	var button: Button = DemoButton.new() if native_touch_buttons else Button.new()
	button.add_theme_color_override("font_color",Color.TRANSPARENT)
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	paper.add_child(button)
	return button

func button_art(button: Button, texture: Texture2D) -> NinePatchRect:
	var art := NinePatchRect.new()
	art.texture = texture
	art.region_rect = Rect2(texture.get_image().get_used_rect())
	art.scale = Vector2.ONE*.5
	art.patch_margin_left = 24
	art.patch_margin_right = 24
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	var text := make_label(18,700,INK)
	text.name = "Caption"
	button.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art

func set_action(button: Button, art: NinePatchRect, value: String, x: float, width: float) -> void:
	button.visible = not value.is_empty()
	var height := SharedPopupArt.WOOD_ACTION_HEIGHT
	button.position = Vector2(x,PAPER_SIZE.y-SharedPopupArt.INSET-height)
	button.size = Vector2(width,height)
	button.tooltip_text = "" if value=="게임 재실행" else value
	art.size = button.size*2.0
	button.get_node("Caption").text = value

func render(title: String, description: String, note: String, current: String, next: String, downloading: bool,
		secondary: String, primary: String, single_width: float = 195.0) -> void:
	heading.text = title
	heading.position = Vector2.ONE*SharedPopupArt.INSET+SharedPopupArt.title_ink_offset(heading)
	body.text = description
	hint.text = note
	version_row.visible = not next.is_empty()
	version_before.text = current
	version_after.text = next
	for child in paper.get_children():
		if child.is_in_group("patch_version_rule"):child.visible = version_row.visible
	progress_bar.visible = downloading
	notes_version = next if not primary.is_empty() else ""
	if downloading:
		var controller := get_parent().get_parent()
		var apk := bool(controller.get("apk_selected"))
		var info: Variant = controller.get("apk_candidate" if apk else "candidate")
		if info is Dictionary:
			notes_version = str(info.get("version",""))
	notes_button.visible = not PATCH_NOTES.rows(notes_version).is_empty()
	var both := not secondary.is_empty() and not primary.is_empty()
	var group_width := 372.0 if both else single_width
	var x := (PAPER_SIZE.x-group_width)*.5 if center_actions else PAPER_SIZE.x-SharedPopupArt.INSET-group_width
	set_action(close_button,secondary_art,secondary,x,180 if both else single_width)
	set_action(update_button,primary_art,primary,x+192 if both else x,180 if both else single_width)

func show_notes() -> void:
	if PATCH_NOTES.rows(notes_version).is_empty() or is_instance_valid(notes_panel):
		return
	notes_panel = preload("res://patch_test/patch_history.gd").new(notes_version,close_notes)
	get_parent().get_parent().add_child(notes_panel)

func close_notes() -> void:
	if is_instance_valid(notes_panel):
		notes_panel.hide()
		notes_panel.queue_free()
		notes_panel = null
