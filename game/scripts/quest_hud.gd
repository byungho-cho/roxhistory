class_name QuestHud
extends Control

const ROW_HEIGHT := 40.0
const INK := Color("374438")
const PAPER := Color("f0edd3e8")
const CREAM := Color("fff5dc")
const HEADER := 40.0

var app: Node
var title: Label
var emblem: TextureRect
var arrow: Label
var badge: DemoButton
var body: Control
var detail: Control
var wood: Label
var stone: Label
var rows: Dictionary = {}
var shown_ids: Array[int] = []
var preview_ids: Array[int] = []
var current := -2
var width := 0.0
var body_height := 0.0
var body_target := 0.0
var motion: Tween
var claim_animation: Tween
var busy := false
var wiggle_time := 0.0
var hold_id := -2
var hold_elapsed := 0.0
var hold_at := Vector2.ZERO

func _init(owner: Node) -> void:
	app = owner

func _ready() -> void:
	name = "QuestPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	width = minf(288.0,app.w-app.safe.x*2-12)
	position = app.safe+Vector2(0,123 if app.w<app.h else 79)
	size = Vector2(width,HEADER)
	body = Control.new()
	body.position = Vector2(5,HEADER)
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	var backdrop := paint(self,Rect2(0,0,width,HEADER),Color.TRANSPARENT,Color("202720aa"),3)
	backdrop.z_index=2
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.19,.53,1])
	gradient.colors = PackedColorArray([Color("909b94e6"),Color("748078e6"),Color("505c52e6"),Color("383f38e6")])
	var sheen := GradientTexture2D.new()
	sheen.gradient = gradient
	sheen.fill_to = Vector2(0,1)
	var background: TextureRect = app.picture(backdrop,sheen,Rect2(1,1,width-2,HEADER-2))
	background.stretch_mode=TextureRect.STRETCH_SCALE
	emblem = app.picture(self,null,Rect2(9,6,29,29))
	emblem.z_index=3
	title = caption(self,"",Rect2(48,0,width-94,HEADER),16,CREAM)
	title.z_index=3
	title.clip_text=true
	var toggle := QuestRewards.art_button(app,self,"QuestToggle",Rect2(width-50,0,50,HEADER),app.toggle_quest)
	toggle.z_index=3
	toggle.set_meta("semantic_text","퀘스트 상세 펼침·접힘")
	arrow = caption(toggle,"",Rect2(9,0,34,HEADER),23,Color("eee6c2bd"))
	arrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	badge = QuestRewards.art_button(app,self,"QuestPendingBadge",Rect2(32,-10,32,25),func(): claim(-1))
	badge.z_index=4
	var oval := paint(badge,Rect2(0,1,31,22),Color("a63a2b"),Color("efc68e"),12)
	oval.name="Tint"
	badge.pivot_offset = Vector2(13,20)
	var number := caption(badge,"",Rect2(0,0,31,23),13,CREAM)
	number.name="Count"
	number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	refresh(true)

func caption(parent: Control,value: String,rect: Rect2,font_size: int,tint := INK) -> Label:
	var item := FigmaArt.text(parent,value,rect,font_size,FigmaArt.BODY,tint,false)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return item

func paint(parent: Control,rect: Rect2,fill: Color,rim: Color,radius: int) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.position=rect.position
	panel.size=rect.size
	var skin := StyleBoxFlat.new()
	skin.bg_color=fill
	skin.border_color=rim
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel",skin)
	parent.add_child(panel)
	return panel

func pending() -> Array[int]:
	return preview_ids.duplicate() if not preview_ids.is_empty() else FirstQuests.pending(app.model.state)

func update_badge() -> void:
	var count := pending().size()
	badge.visible = count > 0
	badge.get_node("Count").text = str(count)
	badge.set_meta("semantic_text","미수령 보상 %d건 모두 받기"%count)

