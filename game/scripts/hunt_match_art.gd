extends RefCounted

const ROOT := "res://assets/ui/hunting-match/"
const BRUSH := preload("res://assets/ui/hunting-match/brush.png")
const SPEAR := preload("res://assets/ui/hunting-match/png/vs/stone-spear-source.png")
const MASK_CODE := """
shader_type canvas_item;
uniform sampler2D brush_mask : source_color, filter_linear, repeat_disable;
uniform vec4 region;
void fragment() {
	COLOR.a *= texture(brush_mask, region.xy + UV * region.zw).a;
}
"""

static func picture(parent: Control, texture: Texture2D, rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = rect.position
	art.size = rect.size
	parent.add_child(art)
	return art

static func layer(parent: Control, at: Vector2) -> Control:
	var result := Control.new()
	result.position = at
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func backdrop(parent: Control) -> Control:
	var panel := layer(parent,Vector2(62,3))
	panel.size = Vector2(356,89)
	picture(panel,BRUSH,Rect2(Vector2.ZERO,panel.size)).modulate.a = .70
	var shader := Shader.new()
	shader.code = MASK_CODE
	var art := {"stone-axe":[Rect2(13,20,24,24),Rect2(224,20,24,24)],
		"pottery":[Rect2(37,53.5,22,22),Rect2(305,16,24,24)],
		"tripitaka-woodblock":[Rect2(107.5,21,23,23),Rect2(314,55,24,24)],
		"fibres":[Rect2(3,0,347,83.5)]}
	for key in art:
		var group := layer(panel,Vector2.ZERO)
		group.name = key
		var texture: Texture2D = load(ROOT+("svg/power/fine-fibres.svg" if key=="fibres" else "svg/motifs/"+key+".svg"))
		for rect: Rect2 in art[key]:
			var item := picture(group,texture,rect)
			item.modulate.a = 1.0 if key=="fibres" else .75
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("brush_mask",BRUSH)
			material.set_shader_parameter("region",Vector4(rect.position.x/panel.size.x,rect.position.y/panel.size.y,rect.size.x/panel.size.x,rect.size.y/panel.size.y))
			item.material = material
	return panel

static func versus(parent: Control, center: Vector2, span: float) -> Dictionary:
	var factor := span/164.0
	var root := layer(parent,center-Vector2.ONE*span*.5)
	var spears: Array[TextureRect] = []
	for index in 2:
		var spear := picture(root,SPEAR,Rect2(Vector2.ONE*-18,Vector2.ONE*200))
		spear.flip_h = index==1
		spear.pivot_offset = spear.size*.5
		spears.append(spear)
	var letter_layer := layer(root,Vector2.ZERO)
	letter_layer.pivot_offset = Vector2(82,82)
	var letters: Array[TextureRect] = [
		picture(letter_layer,preload("res://assets/ui/hunting-match/svg/vs/v.svg"),Rect2(5,32,83.64,86.92)),
		picture(letter_layer,preload("res://assets/ui/hunting-match/svg/vs/s.svg"),Rect2(71.5,56,83.64,86.92))
	]
	for letter in letters:letter.pivot_offset = Vector2(41,42.64)
	root.scale = Vector2.ONE*factor
	return {"root":root,"spears":spears,"letter_layer":letter_layer}

static func format_power(value: int) -> String:
	if value<0:return "—"
	var digits := str(value)
	var formatted := ""
	for index in digits.length():
		if index>0 and (digits.length()-index)%3==0:formatted += ","
		formatted += digits[index]
	return formatted

static func power(parent: Control, center: Vector2, value: int) -> void:
	var formatted := format_power(value)
	var group := layer(parent,center)
	picture(group,preload("res://assets/ui/hunting-match/png/power/stone-spear.png"),Rect2(-32,2.55,21,21))
	if value<0:
		var pending := Label.new()
		pending.text = formatted
		pending.add_theme_font_size_override("font_size",24)
		pending.add_theme_color_override("font_color",Color("ffd278"))
		pending.position = Vector2(-6,-4)
		group.add_child(pending)
		return
	var width := 23.0
	var x := width
	for digit in formatted:
		var file := "comma" if digit=="," else digit
		var tex: Texture2D = load(ROOT+"svg/power/digit-"+file+".svg")
		var glyph_width := 7.45 if digit=="," else 16.8
		picture(group,tex,Rect2(x,0,glyph_width,26.1))
		x += glyph_width-3.8
	group.get_child(0).position.x = 0.0
	group.position.x -= (x+3.8)*.5
