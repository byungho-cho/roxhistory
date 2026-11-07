class_name QuestScreen
extends RefCounted
## U10300 / 1479:76, authored on a 1280x720 design canvas.
var app:Node
const CREAM:=Color("ffe8b8")
const ICONS:=preload("res://assets/ui/v0160/quest-icons-atlas.png")
const HUTS:=preload("res://assets/ui/v0160/quest-huts-atlas.png")
func _init(owner_app:Node)->void:app=owner_app
func text(parent:Node,value:String,at:Vector2,fs:int=20,color:Color=CREAM)->Label:
	var label:Label=app.label(parent,value,fs,color);label.position=at;return label
func crop(source:Texture2D,w:float,h:float,x:float,y:float)->AtlasTexture:
	var result:=AtlasTexture.new();result.atlas=source;result.region=Rect2(source.get_width()*x/w,source.get_height()*y/h,source.get_width()/w,source.get_height()/h);result.filter_clip=true;return result
func hut()->Texture2D:return crop(HUTS,6.3882,2.4626,.25,.966)
func background(parent:Node,key:String,rect:Rect2)->TextureRect:
	var source:Texture2D=load("res://assets/ui/v0160/quest-"+key+"-bg.png")
	var texture:Texture2D=crop(source,1.015,1.366,.007,.1792) if key=="common" else crop(source,1,1.4058,0,.2039) if key=="selected" else crop(source,1.0284,1.2271,.0142,.1102)
	var result:TextureRect=app.picture(parent,texture,rect);result.stretch_mode=TextureRect.STRETCH_SCALE;return result
func line(parent:Node,at:Vector2,extent:Vector2,color:String)->void:
	var rule:=ColorRect.new();rule.position=at;rule.size=extent;rule.color=Color(color);rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(rule)
