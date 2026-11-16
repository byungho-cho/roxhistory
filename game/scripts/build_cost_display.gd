class_name BuildCostDisplay
extends Control
## MAT-007: separate brush, resources, values and confirmation.
var amounts:Array[Label]=[]
var icons: Array[TextureRect] = []
var badges: Array[Panel] = []
var rings: Array[Panel] = []
var shortage := Vector2i.ZERO
var flashed := false
var last_cost: Dictionary = {}
var last_owned: Dictionary = {}
var confirm_button:DemoButton
var cancel_button:DemoButton
var button_holder:Control
var brush:TextureRect
var screen_extent:=Vector2(360,64)
const RESOURCE_WIDTH:=208.0
const BUTTON_GAP:=5.5
func _ready()->void:
	name="PlacementCost";mouse_filter=Control.MOUSE_FILTER_STOP;size=Vector2(RESOURCE_WIDTH,64)
	brush=TextureRect.new();brush.name="CostBrush"
	var source:Texture2D=preload("res://assets/ui/v0159/cost-brush.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=Rect2(0,source.get_height()*.1333/1.2667,source.get_width(),source.get_height()/1.2667);crop.filter_clip=true
	brush.texture=crop;brush.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;brush.position=Vector2(0,10);brush.size=Vector2(360,44);brush.modulate.a=.6;brush.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(brush)
	for i in 2:
		var icon:=TextureRect.new();icon.name="Wood" if i==0 else "Stone";icon.texture=DemoArt.icon("wood" if i==0 else "stone");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position=Vector2(12+i*100,15);icon.size=Vector2(34,34);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(icon);icons.append(icon)
		var count:=Label.new();count.name="WoodAmount" if i==0 else "StoneAmount";count.theme=DemoArt.theme();count.position=Vector2(54+i*100,0);count.size=Vector2(53,64);count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;count.clip_text=true
		count.add_theme_font_size_override("font_size",29);count.add_theme_color_override("font_color",Color("fff7d1"));count.add_theme_color_override("font_outline_color",Color("302715"));count.add_theme_constant_override("outline_size",3);count.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(count);amounts.append(count)
		create_feedback(i)
	button_holder=Control.new();button_holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(button_holder)
	cancel_button=HudButtons.create(button_holder,false,func():pass,"CancelPlacement")
	confirm_button=HudButtons.create(button_holder,true,func():pass,"Confirm")
	confirm_button.position=Vector2(HudButtons.DIAMETER+BUTTON_GAP,0)
	for button in [cancel_button,confirm_button]:
		var art:TextureRect=button.art_feedback.get_node("Icon")
		art.position=Vector2.ONE*HudButtons.DIAMETER*.0625
		art.size=Vector2.ONE*HudButtons.DIAMETER*.875
	confirm_button.set_meta("semantic_text","확인")
	cancel_button.set_meta("semantic_text","배치 취소")
	set_world_scale(1.0)
func set_world_scale(zoom:float)->void:
	var factor:=maxf(.64,HudButtons.world_scale(zoom))
	scale=Vector2.ONE*factor
	button_holder.scale=Vector2.ONE/factor
	button_holder.position=Vector2(RESOURCE_WIDTH+BUTTON_GAP/factor,(64-HudButtons.DIAMETER/factor)*.5)
	screen_extent=Vector2(RESOURCE_WIDTH*factor+2*(HudButtons.DIAMETER+BUTTON_GAP),maxf(64*factor,HudButtons.DIAMETER))
	brush.size.x=screen_extent.x/factor
func update_cost(cost:Dictionary, owned: Dictionary = {})->void:
	if cost == last_cost and owned == last_owned: return
	last_cost = cost.duplicate()
	last_owned = owned.duplicate()
	for i in amounts.size():
		amounts[i].text=str(int(cost.get("wood" if i==0 else "stone",0)))
		amounts[i].add_theme_font_size_override("font_size",29)
		var font:Font=amounts[i].get_theme_font("font")
		var font_size:int=amounts[i].get_theme_font_size("font_size")
		while font_size>8 and font.get_string_size(amounts[i].text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>amounts[i].size.x:
			font_size-=1
		amounts[i].add_theme_font_size_override("font_size",font_size)

	if not owned.is_empty(): update_shortage(cost,owned)

func update_shortage(cost: Dictionary, owned: Dictionary) -> void:
	var key := Vector2i.ZERO
	for i in 2:
		var resource := "wood" if i == 0 else "stone"
		var required := int(cost.get(resource,0))
		var available := int(owned.get(resource,0))
		var missing := maxi(0,required-available)
		key[i] = missing
		badges[i].visible = missing > 0
		if missing > 0:
			icons[i].position = Vector2(5+i*100,17)
			icons[i].size = Vector2(23,23)
			var title := "목재" if i == 0 else "석재"
			amounts[i].text = "%s %d/%d"%[title,available,required]
			amounts[i].position = Vector2(29+i*100,5)
			amounts[i].size = Vector2(72,28)
			fit_amount(amounts[i],15)
			badges[i].get_node("Count").text = "%d 부족"%missing
		else:
			icons[i].position = Vector2(12+i*100,15)
			icons[i].size = Vector2(34,34)
			amounts[i].position = Vector2(54+i*100,0)
			amounts[i].size = Vector2(53,64)
			fit_amount(amounts[i],29)
	if key != shortage:
		flashed = false
		for ring in rings: stop_ring(ring)
	shortage = key

func fit_amount(label: Label, maximum: int) -> void:
	var font := label.get_theme_font("font")
	var point := maximum
	while point>8 and font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>label.size.x:
		point-=1
	label.add_theme_font_size_override("font_size",point)

func flash_shortage() -> void:
	if flashed or shortage == Vector2i.ZERO: return
	flashed = true
	for i in 2:
		if shortage[i] <= 0: continue
		var ring := rings[i]
		ring.scale = Vector2.ONE*.95
		ring.modulate.a = .95
		ring.show()
		var motion := ring.create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		motion.tween_property(ring,"scale",Vector2(1.10,1.18),.44)
		motion.tween_property(ring,"modulate:a",0.0,.44)
		motion.chain().tween_callback(ring.hide)
		ring.set_meta("motion",motion)

func stop_ring(ring: Panel) -> void:
	var motion := ring.get_meta("motion") as Tween if ring.has_meta("motion") else null
	if motion and motion.is_valid(): motion.kill()
	ring.hide()

func clear_shortage() -> void:
	last_cost.clear()
	last_owned.clear()
	flashed = false
	shortage = Vector2i.ZERO
	for i in 2:
		badges[i].hide()
		stop_ring(rings[i])

func create_feedback(i: int) -> void:
	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(32+i*100,34)
	badge.size = Vector2(66,21)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("743a2f")
	fill.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel",fill)
	add_child(badge)
	var count := Label.new()
	count.name = "Count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.theme = DemoArt.theme()
	count.add_theme_font_size_override("font_size",12)
	count.add_theme_color_override("font_color",Color("fff1dc"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(count)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.hide()
	badges.append(badge)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = Vector2(2+i*100,7)
	ring.size = Vector2(98,52)
	ring.pivot_offset = ring.size*.5
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color.TRANSPARENT
	highlight.border_color = Color("ef5b50")
	highlight.set_border_width_all(2)
	highlight.set_corner_radius_all(10)
	ring.add_theme_stylebox_override("panel",highlight)
	add_child(ring)
	ring.hide()
	rings.append(ring)
