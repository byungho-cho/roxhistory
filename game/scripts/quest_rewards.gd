class_name QuestRewards
extends RefCounted

const ICONS:=preload("res://assets/quest-rewards/icons.png")
const CREAM:=Color("f5e1bb")
const INK:=Color("392513")
const BAG:=Rect2(648.23,67.85,770.21,232.8)
const OBJECTIVE_ICONS:=[Rect2(5.41,66.36,533.66,225.55),Rect2(108.98,55.29,527.18,212.94),Rect2(173.76,47.53,431.81,198.9)]

static func part(source:Texture2D,crop:Rect2)->AtlasTexture:
	var texture:=AtlasTexture.new()
	texture.atlas=source
	var dimensions:=source.get_size()
	texture.region=Rect2(crop.position/crop.size*dimensions,Vector2(100,100)/crop.size*dimensions)
	texture.filter_clip=true
	return texture

static func sliced_art(parent:Control,source:Texture2D,rect:Rect2,cap:int)->NinePatchRect:
	var art:=NinePatchRect.new()
	art.texture=source.atlas if source is AtlasTexture else source
	art.region_rect=source.region if source is AtlasTexture else Rect2(Vector2.ZERO,source.get_size())
	var factor:=minf(1.0,rect.size.y/art.region_rect.size.y)
	art.position=rect.position
	art.size=rect.size/factor
	art.scale=Vector2.ONE*factor
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		art.set_patch_margin(side,cap)
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

static func art_button(app:Node,parent:Control,name:String,rect:Rect2,action:Callable)->DemoButton:
	var button:DemoButton=app.button(parent,"",action)
	button.name=name
	button.custom_minimum_size=Vector2.ZERO
	button.position=rect.position
	button.size=rect.size
	for style in ["normal","hover","pressed","disabled","focus"]:
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
	var at:=Vector2(app.safe.x,app.action_row.position.y)
	var journal:=art_button(app,app.stage,"JournalButton",Rect2(at,Vector2(64,77)),app.quest_details)
	journal.z_index=35
	entry_art(app,journal,DemoArt.play_icon("scroll"),"임무",219.0/244.0,1.2)
	var button:=art_button(app,app.stage,"QuestRewardEntry",Rect2(at+Vector2(67,0),Vector2(64,77)),func():
		if not app.modal and not app.world_map_open and not app.map_transition_active:open(app))
	button.z_index=35
	entry_art(app,button,part(ICONS,BAG),"보상",303.0/310.0)
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

static func entry_art(app:Node,button:DemoButton,icon:Texture2D,title:String,visible_height:float,icon_scale:float=1.0)->void:
	var trimmed:AtlasTexture=icon if icon is AtlasTexture else IntegratedMenuArt.trimmed(icon,Rect2(Vector2.ZERO,icon.get_size()))
	var dimensions:=trimmed.get_size()
	var base_size:=dimensions*minf(54.0/dimensions.x,54.0/dimensions.y)
	var display_size:=base_size*icon_scale
	var baseline_offset := visible_height*display_size.y
	var entry_icon:TextureRect=app.picture(button,trimmed,Rect2(Vector2((64-display_size.x)*.5,68-baseline_offset),display_size))
	entry_icon.name="EntryIcon"
	entry_icon.set_meta("visible_baseline",baseline_offset)
	var brush_texture := AtlasTexture.new()
	brush_texture.atlas = preload("res://assets/ui/construction-side-v006/brush.png")
	brush_texture.region = Rect2(0,160,2172,410)
	brush_texture.filter_clip = true
	var brush := app.picture(button,brush_texture,Rect2(0,63,64,14)) as TextureRect
	brush.stretch_mode = TextureRect.STRETCH_SCALE
	brush.modulate.a=.8
	caption(app,button,title,Rect2(0,55,64,22),14,CREAM)

static func paper_style() -> StyleBoxFlat:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f9edd2")
	paper.border_color = Color("bc985f")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(20)
	paper.shadow_color = Color(0.2,0.11,0.04,0.3)
	paper.shadow_size = 8
	paper.shadow_offset = Vector2(0,4)
	return paper

static func dialog(app:Node, id:String, dimensions:Vector2, factor:float) -> Panel:
	app.show_modal("","",[],false,true,false,Vector2.ZERO,false,true)
	app.clear_children(app.overlay)
	var shade := ModalBackdrop.new()
	shade.color = Color(0,0,0,.38)
	shade.dismiss = app.close_modal
	app.overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Panel.new()
	panel.name = id
	panel.size = dimensions
	panel.scale = Vector2.ONE * factor
	panel.position = (Vector2(app.w,app.h) - dimensions * factor) * .5
	panel.add_theme_stylebox_override("panel",paper_style())
	app.overlay.add_child(panel)
	app.animate_popup(panel)
	return panel

