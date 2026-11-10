extends Control

const RULES := preload("res://scripts/deer_hunt_rules.gd")
const DESIGN := Vector2(960,540)
# Provisional separated v001 artwork, replaceable independently of actors and UI.
const GRASS := preload("res://assets/ui/hunting-v001/battle-clean-v001.png")
const PREP_TITLE := preload("res://assets/ui/hunting-v001/prep-title-bg.svg")
const PREP_PANEL := preload("res://assets/ui/hunting-v001/prep-panel-bg.svg")
const BATTLE_TITLE := preload("res://assets/ui/hunting-v001/battle-title-bg.svg")
const OBJECTIVE := preload("res://assets/ui/hunting-v001/objective-banner-bg.svg")
const NAME_BRUSH := preload("res://assets/ui/building-menu-v001/brush-black-v003.png")
const TRANSITION_SECONDS := 0.8
const TREE := preload("res://assets/environment/tree-v018.png")
const GEAR := preload("res://assets/ui/v0158/settings.svg")
const SPEAR := preload("res://assets/ui/s40000/hunt-spear-v001.png")
const AXE := preload("res://assets/ui/s40000/craft-axe-v001.png")
const HERO_MARK := preload("res://assets/ui/s40000/portrait.png")
const HUNTER_SLOTS := [Vector2(408,300),Vector2(336,269),Vector2(344,345)]
const PREP_SLOTS := [Vector2(218,420),Vector2(145,342),Vector2(105,453)]
const DEER_SLOT := Vector2(573,303)

