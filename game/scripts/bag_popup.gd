extends Control

const DESIGN := Vector2(1600,900)
const COLUMNS := 8
const DEFAULT_CAPACITY := 64
const SLOT_SIZE := Vector2(115,125)
const SLOT_GAP := Vector2(13,14)
const LIST_TOP := 113.0
const RAIL_TOP := LIST_TOP + 8.0
const RAIL_HEIGHT := 665.0
const INK := Color("f8f6db")
const ERA_ART := {"stone_age":preload("res://assets/ui/d0031/bag.png")}
const ITEMS := [["wood","목재"],["stone","석재"],["grain","곡식"]]
var app: Node
var layout: Control
var close_layer: Control
var viewport: Control
var grid: GridContainer
var thumb: Panel
var count: Label
var amounts: Dictionary = {}
var offset := 0.0
var max_offset := 0.0
var pointer := -2
var drag_origin := Vector2.ZERO
var drag_offset := 0.0
var dragging := false
var entrance_offset := 0.0
var capacity := DEFAULT_CAPACITY

func _init(owner: Node) -> void:
	app=owner

func _ready() -> void:
	name="BagPanel"
	capacity = maxi(ITEMS.size(), int(ProjectSettings.get_setting("roxhistory/inventory/capacity", DEFAULT_CAPACITY)))
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scenery: TextureRect = app.picture(self,ERA_ART["stone_age"],Rect2())
	scenery.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade(Color("132b20"),[0.0,.59,.73,.91,1.0],[.74,.56,.19,0.0,0.0])
	shade(Color("10190f"),[0.0,.55,.84,1.0],[0.0,0.0,.10,.10])
	layout=Control.new()
	layout.size=DESIGN
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	var back: DemoButton=app.button(layout,"",app.close_modal)
	back.name="BagBack"
	back.custom_minimum_size=Vector2.ZERO
	back.position=Vector2.ONE*SharedPopupArt.INSET
	back.size=Vector2(78,65)
	for state in ["normal","hover","pressed","focus","disabled"]:
		back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(back,preload("res://assets/ui/d0030/bag-back-gold@4x.png"),Rect2(13,12,48.96,42.33))
	FigmaArt.text(layout,"가방",Rect2(173,SharedPopupArt.INSET,250,60),50,FigmaArt.TITLE,INK,false)
	count=FigmaArt.text(layout,"",Rect2(983,59,96,28),23,FigmaArt.NOTO,Color("f0e6be"))
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var left := SharedPopupArt.INSET
	panel(layout,Rect2(left,97,1018,1),style(Color(.91,.85,.64,.36)))
	panel(layout,Rect2(left,805,1018,1),style(Color(.91,.85,.64,.22)))
	count.position.x = left+915
	viewport=Control.new()
	viewport.clip_contents=true
	viewport.position=Vector2(left,LIST_TOP)
	viewport.size=Vector2(1011,SLOT_SIZE.y*5+SLOT_GAP.y*4)
	viewport.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layout.add_child(viewport)
	grid=GridContainer.new()
	grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
	grid.columns=COLUMNS
	grid.add_theme_constant_override("h_separation",int(SLOT_GAP.x))
	grid.add_theme_constant_override("v_separation",int(SLOT_GAP.y))
	viewport.add_child(grid)
	var empty := style(Color(.14,.20,.16,.68),Color(.61,.66,.52,.60),10)
	var occupied := style(Color(.26,.31,.23,.94),Color(.84,.83,.63,.82),10)
	for i in capacity:
		var slot := panel(grid,Rect2(Vector2.ZERO,SLOT_SIZE),occupied if i<ITEMS.size() else empty)
		slot.name="BagSlot%d"%(i+1)
		slot.custom_minimum_size=SLOT_SIZE
		if i>=ITEMS.size():continue
		var key: String=ITEMS[i][0]
		var icon := PlayChrome.CORN_ICON if key=="grain" else DemoArt.icon(key)
		app.picture(slot,icon,Rect2(10.3,15,94.4,94.4))
		FigmaArt.text(slot,ITEMS[i][1],Rect2(8,0,99,25),18,FigmaArt.NOTO,INK,false)
		var amount := FigmaArt.text(slot,"",Rect2(6,98,101,22),19,FigmaArt.NOTO,INK,false)
		amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		amounts[key]=amount
	var rows := ceili(float(capacity)/COLUMNS)
	var content_height := rows*SLOT_SIZE.y+(rows-1)*SLOT_GAP.y
	max_offset = maxf(0,content_height-viewport.size.y)
	if max_offset>0:
		panel(layout,Rect2(left+1034,RAIL_TOP,3,RAIL_HEIGHT),style(Color(.06,.10,.07,.66),Color(.84,.82,.63,.25),2))
		thumb=panel(layout,Rect2(left+1032.5,RAIL_TOP,6,RAIL_HEIGHT*viewport.size.y/content_height),style(Color(.90,.85,.60,.79),Color.TRANSPARENT,3))
	close_layer = Control.new()
	close_layer.size = DESIGN
	close_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(close_layer)
	var content_end := SharedPopupArt.content_rect(DESIGN).end
	var close := QuestRewards.gold_button(app,close_layer,"BagClose",Rect2(content_end-Vector2(171,55),Vector2(171,55)),app.close_modal)
	QuestRewards.caption(app,close,"닫기",Rect2(0,0,171,55),24,QuestRewards.INK)
	resized.connect(fit)
	app.model.changed.connect(update_amounts)
	update_amounts()
	fit()
	if not app.reduced_ui_motion():
		layout.modulate.a = 0.0
		close_layer.modulate.a = 0.0
		entrance_offset = 82.0
		fit()
		var entrance := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		entrance.tween_property(layout,"modulate:a",1.0,.22).set_delay(.10)
		entrance.tween_property(close_layer,"modulate:a",1.0,.22).set_delay(.10)
		entrance.tween_method(set_entrance_offset,82.0,0.0,.28).set_delay(.10)

