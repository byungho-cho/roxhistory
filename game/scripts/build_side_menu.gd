class_name BuildSideMenu
extends Control

# Left-to-right layout; the newest opening starts at the right.
const KINDS := ["outpost","shrine","hearth","training","stone_store","wood_store","farm","hut"]
const FILTERS := ["open","locked"]
const FILTER_SIZE := Vector2(58,58)
const FILTER_ICON_SIZE := Vector2(45,45) * 0.7
const CARD_ART := {
	"hut":[preload("res://assets/ui/d0025/hut-normal-body.png"),Rect2(67.34,56.03,81.31,69.89)],
	"farm":[preload("res://assets/ui/d0025/farm-normal-body.png"),Rect2(58.61,70.78,98.78,59.14)],
	"wood_store":[preload("res://assets/ui/d0025/sawmill-normal-body.png"),Rect2(59.29,65.98,107.48,70.06)],
	"stone_store":[preload("res://assets/ui/d0025/quarry-normal-body.png"),Rect2(56.26,61.70,103.49,69.22)],
	"training":[preload("res://assets/ui/d0025/training-normal-body.png"),Rect2(77.76,45.30,60.48,69.22)],
	"hearth":[preload("res://assets/ui/d0025/hearth-normal-body.png"),Rect2(70,77,75,50)],
	"shrine":[preload("res://assets/ui/d0025/shrine-normal-body.png"),Rect2(77.09,51.03,61.82,69.40)],
	"outpost":[preload("res://assets/ui/d0025/outpost-normal-body.png"),Rect2(58.61,53,98.78,73.92)],
}
const MENU_ICONS:={
	"farm":preload("res://assets/ui/construction-side-v006/menu-farm.png"),
	"hearth":preload("res://assets/ui/construction-side-v006/menu-hearth.png"),
	"wood_store":preload("res://assets/ui/construction-side-v006/menu-sawmill.png"),
	"shrine":preload("res://assets/ui/construction-side-v006/menu-shrine.png"),
	"stone_store":preload("res://assets/ui/construction-side-v006/menu-stoneworks.png"),
}
const TILE_SIZE := Vector2(162,188)
const OUTPOST_END_PADDING := 90.0
const ART_SCALE := .9
const BUILD_GAP := 4.0
const DRAG_THRESHOLD := 10.0
const PAPER := preload("res://assets/ui/d0022/scroll-open-paper.png")
const ROLL := preload("res://assets/ui/d0022/scroll-right-roll.png")
const INK := Color("332211")
var app: Node
var entries: Dictionary = {}
var filters: Dictionary = {}
var visible_kinds: Array = KINDS
var selected_filter := ""
var shade: TextureRect
var paper_clip: Control
var paper: TextureRect
var roller: TextureRect
var clip: Control
var content: Control
var message: Label
var gray: ShaderMaterial
var hut: DemoButton
var outpost_button: DemoButton
var scroll_offset := 0.0
var visible_slots := 5
var pointer := -2
var press_at := Vector2.ZERO
var last_at := Vector2.ZERO
var dragged := false
var pressed_kind := ""
var pressed_filter := ""
var needs_refresh := true
var transition: Tween
var notice: Tween
var layout_view := Vector2.ZERO
var paper_rect := Rect2()
var reveal := 1.0:
	set(value):
		reveal = value
		layout_paper()

func _init(owner_app: Node) -> void:
	app = owner_app

