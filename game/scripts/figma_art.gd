class_name FigmaArt
extends RefCounted

const ROOT := "res://assets/figma-latest/"
const BODY := preload("res://assets/fonts/DoHyeon-Regular.ttf")
const TITLE := preload("res://assets/fonts/BlackHanSans-Regular.ttf")
const NOTO := preload("res://assets/fonts/NotoSansKR.ttf")
static var cache := {}
# Source-image crop transforms, measured from the current A303/I100 frames.
# Each tuple is source, horizontal/vertical scale, left/top crop percentage.
const CROPS := {
	"back":["023a3.png",4.129,2.7978,-.0161,-.2951],
	"reset":["023a3.png",4.1514,2.7978,-1.0541,-.2951],
	"bag":["3135e.png",2.7355,1.0028,-.4282,-.0014],
	"compass":["3135e.png",3.7448,1.0226,-2.1017,0.0],
	"paper":["94e05.png",1.0746,1.0881,-.0377,-.0466],
	"gold":["be529.png",2.1336,3.0678,-1.0904,-.9831],
	"wood":["b7632.png",4.9364,1.8191,-.0227,-.4698],
	"stone":["b7632.png",5.0046,1.8055,-1.0461,-.4813],
	"berries":["b7632.png",5.0394,1.7702,-2.0812,-.4059],
	"acorn":["b7632.png",6.0,1.7446,-4.9613,-.4145],
	"axe":["772af.png",3.8786,1.0284,-.1464,-.0185],
	"pottery":["772af.png",3.8239,1.0569,-1.2923,-.0365],
	"mussels":["772af.png",2.8883,1.119,-1.8245,-.1082]}
const CONTROL_CROPS:={"spear":Rect2(22,546,362,422),"hut":Rect2(754,558,400,403),"scroll":Rect2(1180,106,348,380),"horn":Rect2(780,124,372,362),"hammer":Rect2(410,550,350,414)}

static func texture(key:String) -> Texture2D:
	if cache.has(key):return cache[key]
	if CONTROL_CROPS.has(key):
		var control:=AtlasTexture.new();control.atlas=load(ROOT+"023a3.png");control.region=CONTROL_CROPS[key];control.filter_clip=true;cache[key]=control
		return control
	if not CROPS.has(key):
		cache[key]=load(ROOT+key)
		return cache[key]
	var c:Array=CROPS[key]
	var sheet:Texture2D=load(ROOT+c[0])
	var result:=AtlasTexture.new();result.atlas=sheet
	result.region=Rect2(-c[3]*sheet.get_width()/c[1],-c[4]*sheet.get_height()/c[2],sheet.get_width()/c[1],sheet.get_height()/c[2])
	result.filter_clip=true;cache[key]=result
	return result

static func picture(parent:Node,key:String,rect:Rect2) -> TextureRect:
	var node:=TextureRect.new();node.texture=texture(key)
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_SCALE
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.position=rect.position;node.size=rect.size
	parent.add_child(node);return node

static func text(parent:Node,value:String,rect:Rect2,px:int=22,font:Font=BODY,color:Color=Color("4a240c"),center:bool=true) -> Label:
	var node:=Label.new();node.text=value;node.position=rect.position;node.size=rect.size
	if font==NOTO:
		var medium:=FontVariation.new();medium.base_font=NOTO
		medium.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
		font=medium
	node.add_theme_font_override("font",font);node.add_theme_font_size_override("font_size",px)
	node.add_theme_color_override("font_color",color);node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;parent.add_child(node);return node

static func stone_title(parent:Node,value:String,key:String,rect:Rect2) -> TextureRect:
	var node:=picture(parent,key,rect);node.name=value;node.set_meta("semantic_text",value)
	for property in node.get_property_list():
		if property.name=="accessibility_name":node.set("accessibility_name",value)
	return node

static func button(parent:Node,key:String,rect:Rect2,value:String,callback:Callable,app:Node) -> DemoButton:
	var node:=DemoButton.new();node.position=rect.position;node.size=rect.size;node.text=value
	for state in ["normal","hover","pressed","disabled","focus"]:node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:node.add_theme_color_override(state,Color.TRANSPARENT)
	node.add_theme_font_size_override("font_size",1);parent.add_child(node)
	picture(node,key,Rect2(Vector2.ZERO,rect.size))
	if value!="":text(node,value,Rect2(Vector2.ZERO,rect.size),35,TITLE,Color("401a05"))
	node.pressed.connect(func():
		var popup_before: int = app.popup_sound_revision
		callback.call()
		if popup_before == app.popup_sound_revision:app.audio.cue("ui"))
	node.unavailable.connect(func(reason:String):app.toast(reason,2.5))
	return node
