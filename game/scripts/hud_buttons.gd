class_name HudButtons
extends RefCounted
const DIAMETER:=44.0
static func world_scale(zoom:float)->float:return clampf(zoom*.85,.34,.68)
static func create(parent:Node,positive:bool,callback:Callable,id:String)->DemoButton:
	var button:=DemoButton.new();button.name=id;button.focus_mode=Control.FOCUS_NONE
	button.custom_minimum_size=Vector2.ONE*DIAMETER;button.size=button.custom_minimum_size
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var source:Texture2D=preload("res://assets/ui/v034/build-confirm.png") if positive else preload("res://assets/ui/v034/build-cancel.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.filter_clip=true
	if positive:crop.region=Rect2(source.get_width()*.216/1.4434,source.get_height()*.1878/1.3844,source.get_width()/1.4434,source.get_height()/1.3844)
	else:crop.region=Rect2(source.get_width()*.1163/1.2668,source.get_height()*.0984/1.2144,source.get_width()/1.2668,source.get_height()/1.2144)
	var image:=TextureRect.new();image.name="Icon";image.texture=crop;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.size=Vector2.ONE*DIAMETER;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(button);button.add_child(image);button.enable_art_feedback();button.pressed.connect(callback)
	return button