func _ready() -> void:
	name = "BuildSideMenu"
	z_index = 44
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()
	var darkness := Gradient.new()
	darkness.colors = PackedColorArray([Color(0,0,0,.18),Color(0,0,0,.54)])
	darkness.set_offset(1,.18)
	var dimmer := GradientTexture2D.new()
	dimmer.gradient = darkness
	dimmer.fill_to = Vector2(0,1)
	shade = app.picture(self,dimmer,Rect2())
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	paper_clip = layer(self)
	paper_clip.clip_contents = true
	paper = app.picture(paper_clip,IntegratedMenuArt.trimmed(PAPER,Rect2(10,85,2150,552)),Rect2())
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	clip = layer(self)
	clip.clip_contents = true
	content = layer(clip)
	var grayscale := Shader.new()
	grayscale.code = "shader_type canvas_item; void fragment(){ float gray = dot(COLOR.rgb,vec3(0.299,0.587,0.114)); COLOR.rgb=vec3(gray); }"
	gray = ShaderMaterial.new()
	gray.shader = grayscale
	for kind in KINDS:
		add_card(kind)
	hut = entries.hut
	outpost_button = entries.outpost
	roller = app.picture(self,IntegratedMenuArt.trimmed(ROLL,Rect2(65,34,640,1986)),Rect2())
	for id in FILTERS:
		var button: DemoButton = app.button(self,"",set_filter.bind(id))
		button.custom_minimum_size = FILTER_SIZE
		button.mouse_filter = MOUSE_FILTER_IGNORE
		filters[id] = button
		var icon: Texture2D = preload("res://assets/ui/d0025/filter-open-gold.svg") if id=="open" else preload("res://assets/ui/d0025/filter-locked-neutral.png")
		app.picture(button,icon,Rect2((FILTER_SIZE-FILTER_ICON_SIZE)*.5,FILTER_ICON_SIZE))
	message = FigmaArt.text(self,"",Rect2(),16,FigmaArt.BODY,Color("fff3d4"))
	message.add_theme_color_override("font_outline_color",Color("3e2a17"))
	message.add_theme_constant_override("outline_size",8)
	message.hide()
	visibility_changed.connect(on_visibility)
	app.model.changed.connect(func(): needs_refresh=true)

func layer(parent: Control) -> Control:
	var control := Control.new()
	control.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control

func add_card(kind: String) -> void:
	var card: DemoButton = app.button(content,"",select_kind.bind(kind))
	card.name = kind.capitalize()
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.set_meta("integrated_art",true)
	card.custom_minimum_size = TILE_SIZE
	card.size = TILE_SIZE
	for state in ["normal","hover","pressed","disabled","focus"]:
		card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var composition := layer(card)
	composition.name = "Composition"
	var divider := ColorRect.new()
	divider.color = Color(.43,.27,.11,.27)
	divider.position = Vector2(0,22)
	divider.size = Vector2(1,156)
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	composition.add_child(divider)
	var art := layer(composition)
	art.name = "Artwork"
	var cut: Array = AssetCatalog.entry("GROUND-PAD-L1").alpha_bounds
	var pad := IntegratedMenuArt.trimmed(AssetCatalog.texture("GROUND-PAD-L1"),Rect2(cut[0],cut[1],cut[2],cut[3]))
	app.picture(art,pad,Rect2(14,50,134,66))
	var source: Array = CARD_ART[kind]
	var authored: Rect2 = source[1]
	# The exported body is already resized in the 216×160 design composition.
	var body_rect := Rect2(authored.position*.75+Vector2(0,3.95),authored.size*.75)
	app.picture(art,source[0],body_rect).stretch_mode = TextureRect.STRETCH_SCALE
	var name_label := FigmaArt.text(composition,"움집" if kind=="hut" else BuildingWorkflow.building_name(kind),Rect2(0,115,162,34),23,FigmaArt.BODY,INK)
	name_label.name = "MenuLabel"
	var cost := layer(composition)
	cost.name = "Cost"
	var values: Dictionary = app.model.building_cost(kind,1)
	for i in 2:
		var resource := ["wood","stone"][i] as String
		var x := 27.0 + i*69.0
		app.picture(cost,DemoArt.icon(resource),Rect2(x,156,21,21))
		FigmaArt.text(cost,str(values.get(resource,0)),Rect2(x+23,154,42,24),14,FigmaArt.BODY,INK,false)
	var restriction := layer(composition)
	restriction.name = "Restriction"
	var lock: TextureRect = app.picture(restriction,IntegratedMenuArt.lock_icon(),Rect2(8,158,15,17))
	lock.name = "Locked"
	var caption := FigmaArt.text(restriction,"",Rect2(26,151,130,34),12,FigmaArt.BODY,INK,false)
	caption.name = "Reason"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.enable_art_feedback()
	entries[kind] = card

func max_scroll() -> float:
	return maxf(0.0,content.size.x-clip.size.x)

func layout_scroll() -> void:
	scroll_offset = clampf(scroll_offset,0,max_scroll())
	content.position.x = clip.size.x-content.size.x if max_scroll()==0.0 else -scroll_offset

