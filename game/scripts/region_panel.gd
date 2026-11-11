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
var surface:Control
var content:Control
var ghost:Control
var reveal:Tween
var swap:Tween
var shown:=true
var current_key:=""

func set_shown(value:bool,animate:bool=true) -> void:
	shown=value
	if reveal and reveal.is_valid():reveal.kill()
	mouse_filter=Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	start_button.clear();start_button.mouse_filter=mouse_filter
	start_button.disabled=not value or not RegionCatalog.REGIONS[current_key].playable
	if not value:start_button.release_focus()
	if not animate:
		visible=value;surface.position=Vector2.ZERO;surface.modulate.a=1;return
	if value and not visible:surface.modulate.a=0;surface.position.y=16
	show()
	reveal=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(surface,"modulate:a",1.0 if value else 0.0,.22)
	reveal.tween_property(surface,"position:y",0.0 if value else 12.0,.22)
	if not value:reveal.chain().tween_callback(func():hide())

func finish_motion() -> void:
	if reveal and reveal.is_valid():reveal.kill()
	if swap and swap.is_valid():swap.kill()
	if is_instance_valid(ghost):ghost.get_parent().remove_child(ghost);ghost.queue_free();ghost=null
	content.modulate.a=1;content.position=Vector2.ZERO
	set_shown(shown,false)


func _init(owner_app:Node) -> void:app=owner_app;name="RegionDetails"
func _ready() -> void:
	size=Vector2(397,483);mouse_filter=Control.MOUSE_FILTER_STOP
	surface=Control.new();surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(surface)
	content=Control.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.add_child(content)
	FigmaArt.picture(surface,"paper",Rect2(0,0,397,420))
	var engraving:=FigmaArt.picture(surface,"513aa.png",Rect2(20,18,357,174))
	engraving.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;engraving.modulate.a=.26
	shadow=FigmaArt.picture(content,"f88c0.svg",Rect2(116.31,118.23,164.378,27.913))
	intro_label=FigmaArt.text(content,"",Rect2(25,146,347,29))
	FigmaArt.picture(surface,"57eed.svg",Rect2(43.5,180,310,12))
	# The source string remains available to accessibility/testing; the art carries
	# the approved stone texture, highlights, outline and lower extrusion.
	title_label=FigmaArt.text(content,"",Rect2(25,197,347,66),56,FigmaArt.TITLE,Color.TRANSPARENT)
	title_art=FigmaArt.picture(content,"title-dongsam.png",Rect2(127.586,200.24,146.841,58.96))
	era_label=FigmaArt.text(content,"",Rect2(25,268,347,40),30)
	resources=Control.new();resources.mouse_filter=Control.MOUSE_FILTER_IGNORE;resources.position=Vector2(25,313);resources.size=Vector2(347,76);content.add_child(resources)
	start_button=FigmaArt.button(surface,"gold",Rect2(0,407,397,76),"이곳에서 시작",app.request_first_village,app);start_button.name="RegionStart";start_button.enable_art_feedback()
	var close:=DemoButton.new();close.name="CloseRegionDetails";close.text="×";close.position=Vector2(349,8);close.size=Vector2(44,44);close.set_meta("semantic_text","지역 상세 닫기")
	for state in ["normal","hover","pressed","disabled","focus"]:close.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	close.add_theme_font_size_override("font_size",26);close.add_theme_color_override("font_color",Color("705536"));surface.add_child(close)
	close.pressed.connect(func():app.region_selection.panel_visible=false;set_shown(false))
	symbol=FigmaArt.picture(content,"mussels",Rect2(90.3565,-46.087,216.287,186.087))
	var cast:=ArtShadow.new(symbol);content.add_child(cast);content.move_child(cast,symbol.get_index())

func show_region(key:String) -> void:
	if key==current_key:return
	if swap and swap.is_valid():swap.kill()
	if is_instance_valid(ghost):ghost.get_parent().remove_child(ghost);ghost.queue_free();ghost=null
	var animate:=current_key!="" and shown and visible
	if animate:
		ghost=content.duplicate(0)
		for visual in ghost.find_children("*","CanvasItem",true,false):
			if visual.material:visual.material=visual.material.duplicate()
		ghost.name="PreviousRegionVisuals"
		# Preserve the visible blend when a new selection interrupts the transition.
		# Resetting this copy to opaque makes the outgoing image flash back in.
		surface.add_child(ghost);surface.move_child(ghost,content.get_index())
	current_key=key
	content.modulate.a=1;content.position=Vector2.ZERO
	var data:Dictionary=RegionCatalog.REGIONS[key]
	title_label.text=data.name;intro_label.text=data.intro;era_label.text=data.era
	title_art.texture=FigmaArt.texture("title-"+key+".png");title_art.set_meta("semantic_text",data.name)
	var title_rects:={"jeongok":Rect2(127.0203,200.24,146.1187,58.96),"amsa":Rect2(128.324,200.24,145.3647,58.96),"dongsam":Rect2(127.5857,200.24,146.8413,58.96)}
	title_art.position=title_rects[key].position;title_art.size=title_rects[key].size
	symbol.texture=FigmaArt.texture(data.symbol);symbol.position=data.panel_art.position;symbol.size=data.panel_art.size
	shadow.size=Vector2(symbol.size.x*.76,symbol.size.y*.15);shadow.position=Vector2((397-shadow.size.x)*.5,140-shadow.size.y*.78)
	start_button.disabled=not data.playable
	start_button.hint_text=data.name+"은 지역 소개만 제공됩니다. 현재 데모는 암사동에서 시작할 수 있습니다." if not data.playable else ""
	start_button.set_meta("semantic_text",start_button.hint_text)
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
			food=item;food.name="RegionalFood";food.set_meta("semantic_text","지역 소개 먹거리, 보유 수량 아님")
			if key=="jeongok":food.position.x-=1.45;food.size=Vector2(77.4,69.073)
		x+=item_size.x+14

	# Keep live semantics and support state atomic; only visual layers crossfade.
	surface.move_child(content,surface.get_child_count()-1)
	if animate:
		content.modulate.a=0;content.position.y=5
		swap=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		swap.tween_property(content,"modulate:a",1.0,.2);swap.tween_property(content,"position:y",0.0,.2)
		swap.tween_property(ghost,"modulate:a",0.0,.16)
		swap.chain().tween_callback(func():
			if is_instance_valid(ghost):ghost.get_parent().remove_child(ghost);ghost.queue_free();ghost=null)
