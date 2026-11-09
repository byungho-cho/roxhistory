class_name BuildCostDisplay
extends Control
## MAT-007: separate brush, resources, values and confirmation.
var amounts:Array[Label]=[]
var confirm_button:DemoButton
var cancel_button:DemoButton
var button_holder:Control
var screen_extent:=Vector2(414,65)
func _ready()->void:
	name="PlacementCost";mouse_filter=Control.MOUSE_FILTER_STOP;size=Vector2(310,65)
	var brush:=TextureRect.new();brush.name="CostBrush"
	var source:Texture2D=preload("res://assets/ui/v0159/cost-brush.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=Rect2(0,source.get_height()*.1333/1.2667,source.get_width(),source.get_height()/1.2667);crop.filter_clip=true
	brush.texture=crop;brush.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;brush.position=Vector2(0,13);brush.size=Vector2(310,39);brush.modulate.a=.6;brush.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(brush)
	for i in 2:
		var icon:=TextureRect.new();icon.name="Wood" if i==0 else "Stone";icon.texture=DemoArt.icon("wood" if i==0 else "stone");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position=Vector2(18+i*140,16.5);icon.size=Vector2(32,32);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
		var count:=Label.new();count.name="WoodAmount" if i==0 else "StoneAmount";count.theme=DemoArt.theme();count.position=Vector2(58+i*140,0);count.size=Vector2(96,65);count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size",36);count.add_theme_color_override("font_color",Color("fff7d1"));count.add_theme_color_override("font_outline_color",Color("302715"));count.add_theme_constant_override("outline_size",3);count.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(count);amounts.append(count)
	button_holder=Control.new();button_holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(button_holder)
	cancel_button=HudButtons.create(button_holder,false,func():pass,"CancelPlacement")
	confirm_button=HudButtons.create(button_holder,true,func():pass,"Confirm")
	confirm_button.position=Vector2(52,0)
	confirm_button.set_meta("semantic_text","확인")
	cancel_button.set_meta("semantic_text","배치 취소")
	set_world_scale(1.0)
func set_world_scale(zoom:float)->void:
	var factor:=HudButtons.world_scale(zoom)
	scale=Vector2.ONE*factor
	button_holder.scale=Vector2.ONE/factor
	button_holder.position=Vector2(310+8/factor,(65-HudButtons.DIAMETER/factor)*.5)
	screen_extent=Vector2(310*factor+104,maxf(65*factor,HudButtons.DIAMETER))
func update_cost(cost:Dictionary)->void:
	for i in amounts.size():
		amounts[i].text=str(int(cost.get("wood" if i==0 else "stone",0)))
		amounts[i].add_theme_font_size_override("font_size",36 if amounts[i].text.length()<=3 else 27)
		var font:Font=amounts[i].get_theme_font("font")
		var font_size:int=amounts[i].get_theme_font_size("font_size")
		while font_size>8 and font.get_string_size(amounts[i].text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>amounts[i].size.x:
			font_size-=1
		amounts[i].add_theme_font_size_override("font_size",font_size)
