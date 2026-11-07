class_name UpgradeConfirmation
extends Control
## Figma 1427:6916, stone crop and independent O/X targets.
var app:Node
var key:String
var cost:Dictionary
var confirm:Callable
func _init(owner_app:Node,building_key:String,price:Dictionary,callback:Callable)->void:
	app=owner_app;key=building_key;cost=price;confirm=callback
func _ready()->void:
	name="UpgradeConfirmation";size=Vector2(272,48);mouse_filter=Control.MOUSE_FILTER_STOP
	var clip:=Control.new();clip.position=Vector2(0,14);clip.size=Vector2(160,26);clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(clip)
	var slab:=TextureRect.new();slab.texture=AssetCatalog.texture("UI-UPGRADE-COST-SLAB");slab.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;slab.position=Vector2(-7.235,-17.525);slab.size=Vector2(174.635,58.21);slab.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.add_child(slab)
	for i in 2:
		var image:=TextureRect.new();image.texture=DemoArt.icon("wood" if i==0 else "stone");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.position=Vector2(8+i*76,15);image.size=Vector2(23,22);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(image)
		var count:=Label.new();count.theme=DemoArt.theme();count.text=str(cost.get("wood" if i==0 else "stone",0));count.add_theme_font_size_override("font_size",15);count.add_theme_color_override("font_color",Color("48230e"));count.position=Vector2(33+i*76,15);count.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(count)
	for i in 2:
		var b:DemoButton=app.button(self,"",confirm if i==0 else app.close_modal);b.name="ConfirmUpgrade" if i==0 else "CancelUpgrade"
		b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size=Vector2(48,48);b.size=Vector2(48,48);b.position=Vector2(168+i*56,0)
		var source:Texture2D=preload("res://assets/ui/v034/build-confirm.png") if i==0 else preload("res://assets/ui/v034/build-cancel.png")
		var cropped:=AtlasTexture.new();cropped.atlas=source;cropped.region=source.get_image().get_used_rect();b.icon=cropped;b.expand_icon=true;b.add_theme_constant_override("icon_max_width",48)
		b.set_meta("semantic_text","업그레이드 확인" if i==0 else "취소")
		for state in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
func _process(_delta:float)->void:
	if not is_instance_valid(app.world):return
	var sprite:Sprite2D=app.world.building_sprite(key)
	if not is_instance_valid(sprite):app.close_modal();return
	var bounds:Rect2=sprite.get_global_transform_with_canvas()*sprite.get_rect()
	position=Vector2(clampf(bounds.get_center().x-136,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-272)),clampf(bounds.position.y-60,app.safe.y+85,maxf(app.safe.y+85,app.h-app.safe.y-150)))
