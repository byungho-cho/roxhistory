class_name SharedPopupArt
extends RefCounted

const ASSETS := "res://assets/ui/d0049/"
const CLOSE := preload(ASSETS+"popup-close-x.png")
const WOOD_DIVIDER := preload(ASSETS+"popup-divider.png")
const INSET := 30
const WOOD_ACTION_HEIGHT := 48.0
const SCROLL_RAIL := preload("res://assets/ui/d0050/journal-scroll-rail.png")
const SCROLL_THUMB := preload("res://assets/ui/d0050/journal-scroll-thumb.png")
static var scroll_themes := {}
static var button_faces := {}
static var close_faces := {}

static func shell(finish: String, format: String) -> Texture2D:
	return load(ASSETS+"popup-%s-%s.png" % [finish,format]) as Texture2D

static func panel_style(finish: String, format: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = shell(finish,format)
	return style

static func button_texture(finish: String, color: String) -> Texture2D:
	var suffix := "@2x" if finish=="stone" else ""
	var path := ASSETS+"button-%s-%s%s.png" % [finish,color,suffix]
	if not button_faces.has(path):
		var image := load(path) as Texture2D
		var face := AtlasTexture.new()
		face.atlas=image
		face.region=Rect2(image.get_image().get_used_rect())
		face.filter_clip=true
		button_faces[path]=face
	return button_faces[path]

static func button_style(button: Button, finish: String, color: String) -> void:
	var normal := StyleBoxTexture.new()
	normal.texture = button_texture(finish,color)
	var disabled := normal.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(.65,.65,.65)
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,disabled if state=="disabled" else normal)
		var ink := Color("fff3df") if color in ["blue","red"] else Color("472e1d")
		button.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",ink)

static func close_icon(button: Button) -> void:
	align_header_icon(button,CLOSE,20.0)

static func align_header_icon(button: Button, source: Texture2D, extent: float, at_left := false) -> void:
	var icon := button.find_child("Icon",true,false) as TextureRect
	if icon.get_parent()!=button: icon.reparent(button,false)
	if not close_faces.has(source):
		var face := AtlasTexture.new()
		face.atlas = source
		face.region = Rect2(source.get_image().get_used_rect())
		face.filter_clip = true
		close_faces[source] = face
	icon.texture = close_faces[source]
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if at_left else Control.PRESET_TOP_RIGHT)
	icon.offset_left = 0.0 if at_left else -extent
	icon.offset_right = extent if at_left else 0.0
	icon.offset_top = 0.0
	icon.offset_bottom = extent
	button.set_process(false)

static func header_title(title: Label) -> void:
	var parent := title.get_parent()
	var index := title.get_index()
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size.y = title.get_combined_minimum_size().y
	title.name = "ModalTitle"
	parent.add_child(slot)
	parent.move_child(slot,index)
	title.reparent(slot,false)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.minimum_size_changed.connect(func():
		slot.custom_minimum_size.y = title.get_combined_minimum_size().y)
	title.resized.connect(func(): update_header_title(title))
	update_header_title(title)

static func update_header_title(title: Label) -> void:
	var offset := title_ink_offset(title)
	title.offset_top = offset.y
	title.offset_bottom = offset.y
	title.offset_left = offset.x
	title.offset_right = offset.x

static func title_ink_offset(title: Label) -> Vector2:
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var text_server := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string(title.text,font,font_size,title.language)
	var first_ink := Vector2.INF
	for glyph in text_server.shaped_text_get_glyphs(line.get_rid()):
		var font_rid: RID = glyph.font_rid
		if not font_rid.is_valid(): continue
		var raster_size := Vector2i(glyph.font_size,0)
		text_server.font_render_glyph(font_rid,raster_size,glyph.index)
		if text_server.font_get_glyph_size(font_rid,raster_size,glyph.index)==Vector2.ZERO: continue
		var glyph_offset := text_server.font_get_glyph_offset(font_rid,raster_size,glyph.index)
		if first_ink.x==INF: first_ink.x = glyph_offset.x+glyph.offset.x
		first_ink.y = minf(first_ink.y,glyph_offset.y+glyph.offset.y)
	if not first_ink.is_finite(): return Vector2.ZERO
	var x := -first_ink.x if title.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT else 0.0
	return Vector2(x,-roundf(line.get_line_ascent()+first_ink.y))

static func content_rect(panel_size: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO,panel_size).grow(-INSET)

static func style_scroll(scroll: ScrollContainer, stone := false, gap := 8) -> void:
	var key := Vector2i(int(stone),gap)
	if not scroll_themes.has(key):
		var theme := Theme.new()
		var rail := scroll_style(SCROLL_RAIL,4,gap,stone)
		var thumb := scroll_style(SCROLL_THUMB,5,gap,stone)
		theme.set_stylebox("scroll","VScrollBar",rail)
		theme.set_stylebox("scroll_focus","VScrollBar",rail)
		for state in ["grabber","grabber_highlight","grabber_pressed"]:
			theme.set_stylebox(state,"VScrollBar",thumb)
		scroll_themes[key]=theme
	scroll.get_v_scroll_bar().theme = scroll_themes[key]

static func scroll_style(texture: Texture2D, cap: int, gap: int, stone: bool) -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture=texture
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		skin.set_texture_margin(side,cap)
		skin.set_content_margin(side,0)
	skin.content_margin_left=5+gap
	skin.content_margin_right=5
	skin.expand_margin_left=-gap
	if stone: skin.modulate_color=Color(.73,.82,.94)
	return skin