func set_entrance_offset(pixels: float) -> void:
	entrance_offset = pixels
	fit()

func style(fill: Color, rim := Color.TRANSPARENT, radius := 0) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=fill
	result.border_color=rim
	result.set_border_width_all(1 if rim.a>0 else 0)
	result.set_corner_radius_all(radius)
	return result

func panel(parent: Control, rect: Rect2, skin: StyleBoxFlat) -> Panel:
	var result := Panel.new()
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result.position=rect.position
	result.size=rect.size
	result.add_theme_stylebox_override("panel",skin)
	parent.add_child(result)
	return result

func shade(tint: Color, stops: Array, opacity: Array) -> void:
	var gradient := Gradient.new()
	var colors := PackedColorArray()
	for alpha in opacity:colors.append(Color(tint.r,tint.g,tint.b,alpha))
	gradient.offsets=PackedFloat32Array(stops)
	gradient.colors=colors
	var texture := GradientTexture2D.new()
	texture.gradient=gradient
	texture.fill_to=Vector2(1,0)
	var layer: TextureRect=app.picture(self,texture,Rect2())
	layer.stretch_mode=TextureRect.STRETCH_SCALE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fit() -> void:
	var region := size-Vector2(app.safe)*2.0
	var factor := maxf(.1,minf(region.x/DESIGN.x,region.y/DESIGN.y))
	var at := (size-DESIGN*factor)*.5
	layout.scale=Vector2.ONE*factor
	layout.position=at - Vector2(entrance_offset*factor,0)
	close_layer.scale = layout.scale
	close_layer.position = at + Vector2(entrance_offset*factor,0)

func update_amounts() -> void:
	for resource in amounts:
		amounts[resource].text=str(int(app.model.state.get(resource,app.model.state.get("tokens",0) if resource=="grain" else 0)))
	count.text="%d/%d"%[amounts.size(),capacity]

func scroll_to(next: float) -> void:
	offset=clampf(next,0,max_offset)
	grid.position.y=-offset
	if is_instance_valid(thumb):
		thumb.position.y=RAIL_TOP+(RAIL_HEIGHT-thumb.size.y)*offset/max_offset

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not app.modal or not is_instance_valid(app.overlay) or not app.overlay.is_ancestor_of(self):return
	var touch := event is InputEventScreenTouch
	var mouse := event is InputEventMouseButton
	var move := event is InputEventScreenDrag or event is InputEventMouseMotion
	if not touch and not mouse and not move:return
	var at: Vector2=event.position
	if mouse and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed and viewport.get_global_rect().has_point(at):
			scroll_to(offset+65.0*(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1))
			get_viewport().set_input_as_handled()
		return
	if mouse and event.button_index!=MOUSE_BUTTON_LEFT:return
	var id: int=event.index if touch or event is InputEventScreenDrag else -1
	if move:
		if pointer!=id:return
		dragging=dragging or absf(at.y-drag_origin.y)>6.0
		if dragging:scroll_to(drag_offset-(at.y-drag_origin.y)/layout.scale.y)
	elif event.pressed:
		if pointer!=-2 or not viewport.get_global_rect().has_point(at):return
		pointer=id
		drag_origin=at
		drag_offset=offset
		dragging=false
	elif pointer==id:
		pointer=-2
	else:return
	get_viewport().set_input_as_handled()