func layout_paper() -> void:
	if not is_instance_valid(paper_clip): return
	var width := paper_rect.size.x*reveal
	paper_clip.position = Vector2(paper_rect.end.x-width,paper_rect.position.y)
	paper_clip.size = Vector2(width,paper_rect.size.y)
	paper.position = Vector2(width-paper_rect.size.x,0)
	paper.size = paper_rect.size

func refresh() -> void:
	needs_refresh = false
	layout_view = Vector2(app.w,app.h)
	size = layout_view
	var scale_factor := clampf(size.y/540.0,.8,1.0)
	var right: float = size.x-maxf(18.0,app.safe.x)
	var bottom: float = size.y-maxf(5.0,app.safe.y*.25)
	var roll_size := Vector2(97,267)*scale_factor
	roller.position = Vector2(right-roll_size.x,bottom-roll_size.y)
	roller.size = roll_size
	var top := bottom-238.0*scale_factor
	paper_rect = Rect2(Vector2(-22,top),Vector2(right-roll_size.x*.62+22,223.0*scale_factor))
	layout_paper()
	shade.size = size
	clip.position = Vector2(0,top+1.0)
	clip.size = Vector2(roller.position.x,194.0*scale_factor)
	visible_slots = maxi(1,ceili(clip.size.x/(TILE_SIZE.x*scale_factor)))
	var locked_by_kind := {}
	visible_kinds = []
	for kind in KINDS:
		var locked: bool = not app.model.building_availability_requirement(kind).is_empty()
		locked_by_kind[kind] = locked
		if selected_filter.is_empty() or locked==(selected_filter=="locked"):
			visible_kinds.append(kind)
	var end_padding := OUTPOST_END_PADDING if "outpost" in visible_kinds else 0.0
	content.size = Vector2((end_padding+TILE_SIZE.x*visible_kinds.size())*scale_factor,clip.size.y)
	content.scale = Vector2.ONE*scale_factor
	for kind in KINDS:
		var card: DemoButton = entries[kind]
		card.visible = kind in visible_kinds
		if not card.visible: continue
		card.position = Vector2(end_padding+visible_kinds.find(kind)*TILE_SIZE.x,0)
		var art: Control = card.art_feedback.get_node("Composition/Artwork")
		var locked: bool = locked_by_kind[kind]
		var reason: String = app.building_workflow.build_block_reason(kind,false)
		# Display the campaign level even when another prerequisite is also unmet.
		if locked and app.model.chief_level()<int(BuildingRules.REQUIRED_HQ.get(kind,0)):
			reason = "촌장집 Lv.%d에서 해금"%int(BuildingRules.REQUIRED_HQ[kind])
		art.material = gray if locked else null
		for image in art.get_children():
			image.material = art.material
		card.art_feedback.get_node("Composition/Cost").visible = reason.is_empty()
		var restriction: Control = card.art_feedback.get_node("Composition/Restriction")
		restriction.visible = not reason.is_empty()
		restriction.get_node("Locked").visible = locked
		restriction.get_node("Reason").text = reason
	for i in FILTERS.size():
		var id: String = FILTERS[i]
		var button: DemoButton = filters[id]
		button.position = roller.position+Vector2((97-FILTER_SIZE.x)*.5,62+i*77)*scale_factor
		button.scale = Vector2.ONE*scale_factor
		button.size = FILTER_SIZE
		var style := StyleBoxFlat.new()
		var selected := selected_filter==id
		style.bg_color = Color("183c79") if selected else Color(.41,.23,.09,.05)
		style.border_color = Color("5678ad") if selected else Color(.42,.24,.10,.25)
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		for state in ["normal","hover","pressed","focus"]:
			button.add_theme_stylebox_override(state,style)
	message.position = Vector2(0,top-45)
	message.size = Vector2(size.x,40)
	layout_scroll()

func on_visibility() -> void:
	cancel_pointer()
	if visible:
		selected_filter = ""
		visible_kinds = KINDS
		refresh()
		scroll_offset = max_scroll()
		layout_scroll()
		play_open()
	else:
		finish_open()
		if is_instance_valid(message): message.hide()

func toggle_animated() -> void:
	visible = not visible