func refresh(immediate := false) -> void:
	var active := FirstQuests.current(app.model.state)
	var ids := pending()
	update_badge()
	if busy: return
	ids.reverse()
	var visible_ids := ids.slice(0,3)
	if current != active or shown_ids != visible_ids:
		var old_height := body_target
		current = active
		shown_ids = visible_ids
		draw_body()
		update_amounts()
		if not immediate and app.quest_expanded and old_height > body_target:
			animate_height(body_target,false)
		else:
			if motion and motion.is_valid():motion.kill()
			set_body_height(body_target if app.quest_expanded else 0.0)
	else:
		update_amounts()

func update_amounts() -> void:
	if not is_instance_valid(wood):return
	var kind: String = {2:"chief",3:"hut",5:"chief",6:"farm"}.get(current,"chief")
	var cost: Dictionary = app.model.building_cost(kind,2 if current==5 else 1)
	wood.text = "%d/%d"%[mini(int(app.model.state.wood),int(cost.wood)),int(cost.wood)]
	stone.text = "%d/%d"%[mini(int(app.model.state.stone),int(cost.stone)),int(cost.stone)]

func draw_body() -> void:
	app.clear_children(body)
	rows.clear()
	wood=null
	stone=null
	title.text = FirstQuests.TITLES[current] if current>=0 else "첫 여정 완료"
	emblem.texture = QuestRewards.objective_icon(current) if current>=0 else DemoArt.icon("scroll")
	arrow.text = "⌃" if app.quest_expanded else "⌄"
	detail = Control.new()
	detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body.add_child(detail)
	paint(detail,Rect2(0,0,width-10,1),PAPER,Color("30372c90"),8).name="Paper"
	var y := 7.0
	if current >= 0:
		var description := caption(detail,FirstQuests.OBJECTIVES[current],Rect2(10,y,width-30,32),12)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		y += 35
	if current in [2,3,5,6]:
		app.picture(detail,DemoArt.icon("wood"),Rect2(12,y,24,23))
		wood=caption(detail,"",Rect2(41,y,70,23),13)
		app.picture(detail,DemoArt.icon("stone"),Rect2(width*.48,y,24,23))
		stone=caption(detail,"",Rect2(width*.48+29,y,65,23),13)
		y += 27
	if current >= 0 and current+1 < FirstQuests.IDS.size():
		var next := paint(detail,Rect2(8,y,width-26,30),Color("f8f4e5b8"),Color("aab49a"),5)
		caption(next,"다음 임무  ·  "+FirstQuests.TITLES[current+1],Rect2(7,0,width-42,30),12)
		y += 35
	if not shown_ids.is_empty():
		caption(detail,"최근 미수령 보상",Rect2(10,y,width-35,22),12)
		y += 23
		for index in shown_ids:
			var row := paint(detail,Rect2(8,y,width-26,ROW_HEIGHT-3),Color("fffbe4d9"),Color("b2bda2"),6)
			row.name = "PendingQuest%d"%index
			rows[index] = row
			app.picture(row,QuestRewards.objective_icon(index),Rect2(5,4,28,28))
			var row_title := caption(row,FirstQuests.TITLES[index],Rect2(38,0,width-130,ROW_HEIGHT-3),12)
			row_title.clip_text=true
			var award := QuestRewards.art_button(app,row,"Award",Rect2(row.size.x-59,0,59,row.size.y),claim.bind(index))
			award.set_meta("semantic_text",FirstQuests.TITLES[index]+" 보상 받기")
			app.picture(award,PlayChrome.CORN_ICON,Rect2(17,1,30,29))
			paint(award,Rect2(18,22,30,12),Color("45301ab3"),Color.TRANSPARENT,4)
			var amount := caption(award,str(FirstQuests.MANUAL_AMOUNT),Rect2(18,20,30,13),11,CREAM)
			amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			y += ROW_HEIGHT
	body_target = y+4 if y>7 else 0.0
	detail.get_node("Paper").size.y = body_target

func set_body_height(value: float) -> void:
	body_height = maxf(0.0,value)
	body.size = Vector2(width-10,body_height)
	size.y = HEADER+body_height
	body.visible = body_height > .1

