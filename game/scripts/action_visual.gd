class_name ActionVisual
extends Control
## Figma 956:419: independent icon, pedestal and vertically centered name.
var button:DemoButton
var caption:Label
func _init(owner_button:DemoButton, texture:Texture2D)->void:
	button=owner_button;mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pedestal:=TextureRect.new();pedestal.texture=preload("res://assets/ui/brush/action-stone-base@2x.png")
	pedestal.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pedestal.position=Vector2(0,28);pedestal.size=Vector2(button.custom_minimum_size.x,49)
	pedestal.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(pedestal)
	var icon:=TextureRect.new();icon.texture=texture;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position=Vector2(4,0);icon.size=Vector2(button.custom_minimum_size.x-8,52);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
	if button.text=="건설":
		var previous_size:=icon.size
		icon.size=previous_size*.9
		icon.position+=(previous_size-icon.size)*.5
	# Lift the glyphs within the nameplate to compensate for the font's baseline.
	caption=Label.new();caption.position=Vector2(5,49);caption.size=Vector2(button.custom_minimum_size.x-10,19)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",12);caption.add_theme_color_override("font_color",Color("fff5d6"));caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(caption)
func _process(_delta:float)->void:
	caption.text=button.text
	modulate=Color(1,1,1,.55) if button.disabled else Color.WHITE
