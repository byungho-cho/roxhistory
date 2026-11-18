class_name SharedPopupArt
extends RefCounted

const ASSETS := "res://assets/ui/d0049/"
const CLOSE := preload(ASSETS+"popup-close-x.png")
const WOOD_DIVIDER := preload(ASSETS+"popup-divider.png")

static func shell(finish: String, format: String) -> Texture2D:
	return load(ASSETS+"popup-%s-%s.png" % [finish,format]) as Texture2D

static func panel_style(finish: String, format: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = shell(finish,format)
	return style

static func button_texture(finish: String, color: String) -> Texture2D:
	var suffix := "@2x" if finish=="stone" else ""
	return load(ASSETS+"button-%s-%s%s.png" % [finish,color,suffix]) as Texture2D

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
