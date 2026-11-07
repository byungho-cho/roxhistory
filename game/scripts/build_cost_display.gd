class_name BuildCostDisplay
extends Control
## MAT-007: separate brush, resources, values and confirmation.
var amounts:Array[Label]=[]
var confirm_button:DemoButton
func _ready()->void:
	name="PlacementCost";mouse_filter=Control.MOUSE_FILTER_STOP;size=Vector2(380,65)
	var brush:=TextureRect.new();brush.name="CostBrush"
	var source:Texture2D=preload("res://assets/ui/v0159/cost-brush.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=Rect2(0,source.get_height()*.1333/1.2667,source.get_width(),source.get_height()/1.2667);crop.filter_clip=true
	brush.texture=crop;brush.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;brush.position=Vector2(0,26);brush.size=Vector2(380,39);brush.modulate.a=.6;brush.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(brush)
	for i in 2:
		var icon:=TextureRect.new();icon.name="Wood" if i==0 else "Stone";icon.texture=DemoArt.icon("wood" if i==0 else "stone");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position=Vector2(44+i*130,19);icon.size=Vector2(32,32);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon)
		var count:=Label.new();count.name="WoodAmount" if i==0 else "StoneAmount";count.theme=DemoArt.theme();count.position=Vector2(102+i*130,0);count.size=Vector2(70,65);count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size",36);count.add_theme_color_override("font_color",Color("fff7d1"));count.add_theme_color_override("font_outline_color",Color("302715"));count.add_theme_constant_override("outline_size",3);count.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(count);amounts.append(count)
	confirm_button=DemoButton.new();confirm_button.name="Confirm";confirm_button.focus_mode=Control.FOCUS_NONE;confirm_button.custom_minimum_size=Vector2(60,60);confirm_button.size=Vector2(60,60);confirm_button.position=Vector2(305,5);add_child(confirm_button)
	for state in ["normal","hover","pressed","disabled","focus"]:confirm_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	confirm_button.set_meta("semantic_text","확인")
	var source_confirm:Texture2D=preload("res://assets/ui/v034/build-confirm.png")
	var cropped:=AtlasTexture.new();cropped.atlas=source_confirm;cropped.region=Rect2(source_confirm.get_width()*.216/1.4434,source_confirm.get_height()*.1878/1.3844,source_confirm.get_width()/1.4434,source_confirm.get_height()/1.3844);cropped.filter_clip=true
	var image:=TextureRect.new();image.name="ConfirmArt";image.texture=cropped;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.size=Vector2(50.909,52.364);image.position=Vector2(.73,0);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;confirm_button.add_child(image)
	confirm_button.enable_art_feedback()
func update_cost(cost:Dictionary)->void:
	for i in amounts.size():
		amounts[i].text=str(int(cost.get("wood" if i==0 else "stone",0)))
		amounts[i].add_theme_font_size_override("font_size",36 if amounts[i].text.length()<=3 else 27)
		var font:Font=amounts[i].get_theme_font("font")
		var font_size:int=amounts[i].get_theme_font_size("font_size")
		while font_size>8 and font.get_string_size(amounts[i].text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>amounts[i].size.x:
			font_size-=1
		amounts[i].add_theme_font_size_override("font_size",font_size)