func open()->void:
	app.show_modal("","",[],false,true)
	app.clear_children(app.overlay)
	app.overlay.set_meta("restore_stage_visibility",app.stage.visible);app.stage.hide()
	var shade:=ModalBackdrop.new();shade.dismiss=app.close_modal;shade.color=Color(.063,.055,.043,.24);shade.size=Vector2(app.w,app.h);app.overlay.add_child(shade)
	var layer:=Control.new();layer.name="QuestScreen";layer.size=Vector2(1280,720);layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var factor:float=minf(app.w/1280.0,app.h/720.0);layer.scale=Vector2.ONE*factor;layer.position=(Vector2(app.w,app.h)-layer.size*factor)*.5;app.overlay.add_child(layer)
	var back:DemoButton=app.button(layer,"",app.close_modal);back.name="QuestBack";back.custom_minimum_size=Vector2.ZERO;back.position=Vector2(32,26);back.size=Vector2(48,48)
	for state in ["normal","hover","pressed","focus"]:back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(back,crop(ICONS,4.129,2.7978,.0161,.2951),Rect2(0,0,48,48))
	text(layer,"여정의 기록",Vector2(100,30),30,Color("fff0cf"))
	var close:=HudButtons.create(layer,false,app.close_modal,"QuestClose");close.position=Vector2(1198,26)
	var panel:=Panel.new();panel.name="QuestPanel";panel.position=Vector2(38,102);panel.size=Vector2(1204,548);panel.mouse_filter=Control.MOUSE_FILTER_STOP;panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new());layer.add_child(panel)
	var panel_image:TextureRect=app.picture(panel,preload("res://assets/ui/v0158/quest-panel-bg.png"),Rect2(Vector2.ZERO,panel.size));panel_image.stretch_mode=TextureRect.STRETCH_SCALE
	# All following coordinates use the Figma canvas, keeping one shared origin.
	var content:=Control.new();content.name="QuestContent";content.position=-panel.position;content.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(content)
	app.picture(content,crop(ICONS,4.4138,2.6947,3.3908,.2789),Rect2(88,127,38,42));text(content,"이야기",Vector2(148,128),28,Color("ffe1a0"))
	line(content,Vector2(249,131),Vector2(1,34),"9a713f");app.picture(content,hut(),Rect2(272,127,48,41.506));text(content,"생활",Vector2(342,130),25,Color("b8a58c"))
	line(content,Vector2(84,176),Vector2(1114,1),"866039");line(content,Vector2(431,198),Vector2(1,425),"775639")
	var glow:TextureRect=app.picture(content,crop(preload("res://assets/ui/v0160/quest-story-glow.png"),7.0549,40.913,.4768,9.3043),Rect2(87,165,182,18));var blend:=ShaderMaterial.new();blend.shader=preload("res://shaders/quest_lighten.gdshader");glow.material=blend
	var captions:=["우리의 첫 보금자리","숲에서 만난 흔적","함께 살아가는 마을"]
	for i in 3:
		var y:int=[208,330,444][i];var height:int=106 if i==0 else 98
		background(content,"selected" if i==0 else "common",Rect2(61,y,348,height))
		var texture:Texture2D=hut() if i==0 else crop(ICONS,4.2431,2.4265,.0608,1.2938) if i==1 else crop(ICONS,4.2198,2.56,3.1648,1.395)
		app.picture(content,texture,Rect2(79,y+24.46 if i==0 else y+18.75,66,57.071 if i==0 else 60.5))
		text(content,captions[i],Vector2(157,y+24 if i==0 else y+19),19);text(content,"진행 중" if i==0 else "잠김",Vector2(157,y+56 if i==0 else y+51),16)
	app.picture(content,hut(),Rect2(462,208,143,123.653));text(content,"이야기 · 첫 터전",Vector2(618,202),19,Color("d0ae7d"))
	text(content,"우리의 첫 보금자리",Vector2(618,235),39,Color("ffebc2"));text(content,"나무와 돌을 모아 주민이 머물 움집을 지어주세요.",Vector2(551,318),21,Color("f5e3be"))
	line(content,Vector2(456,363),Vector2(755,1),"87623c")
	var cost:Dictionary=app.model.building_cost("chief" if app.model.chief_level()==0 else "hut",1)
	for i in 2:
		var key:String="wood" if i==0 else "stone";var x:int=456+i*386
		background(content,"common",Rect2(x,389,371,110));app.picture(content,DemoArt.icon(key),Rect2(x+20,410,74,67.833))
		text(content,"목재 모으기" if i==0 else "석재 모으기",Vector2(x+109,410),22,Color("f7e5c0"))
		text(content,"%d / %d"%[mini(int(app.model.state.get(key,0)),int(cost[key])),int(cost[key])],Vector2(x+279,415),19,Color("f5dcab"))
		var bar:=ProgressBar.new();bar.name="WoodProgress" if i==0 else "StoneProgress";bar.position=Vector2(x+109,463);bar.size=Vector2(242,12);bar.show_percentage=false;bar.max_value=int(cost[key]);bar.value=mini(int(app.model.state.get(key,0)),int(cost[key]));bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var track:=StyleBoxFlat.new();track.bg_color=Color("241d14");track.border_color=Color("99815b");track.set_border_width_all(1);track.set_corner_radius_all(6)
		var fill:=StyleBoxFlat.new();fill.bg_color=Color("98af31");fill.set_corner_radius_all(5);fill.set_expand_margin_all(-1)
		bar.add_theme_stylebox_override("background",track);bar.add_theme_stylebox_override("fill",fill);content.add_child(bar);bar.size=Vector2(242,12)
	background(content,"common",Rect2(459,533,472,80));text(content,"보상",Vector2(478,551),27,Color("e8bb70"));line(content,Vector2(562,549),Vector2(1,48),"ad7a3e")
	app.picture(content,DemoArt.icon("meat"),Rect2(585,542,69,63.25));app.picture(content,DemoArt.icon("berries"),Rect2(682,542,69,63.25));app.picture(content,preload("res://assets/ui/v0160/quest-leather.png"),Rect2(762,520,108,108))
	var track:DemoButton=app.button(content,"",func():app.close_modal();app.focus_objective());track.name="TrackQuest";track.custom_minimum_size=Vector2.ZERO;track.position=Vector2(957,532);track.size=Vector2(260,81)
	for state in ["normal","hover","pressed","focus"]:track.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	background(track,"track",Rect2(0,0,260,81));app.picture(track,DemoArt.icon("compass"),Rect2(18,17.13,51,46.75));text(track,"임무 추적",Vector2(81,23),23,Color("3d210a"))
