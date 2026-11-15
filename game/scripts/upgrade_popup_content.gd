extends Control

const ROOT := "res://assets/ui/d0019/"
var app: Node
var kind: String
var current: int
var costs: Dictionary
var confirm: Callable
var art: Control

func _init(owner: Node, building_kind: String, level: int, cost: Dictionary, callback: Callable) -> void:
	app=owner;kind=building_kind;current=level;costs=cost;confirm=callback
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL

func _ready() -> void:
	art=Control.new()
	art.size=Vector2(520,246)
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(art)
	resized.connect(fit)
	fit()
	var shade := Gradient.new()
	shade.colors=PackedColorArray([Color(.29,.20,.13,.25),Color(.29,.20,.13,0)])
	var texture := GradientTexture2D.new()
	texture.gradient=shade
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(1,.5)
	app.picture(art,texture,Rect2(22,132,180,34)).stretch_mode=TextureRect.STRETCH_SCALE
	var sparkle := Gradient.new()
	sparkle.colors=PackedColorArray([Color(1,.75,.22,.63),Color(1,.75,.22,0)])
	var ray := GradientTexture2D.new()
	ray.gradient=sparkle
	ray.fill=GradientTexture2D.FILL_RADIAL
	ray.fill_from=Vector2(.5,.5)
	ray.fill_to=Vector2(1,.5)
	var glow_art: TextureRect=app.picture(art,ray,Rect2(41,99,135,80))
	glow_art.stretch_mode=TextureRect.STRETCH_SCALE
	glow_art.modulate.a=0
	var fade := create_tween()
	fade.tween_property(glow_art,"modulate:a",1.0,.24).set_delay(.15)
	fade.tween_property(glow_art,"position:y",33.0,.66)
	fade.parallel().tween_property(glow_art,"modulate:a",0.0,.66)
	var image := BuildingWorkflow.approved_texture(BuildingWorkflow.building_asset_id(kind,current+1))
	if image:
		var cropped := AtlasTexture.new()
		cropped.atlas=image
		cropped.region=Rect2(image.get_image().get_used_rect())
		cropped.filter_clip=true
		app.picture(art,cropped,Rect2(8,20,207,139))
	FigmaArt.text(art,"Lv. %d" % current,Rect2(226,5,91,38),27,FigmaArt.BODY,Color("796654"))
	app.picture(art,preload(ROOT+"arrow-right-warm.svg"),Rect2(325,14,29,19))
	FigmaArt.text(art,str(current+1),Rect2(360,4,65,40),31,FigmaArt.BODY,Color("47240e"))
	var detail := ""
	match kind:
		"chief":
			if not app.model.debug_unlimited_buildings and current < DemoConfig.MAX_RESIDENT_HOMES:
				detail = "건설 가능 움집  %d → %d" % [current,current+1]
		"hut":
			var limits := [1,2,3,5]
			detail = "주민 수용  %d → %d" % [limits[current-1],limits[current]]
		"wood_store","stone_store":
			detail = "저장 한도  %d → %d\n주민 배정  %d → %d" % [ResourceStorage.LIMITS[current-1],ResourceStorage.LIMITS[current],current,current+1]
	var y := 46.0
	if not detail.is_empty():
		FigmaArt.text(art,"효과",Rect2(226,y,242,21),15,FigmaArt.BODY,Color("553820"),false)
		var group := ColorRect.new()
		group.color=Color(.54,.37,.20,.12)
		group.position=Vector2(226,y+23)
		group.size=Vector2(270,43)
		group.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art.add_child(group)
		FigmaArt.text(group,detail,Rect2(9,0,252,43),15,FigmaArt.BODY,Color("553820"),false)
		y+=72.0
	if kind == "chief":
		var unlocks: Array[String] = []
		for building: String in BuildingRules.REQUIRED_HQ:
			if BuildingRules.REQUIRED_HQ[building]==current+1: unlocks.append(building)
		if not unlocks.is_empty():
			FigmaArt.text(art,"신규 건설",Rect2(226,y,244,17),15,FigmaArt.BODY,Color("553820"),false)
			for i in unlocks.size():
				app.picture(art,BuildingVisuals.texture(unlocks[i],1),Rect2(226+i*47,y+18,40,38))
	for i in 2:
		var resource := ["wood","stone"][i] as String
		var x := 8.0+i*98
		app.picture(art,DemoArt.icon(resource),Rect2(x,195,32,32))
		FigmaArt.text(art,str(costs.get(resource,0)),Rect2(x+33,195,53,32),18,FigmaArt.BODY,Color("553820"),false)
	var seconds := int(app.model.building_duration(current+1))
	var time := "%d초" % seconds if seconds<60 else "%d분" % (seconds/60)
	action(Rect2(213,188,156,42),"업그레이드",time,preload(ROOT+"hourglass-teal-amber.svg"),preload(ROOT+"button-gold-166x44@2x.png"),false)
	action(Rect2(375,188,141,42),"즉시 업그레이드","3",preload(ROOT+"diamond-premium.svg"),preload(ROOT+"button-sapphire-192x44@2x.png"),true)
	FigmaArt.text(art,"즉시 완료 준비 중",Rect2(375,228,141,16),10,FigmaArt.BODY,Color("69563f"))

func fit() -> void:
	var factor := minf(1.0,minf(size.x/520.0,size.y/246.0))
	art.scale=Vector2.ONE*factor
	art.position=(size-art.size*factor)*.5

func action(rect: Rect2, title: String, value: String, icon: Texture2D, background: Texture2D, locked: bool) -> void:
	var button: DemoButton=app.button(art,"",confirm if not locked else func(): pass)
	button.name="InstantUpgrade" if locked else "ConfirmUpgrade"
	button.custom_minimum_size=Vector2.ZERO
	button.position=rect.position
	button.size=rect.size
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var skin := NinePatchRect.new()
	skin.texture=background
	skin.size=button.size
	skin.patch_margin_left=14
	skin.patch_margin_right=14
	skin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(skin)
	app.picture(button,icon,Rect2(9,12,18,18))
	FigmaArt.text(button,value,Rect2(28,0,39,42),15,FigmaArt.BODY,Color("fff4c9"))
	var label:=FigmaArt.text(button,title,Rect2(51 if locked else 65,0,rect.size.x-(55 if locked else 69),42),12 if locked else 13,FigmaArt.BODY,Color("332414"))
	label.add_theme_color_override("font_shadow_color",Color(1,.9,.7,.35))
	label.add_theme_constant_override("shadow_offset_y",1)
	button.disabled=locked
	if locked: button.modulate.a=.67
