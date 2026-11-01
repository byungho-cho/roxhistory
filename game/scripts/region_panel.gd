class_name RegionPanel
extends Control

var app:Node
var title_label:Label
var title_art:TextureRect
var era_label:Label
var intro_label:Label
var symbol:TextureRect
var shadow:TextureRect
var food:TextureRect
var start_button:DemoButton
var resources:Control

func _init(owner_app:Node) -> void:app=owner_app;name="RegionDetails"
func _ready() -> void:
	size=Vector2(397,483);mouse_filter=Control.MOUSE_FILTER_STOP
	FigmaArt.picture(self,"paper",Rect2(0,0,397,420))
	var engraving:=FigmaArt.picture(self,"513aa.png",Rect2(20,18,357,174))
	engraving.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;engraving.modulate.a=.26
	shadow=FigmaArt.picture(self,"f88c0.svg",Rect2(116.31,118.23,164.378,27.913))
	intro_label=FigmaArt.text(self,"",Rect2(25,146,347,29))
	FigmaArt.picture(self,"57eed.svg",Rect2(43.5,180,310,12))
	# The source string remains available to accessibility/testing; the art carries
	# the approved stone texture, highlights, outline and lower extrusion.
	title_label=FigmaArt.text(self,"",Rect2(25,197,347,66),56,FigmaArt.TITLE,Color.TRANSPARENT)
	title_art=FigmaArt.picture(self,"title-dongsam.png",Rect2(127.586,200.24,146.841,58.96))
	era_label=FigmaArt.text(self,"",Rect2(25,268,347,40),30)
	resources=Control.new();resources.mouse_filter=Control.MOUSE_FILTER_IGNORE;resources.position=Vector2(25,313);resources.size=Vector2(347,76);add_child(resources)
	start_button=FigmaArt.button(self,"gold",Rect2(0,407,397,76),"이곳에서 시작",app.start_region,app);start_button.name="RegionStart"
	symbol=FigmaArt.picture(self,"mussels",Rect2(90.3565,-46.087,216.287,186.087))
	var cast:=ArtShadow.new(symbol);add_child(cast);move_child(cast,symbol.get_index())

func show_region(key:String) -> void:
	var data:Dictionary=RegionCatalog.REGIONS[key]
	title_label.text=data.name;intro_label.text=data.intro;era_label.text=data.era
	title_art.texture=FigmaArt.texture("title-"+key+".png");title_art.tooltip_text=data.name;title_art.set_meta("semantic_text",data.name)
	var title_rects:={"jeongok":Rect2(127.0203,200.24,146.1187,58.96),"amsa":Rect2(128.324,200.24,145.3647,58.96),"dongsam":Rect2(127.5857,200.24,146.8413,58.96)}
	title_art.position=title_rects[key].position;title_art.size=title_rects[key].size
	symbol.texture=FigmaArt.texture(data.symbol);symbol.position=data.panel_art.position;symbol.size=data.panel_art.size
	shadow.size=Vector2(symbol.size.x*.76,symbol.size.y*.15);shadow.position=Vector2((397-shadow.size.x)*.5,140-shadow.size.y*.78)
	start_button.disabled=not data.playable
	start_button.hint_text=data.name+"은 지역 소개만 제공됩니다. 현재 데모는 암사동에서 시작할 수 있습니다." if not data.playable else ""
	start_button.tooltip_text=start_button.hint_text
	for child in resources.get_children():resources.remove_child(child);child.queue_free()
	var food_size:Vector2={"jeongok":Vector2(73,64.373),"amsa":Vector2(62.805,72),"dongsam":Vector2(72.769,62.609)}[key]
	var x:float=(347-72*3-14*3-food_size.x)*.5
	for i in 4:
		var item_size:Vector2=Vector2(72,[65.127,66.525,66.624][mini(i,2)]) if i<3 else food_size
		var position_value:=Vector2(x,(76-item_size.y)*.5)
		FigmaArt.picture(resources,"ad8e3.svg",Rect2(position_value+Vector2(item_size.x*.06,item_size.y*.885),Vector2(item_size.x*.88,12)))
		var item_key:String=["wood","stone","berries"][i] if i<3 else ("meat.png" if key=="jeongok" else data.food)
		var item:=FigmaArt.picture(resources,item_key,Rect2(position_value,item_size))
		item.set_meta("resource_kind",item_key)
		var cast:=ArtShadow.new(item,Vector2(.75,2.5),2.2);resources.add_child(cast);resources.move_child(cast,item.get_index())
		if i==3:
			food=item;food.name="RegionalFood";food.tooltip_text="지역의 생활을 소개하는 먹거리입니다. 보유 수량이 아닙니다."
			if key=="jeongok":food.position.x-=1.45;food.size=Vector2(77.4,69.073)
		x+=item_size.x+14