func animate_height(target: float, spring: bool) -> void:
	if motion and motion.is_valid():motion.kill()
	if app.reduced_ui_motion():
		set_body_height(target)
		return
	motion = create_tween()
	if spring and target>0:
		motion.tween_method(set_body_height,body_height,target+3.0,.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_method(set_body_height,target+3.0,target,.09).set_trans(Tween.TRANS_SINE)
	else:
		motion.tween_method(set_body_height,body_height,target,.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func fold() -> void:
	arrow.text = "⌃" if app.quest_expanded else "⌄"
	animate_height(body_target if app.quest_expanded else 0.0,true)

func claim(index: int) -> void:
	if busy or app.modal or app.world_map_open or not app.application_active or not is_instance_valid(app.chrome):
		return
	var ids := pending()
	if ids.is_empty() or (index>=0 and index not in ids):return
	var matching: Array[int] = [index]
	if index<0:matching = ids
	var origins := PackedVector2Array()
	var expanded: bool = app.quest_expanded
	if expanded:
		for id in shown_ids:
			if id not in matching:continue
			origins.append(rows[id].get_node("Award").get_global_rect().get_center())
	else:
		for entry in mini(3,matching.size()):
			origins.append(global_position+Vector2(width-18,HEADER*.54))
	if origins.is_empty():origins.append(global_position+Vector2(width-18,HEADER*.54))
	busy = true
	var preview := not preview_ids.is_empty()
	if preview:
		for id in matching:preview_ids.erase(id)
	else:
		var committed: bool = app.model.claim_all_quest_rewards() if index<0 else app.model.claim_quest_reward(index)
		if not committed:
			busy=false
			return
	update_badge()
	app.audio.cue("reward")
	app.chrome.quest_reward_effect(origins,matching.size()*FirstQuests.MANUAL_AMOUNT,preview)
	var instant: bool = app.reduced_ui_motion()
	for id in matching:
		if not rows.has(id):continue
		var row: Panel = rows[id]
		row.get_node("Award").hide()
		if expanded and not instant:
			var exit := row.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			exit.tween_property(row,"position:x",row.position.x-width,.23)
			exit.tween_property(row,"modulate:a",0.0,.23)
	if not expanded or instant:
		finish_claim()
		return
	claim_animation = create_tween()
	claim_animation.tween_interval(.23)
	claim_animation.tween_callback(finish_claim)

func finish_claim() -> void:
	busy=false
	var former: Dictionary = {}
	for index in rows:
		former[index] = rows[index].position.y
	refresh()
	if not app.quest_expanded or app.reduced_ui_motion():return
	for index in rows:
		if not former.has(index):continue
		var row: Panel = rows[index]
		var final_y := row.position.y
		if final_y>=float(former[index]):continue
		row.position.y=former[index]
		row.create_tween().tween_property(row,"position:y",final_y,.23).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or app.modal or not app.application_active:
		hold_id=-2
		return
	if hold_id!=-2:
		hold_elapsed+=delta
		if hold_elapsed>=.65:
			hold_id=-2
			seed_preview(randi_range(1,5))
	if not badge.visible:
		wiggle_time=0.0
		return
	wiggle_time+=delta
	if wiggle_time>=5.0:
		wiggle_time=0.0
		if not app.reduced_ui_motion():
			var wiggle := badge.create_tween()
			for angle in [-10.0,7.0,-4.0,0.0]:
				wiggle.tween_property(badge,"rotation_degrees",angle,.10)

func seed_preview(count: int) -> void:
	if not app.test_mode or current!=6 or busy: return
	preview_ids.clear()
	for offset in clampi(count,1,5):preview_ids.append(3+offset)
	refresh()

func _input(event: InputEvent) -> void:
	if not app.test_mode or current!=6 or not is_visible_in_tree() or app.modal or busy:return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:return
		var id: int = event.index if event is InputEventScreenTouch else -1
		if not event.pressed and id==hold_id:hold_id=-2
		elif event.pressed and hold_id==-2 and title.get_global_rect().has_point(event.position):
			hold_id=id
			hold_at=event.position
			hold_elapsed=0.0
	elif (event is InputEventScreenDrag and event.index==hold_id) or (event is InputEventMouseMotion and hold_id==-1):
		if hold_at.distance_to(event.position)>10.0:hold_id=-2
