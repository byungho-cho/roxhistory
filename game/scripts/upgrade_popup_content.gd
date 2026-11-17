extends Control

const UPDATE_ART := "res://assets/ui/d0020/"
const FINISH_ART := "res://assets/ui/d0021/"
const DESIGN_SIZE := Vector2(652,346)
var app: Node
var kind: String
var current: int
var costs: Dictionary
var confirm: Callable
var art: Control
var unsupported_notice: Label
var notice_fade: Tween
var shortage_items: Dictionary = {}
var shortage_labels: Dictionary = {}
var shortage_motion: Tween
var submission_pending := false
const COST_INK := Color("553820")
const SHORTAGE_INK := Color("a32a20")

func _init(owner: Node, building_kind: String, level: int, cost: Dictionary, callback: Callable) -> void:
	app=owner;kind=building_kind;current=level;costs=cost;confirm=callback
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL

func _ready() -> void:
	art=Control.new()
	art.size=DESIGN_SIZE
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(art)
	resized.connect(fit)
	fit()
	rule(Rect2(0,0,652,1))
	rule(Rect2(284,20,1,239))
	rule(Rect2(0,277,652,1))
	var shade := Gradient.new()
	shade.colors=PackedColorArray([Color(.29,.20,.13,.25),Color(.29,.20,.13,0)])
	var texture := GradientTexture2D.new()
	texture.gradient=shade
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(1,.5)
	app.picture(art,texture,Rect2(46,195,191,34)).stretch_mode=TextureRect.STRETCH_SCALE
	var sparkle := Gradient.new()
	sparkle.colors=PackedColorArray([Color(1,.95,.64,.76),Color(1,.77,.30,0)])
	sparkle.add_point(.45,Color(1,.77,.30,.34))
	var ray := GradientTexture2D.new()
	ray.gradient=sparkle
	ray.fill=GradientTexture2D.FILL_RADIAL
	ray.fill_from=Vector2(.5,.5)
	ray.fill_to=Vector2(1,.5)
	var glow_art: TextureRect=app.picture(art,ray,Rect2(27,55,230,175))
	glow_art.stretch_mode=TextureRect.STRETCH_SCALE
	glow_art.modulate.a=.52
	var fade := create_tween()
	fade.tween_property(glow_art,"modulate:a",1.0,.24)
	fade.tween_property(glow_art,"modulate:a",.56,.66)
	var image := BuildingWorkflow.approved_texture(BuildingWorkflow.building_asset_id(kind,current+1))
	if image:
		var cropped: Texture2D = image
		if not image is AtlasTexture:
			var atlas := AtlasTexture.new()
			atlas.atlas=image
			atlas.region=Rect2(image.get_image().get_used_rect())
			atlas.filter_clip=true
			cropped=atlas
		app.picture(art,cropped,Rect2(24,70,236,160))
	FigmaArt.text(art,"Lv. %d" % current,Rect2(308,24,73,38),27,FigmaArt.BODY,Color("796654"),false)
	app.picture(art,preload(FINISH_ART+"upgrade-level-arrow-gold-right.svg"),Rect2(392,28,36,36))
	FigmaArt.text(art,str(current+1),Rect2(445,24,48,40),31,FigmaArt.BODY,Color("47240e"),false)
	var detail := ""
	match kind:
		"chief":
			if current < DemoConfig.MAX_RESIDENT_HOMES:
				detail = "건설 가능 움집"
		"hut":
			var limits := [1,2,3,5]
			detail = "주민 수용  %d → %d" % [limits[current-1],limits[current]]
		"wood_store","stone_store":
			detail = "저장 한도  %d → %d\n주민 배정  %d → %d" % [ResourceStorage.LIMITS[current-1],ResourceStorage.LIMITS[current],current,current+1]
	var unlocks: Array[String] = []
	if kind=="chief":
		for building: String in BuildingRules.REQUIRED_HQ:
			if BuildingRules.REQUIRED_HQ[building]==current+1: unlocks.append(building)
	if not detail.is_empty() or not unlocks.is_empty():
		FigmaArt.text(art,"업그레이드 효과",Rect2(308,82,242,21),17,FigmaArt.BODY,Color("553820"),false)
		var group := ColorRect.new()
		group.color=Color(.54,.37,.20,.12)
		group.position=Vector2(304,122)
		group.size=Vector2(348,(58.0 if not detail.is_empty() else 0.0)+(81.0 if not unlocks.is_empty() else 0.0))
		group.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art.add_child(group)
		if not detail.is_empty():
			FigmaArt.text(group,detail,Rect2(14,0,320,58),17,FigmaArt.BODY,Color("553820"),false)
		if kind=="chief" and not detail.is_empty():
			var capacity := FigmaArt.text(group,"%d채 → %d채"%[current,current+1],Rect2(230,0,104,58),17,FigmaArt.BODY,Color("553820"),false)
			capacity.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		if not unlocks.is_empty():
			var y := 8.0
			if not detail.is_empty():
				rule(Rect2(14,58,320,1),group)
				y += 58.0
			FigmaArt.text(group,"신규 건설",Rect2(14,y,244,19),17,FigmaArt.BODY,Color("553820"),false)
			for i in unlocks.size():
				app.picture(group,BuildingVisuals.texture(unlocks[i],1),Rect2(14+i*47,y+29,40,38))
	var cost_row := HBoxContainer.new()
	cost_row.position = Vector2(0,238)
	cost_row.size = Vector2(284,32)
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override("separation",18)
	art.add_child(cost_row)
	for resource in ["wood","stone"]:
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_child(item)
		var icon: TextureRect = app.picture(item,DemoArt.icon(resource),Rect2(0,0,32,32))
		icon.custom_minimum_size = Vector2(32,32)
		var amount := FigmaArt.text(item,str(costs.get(resource,0)),Rect2(0,0,0,32),18,FigmaArt.BODY,Color("553820"),false)
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_shortage_art(item,amount,resource)
	var seconds := int(app.model.building_duration(current+1,kind))
	var time := "%d초" % seconds if seconds<60 else "%d분" % (seconds/60)
	action(Rect2(270,300,192,44),"즉시 업그레이드","3",preload(UPDATE_ART+"diamond-premium-illustrated.png"),preload(FINISH_ART+"popup-button-stone-gray-disabled-192x44.svg"),true)
	action(Rect2(486,300,166,44),"업그레이드",time,preload(UPDATE_ART+"hourglass-teal-amber-illustrated.png"),preload(FINISH_ART+"popup-button-gold-volume-166x44.svg"),false)
	unsupported_notice=FigmaArt.text(art,"미지원",Rect2(251,249,150,27),16,FigmaArt.BODY,Color("fff4d6"))
	unsupported_notice.add_theme_color_override("font_outline_color",Color("503016"))
	unsupported_notice.add_theme_constant_override("outline_size",8)
	unsupported_notice.modulate.a=0.0
	refresh_cost_ink()
	app.model.changed.connect(refresh_cost_ink)

