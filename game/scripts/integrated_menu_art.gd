class_name IntegratedMenuArt
extends RefCounted
const ROOT:="res://assets/ui/building-menu-integrated-v002/exports/"
static var cache:Dictionary={}
static func texture(key:String,state:String)->Texture2D:
	var path:=ROOT+key+"-"+state+".png"
	if not cache.has(path):cache[path]=load(path)
	return cache[path]
static func install(button:DemoButton,key:String,dimensions:Vector2)->void:
	button.text="";button.custom_minimum_size=dimensions;button.size=dimensions
	button.set_meta("integrated_art",true);button.set_meta("integrated_key",key)
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var image:=TextureRect.new();image.name="IntegratedImage";image.texture=texture(key,"normal")
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size=dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(image)
	button.enable_art_feedback()
static func refresh(button:DemoButton,highlight:bool=false)->void:
	var image:TextureRect=button.art_feedback.get_node("IntegratedImage")
	image.texture=texture(str(button.get_meta("integrated_key")),"disabled" if button.disabled else ("highlight" if highlight else "normal"))