func play_open() -> void:
	reveal = 0.0
	transition = create_tween().set_parallel(true)
	transition.tween_property(self,"reveal",1.0,.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	clip.modulate.a = 0.0
	transition.tween_property(clip,"modulate:a",1.0,.08).set_delay(.17)
	for i in mini(visible_slots,visible_kinds.size()):
		var kind: String = visible_kinds[visible_kinds.size()-1-i]
		var art: Control = entries[kind].art_feedback.get_node("Composition/Artwork")
		art.position.y = -20
		art.modulate.a = 0.0
		transition.tween_property(art,"position:y",0.0,.20).set_delay(.18+i*.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		transition.tween_property(art,"modulate:a",1.0,.15).set_delay(.18+i*.04)
	transition.finished.connect(func(): transition=null)

func finish_open() -> void:
	if transition:transition.kill()
	transition = null
	reveal = 1.0
	if not is_instance_valid(clip):return
	clip.modulate.a = 1.0
	for card in entries.values():
		var art: Control = card.art_feedback.get_node("Composition/Artwork")
		art.position.y = 0.0
		art.modulate.a = 1.0

func set_filter(id: String) -> void:
	finish_open()
	selected_filter = "" if selected_filter==id else id
	message.hide()
	refresh()
	scroll_offset = max_scroll()
	layout_scroll()

func scroll_by(amount: float) -> void:
	finish_open()
	scroll_offset += amount
	layout_scroll()

func contains_point(at: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(at)

func kind_at(at: Vector2) -> String:
	if not clip.get_global_rect().has_point(at):return ""
	for kind in visible_kinds:
		if entries[kind].get_global_rect().has_point(at):return kind
	return ""

func filter_at(at: Vector2) -> String:
	for id in filters:
		if filters[id].get_global_rect().has_point(at):return id
	return ""

func on_scroll_art(at: Vector2) -> bool:
	return paper_rect.has_point(at-global_position) or roller.get_global_rect().has_point(at) or clip.get_global_rect().has_point(at)

func cancel_pointer() -> void:
	for button in entries.values():button.clear()
	pointer = -2
	pressed_kind = ""
	pressed_filter = ""
	dragged = false

func begin_pointer(at: Vector2, id: int) -> void:
	pointer=id
	press_at=at
	last_at=at
	dragged=false
	pressed_kind=kind_at(at)
	pressed_filter=filter_at(at)
	if not pressed_kind.is_empty(): entries[pressed_kind].finger=0

func move_pointer(at: Vector2) -> void:
	if not dragged and at.distance_to(press_at)>DRAG_THRESHOLD:
		dragged=true
		if not pressed_kind.is_empty(): entries[pressed_kind].clear()
		last_at=press_at
	if dragged and clip.get_global_rect().has_point(press_at):
		scroll_by(last_at.x-at.x)
	last_at=at

func end_pointer(at: Vector2, canceled := false) -> void:
	var kind := pressed_kind
	var filter := pressed_filter
	var activate := not canceled and not dragged and press_at.distance_to(at)<=DRAG_THRESHOLD
	var outside := not on_scroll_art(press_at) and not on_scroll_art(at)
	cancel_pointer()
	if not activate:return
	if not filter.is_empty() and filter_at(at)==filter:set_filter(filter)
	elif not kind.is_empty() and kind_at(at)==kind:select_kind(kind)
	elif outside:hide()

func handle_input(event: InputEvent) -> bool:
	if not is_visible_in_tree():return false
	if event is InputEventMouseButton:
		if event.pressed and clip.get_global_rect().has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
			scroll_by(TILE_SIZE.x*(-1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT] else 1))
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and pointer==-2:begin_pointer(event.position,-1)
			elif not event.pressed and pointer==-1:end_pointer(event.position)
		return true
	if event is InputEventMouseMotion:
		if pointer==-1:move_pointer(event.position)
		return true
	if event is InputEventScreenTouch:
		if event.pressed and pointer==-2:begin_pointer(event.position,event.index)
		elif not event.pressed and pointer==event.index:end_pointer(event.position,event.canceled)
		return true
	if event is InputEventScreenDrag:
		if pointer==event.index:move_pointer(event.position)
		return true
	return false

func _process(_delta:float) -> void:
	if not visible:return
	if app.world_map_open or app.modal or not app.application_active:hide();return
	if needs_refresh or layout_view!=Vector2(app.w,app.h):
		var right_offset := max_scroll()-scroll_offset
		refresh()
		scroll_offset=max_scroll()-right_offset
		layout_scroll()

func select_kind(kind:String) -> void:
	cancel_pointer()
	var reason: String = app.building_workflow.build_block_reason(kind,false)
	if not reason.is_empty():
		if not visible:
			app.toast(reason)
			return
		if notice and notice.is_valid():notice.kill()
		message.text=reason
		message.show()
		notice=create_tween()
		notice.tween_callback(message.hide).set_delay(2.4)
		return
	app.cancel_build_preview()
	app.build_kind=kind
	hide()
	app.choosing_plot=true
	app.world.show_candidates=false
	app.world.queue_redraw()
	app.toast("%s을 지을 위치를 눌러 주세요"%BuildingWorkflow.building_name(kind))

func select_hut()->void:select_kind("hut")
func select_outpost()->void:select_kind("outpost")
# Slots from I10000 1295:229. Clip source atlases without modifying approved images.
static func image_slot(parent:Control,file:String,at:Vector2,dimensions:Vector2,relative:Rect2=Rect2(0,0,1,1))->void:
	var clip:=Control.new();clip.position=at;clip.size=dimensions;clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(clip)
	var image:=TextureRect.new();image.texture=load("res://assets/ui/construction-side-v006/"+file+".png");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.position=relative.position*dimensions;image.size=relative.size*dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.add_child(image)
static func install_side_art(button:DemoButton,kind:String)->void:
	button.set_meta("integrated_art",true) # This composition owns its disabled contrast.
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var composition:=Control.new();composition.name="Composition";composition.size=Vector2(180,200);composition.scale=TILE_SIZE/Vector2(180,200);composition.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(composition)
	var pedestal:=TextureRect.new();pedestal.texture=preload("res://assets/ui/brush/action-stone-base@2x.png");pedestal.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	pedestal.position=Vector2(0,82);pedestal.size=Vector2(180,118);pedestal.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(pedestal)
	var art:=Control.new();art.name="Artwork";art.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(art)
	art.scale=Vector2.ONE*ART_SCALE;art.position=Vector2(9,-23)
	match kind:
		"farm","hearth","wood_store","shrine","stone_store":
			var icon:=TextureRect.new()
			# Opaque bounds measured from the approved menu PNGs.
			const ICON_BOUNDS := {
				"farm": Rect2(67,25,1167,1200), "hearth": Rect2(0,17,1270,1208),
				"wood_store": Rect2(0,15,1284,1210), "shrine": Rect2(0,17,1300,1182),
				"stone_store": Rect2(0,20,1294,1179)
			}
			icon.texture=IntegratedMenuArt.trimmed(MENU_ICONS[kind],ICON_BOUNDS[kind])
			icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			var native:=icon.texture.get_size()
			var slot_scale:=composition.scale*art.scale
			var fit:=Vector2(156,131)*slot_scale
			icon.size=native*minf(fit.x/native.x,fit.y/native.y)/slot_scale
			icon.position=Vector2((180-icon.size.x)*.5,155-icon.size.y+6.0/slot_scale.y)
			icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
			art.add_child(icon)
		"outpost":image_slot(art,kind,Vector2(15,33),Vector2(150,150))
		"training":image_slot(art,kind,Vector2(30.18,37.5),Vector2(119.64,137.5),Rect2(-.1084,-.3522,5.2337,1.5178))
		"hut":image_slot(art,kind,Vector2(16.13,48.7),Vector2(143.75,124.301),Rect2(-.25,-.966,6.3882,2.4626))
	var label:=Label.new();label.name="MenuLabel";label.text={"hut":"움집","farm":"농장","training":"훈련소","hearth":"화덕","shrine":"신당","outpost":"초소","stone_store":"채석장","wood_store":"제재소"}[kind];label.theme=DemoArt.theme();label.add_theme_font_size_override("font_size",27);label.add_theme_color_override("font_color",Color("fff2cf"));label.position=Vector2(6.666,137);label.size=Vector2(166.667,45);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(label)
	var locked:=TextureRect.new();locked.name="Locked";locked.texture=IntegratedMenuArt.lock_icon();locked.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;locked.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;locked.position=Vector2(4,137);locked.size=Vector2.ONE*48;locked.modulate.a=.85;locked.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(locked)
	button.enable_art_feedback()