func add_shortage_art(item: Control, amount: Label, resource: String) -> void:
	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font",FigmaArt.BODY)
	badge.add_theme_font_size_override("font_size",13)
	badge.add_theme_color_override("font_color",Color("fff2d4"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("922c24df")
	fill.set_corner_radius_all(5)
	badge.add_theme_stylebox_override("normal",fill)
	art.add_child(badge)
	var align := func():
		var at: Vector2 = art.get_global_transform().affine_inverse()*item.get_global_transform().origin
		badge.position = at+Vector2(0,-22)
		badge.set_meta("rest_x",badge.position.x)
		badge.size = Vector2(item.size.x,18)
	item.item_rect_changed.connect(align)
	align.call_deferred()
	shortage_items[resource] = amount
	shortage_labels[resource] = badge

func resource_deficit(resource: String) -> int:
	return int(costs.get(resource,0))-int(app.model.state.get(resource,0))

func refresh_cost_ink() -> void:
	if submission_pending or not can_process(): return
	for resource: String in shortage_items:
		var amount: Label = shortage_items[resource]
		var missing := resource_deficit(resource)
		var required := int(costs.get(resource,0))
		amount.text = "%d/%d"%[required-missing,required] if missing>0 else str(required)
		amount.add_theme_color_override("font_color",SHORTAGE_INK if missing>0 else COST_INK)
		var badge: Label = shortage_labels[resource]
		badge.text = "%d 부족"%missing if missing>0 else ""
		badge.visible = missing>0

func play_shortage() -> bool:
	refresh_cost_ink()
	if resource_deficit("wood")<=0 and resource_deficit("stone")<=0: return false
	app.audio.cue("upgrade_insufficient")
	if app.reduced_ui_motion(): return true
	if shortage_motion and shortage_motion.is_valid(): shortage_motion.kill()
	shortage_motion = create_tween().set_parallel()
	for resource: String in shortage_labels:
		var badge: Label = shortage_labels[resource]
		var rest: float = badge.get_meta("rest_x",badge.position.x)
		badge.position.x = rest
		if badge.visible:
			var shake := func(phase: float): badge.position.x = rest + sin(phase*TAU)*4.0
			shortage_motion.tween_method(shake,0.0,1.0,.20)
	return true

func request_upgrade() -> void:
	if submission_pending or not can_process() or play_shortage(): return
	submission_pending = true
	if not confirm.call():
		submission_pending = false
		refresh_cost_ink()

func rule(rect: Rect2, parent: Control = null) -> void:
	var line := ColorRect.new()
	line.position=rect.position
	line.size=rect.size
	line.color=Color(.55,.38,.23,.38)
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(parent if parent else art).add_child(line)

func show_unsupported() -> void:
	if notice_fade and notice_fade.is_valid():notice_fade.kill()
	unsupported_notice.modulate.a=1.0
	notice_fade=create_tween()
	notice_fade.tween_property(unsupported_notice,"modulate:a",0.0,.2).set_delay(1.1)

func fit() -> void:
	var factor := minf(1.0,minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y))
	art.scale=Vector2.ONE*factor
	art.position=(size-art.size*factor)*.5

func action(rect: Rect2, title: String, value: String, icon: Texture2D, background: Texture2D, locked: bool) -> void:
	var button: DemoButton=app.button(art,"",request_upgrade if not locked else show_unsupported,false,"","ui" if locked else "")
	button.name="InstantUpgrade" if locked else "ConfirmUpgrade"
	button.custom_minimum_size=Vector2.ZERO
	button.position=rect.position
	button.size=rect.size
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(button,background,Rect2(Vector2.ZERO,rect.size))
	var icon_x := 20.0 if locked else 15.0
	app.picture(button,icon,Rect2(icon_x,9,25,25))
	var ink := Color("141a20") if locked else Color.WHITE
	FigmaArt.text(button,value,Rect2(icon_x+30,0,34,42),14,FigmaArt.BODY,ink,false)
	FigmaArt.text(button,title,Rect2(78,0,rect.size.x-86,42),15,FigmaArt.BODY,ink,false)
