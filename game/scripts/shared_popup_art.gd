class_name SharedPopupArt
extends RefCounted

const ASSETS := "res://assets/ui/d0049/"
const CLOSE := preload(ASSETS+"popup-close-x.png")
const WOOD_DIVIDER := preload(ASSETS+"popup-divider.png")
const INSET := 30
const SCROLL_RAIL := preload("res://assets/ui/d0050/journal-scroll-rail.png")
const SCROLL_THUMB := preload("res://assets/ui/d0050/journal-scroll-thumb.png")
static var scroll_themes := {}
static var button_faces := {}

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
	var icon := button.find_child("Icon",true,false) as TextureRect
	icon.texture = CLOSE
	icon.size = Vector2.ONE*20
	icon.position = (button.size-icon.size)*.5

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