var app: Node
var rules := RULES.new()
var canvas: Control
var preparation: Control
var combat: Control
var combat_top: Control
var combat_controls: Control
var prep_title: DemoButton
var prep_card: TextureRect
var foreground: TextureRect
var deer_status: Control
var transition_elapsed := -1.0
var actor_offset := Vector2.ZERO
var deer_offset := Vector2.ZERO
var combat_layout := false
var hunters: Array[HybridCharacter] = []
var deer: WorldAnimal
var hunter_bar: ProgressBar
var deer_bar: ProgressBar
var gauge_text: Label
var skill_buttons: Dictionary = {}
var skill_icons: Dictionary = {}
var ready_flashes: Dictionary = {}
var running := false
var result_shown := false
var result_timer := 0.0
var pose_clock := 1.0
var actor_delta := 0.0
var pose := ""
var exit_button: DemoButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground: TextureRect = app.picture(self,GRASS,Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = DESIGN
	add_child(canvas)
	canvas.draw.connect(draw_stage)
	foreground = app.picture(canvas,TREE,Rect2(-100,282,244,258))
	foreground.modulate = Color(.79,.85,.64)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	canvas.add_child(actors)
	for model in ["meshy01/hero","residents/sturdy_male","residents/female"]:
		var hunter := HybridCharacter.new()
		hunter.model_path = "res://assets/characters/"+model+".glb"
		hunter.render_size_factor = .5
		actors.add_child(hunter)
		hunter.set_enabled(true)
		hunter.use_training_spear()
		hunters.append(hunter)
	deer = WorldAnimal.new()
	deer.world_height = 90
	deer.heading = -PI*.5
	deer.position = DEER_SLOT
	actors.add_child(deer)
	deer.set_physics_process(false)
	deer.footprint_body.collision_layer = 0
	deer.footprint_body.collision_mask = 0
	deer.scale = Vector2.ONE
	build_preparation()
	build_combat()
	resized.connect(fit_layout)
	fit_layout()
	update_actors(0.1)

func fit_layout() -> void:
	var inset := Vector2(20,14)
	if OS.has_feature("android"):
		var area := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		if physical.x>0 and physical.y>0:
			var edge := Vector2(maxi(area.position.x,int(physical.x)-area.end.x),maxi(area.position.y,int(physical.y)-area.end.y))
			inset = inset.max(edge*size/physical)
	var fit := minf((size.x-inset.x*2)/DESIGN.x,(size.y-inset.y*2)/DESIGN.y)
	canvas.scale = Vector2.ONE*maxf(.1,fit)
	canvas.position = (size-DESIGN*canvas.scale)*.5

func build_preparation() -> void:
	preparation = layer()
	var enter: DemoButton = app.button(preparation,"",start_combat)
	enter.name = "PrepareTap"
	enter.custom_minimum_size = Vector2.ZERO
	enter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal","hover","pressed","focus"]:enter.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	# The full viewport also advances the preparation on wider screens.
	prep_title = make_button(preparation,"",Rect2(16,12,190,51),app.close_hunt)
	prep_title.name = "PrepareBack"
	for state in ["normal","hover","pressed","focus"]:
		prep_title.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(prep_title,PREP_TITLE,Rect2(Vector2.ZERO,prep_title.size))
	caption(prep_title,"‹   사냥 준비",Rect2(Vector2.ZERO,prep_title.size),22)
	prep_card = app.picture(preparation,PREP_PANEL,Rect2(668,28,280,455))
	var ink := Color("49321e")
	caption(prep_card,"첫 사냥",Rect2(12,44,256,39),29,ink)
	caption(prep_card,"숲 가장자리",Rect2(12,83,256,34),20,ink)
	caption(prep_card,"목표   사슴 처치",Rect2(12,122,256,33),20,ink)
	caption(prep_card,"사냥꾼 3명",Rect2(12,187,256,34),18,ink)
	caption(prep_card,"출전 준비 완료",Rect2(12,263,256,32),17,ink)
	caption(prep_card,"화면을 터치하여 전투 시작",Rect2(10,333,260,46),18,ink)

func build_combat() -> void:
	combat = layer()
	combat.hide()
	combat_top = layer(combat)
	combat_controls = layer(combat)
	hunter_bar = hp_bar(combat_top,Rect2(24,24,245,17),Color("84b73a"))
	var place: TextureRect = app.picture(combat_top,BATTLE_TITLE,Rect2(381,12,198,46))
	caption(place,"숲 가장자리",Rect2(Vector2.ZERO,place.size),22)
	exit_button = make_button(combat_top,"",Rect2(888,10,56,56),app.close_hunt)
	exit_button.name = "ExitHunt"
	exit_button.tooltip_text = "사냥 종료"
	app.picture(exit_button,GEAR,Rect2(5,5,46,46))
	deer_status = app.picture(combat_top,NAME_BRUSH,Rect2(528,177,100,27))
	caption(deer_status,"사슴",Rect2(0,0,100,25),17)
	deer_bar = hp_bar(deer_status,Rect2(8,26,84,9),Color("c8543e"))
	var objective: TextureRect = app.picture(combat_controls,OBJECTIVE,Rect2(302,475,356,42))
	var objective_text := caption(objective,"사슴을 처치하세요",Rect2(Vector2.ZERO,objective.size),21)
	objective_text.add_theme_color_override("font_outline_color",Color("492f1b"))
	objective_text.add_theme_constant_override("outline_size",5)
	# Secondary controls are added above the primary control for overlapping taps.
	add_skill("thrust",Rect2(778,341,102,102),SPEAR)
	add_skill("strike",Rect2(797,283,64,64),AXE)
	add_skill("team",Rect2(720,326,64,64),HERO_MARK)
	var gauge_plate := plaque(combat_controls,Rect2(778,447,102,28),Color("164253"),Color("5aa0ae"))
	gauge_text = caption(gauge_plate,"0 / 100",Rect2(Vector2.ZERO,gauge_plate.size),17)
	update_combat_ui()

func layer(parent: Control = null) -> Control:
	var result := Control.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(canvas if parent==null else parent).add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

func make_button(parent: Control, title: String, rect: Rect2, callback: Callable) -> DemoButton:
	var button: DemoButton = app.button(parent,title,callback)
	button.custom_minimum_size = Vector2.ZERO
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",20)
	return button

func plaque(parent: Control, rect: Rect2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",box(color,border,14))
	parent.add_child(panel)
	return panel

func box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func caption(parent: Control, value: String, rect: Rect2, font_size: int, color := Color("fff0d0")) -> Label:
	var line: Label = app.label(parent,value,font_size,color)
	line.position = rect.position
	line.size = rect.size
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func hp_bar(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.value = RULES.MAX_HP
	bar.position = rect.position
	bar.size = rect.size
	bar.add_theme_stylebox_override("background",box(Color("302415"),Color("755638"),5))
	bar.add_theme_stylebox_override("fill",box(color,color,5))
	parent.add_child(bar)
	return bar

func add_skill(id: String, rect: Rect2, texture: Texture2D) -> void:
	var info: Dictionary = RULES.SKILLS[id]
	var control := make_button(combat_controls,"",rect,use_skill.bind(id))
	control.name = id
	control.tooltip_text = info.label
	var radius := int(rect.size.x*.5)
	var color := Color("7c4721") if id=="thrust" else Color("984126") if id=="strike" else Color("6b663a")
	control.add_theme_stylebox_override("normal",box(color,Color("edbd68"),radius))
	control.add_theme_stylebox_override("hover",box(color.lightened(.14),Color("ffe4a0"),radius))
	control.add_theme_stylebox_override("pressed",box(color.darkened(.18),Color("e7ba60"),radius))
	control.add_theme_stylebox_override("disabled",box(Color("474747"),Color("969696"),radius))
	var icon_rect := Rect2(rect.size*.16,rect.size*.66)
	var icon: TextureRect = app.picture(control,texture,icon_rect)
	var grayscale := Shader.new()
	grayscale.code = "shader_type canvas_item; uniform bool gray = false; void fragment(){vec4 c=COLOR; if(gray){c.rgb=vec3(dot(c.rgb,vec3(0.299,0.587,0.114)));} COLOR=c;}"
	var material := ShaderMaterial.new()
	material.shader = grayscale
	icon.material = material
	skill_icons[id] = material
	caption(control,"%s  %d"%[info.label,info.cost],Rect2(0,rect.size.y*.71,rect.size.x,22),13)
	skill_buttons[id] = control
	ready_flashes[id] = 0.0

func _gui_input(event: InputEvent) -> void:
	if not running and ((event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)):
		start_combat()
		accept_event()

func start_combat() -> void:
	if running or transition_elapsed>=0 or not app.application_active:return
	transition_elapsed = 0.0
	preparation.get_node("PrepareTap").hide()
	prep_title.disabled = true

func advance_transition(delta: float) -> void:
	transition_elapsed += delta
	var progress := clampf(transition_elapsed/TRANSITION_SECONDS,0,1)
	var travel := size/canvas.scale
	if progress<.5:
		var leaving := smoothstep(0,.5,progress)
		prep_title.position.y = 12-travel.y*leaving
		prep_card.position.x = 668+travel.x*leaving
		actor_offset = Vector2(-travel.x*leaving,0)
		foreground.position.x = -100+actor_offset.x
		deer_offset = Vector2(travel.x*leaving,0)
	else:
		if not combat_layout:
			preparation.hide()
			foreground.hide()
			combat_layout = true
			combat.show()
			exit_button.disabled = true
		var remaining := 1.0-smoothstep(.5,1,progress)
		combat_top.position.y = -travel.y*remaining
		combat_controls.position.y = travel.y*remaining
		actor_offset = Vector2(-travel.x*remaining,0)
		deer_offset = Vector2(travel.x*remaining,0)
	if progress>=1:
		transition_elapsed = -1.0
		exit_button.disabled = false
		running = true

func use_skill(id: String) -> void:
	if not running or not app.application_active or not rules.use_skill(id):return
	play_pose(id)
	update_combat_ui()

func play_pose(id: String) -> void:
	pose = id
	pose_clock = 0.0

func _process(delta: float) -> void:
	if not app.application_active:return
	if transition_elapsed>=0:advance_transition(delta)
	if running and not result_shown:
		for move in rules.advance(delta):
			play_pose(move)
		for id in ready_flashes:
			ready_flashes[id] = maxf(0,ready_flashes[id]-delta)
		update_combat_ui()
		if not rules.outcome.is_empty():show_result()
	if result_shown:
		result_timer -= delta
		if result_timer<=0:
			app.close_hunt()
			return
	pose_clock += delta
	actor_delta += delta
	if actor_delta>=1.0/30.0:
		update_actors(actor_delta)
		actor_delta = 0.0
	canvas.queue_redraw()

func update_combat_ui() -> void:
	hunter_bar.value = rules.hunter_hp
	deer_bar.value = rules.deer_hp
	gauge_text.text = "%d / %d"%[floori(rules.gauge),int(RULES.MAX_GAUGE)]
	for id in skill_buttons:
		var control: DemoButton = skill_buttons[id]
		var ready := rules.can_use(id)
		if id!="thrust" and running and control.disabled and ready:
			ready_flashes[id] = .42
		control.disabled = not ready
		skill_icons[id].set_shader_parameter("gray",not ready)

func update_actors(delta: float) -> void:
	var beat := sin(clampf(pose_clock/.52,0,1)*PI)
	for i in hunters.size():
		var hunter := hunters[i]
		var attack := running and pose_clock<.52 and pose!="counter" and (i==0 or pose=="team")
		var dodge := running and pose=="counter" and i==0
		var base: Vector2 = HUNTER_SLOTS[i] if combat_layout else PREP_SLOTS[i]
		hunter.scale = Vector2.ONE*(.89 if combat_layout else 1.13)
		hunter.position = base + actor_offset + Vector2((32 if attack else -18 if dodge else 0)*beat,-5*beat if attack else 0)
		hunter.animate(delta,Vector2.RIGHT,pose_clock*12,dodge,"" if not attack else "hunt",pose_clock,false)
		if attack:
			hunter.blend_bone("spine",Vector3(.10+beat*.12,0,-.08),.9)
			hunter.blend_bone("armR",Vector3(-.88-beat*.38,0,-.15),1)
			hunter.blend_bone("forearmR",Vector3(-.95+beat*.75,0,0),1)
		hunter.tool_3d.visible = true
		hunter.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var charge := running and pose=="counter"
	deer.position = DEER_SLOT+deer_offset+Vector2((-29 if charge else 23)*beat if combat_layout else -45,-8*beat if combat_layout else -38)
	deer_status.position = Vector2(deer.position.x-50,177)
	deer.walking = beat if running else 0.0
	deer.gait_phase = pose_clock*14

func draw_stage() -> void:
	if not combat_layout:return
	var center := Vector2(829,392)+combat_controls.position
	canvas.draw_arc(center,57,-1.24,1.31,38,Color("15272b"),9,true)
	if rules.gauge>0:
		canvas.draw_arc(center,57,-1.24,lerpf(-1.24,1.31,rules.gauge/RULES.MAX_GAUGE),38,Color("57deff"),6,true)
	for id in ["strike","team"]:
		var flash: float = ready_flashes[id]
		if flash<=0:continue
		var button: DemoButton = skill_buttons[id]
		canvas.draw_arc(button.position+button.size*.5,36,0,TAU,40,Color(1,.87,.43,flash/.42),4,true)

func show_result() -> void:
	result_shown = true
	result_timer = 1.6
	var panel := plaque(combat,Rect2(310,208,340,108),Color("503317"),Color("e2b273"))
	caption(panel,"사냥 성공" if rules.outcome=="win" else "사냥 실패",Rect2(Vector2.ZERO,panel.size),32)
