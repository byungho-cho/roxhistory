class_name QuestScreen
extends RefCounted

const INK := Color("49321e")
var app: Node
var panel: Panel
var body: Control
var tabs: Array[DemoButton] = []
var selected := 0

func _init(owner_app: Node) -> void:
	app = owner_app

func open() -> void:
	var room := Vector2(app.w,app.h) - Vector2(app.safe)*2.0 - Vector2(16,16)
	var dimensions := Vector2(1166,497)
	var factor := minf(room.x/dimensions.x,room.y/dimensions.y)
	panel = QuestRewards.dialog(app,"QuestScreen",dimensions,factor)
	var heading := text(panel,"여정의 기록",Rect2(32,28,157,51),28)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HudButtons.create_modal_close(panel,app.close_modal,"QuestClose").position = Vector2(1098,14)
	for index in 2:
		var tab := QuestRewards.art_button(app,panel,"QuestTab%d"%index,Rect2(192+index*116,28,116,51),func():
			select_tab(index))
		tab.text = ["이야기","생활"][index]
		tab.add_theme_font_override("font",FigmaArt.NOTO)
		tab.add_theme_font_size_override("font_size",23)
		tabs.append(tab)
	body = Control.new()
	body.position.y = 79
	panel.add_child(body)
	selected = maxi(0,FirstQuests.current(app.model.state))
	select_tab(0,true)

func select_tab(index: int, initial := false) -> void:
	for item in tabs.size():
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("fff4db") if item == index else Color("ecdab7")
		skin.border_color = Color("c8ad85")
		skin.set_border_width_all(1)
		skin.border_width_bottom = 0
		skin.corner_radius_top_left = 6
		skin.corner_radius_top_right = 6
		for state in ["normal","hover","pressed","focus"]:
			tabs[item].add_theme_stylebox_override(state,skin)
			var font_color := "font_color" if state == "normal" else "font_%s_color"%state
			tabs[item].add_theme_color_override(font_color,Color("9d302b") if item == index else INK)
	app.clear_children(body)
	var active_x := 192 + index*116
	QuestRewards.rule(body,Rect2(32,0,active_x-32,1))
	QuestRewards.rule(body,Rect2(active_x+116,0,1100-active_x-116,1))
	if index == 0:
		story(initial)
	else:
		text(body,"등록된 생활 임무가 없어요.",Rect2(35,31,884,48),25)

func story(initial: bool) -> void:
	QuestRewards.rule(body,Rect2(375,20,1,373))
	var scroll := DevelopmentSettingsScroll.new()
	scroll.name = "QuestList"
	scroll.position = Vector2(32,30)
	scroll.size = Vector2(332,336)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",12)
	scroll.add_child(rows)
	var details := Control.new()
	details.position = Vector2(396,20)
	body.add_child(details)
	var state: Dictionary = app.model.state
	var current := FirstQuests.current(state)
	var row_buttons: Array[DemoButton] = []
	for index in FirstQuests.IDS.size():
		var row := QuestRewards.art_button(app,rows,"QuestStory%d"%index,Rect2(0,0,318,84),func():
			selected = index
			for row_index in row_buttons.size():
				style_row(row_buttons[row_index],row_index == selected)
			render_details(details,current))
		row.custom_minimum_size = Vector2(0,84)
		row_buttons.append(row)
		style_row(row, index == selected)
		app.picture(row,QuestRewards.objective_icon(index),Rect2(10,14,49,55))
		text(row,FirstQuests.TITLES[index],Rect2(72,13,237,31),21)
		text(row,status(index,current,state),Rect2(72,48,210,24),16,Color("55723d") if index == current else Color("80613f"))
	render_details(details,current)
	var scroll_at := clampi(selected-2,0,FirstQuests.IDS.size()-4)
	if scroll_at > 0:
		scroll.set_deferred("scroll_vertical",scroll_at*96)
	if initial:
		QuestRewards.reveal_rows(app,rows,scroll_at,4)

