extends Control

const ROOT := "res://assets/ui/d0019/"
const UPDATE_ART := "res://assets/ui/d0020/"
const DESIGN_SIZE := Vector2(652,346)
var app: Node
var kind: String
var current: int
var costs: Dictionary
var confirm: Callable
var art: Control
var unsupported_notice: Label
var notice_fade: Tween

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
	sparkle.colors=PackedColorArray([Color(1,.75,.22,.63),Color(1,.75,.22,0)])
	var ray := GradientTexture2D.new()
	ray.gradient=sparkle
	ray.fill=GradientTexture2D.FILL_RADIAL
	ray.fill_from=Vector2(.5,.5)
	ray.fill_to=Vector2(1,.5)
	var glow_art: TextureRect=app.picture(art,ray,Rect2(67,132,148,80))
	glow_art.stretch_mode=TextureRect.STRETCH_SCALE
	glow_art.modulate.a=0
	var fade := create_tween()
	fade.tween_property(glow_art,"modulate:a",1.0,.24).set_delay(.15)
	fade.tween_property(glow_art,"position:y",33.0,.66)
	fade.parallel().tween_property(glow_art,"modulate:a",0.0,.66)
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
	app.picture(art,preload(ROOT+"arrow-right-warm.svg"),Rect2(395,35,29,19))
	FigmaArt.text(art,str(current+1),Rect2(445,24,48,40),31,FigmaArt.BODY,Color("47240e"),false)
	var detail := ""
	match kind:
		"chief":
			if not app.model.debug_unlimited_buildings and current < DemoConfig.MAX_RESIDENT_HOMES:
				detail = "건설 가능 움집"
		"hut":
			var limits := [1,2,3,5]
			detail = "주민 수용  %d → %d" % [limits[current-1],limits[current]]
		"wood_store","stone_store":
			detail = "저장 한도  %d → %d\n주민 배정  %d → %d" % [ResourceStorage.LIMITS[current-1],ResourceStorage.LIMITS[current],current,current+1]
	var y := 82.0
	if not detail.is_empty():
		FigmaArt.text(art,"업그레이드 효과",Rect2(308,y,242,21),17,FigmaArt.BODY,Color("553820"),false)
		var group := ColorRect.new()
		group.color=Color(.54,.37,.20,.12)
		group.position=Vector2(304,y+40)
		group.size=Vector2(348,58)
		group.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art.add_child(group)
		FigmaArt.text(group,detail,Rect2(14,0,320,58),17,FigmaArt.BODY,Color("553820"),false)
		if kind=="chief":
			var capacity := FigmaArt.text(group,"%d채 → %d채"%[current,current+1],Rect2(230,0,104,58),17,FigmaArt.BODY,Color("553820"),false)
			capacity.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		y+=99.0
	if kind == "chief":
		var unlocks: Array[String] = []
		for building: String in BuildingRules.REQUIRED_HQ:
			if BuildingRules.REQUIRED_HQ[building]==current+1: unlocks.append(building)
		if not unlocks.is_empty():
			FigmaArt.text(art,"신규 건설",Rect2(318,y,244,19),17,FigmaArt.BODY,Color("553820"),false)
			for i in unlocks.size():
				app.picture(art,BuildingVisuals.texture(unlocks[i],1),Rect2(318+i*47,y+22,40,38))
	for i in 2:
		var resource := ["wood","stone"][i] as String
		var x := 76.0+i*76
		app.picture(art,DemoArt.icon(resource),Rect2(x,238,32,32))
		FigmaArt.text(art,str(costs.get(resource,0)),Rect2(x+34,238,41,32),18,FigmaArt.BODY,Color("553820"),false)
	var seconds := int(app.model.building_duration(current+1))
	var time := "%d초" % seconds if seconds<60 else "%d분" % (seconds/60)
	action(Rect2(270,300,192,44),"즉시 업그레이드","3",preload(UPDATE_ART+"diamond-premium-illustrated.png"),preload(UPDATE_ART+"popup-button-sapphire-disabled-192x44.svg"),true)
	action(Rect2(486,300,166,44),"업그레이드",time,preload(UPDATE_ART+"hourglass-teal-amber-illustrated.png"),preload(UPDATE_ART+"popup-button-gold-normal-166x44.svg"),false)
	unsupported_notice=FigmaArt.text(art,"미지원",Rect2(251,249,150,27),16,FigmaArt.BODY,Color("fff4d6"))
	unsupported_notice.add_theme_color_override("font_outline_color",Color("503016"))
	unsupported_notice.add_theme_constant_override("outline_size",8)
	unsupported_notice.modulate.a=0.0

func rule(rect: Rect2) -> void:
	var line := ColorRect.new()
	line.position=rect.position
	line.size=rect.size
	line.color=Color(.55,.38,.23,.38)
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.add_child(line)

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
	var button: DemoButton=app.button(art,"",confirm if not locked else show_unsupported)
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
	FigmaArt.text(button,value,Rect2(icon_x+23,0,34,42),14,FigmaArt.BODY,ink,false)
	FigmaArt.text(button,title,Rect2(68,0,rect.size.x-76,42),15,FigmaArt.BODY,ink,false)
