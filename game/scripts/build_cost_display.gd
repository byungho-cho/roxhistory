class_name BuildCostDisplay
extends Control
## Figma 1437:6984: brush under a pair of real resource amounts.
var amounts:Array[Label]=[]
func _ready()->void:
	name="PlacementCost";mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(230,48)
	var brush:=TextureRect.new();brush.texture=AssetCatalog.texture("UI-BUILD-COST-BRUSH")
	brush.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;brush.position=Vector2(0,19);brush.size=Vector2(230,30);brush.modulate.a=.6;brush.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(brush)
	for i in 2:
		var icon:=TextureRect.new();icon.texture=DemoArt.icon("wood" if i==0 else "stone");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position=Vector2(23+i*104,0);icon.size=Vector2(38,38);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
		var count:=Label.new();count.theme=DemoArt.theme();count.position=Vector2(66+i*104,2);count.size=Vector2(60,38);count.add_theme_font_size_override("font_size",25);count.add_theme_color_override("font_color",Color("fff7d1"));count.add_theme_color_override("font_outline_color",Color("47321d"));count.add_theme_constant_override("outline_size",3);count.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(count);amounts.append(count)
func update_cost(cost:Dictionary)->void:
	for i in amounts.size():amounts[i].text=str(int(cost.get("wood" if i==0 else "stone",0)))