func style_row(row: DemoButton, active: bool) -> void:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("f0dcb5") if active else Color("fff7e4")
	skin.border_color = Color("b99055") if active else Color("dcc59d")
	skin.set_corner_radius_all(10)
	skin.set_border_width_all(1)
	for style in ["normal","hover","pressed","focus"]:
		row.add_theme_stylebox_override(style,skin)

func render_details(details: Control, current: int) -> void:
	app.clear_children(details)
	app.picture(details,QuestRewards.objective_icon(selected),Rect2(0,0,145,120))
	text(details,"이야기 · "+status(selected,current,app.model.state),Rect2(164,10,530,24),19,Color("80613f"))
	text(details,FirstQuests.TITLES[selected],Rect2(164,43,550,45),34)
	text(details,FirstQuests.OBJECTIVES[selected],Rect2(164,93,540,31),20)
	QuestRewards.rule(details,Rect2(0,143,733,1))
	var status_box := Panel.new()
	status_box.position = Vector2(0,164)
	status_box.size = Vector2(733,91)
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("fff7e4")
	surface.set_corner_radius_all(10)
	status_box.add_theme_stylebox_override("panel",surface)
	details.add_child(status_box)
	var done: bool = FirstQuests.IDS[selected] in app.model.state.get("quests_done",[])
	text(status_box,"임무 진행",Rect2(18,12,240,29),21)
	var tally := text(status_box,"%d / 1" % int(done),Rect2(560,12,150,29),20)
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var progress := ProgressBar.new()
	progress.position = Vector2(18,53)
	progress.size = Vector2(692,10)
	progress.max_value = 1
	progress.value = int(done)
	progress.show_percentage = false
	for part in ["background","fill"]:
		var track_style := StyleBoxFlat.new()
		track_style.bg_color = Color("7d9a58") if part == "fill" else Color("dac9a6")
		track_style.set_corner_radius_all(5)
		progress.add_theme_stylebox_override(part,track_style)
	status_box.add_child(progress)
	var reward := Panel.new()
	reward.position = Vector2(0,286)
	reward.size = Vector2(488,73)
	var reward_style := StyleBoxFlat.new()
	reward_style.bg_color = Color("eddbb8")
	reward_style.set_corner_radius_all(10)
	reward.add_theme_stylebox_override("panel",reward_style)
	details.add_child(reward)
	text(reward,"보상",Rect2(17,22,85,32),22)
	var kind: String = FirstQuests.INTRO_KINDS[selected] if selected < FirstQuests.INTRO_KINDS.size() else "grain"
	app.picture(reward,PlayChrome.CORN_ICON if kind == "grain" else DemoArt.icon(kind),Rect2(104,9,57,55))
	var amount := FirstQuests.INTRO_AMOUNT if selected < FirstQuests.INTRO_KINDS.size() else FirstQuests.MANUAL_AMOUNT
	text(reward,str(amount),Rect2(174,22,110,32),22)
	var track := QuestRewards.gold_button(app,details,"QuestTrack",Rect2(507,286,228,73),func():
		app.close_modal()
		app.guide_current_quest())
	track.disabled = selected != current
	track.modulate.a = .55 if track.disabled else 1.0
	app.picture(track,DemoArt.icon("compass"),Rect2(34,20,31,31))
	text(track,"임무 추적",Rect2(76,20,149,36),24)

func status(index: int,current: int,state: Dictionary) -> String:
	var id: String = FirstQuests.IDS[index]
	if id in state.get("quests_claimed",[]): return "수령 완료"
	if id in state.get("quests_done",[]): return "보상 미수령"
	return "진행 중" if index == current else "잠김"

func text(parent: Control,value: String,rect: Rect2,font_size: int,color := INK) -> Label:
	return FigmaArt.text(parent,value,rect,font_size,FigmaArt.NOTO,color,false)
