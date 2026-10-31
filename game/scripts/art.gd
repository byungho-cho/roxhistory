class_name DemoArt
extends RefCounted

static var sheet: Texture2D = preload("res://assets/figma/20204.png")
static var cache := {}
static var shared_theme: Theme

static func icon(key: String) -> Texture2D:
	if cache.has(key):
		return cache[key]
	var boxes := {"spear":Rect2(30,16,369,348),"hammer":Rect2(790,16,354,344),"meat":Rect2(8,690,380,310),"hut":Rect2(1143,12,378,355),"wood":Rect2(777,389,375,287),
		"stone":Rect2(1169,380,366,297),"scroll":Rect2(391,384,372,282),
		"berries":Rect2(430,20,343,323),"bag":Rect2(22,369,353,317),
		"horn":Rect2(1150,720,365,292),"compass":Rect2(410,665,330,335)}
	var tex := AtlasTexture.new()
	tex.atlas = sheet
	tex.region = boxes.get(key,boxes.hut)
	cache[key] = tex
	return tex

static func panel(dark: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("302d26f7") if dark else Color("f1deb9fc")
	s.border_color = Color("a77942")
	s.set_border_width_all(0 if dark else 2)
	s.set_corner_radius_all(16)
	s.shadow_color = Color(0,0,0,0.4)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0,5)
	s.set_content_margin_all(18)
	return s

static func button_style(primary: bool = false) -> StyleBoxFlat:
	var s := panel()
	s.bg_color = Color("81562c") if primary else Color("503b29")
	s.border_color = Color("d2ad66")
	s.set_corner_radius_all(12)
	s.set_content_margin_all(10)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0,3)
	return s

static func theme() -> Theme:
	if shared_theme: return shared_theme
	var t := Theme.new()
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansKR.ttf")
	# Numeric OpenType tag: string "wght" is ignored by Godot 4.5.1.
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):600.0}
	t.default_font = font
	t.default_font_size = 19
	for cls in ["Label","Button"]:
		t.set_color("font_color",cls,Color("49321e"))
	for prop in ["font_hover_color","font_pressed_color"]:
		t.set_color(prop,"Button",Color("fff4d6"))
	t.set_color("font_color","Button",Color("fff4d6"))
	t.set_color("font_disabled_color","Button",Color("d9d1bd"))
	t.set_color("icon_disabled_color","Button",Color(.9,.86,.75,.85))
	t.set_stylebox("normal","Button",button_style())
	t.set_stylebox("hover","Button",button_style(true))
	var down := button_style(true)
	down.bg_color = Color("382719")
	t.set_stylebox("pressed","Button",down)
	var disabled := button_style()
	disabled.bg_color = Color("514d42")
	disabled.border_color=Color("827969")
	t.set_stylebox("disabled","Button",disabled)
	shared_theme = t
	return t
