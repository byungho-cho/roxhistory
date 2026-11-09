class_name QuestRewards
extends RefCounted

const PANEL:=preload("res://assets/quest-rewards/panel.png")
const PARTS:=preload("res://assets/quest-rewards/parts.png")
const ICONS:=preload("res://assets/quest-rewards/icons.png")
const CREAM:=Color("f5e1bb")
const INK:=Color("392513")
const CARD:=Rect2(1.75,8.2,103.44,290.82)
const CLAIM:=Rect2(54.35,161.36,385.65,403.18)
const COUNT:=Rect2(106.8,161.36,241.36,403.18)
const CLOSE:=Rect2(277.78,224.07,657.04,328.52)
const BAG:=Rect2(648.23,67.85,770.21,232.8)
const CORN:=Rect2(486.33,71.38,724,238.16)
const OBJECTIVE_ICONS:=[Rect2(5.41,66.36,533.66,225.55),Rect2(108.98,55.29,527.18,212.94),Rect2(173.76,47.53,431.81,198.9)]

static func part(source:Texture2D,crop:Rect2)->AtlasTexture:
	var texture:=AtlasTexture.new()
	texture.atlas=source
	var dimensions:=source.get_size()
	texture.region=Rect2(crop.position/crop.size*dimensions,Vector2(100,100)/crop.size*dimensions)
	texture.filter_clip=true
	return texture

static func art_button(app:Node,parent:Control,name:String,rect:Rect2,action:Callable)->DemoButton:
	var button:DemoButton=app.button(parent,"",action)
	button.name=name
	button.custom_minimum_size=Vector2.ZERO
	button.position=rect.position
	button.size=rect.size
	for style in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	return button

static func caption(app:Node,parent:Control,value:String,rect:Rect2,font_size:int,color:Color)->Label:
	var label:Label=app.label(parent,value,font_size,color)
	label.position=rect.position
	label.size=rect.size
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return label

static func install_entry(app:Node)->Label:
	var at:=Vector2(app.safe.x,app.h-app.safe.y-87)
	var journal:=art_button(app,app.stage,"JournalButton",Rect2(at,Vector2(64,83)),app.quest_details)
	journal.z_index=35
	entry_art(app,journal,DemoArt.play_icon("scroll"),"임무")
	var button:=art_button(app,app.stage,"QuestRewardEntry",Rect2(at+Vector2(67,0),Vector2(64,83)),func():
		if not app.modal and not app.world_map_open and not app.map_transition_active:open(app))
	button.z_index=35
	button.tooltip_text="퀘스트 보상"
	entry_art(app,button,part(ICONS,BAG),"보상")
	var badge:=Panel.new()
	badge.position=Vector2(44,0)
	badge.size=Vector2(22,22)
	badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("c9511b")
	style.set_corner_radius_all(11)
	badge.add_theme_stylebox_override("panel",style)
	button.add_child(badge)
	return caption(app,badge,"",Rect2(0,0,22,22),14,Color.WHITE)

static func entry_art(app:Node,button:DemoButton,icon:Texture2D,title:String)->void:
	app.picture(button,icon,Rect2(7,5,50,55))
	var brush:TextureRect=app.picture(button,preload("res://assets/ui/construction-side-v006/brush.png"),Rect2(0,49,64,26))
	brush.modulate.a=.8
	caption(app,button,title,Rect2(0,50,64,24),14,CREAM)

static func open(app:Node)->void:
	app.show_modal("","",[],false,true)
	app.clear_children(app.overlay)
	var shade:=ModalBackdrop.new()
	shade.color=Color(0,0,0,.38)
	shade.dismiss=app.close_modal
	app.overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=Control.new()
	panel.name="QuestRewardPanel"
	panel.size=Vector2(1000,820)
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var factor:float=minf((app.w-2*app.safe.x)/panel.size.x,(app.h-2*app.safe.y)/panel.size.y)
	panel.scale=Vector2.ONE*factor
	panel.position=(Vector2(app.w,app.h)-panel.size*factor)*.5
	app.overlay.add_child(panel)
	app.picture(panel,PANEL,Rect2(Vector2.ZERO,panel.size)).stretch_mode=TextureRect.STRETCH_SCALE
	caption(app,panel,"퀘스트 보상",Rect2(295,25,410,82),60,CREAM)
	var close_size:=maxf(92,48/factor)
	var close:=art_button(app,panel,"QuestRewardClose",Rect2(Vector2(927,70)-Vector2.ONE*close_size*.5,Vector2.ONE*close_size),app.close_modal)
	app.picture(close,part(PARTS,CLOSE),Rect2(Vector2.ONE*(close_size-92)*.5,Vector2.ONE*92))
	var scroll:=DevelopmentSettingsScroll.new()
	scroll.position=Vector2(75,138)
	scroll.size=Vector2(850,545)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	panel.add_child(scroll)
	var cards:=VBoxContainer.new()
	cards.add_theme_constant_override("separation",8)
	scroll.add_child(cards)
	var claim_all:=art_button(app,panel,"ClaimAllQuestRewards",Rect2(315,702,370,76),func():
		if app.model.claim_all_quest_rewards():fill_cards(app,cards))
	app.picture(claim_all,part(PARTS,CLAIM),Rect2(0,0,370,76)).stretch_mode=TextureRect.STRETCH_SCALE
	caption(app,claim_all,"모두 받기",Rect2(0,0,370,76),32,INK)
	fill_cards(app,cards)

static func fill_cards(app:Node,cards:VBoxContainer)->void:
	app.clear_children(cards)
	var pending:=FirstQuests.pending(app.model.state)
	var all_button:Button=app.overlay.find_child("ClaimAllQuestRewards",true,false)
	all_button.disabled=pending.is_empty()
	all_button.modulate.a=.55 if all_button.disabled else 1.0
	if pending.is_empty():
		caption(app,cards,"받을 보상이 없어요",Rect2(0,0,850,104),32,CREAM).custom_minimum_size=Vector2(850,104)
	for index in pending:
		var card:=Control.new()
		card.custom_minimum_size=Vector2(850,104)
		cards.add_child(card)
		app.picture(card,part(PARTS,CARD),Rect2(0,0,850,104)).stretch_mode=TextureRect.STRETCH_SCALE
		var icon:Texture2D
		if index<=5:
			icon=part(ICONS,OBJECTIVE_ICONS[index-3])
		else:
			icon=BuildingVisuals.texture("farm",1) if index==6 else PlayChrome.RESIDENT_ICON
		app.picture(card,icon,Rect2(24,6,138,92)).stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var title:=caption(app,card,FirstQuests.TITLES[index],Rect2(190,0,315,104),34,INK)
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		app.picture(card,part(ICONS,CORN),Rect2(524,24,54,55))
		caption(app,card,str(FirstQuests.MANUAL_AMOUNT),Rect2(582,0,75,104),37,INK)
		var claim:=art_button(app,card,"ClaimQuest%d"%index,Rect2(687,16,142,71),func():
			if app.model.claim_quest_reward(index):fill_cards(app,cards))
		app.picture(claim,part(PARTS,CLAIM),Rect2(0,0,142,71)).stretch_mode=TextureRect.STRETCH_SCALE
		caption(app,claim,"받기",Rect2(0,0,142,71),32,INK)
