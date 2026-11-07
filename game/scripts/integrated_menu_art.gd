class_name IntegratedMenuArt
extends RefCounted
const ROOT:="res://assets/ui/building-menu-integrated-v004/"
const LEGACY_ROOT:="res://assets/ui/building-menu-integrated-v002/exports/"
static var cache:Dictionary={}
static func texture(key:String,state:String)->Texture2D:
	var path:=ROOT+key+"-"+state+".png"
	if not ResourceLoader.exists(path):path="res://assets/ui/facility-side-v001/"+key+"-"+state+".png"
	if not ResourceLoader.exists(path):path=LEGACY_ROOT+key+"-"+state+".png"
	if not ResourceLoader.exists(path):return null
	if not cache.has(path):cache[path]=load(path)
	return cache[path]
static func install(button:DemoButton,key:String,dimensions:Vector2)->void:
	if key in ["upgrade","move","demolish"]:
		install_parts(button,key,dimensions)
		return
	button.text="";button.custom_minimum_size=dimensions;button.size=dimensions
	button.set_meta("integrated_art",true);button.set_meta("integrated_key",key)
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var image:=TextureRect.new();image.name="IntegratedImage";image.texture=texture(key,"normal")
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size=dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(image)
	button.enable_art_feedback()
static func refresh(button:DemoButton,highlight:bool=false)->void:
	if button.get_meta("separated_menu",false):
		for child in button.art_feedback.get_children():
			if child is CanvasItem:child.modulate=Color(.52,.50,.46,.80) if button.disabled else Color.WHITE
		return
	if not is_instance_valid(button.art_feedback):return
	var image:TextureRect=button.art_feedback.get_node("IntegratedImage")
	var state:="disabled" if button.disabled else ("highlight" if highlight else "normal")
	var result:=texture(str(button.get_meta("integrated_key")),state)
	if result==null:result=texture(str(button.get_meta("integrated_key")),"normal")
	image.texture=result

static func trimmed(source:Texture2D)->Texture2D:
	var tex:=AtlasTexture.new();tex.atlas=source;tex.region=source.get_image().get_used_rect();tex.filter_clip=true
	return tex
static func install_parts(button:DemoButton,key:String,dimensions:Vector2)->void:
	button.text="";button.custom_minimum_size=dimensions;button.size=dimensions
	button.set_meta("integrated_art",true);button.set_meta("integrated_key",key);button.set_meta("separated_menu",true)
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var scale_factor:=dimensions.x/96.0
	var base:=TextureRect.new();base.name="RoundBackground";base.texture=BuildingMenu.art("button-base.png")
	base.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;base.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;base.position=Vector2(10,1)*scale_factor;base.size=Vector2(76,76)*scale_factor;base.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(base)
	var icon:=TextureRect.new();icon.name="ActionIcon"
	icon.texture=trimmed(load("res://assets/ui/v0158/upgrade-arrow.png")) if key=="upgrade" else BuildingMenu.art("icon-"+key+".png")
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.size=Vector2(50,50)*scale_factor;icon.position=Vector2(23,14)*scale_factor;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(icon)
	var label_bg:=TextureRect.new();label_bg.name="LabelBackground";label_bg.texture=BuildingMenu.art("brush-black-v003.png");label_bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;label_bg.position=Vector2(0,65)*scale_factor;label_bg.size=Vector2(96,24)*scale_factor;label_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(label_bg)
	var label:=Label.new();label.name="ActionName";label.theme=DemoArt.theme();label.text={"upgrade":"업그레이드","move":"이동","demolish":"철거"}[key];label.add_theme_font_size_override("font_size",roundi(13*scale_factor));label.add_theme_color_override("font_color",Color("fff3d3"));label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.position=label_bg.position;label.size=label_bg.size;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(label)
	button.enable_art_feedback()