static func rule(parent:Control, rect:Rect2) -> void:
	var divider := ColorRect.new()
	divider.color = Color("c7ac81")
	divider.position = rect.position
	divider.size = rect.size
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)

static func gold_button(app:Node,parent:Control,id:String,rect:Rect2,action:Callable) -> DemoButton:
	var button := art_button(app,parent,id,rect,action)
	sliced_art(button,preload("res://assets/ui/d0026/common-gold-default.svg"),Rect2(Vector2.ZERO,rect.size),8)
	return button

static func objective_icon(index:int) -> Texture2D:
	match index:
		0: return DemoArt.icon("wood")
		1: return DemoArt.icon("stone")
		2: return BuildingVisuals.texture("chief",1)
		3,4,5: return part(ICONS,OBJECTIVE_ICONS[index-3])
		6: return BuildingVisuals.texture("farm",1)
		_: return PlayChrome.RESIDENT_ICON

static func open(app:Node) -> void:
	var room := Vector2(app.w,app.h) - Vector2(app.safe)*2.0 - Vector2(18,18)
	var factor := minf(maxf(app.w/1600.0,app.h/900.0),minf(room.x/870.0,room.y/537.0))
	var rows := 5 if room.y >= 614.0 * factor else 4
	var height := 229.0 + rows*77.0
	var panel := dialog(app,"QuestRewardPanel",Vector2(870,height),factor)
	var heading := caption(app,panel,"퀘스트 보상",Rect2(61,23,590,58),40,INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	HudButtons.create_modal_close(panel,app.close_modal,"QuestRewardClose").position = Vector2(786,15)
	rule(panel,Rect2(60,91,730,1.5))
	var scroll := DevelopmentSettingsScroll.new()
	scroll.name = "QuestRewardList"
	scroll.position = Vector2(59,105)
	scroll.size = Vector2(751,rows*77)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation",0)
	scroll.add_child(cards)
	rule(panel,Rect2(60,height-113,750,1.5))
	var hint := caption(app,panel,"아이콘을 눌러 받기",Rect2(61,height-101,300,25),16,INK)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var claim_all := gold_button(app,panel,"ClaimAllQuestRewards",Rect2(443,height-94,336,55),func():
		if app.model.claim_all_quest_rewards():
			app.audio.cue("reward")
			fill_cards(app,cards))
	caption(app,claim_all,"모두 받기",Rect2(0,0,336,55),25,INK)
	var badge: TextureRect = app.picture(claim_all,preload("res://assets/ui/d0031/reward-badge.png"),Rect2(304,-13,36,36))
	badge.name = "PendingBadge"
	badge.pivot_offset = badge.size * .5
	badge.rotation_degrees = -8.0
	caption(app,badge,"",Rect2(0,0,36,36),20,CREAM).name = "Count"
	fill_cards(app,cards)

static func fill_cards(app:Node, cards:VBoxContainer) -> void:
	app.clear_children(cards)
	var pending := FirstQuests.pending(app.model.state)
	var all_button: Button = app.overlay.find_child("ClaimAllQuestRewards",true,false)
	all_button.disabled = pending.is_empty()
	all_button.modulate.a = .55 if all_button.disabled else 1.0
	var badge: TextureRect = all_button.get_node("PendingBadge")
	badge.visible = not pending.is_empty()
	badge.get_node("Count").text = str(pending.size())
	if pending.is_empty():
		var empty := caption(app,cards,"받을 보상이 없어요",Rect2(0,0,736,77),28,INK)
		empty.custom_minimum_size = Vector2(0,77)
	for index in pending:
		var card := Control.new()
		card.custom_minimum_size = Vector2(736,77)
		cards.add_child(card)
		app.picture(card,objective_icon(index),Rect2(10,7,68,63))
		var title := caption(app,card,FirstQuests.TITLES[index],Rect2(120,0,470,77),26,INK)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var claim := art_button(app,card,"ClaimQuest%d"%index,Rect2(608,6,112,67),func():
			if app.model.claim_quest_reward(index):
				app.audio.cue("reward")
				fill_cards(app,cards))
		claim.set_meta("semantic_text",FirstQuests.TITLES[index]+" 보상 받기")
		app.picture(claim,preload("res://assets/ui/d0031/reward-tile.png"),Rect2(0,0,112,67))
		app.picture(claim,PlayChrome.CORN_ICON,Rect2(33,1,46,49))
		caption(app,claim,str(FirstQuests.MANUAL_AMOUNT),Rect2(0,44,112,20),16,CREAM)
		rule(card,Rect2(0,76,720,1))
