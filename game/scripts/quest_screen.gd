class_name QuestScreen
extends RefCounted
var app:Node
const CREAM:=Color("ffe6b8")
func _init(owner_app:Node)->void:app=owner_app
func text(parent:Node,value:String,at:Vector2,fs:int=20)->Label:
	var label:Label=app.label(parent,value,fs,CREAM);label.position=at;return label
func background(parent:Node,key:String,rect:Rect2)->TextureRect:
	var result:TextureRect=app.picture(parent,load("res://assets/ui/v0158/quest-"+key+"-bg.png"),rect);result.stretch_mode=TextureRect.STRETCH_SCALE;return result
func open()->void:
	app.show_modal("","",[],false,true)
	app.clear_children(app.overlay)
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.22);shade.size=Vector2(app.w,app.h);app.overlay.add_child(shade)
	var layer:=Control.new();layer.name="QuestScreen";layer.size=Vector2(960,540)
	var scale_factor:float=minf(app.w/960.0,app.h/540.0);layer.scale=Vector2.ONE*scale_factor;layer.position=(Vector2(app.w,app.h)-layer.size*scale_factor)*.5;app.overlay.add_child(layer)
	text(layer,"여정의 기록",Vector2(54,20),26)
	var close:DemoButton=app.button(layer,"",app.close_modal);close.name="QuestClose";close.custom_minimum_size=Vector2.ZERO;close.position=Vector2(894,14);close.size=Vector2(48,48)
	for state in ["normal","hover","pressed"]:close.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(close,AssetCatalog.texture("UI-BUILDING-MENU-CLOSE-NORMAL"),Rect2(0,0,48,48))
	var panel:=Panel.new();panel.position=Vector2(28,76);panel.size=Vector2(904,412);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new());layer.add_child(panel)
	var panel_image:TextureRect=app.picture(panel,preload("res://assets/ui/v0158/quest-panel-bg.png"),Rect2(Vector2.ZERO,panel.size));panel_image.stretch_mode=TextureRect.STRETCH_SCALE
	app.picture(panel,DemoArt.icon("scroll"),Rect2(28,18,40,40));text(panel,"이야기",Vector2(82,21),24)
	var gold:=ColorRect.new();gold.color=Color("e9b940");gold.position=Vector2(36,57);gold.size=Vector2(140,3);gold.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(gold)
	var captions:=["우리의 첫 보금자리","숲에서 만난 흔적","함께 살아가는 마을"]
	for i in 3:
		background(panel,"selected" if i==0 else "common",Rect2(20,80+i*85,264,74))
		app.picture(panel,DemoArt.facility_icon("hut") if i==0 else DemoArt.icon("spear") if i==1 else load("res://assets/ui/v0158/lock.png"),Rect2(34,92+i*85,45,45))
		text(panel,captions[i],Vector2(90,93+i*85),17);text(panel,"진행 중" if i==0 else "잠김",Vector2(90,120+i*85),13)
	text(panel,"이야기 · 첫 터전",Vector2(435,76),14)
	app.picture(panel,DemoArt.facility_icon("hut"),Rect2(320,90,105,85))
	text(panel,"우리의 첫 보금자리",Vector2(435,102),29)
	text(panel,"나무와 돌을 모아 주민이 머물 움집을 지어주세요.",Vector2(345,162),16)
	var cost:Dictionary=app.model.building_cost("chief" if app.model.chief_level()==0 else "hut",1)
	for i in 2:
		var key:String="wood" if i==0 else "stone"
		var x:=314+i*290
		background(panel,"common",Rect2(x,215,278,82));app.picture(panel,DemoArt.icon(key),Rect2(x+16,235,48,44))
		text(panel,"목재 모으기" if i==0 else "석재 모으기",Vector2(x+76,231),17)
		text(panel,"%d / %d"%[mini(int(app.model.state.get(key,0)),int(cost[key])),int(cost[key])],Vector2(x+195,234),14)
		var bar:=ProgressBar.new();bar.position=Vector2(x+77,270);bar.size=Vector2(182,8);bar.show_percentage=false;bar.max_value=int(cost[key]);bar.value=mini(int(app.model.state.get(key,0)),int(cost[key]));bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var track_bg:=StyleBoxFlat.new();track_bg.bg_color=Color("493b29");track_bg.set_corner_radius_all(4);track_bg.set_border_width_all(1);track_bg.border_color=Color("c3a365")
		var fill:=StyleBoxFlat.new();fill.bg_color=Color("9baa35");fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background",track_bg);bar.add_theme_stylebox_override("fill",fill);panel.add_child(bar)
	background(panel,"common",Rect2(314,322,350,63));text(panel,"보상",Vector2(330,340),21)
	for i in 3:app.picture(panel,DemoArt.icon(["meat","berries","tokens"][i]),Rect2(415+i*65,333,48,42))
	var track:DemoButton=app.button(panel,"",func():app.close_modal();app.focus_objective());track.name="TrackQuest";track.custom_minimum_size=Vector2.ZERO;track.position=Vector2(680,322);track.size=Vector2(204,63)
	for state in ["normal","hover","pressed"]:track.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	background(track,"track",Rect2(0,0,204,63));app.picture(track,DemoArt.icon("compass"),Rect2(12,12,39,39));var caption:=text(track,"임무 추적",Vector2(61,18),22);caption.add_theme_color_override("font_color",Color("49321e"))
