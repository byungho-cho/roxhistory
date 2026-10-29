class_name DemoArt
extends RefCounted

static var sheet: Texture2D = preload("res://assets/figma/20204.png")
static var cache := {}

static func icon(key: String) -> Texture2D:
	if cache.has(key):
		return cache[key]
	var boxes := {"hut":Rect2(1143,12,378,355),"wood":Rect2(777,389,375,287),
		"stone":Rect2(1169,380,366,297),"scroll":Rect2(391,384,372,282),
		"berries":Rect2(430,20,343,323),"bag":Rect2(22,369,353,317),
		"horn":Rect2(1150,720,365,292),"compass":Rect2(785,723,355,290)}
	var tex := AtlasTexture.new()
	tex.atlas = sheet
	tex.region = boxes.get(key,boxes.hut)
	cache[key] = tex
	return tex

static func panel(dark: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("35332eeb") if dark else Color("f1deb9f5")
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
	s.bg_color = Color("e9c575") if primary else Color("f4e8cf")
	s.border_color = Color("a77c40")
	s.set_corner_radius_all(12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0,3)
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = preload("res://assets/fonts/NotoSansKR.ttf")
	t.default_font_size = 19
	for cls in ["Label","Button"]:
		t.set_color("font_color",cls,Color("49321e"))
	for prop in ["font_hover_color","font_pressed_color"]:
		t.set_color(prop,"Button",Color("49321e"))
	t.set_color("font_disabled_color","Button",Color("968b79"))
	t.set_stylebox("normal","Button",button_style())
	t.set_stylebox("hover","Button",button_style(true))
	var down := button_style(true)
	down.bg_color = Color("caa15a")
	t.set_stylebox("pressed","Button",down)
	var disabled := button_style()
	disabled.bg_color = Color("b5ad9b")
	t.set_stylebox("disabled","Button",disabled)
	return t
