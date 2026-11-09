class_name ChapterSelection
extends RefCounted
var app:Node
func _init(owner_app:Node)->void:app=owner_app
func open()->void:
	app.picture(app.stage,preload("res://assets/figma/3eebe.png"),Rect2(0,0,app.w,app.h)).stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	app.back_button(func():app.show_screen("title"))
	var title:Label=app.label(app.stage,"역사의 길을 따라",28,Color("fff0d0"));title.position=Vector2(95,app.safe.y+5)
	var subtitle:Label=app.label(app.stage,"작은 터전에서 시작해 새로운 시대로 나아갑니다",14,Color("fff0d0"));subtitle.position=Vector2(95,app.safe.y+40)
	var portrait:bool=app.w<app.h
	var card_size:=Vector2(minf(276,(app.w-app.safe.x*2-40)/3),minf(346,app.h-150))
	if portrait:card_size=Vector2(app.w-app.safe.x*2,minf(225,(app.h-180)/3))
	var group_height := card_size.y * 3 + 24 if portrait else card_size.y
	var top: float = (app.h - group_height) * 0.5
	var names:=["선사시대의 첫 불씨","고조선의 시작","삼국의 새로운 길"]
	for i in 3:
		var at:=Vector2((app.w-card_size.x*3-40)*.5+i*(card_size.x+20),top)
		if portrait:at=Vector2(app.safe.x,top+i*(card_size.y+12))
		var card:=Control.new();card.position=at;card.size=card_size;app.stage.add_child(card)
		var bg:TextureRect=app.picture(card,preload("res://assets/ui/v0158/chapter-card-bg.png"),Rect2(Vector2.ZERO,card_size));bg.stretch_mode=TextureRect.STRETCH_SCALE
		var image_height:=card_size.y*.44
		var scene:TextureRect=app.picture(card,preload("res://assets/ui/v0158/chapter-scene-prehistory.png") if i==0 else preload("res://assets/figma/3eebe.png"),Rect2(12,12,card_size.x-24,image_height));scene.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if i>0:scene.modulate=Color(1,1,1,.35)
		app.picture(card,DemoArt.facility_icon("hut") if i==0 else preload("res://assets/ui/v0158/lock.png"),Rect2(16,image_height+23,35,35))
		var chapter:Label=app.label(card,"%d장 · %s"%[i+1,"여정 시작" if i==0 else "잠겨 있는 이야기"],14);chapter.position=Vector2(56,image_height+30)
		var caption:Label=app.label(card,names[i],19);caption.position=Vector2(16,image_height+65);caption.size=Vector2(card_size.x-32,30);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var button:DemoButton=app.button(card,"",func():app.show_screen("region"));button.name="Chapter%d"%(i+1);button.custom_minimum_size=Vector2.ZERO;button.position=Vector2(14,card_size.y-62);button.size=Vector2(card_size.x-28,48)
		button.disabled=i>0;button.hint_text="다음 장은 준비 중입니다."
		for state in ["normal","hover","pressed","disabled"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		app.picture(button,preload("res://assets/ui/v0158/chapter-start-bg.png"),Rect2(Vector2.ZERO,button.size)).stretch_mode=TextureRect.STRETCH_SCALE
		var action:Label=app.label(button,"이 장에서 시작" if i==0 else "잠긴 장",18);action.size=button.size;action.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;action.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		if i>0:button.modulate.a=.55
