class_name DesignSkin
extends RefCounted
static var cache: Dictionary={}
static func style(kind: String) -> StyleBoxTexture:
	if cache.has(kind):return cache[kind]
	var skin:=StyleBoxTexture.new()
	skin.texture=load("res://assets/ui/design/"+kind+".svg")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		skin.set_texture_margin(side,20)
		skin.set_content_margin(side,10)
	cache[kind]=skin
	return skin

static func round_style(kind: String) -> StyleBoxFlat:
	var skin:=StyleBoxFlat.new()
	skin.bg_color=Color("fff3da") if kind=="ivory" else Color("3c3c3cbb")
	skin.border_color=Color("a77942") if kind=="ivory" else Color("171717")
	skin.set_border_width_all(2);skin.set_corner_radius_all(64);skin.set_content_margin_all(8)
	return skin
