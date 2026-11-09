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
func background(parent:Control,key:String,rect:Rect2)->NinePatchRect:
	var source:Texture2D=load("res://assets/ui/v0160/quest-"+key+"-bg.png")
	var texture:Texture2D=crop(source,1.015,1.366,.007,.1792) if key=="common" else crop(source,1,1.4058,0,.2039) if key=="selected" else crop(source,1.0284,1.2271,.0142,.1102)
	return QuestRewards.sliced_art(parent,texture,rect,110)
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
	var scroll:=DevelopmentSettingsScroll.new()
	scroll.name="QuestList"
	scroll.position=Vector2(61,197)
	scroll.size=Vector2(1148,426)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	var state:Dictionary=app.model.state
	var current:=FirstQuests.current(state)
	var claimed_style:=ShaderMaterial.new()
	claimed_style.shader=preload("res://shaders/quest_claimed.gdshader")
	for i in FirstQuests.IDS.size():
		var row:=Control.new()
		row.custom_minimum_size=Vector2(1125,76)
		list.add_child(row)
		var row_art:=background(row,"selected" if i==current else "common",Rect2(0,0,1125,76))
		text(row,"%02d"%[i+1],Vector2(16,18),22)
		text(row,FirstQuests.TITLES[i],Vector2(78,18),22)
		text(row,FirstQuests.OBJECTIVES[i],Vector2(330,18),19)
		var id:String=FirstQuests.IDS[i]
		var status:="대기"
		var tint:=CREAM
		if id in state.get("quests_claimed",[]):
			status="✓ 수령 완료"
			row_art.material=claimed_style
			row.modulate=Color(.77,.77,.77,.83)
			tint=Color("dbd7c9")
		elif id in state.get("quests_done",[]):
			status="보상 미수령"
			tint=Color("ffcc70")
		elif i==current:status="진행 중"
		text(row,status,Vector2(988,18),18,tint)
