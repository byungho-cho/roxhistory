extends Control

const RULES := preload("res://scripts/deer_hunt_rules.gd")
const DESIGN := Vector2(960,540)
const CLEARING := preload("res://assets/ui/hunting-formation/clearing.png")
const ALLY_CELL := preload("res://assets/ui/hunting-formation/ally-cell.svg")
const ENEMY_CELL := preload("res://assets/ui/hunting-formation/enemy-cell.svg")
const PORTRAITS := preload("res://assets/ui/hunting-formation/portraits.png")
const PORTRAIT_FRAME := preload("res://assets/ui/hunting-formation/portrait-frame.svg")
const PORTRAIT_SELECTED := preload("res://assets/ui/hunting-formation/portrait-selected.svg")
const CELL_X := Vector2(52.5,-37.123)
const CELL_Y := Vector2(52.5,37.123)
const ALLY_ORIGIN := Vector2(272,348)
const ENEMY_ORIGIN := ALLY_ORIGIN + CELL_X * 3.155
const CELL_SIZE := Vector2(107,76.246)
const NAME_BRUSH := preload("res://assets/ui/brush/resource-slot-brush@2x.png")
const TRANSITION_SECONDS := 2.4
const HUNTER_SLOTS := [Vector2(434,314),Vector2(304,299),Vector2(358,361)]
const DEER_SLOT := Vector2(568,320)

var app: Node
var rules := RULES.new()
var canvas: Control
var battlefield: Control
var ground: TextureRect
var zoom := 1.0
var touch_points := {}
var speed := 1.0
var auto_button: DemoButton
var speed_button: DemoButton
var exit_popup: Control
var exit_shade: ColorRect
var orb_icons: Array[TextureRect] = []
var skill_layers := {}
var last_orbs := 0
var sound_delay := 0.0
var camera_progress := -1.0
var prey_hud: Control
var prey_hp: TextureProgressBar
var controls_gray: Shader
const ART := "res://assets/ui/hunting-combat/"
const ORB_FULL := preload("res://assets/ui/hunting-combat/svg/skills/orb-active.svg")
const ORB_EMPTY := preload("res://assets/ui/hunting-combat/svg/skills/orb-inactive.svg")
var preparation: Control
var combat: Control
var combat_controls: Control
var placement_grid: Control
var portrait_frames: Array[TextureRect] = []
var assigned_cells: Array[int] = [2,0,7]
var selected_hunter := 0
var approach := 0.0
var ally_hud: Control
var enemy_hud: Control
var duel_ally_portrait: TextureRect
var prep_ally_portrait: TextureRect
var battle_header: Control
var location_brush: TextureRect
var location_caption: Label
var versus: Control
var versus_letters: Array[TextureRect] = []
var deer_health_text: Label
var transition_elapsed := -1.0
var combat_layout := false
var hunters: Array[HybridCharacter] = []
var deer: WorldAnimal
var hunter_bar: TextureProgressBar
var deer_bar: TextureProgressBar
var skill_buttons: Dictionary = {}
var ready_flashes: Dictionary = {}
var running := false
var result_shown := false
var result_timer := 0.0
var pose_clock := 1.0
const BASIC_RECOIL_TIME := 0.19
var basic_recoil := 0.0
var actor_delta := 0.0
var pose := ""
var exit_button: DemoButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ground = app.picture(self,CLEARING,Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = DESIGN
	add_child(canvas)
	battlefield = layer()
	battlefield.draw.connect(draw_stage)
	placement_grid = layer(battlefield)
	for i in 9:
		app.picture(placement_grid,ALLY_CELL,Rect2(cell_center(ALLY_ORIGIN,i)-CELL_SIZE*.5,CELL_SIZE))
		app.picture(placement_grid,ENEMY_CELL,Rect2(cell_center(ENEMY_ORIGIN,i)-CELL_SIZE*.5,CELL_SIZE))
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	battlefield.add_child(actors)
	for model in ["meshy01/hero","residents/sturdy_male","residents/female"]:
		var hunter := HybridCharacter.new()
		hunter.model_path = "res://assets/characters/"+model+".glb"
		hunter.render_size_factor = .5
		actors.add_child(hunter)
		hunter.set_enabled(true)
		hunter.use_training_spear()
		hunter.camera.position.y = 7.45
		hunter.camera.look_at(Vector3(0,1.45,0))
		hunter.display.position = -hunter.camera.unproject_position(Vector3.ZERO)*hunter.display.scale
		hunters.append(hunter)
	deer = WorldAnimal.new()
	deer.world_height = 90
	deer.heading = -PI*.72
	deer.position = DEER_SLOT
	actors.add_child(deer)
	deer.camera.position.y = 7.0
	deer.camera.look_at(Vector3(0,1,0))
	deer.update_geometry()
	deer.set_physics_process(false)
	deer.presentation_paused = true
	deer.footprint_body.collision_layer = 0
	deer.footprint_body.collision_mask = 0
	deer.scale = Vector2.ONE
	build_preparation()
	build_combat()
	build_duel_header()
	update_combat_ui()
	resized.connect(fit_layout)
	fit_layout()
	update_actors(0.1)

func fit_layout() -> void:
	var inset := Vector2.ZERO
	if OS.has_feature("android"):
		var area := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		if physical.x>0 and physical.y>0:
			var edge := Vector2(maxi(area.position.x,int(physical.x)-area.end.x),maxi(area.position.y,int(physical.y)-area.end.y))
			inset = inset.max(edge*size/physical)
	var fit := minf((size.x-inset.x*2)/DESIGN.x,(size.y-inset.y*2)/DESIGN.y)
	canvas.scale = Vector2.ONE*maxf(.1,fit)
	canvas.position = (size-DESIGN*canvas.scale)*.5
	fit_exit_shade()

func cell_center(origin: Vector2, index: int) -> Vector2:
	return origin + CELL_X*(index%3) + CELL_Y*floori(index/3.0)

func crop(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = rect
	result.filter_clip = true
	return result

func hunter_portrait(index: int) -> Texture2D:
	const REGIONS := [Rect2(15,0,675,710),Rect2(725,0,690,710),Rect2(1495,10,610,700)]
	return crop(PORTRAITS,REGIONS[index])

func build_preparation() -> void:
	preparation = layer()
	var roster: TextureRect = app.picture(preparation,preload("res://assets/ui/hunting-formation/roster.png"),Rect2(31.5,79.5,165,355))
	roster.stretch_mode = TextureRect.STRETCH_SCALE
	var ink := Color("49321e")
	caption(roster,"출전 편성",Rect2(17,40,131,25),17,ink)
	caption(roster,"%d / 3"%hunters.size(),Rect2(37.5,65,90,21),15,ink)
	for index in hunters.size():
		var card := make_button(roster,"",Rect2(35,90+85*index,95,77),select_hunter.bind(index))
		clear_button_art(card)
		card.name = "Hunter%d"%index
		var frame: TextureRect = app.picture(card,PORTRAIT_FRAME,Rect2(0,0,95,77))
		portrait_frames.append(frame)
		var portrait: TextureRect = app.picture(card,hunter_portrait(index),Rect2(5,2,85,72))
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		app.picture(card,preload("res://assets/ui/hunting-formation/swap.svg"),Rect2(71,53,24,24))
	select_hunter(0)
	var start := artwork_button(preparation,Rect2(776.5,474.5,160,50),"사냥 시작","png/preparation/start-battle-background.png",start_combat,ink)
	start.name = "StartBattle"
	var quick := artwork_button(preparation,Rect2(604,474.5,160,50),"빠른 출전","png/preparation/quick-sortie-background.png",func():pass)
	quick.disabled = true
	for control in [start,quick]:
		var background: TextureRect = control.get_child(0)
		background.stretch_mode = TextureRect.STRETCH_SCALE
		control.get_child(1).add_theme_font_size_override("font_size",18)
	build_preparation_plaque()
	build_power_comparison()

func build_preparation_plaque() -> void:
	const ATLAS := preload("res://assets/ui/hunting-formation/preparation-plaque-atlas.png")
	const LEFT := Rect2(.53775,.0791,.0703125,.1660)
	const CENTER := Rect2(.60837,.0791,.3060,.1660)
	const RIGHT := Rect2(.9140625,.0791,.0703125,.1660)
	var regions := [LEFT,CENTER,RIGHT]
	var positions := [Rect2(33.5,473.5,23.506,37),Rect2(57.006,473.5,101.99,37),Rect2(158.996,473.5,23.41,37)]
	for index in regions.size():
		var region: Rect2 = regions[index]
		var art: TextureRect = app.picture(preparation,crop(ATLAS,Rect2(region.position*ATLAS.get_size(),region.size*ATLAS.get_size())),positions[index])
		art.stretch_mode = TextureRect.STRETCH_SCALE
	caption(preparation,"사냥 준비",Rect2(33.5,473.5,150,37),16)
	var bag := make_button(preparation,"",Rect2(142.5,462.5,56,62),app.inventory_summary)
	clear_button_art(bag)
	app.picture(bag,preload("res://assets/ui/hunting-formation/bag.png"),Rect2(5.2,0,45.6,48))
	var brush: TextureRect = app.picture(bag,NAME_BRUSH,Rect2(0,41,56,19))
	brush.modulate.a = .8
	caption(bag,"가방",Rect2(4,41,48,19),12)

func build_power_comparison() -> void:
	var ally_icon := plaque(preparation,Rect2(297,4,48,48),Color("1c291f"),Color("f2bd4d"))
	prep_ally_portrait = app.picture(ally_icon,hunter_portrait(selected_hunter),Rect2(2,2,44,44))
	app.picture(preparation,preload("res://assets/ui/hunting-combat/png/common/hp-portrait-deer.png"),Rect2(705,4,48,48))
	# Lv 1 planning values shown by the preparation mockup. No combat rules read them.
	add_power_digits("12,300",Vector2(425,25))
	add_power_digits("8,000",Vector2(625,25))
	app.picture(preparation,preload("res://assets/ui/hunting-formation/vs-backdrop.svg"),Rect2(507,10,36,36))
	app.picture(preparation,preload("res://assets/ui/hunting-formation/vs-v.svg"),Rect2(510,17,18,22.5))
	app.picture(preparation,preload("res://assets/ui/hunting-formation/vs-s.svg"),Rect2(522.3,17,18,22.5))

func add_power_digits(value: String, center: Vector2) -> void:
	const GLYPHS := {
		"0": preload("res://assets/ui/hunting-formation/power-0.svg"),
		"1": preload("res://assets/ui/hunting-formation/power-1.svg"),
		"2": preload("res://assets/ui/hunting-formation/power-2.svg"),
		"3": preload("res://assets/ui/hunting-formation/power-3.svg"),
		"8": preload("res://assets/ui/hunting-formation/power-8.svg"),
		",": preload("res://assets/ui/hunting-formation/power-comma.svg")
	}
	const OVERLAP := 5.0
	var width := OVERLAP
	for digit in value:width += (GLYPHS[digit] as Texture2D).get_width()*.5-OVERLAP
	var x := center.x-width*.5
	for digit in value:
		var glyph: Texture2D = GLYPHS[digit]
		var dimensions := glyph.get_size()*.5
		app.picture(preparation,glyph,Rect2(Vector2(x,center.y-dimensions.y*.5),dimensions))
		x += dimensions.x-OVERLAP

func clear_button_art(control: DemoButton) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state,StyleBoxEmpty.new())

func select_hunter(index: int) -> void:
	if transition_elapsed>=0 or running:return
	selected_hunter = index
	for i in portrait_frames.size():
		portrait_frames[i].texture = PORTRAIT_SELECTED if i==index else PORTRAIT_FRAME
	if prep_ally_portrait:
		prep_ally_portrait.texture = hunter_portrait(index)
	if duel_ally_portrait:
		duel_ally_portrait.texture = hunter_portrait(index)

func build_duel_header() -> void:
	var header := layer()
	location_brush = app.picture(header,NAME_BRUSH,Rect2(10,1,220,56))
	location_caption = caption(location_brush,"숲 가장자리",Rect2(44,0,163,56),21)
	exit_button = make_button(header,"",Rect2(10,5,48,48),request_exit)
	exit_button.name = "ExitHunt"
	exit_button.tooltip_text = "뒤로가기"
	clear_button_art(exit_button)
	app.picture(exit_button,FigmaArt.texture("back"),Rect2(0,0,48,48))
	battle_header = layer(header)
	battle_header.hide()
	ally_hud = layer(battle_header)
	enemy_hud = layer(battle_header)
	hunter_bar = hp_bar(ally_hud,Rect2(339,32,160,32),true)
	deer_bar = hp_bar(enemy_hud,Rect2(552,32,160,32),false)
	deer_health_text = caption(deer_bar,"",Rect2(0,0,160,32),15)
	deer_health_text.add_theme_color_override("font_outline_color",Color("331a12"))
	deer_health_text.add_theme_constant_override("outline_size",4)
	var ally_icon := plaque(ally_hud,Rect2(297,24,48,48),Color("1c291f"),Color("f2bd4d"))
	duel_ally_portrait = app.picture(ally_icon,hunter_portrait(selected_hunter),Rect2(2,2,44,44))
	app.picture(enemy_hud,preload("res://assets/ui/hunting-combat/png/common/hp-portrait-deer.png"),Rect2(706,24,48,48))
	versus = layer(battle_header)
	app.picture(versus,preload("res://assets/ui/hunting-formation/vs-backdrop.svg"),Rect2(507,30,36,36))
	versus_letters.append(app.picture(versus,preload("res://assets/ui/hunting-formation/vs-v.svg"),Rect2(510,37,18,22.5)))
	versus_letters.append(app.picture(versus,preload("res://assets/ui/hunting-formation/vs-s.svg"),Rect2(522.3,37,18,22.5)))
	for letter in versus_letters:letter.pivot_offset = letter.size*.5
	auto_button = toggle_control(header,Rect2(840,4,48,48),"AUTO","auto",toggle_auto)
	speed_button = toggle_control(header,Rect2(894,4,48,48),"X2","speed-2x",toggle_speed)
	update_toggles()

func toggle_control(parent: Control, rect: Rect2, label: String, asset: String, action: Callable) -> DemoButton:
	var button := make_button(parent,"",rect,action)
	clear_button_art(button)
	if not controls_gray:
		controls_gray = Shader.new()
		controls_gray.code = "shader_type canvas_item; uniform bool gray; void fragment(){if(gray){COLOR.rgb=vec3(dot(COLOR.rgb,vec3(.299,.587,.114)));}}"
	var icon: TextureRect = app.picture(button,load(ART+"svg/common/"+asset+".svg"),Rect2(Vector2.ZERO,rect.size))
	var material := ShaderMaterial.new()
	material.shader = controls_gray
	icon.material = material
	button.set_meta("toggle_material",material)
	button.tooltip_text = label
	return button

func toggle_auto() -> void:
	if exit_popup or app.modal or result_shown:return
	rules.set_auto(not rules.auto_enabled and transition_elapsed>=0 or running and not rules.auto_enabled)
	update_toggles()

func toggle_speed() -> void:
	if exit_popup or app.modal or result_shown:return
	speed = 1.0 if speed == 2.0 else 2.0
	update_toggles()

func update_toggles() -> void:
	var in_battle := transition_elapsed>=0 or running
	auto_button.get_meta("toggle_material").set_shader_parameter("gray",in_battle and not rules.auto_enabled)
	speed_button.get_meta("toggle_material").set_shader_parameter("gray",in_battle and speed!=2.0)

func build_combat() -> void:
	combat = layer()
	combat.hide()
	combat_controls = layer(combat)
	add_skill("thrust","strike",Rect2(735,350,150,150),[])
	add_skill("strike","strong",Rect2(703.58,311.18,68,68),[Rect2(29.6,52,8.8,8.8)])
	add_skill("team","cooperation",Rect2(771,265.75,85,85),[Rect2(29.5,65,11,11),Rect2(44.5,65,11,11)])
	for center in [Vector2(898.4,421),Vector2(895.6,447.6),Vector2(885.2,472.15)]:
		orb_icons.append(app.picture(combat_controls,ORB_EMPTY,Rect2(center-Vector2.ONE*12.35,Vector2.ONE*24.7)))
	prey_hud = layer(battlefield)
	prey_hud.hide()
	app.picture(prey_hud,NAME_BRUSH,Rect2(-30,-15,60,16))
	caption(prey_hud,"사슴",Rect2(-30,-16,60,16),13)
	prey_hp = hp_bar(prey_hud,Rect2(-27,3,54,8),false)

func artwork_button(parent: Control, rect: Rect2, label: String, asset: String, action: Callable, ink := Color("fff0d0")) -> DemoButton:
	var button := make_button(parent,"",rect,action)
	clear_button_art(button)
	app.picture(button,load(ART+asset),Rect2(Vector2.ZERO,rect.size))
	caption(button,label,Rect2(Vector2.ZERO,rect.size),24,ink)
	return button

func request_exit() -> void:
	if app.modal:
		app.close_modal()
		return
	if exit_popup:
		resume_battle()
		return
	if not running and transition_elapsed < 0:
		app.close_hunt()
		return
	if result_shown:return
	exit_popup = layer()
	exit_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_shade = ColorRect.new()
	exit_shade.color = Color(0,0,0,.6)
	exit_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_popup.add_child(exit_shade)
	fit_exit_shade()
	var panel: TextureRect = app.picture(exit_popup,preload("res://assets/ui/hunting-combat/png/popup/panel.png"),Rect2(261,186.5,438,167))
	caption(panel,"전투를 종료할까요?",Rect2(0,24,438,48),25,Color("49321e"))
	artwork_button(panel,Rect2(40,85,170,52),"종료","png/popup/exit-button-background.png",app.close_hunt).name = "ExitBattle"
	artwork_button(panel,Rect2(227,85,170,52),"계속","png/popup/continue-button-background.png",resume_battle,Color("49321e")).name = "ContinueBattle"
	# A touch that began before the popup must not activate an underlying skill.
	for button in skill_buttons.values():button.clear()

func fit_exit_shade() -> void:
	if not is_instance_valid(exit_shade):return
	exit_shade.position = -canvas.position/canvas.scale
	exit_shade.size = size/canvas.scale

func resume_battle() -> void:
	exit_popup.hide()
	exit_popup.queue_free()
	exit_popup = null

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

func hp_bar(parent: Control, rect: Rect2, ally: bool) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = RULES.MAX_HP
	bar.step = 0.0
	bar.value = RULES.MAX_HP
	bar.nine_patch_stretch = true
	app.picture(parent,preload("res://assets/ui/hunting-combat/png/common/hp-track.png"),rect)
	bar.texture_progress = preload("res://assets/ui/hunting-combat/png/common/hp-fill-ally.png") if ally else preload("res://assets/ui/hunting-combat/png/common/hp-fill-enemy.png")
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	var inset := Vector2.ONE*minf(2.0,rect.size.y*.12)
	bar.position = rect.position+inset
	bar.size = rect.size-inset*2
	parent.add_child(bar)
	return bar

func add_skill(id: String, asset: String, rect: Rect2, cost_slots: Array) -> void:
	var control := make_button(combat_controls,"",rect,use_skill.bind(id))
	control.name = id
	control.tooltip_text = RULES.SKILLS[id].label
	clear_button_art(control)
	var inner := Rect2(Vector2.ZERO,rect.size)
	var background: TextureRect = app.picture(control,load(ART+"png/skills/"+asset+"-background.png"),inner)
	var effect: TextureRect = app.picture(control,load(ART+"svg/skills/"+asset+"-effect.svg"),inner)
	var icon: TextureRect = app.picture(control,load(ART+"png/skills/"+asset+"-icon.png"),inner)
	var disabled: TextureRect = app.picture(control,load(ART+"png/skills/"+asset+"-disabled.png"),inner)
	var costs: Array[TextureRect] = []
	for slot in cost_slots:
		costs.append(app.picture(control,ORB_FULL,slot))
	skill_layers[id] = {"base":background,"effect":effect,"icon":icon,"disabled":disabled,"costs":costs}
	skill_buttons[id] = control
	ready_flashes[id] = 0.0
	effect.hide()

func _input(event: InputEvent) -> void:
	if not running or result_shown or exit_popup or app.modal or not app.application_active:
		touch_points.clear()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
	elif event is InputEventScreenDrag and touch_points.has(event.index):
		var previous: Vector2 = touch_points[event.index]
		touch_points[event.index] = event.position
		if touch_points.size()!=2:return
		var keys := touch_points.keys()
		var other: Vector2 = touch_points[keys[0] if keys[1]==event.index else keys[1]]
		var span := previous.distance_to(other)
		if span>1.0:
			zoom = clampf(zoom*event.position.distance_to(other)/span,1.0,1.55)
			for button in skill_buttons.values():button.clear()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if exit_popup or not app.application_active or app.modal:return
	if running and not result_shown:
		if event is InputEventMagnifyGesture:
			zoom = clampf(zoom*event.factor,1.0,1.55)
			accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom+(.10 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -.10),1.0,1.55)
			accept_event()
		return
	if transition_elapsed>=0:return
	var released: bool = (event is InputEventScreenTouch and not event.pressed) or (
		event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)
	if not released:return
	var at: Vector2 = canvas.get_global_transform().affine_inverse() * (get_global_transform() * event.position)
	for index in 9:
		var difference: Vector2 = (at-cell_center(ALLY_ORIGIN,index)).abs()
		if difference.x/52.5 + difference.y/37.123 <= 1.0:
			move_hunter(index)
			accept_event()
			return

func move_hunter(index: int) -> void:
	if index<0 or index>=9 or transition_elapsed>=0 or running:return
	var occupying := assigned_cells.find(index)
	if occupying>=0:assigned_cells[occupying] = assigned_cells[selected_hunter]
	assigned_cells[selected_hunter] = index

func start_combat() -> void:
	if running or transition_elapsed>=0 or not app.application_active or app.modal:return
	transition_elapsed = 0.0
	preparation.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	combat.show()
	combat.modulate.a = 0.0
	battle_header.modulate.a = 0.0
	battle_header.show()
	update_toggles()

func advance_transition(delta: float) -> void:
	transition_elapsed += delta
	var progress := clampf(transition_elapsed/TRANSITION_SECONDS,0,1)
	approach = smoothstep(.16,1.0,progress)
	var fade := 1.0-smoothstep(0.0,.38,progress)
	placement_grid.modulate.a = fade
	preparation.modulate.a = fade
	combat.modulate.a = smoothstep(.45,1.0,progress)
	battle_header.modulate.a = 1.0-fade
	var header_progress := 1.0-fade
	location_brush.position = Vector2(10,1).lerp(Vector2(25,18),header_progress)
	location_brush.size = Vector2(220,56).lerp(Vector2(198,41),header_progress)
	location_caption.position = Vector2(44,0).lerp(Vector2(21,0),header_progress)
	location_caption.size = Vector2(163,56).lerp(Vector2(160,41),header_progress)
	exit_button.position = Vector2(10,5).lerp(Vector2(16,18),header_progress)
	auto_button.position = Vector2(840,4).lerp(Vector2(840,22),header_progress)
	speed_button.position = Vector2(894,4).lerp(Vector2(896,22),header_progress)
	var matching := sin(progress*PI)*22.0
	ally_hud.position.x = -matching
	enemy_hud.position.x = matching
	for index in versus_letters.size():
		var beat := clampf((progress-.1-index*.18)/.42,0.0,1.0)
		versus_letters[index].scale = Vector2.ONE*(1.0+.40*sin(beat*PI))
	if progress>=1.0:
		transition_elapsed = -1.0
		preparation.hide()
		placement_grid.hide()
		combat_layout = true
		running = true
func use_skill(id: String) -> void:
	if not running or result_shown or exit_popup or app.modal or not app.application_active or not rules.use_skill(id):return
	play_pose(id)
	update_combat_ui()

func play_pose(id: String) -> void:
	pose = id
	pose_clock = 0.0

func _process(delta: float) -> void:
	if not app.application_active or exit_popup or app.modal:return
	sound_delay = maxf(0.0,sound_delay-delta)
	var elapsed := delta*speed
	pose_clock += elapsed
	basic_recoil = maxf(0.0,basic_recoil-elapsed)
	if transition_elapsed>=0:
		advance_transition(elapsed)
	elif running and not result_shown:
		var move := rules.advance(elapsed)
		if not move.is_empty():play_pose(move)
		if pose in ["thrust","auto_thrust","strike","team"] and pose_clock>=.26 and pose_clock-elapsed<.26:
			basic_recoil = BASIC_RECOIL_TIME
			app.audio.cue("hunt_impact")
	if running:
		for id in ready_flashes:ready_flashes[id] = maxf(0.0,ready_flashes[id]-elapsed)
		update_combat_ui(elapsed)
		if not result_shown and not rules.outcome.is_empty():show_result()
	if result_shown:
		result_timer -= delta
		if result_timer<=0:
			app.close_hunt()
			return
	actor_delta += elapsed
	if actor_delta>=1.0/30.0:
		update_actors(actor_delta)
		actor_delta = 0.0
	update_camera(delta)
	battlefield.queue_redraw()

func update_combat_ui(delta := 0.0) -> void:
	var weight := 1.0-exp(-delta*15.0)
	hunter_bar.value = lerpf(hunter_bar.value,rules.hunter_hp,weight)
	deer_bar.value = lerpf(deer_bar.value,rules.deer_hp,weight)
	prey_hp.value = deer_bar.value
	deer_health_text.text = "%d / %d"%[rules.deer_hp,RULES.MAX_HP]
	var filled := rules.orbs()
	var chime := filled>last_orbs or rules.orb_filled
	for index in orb_icons.size():
		var orb := orb_icons[index]
		orb.texture = ORB_FULL if index<filled else ORB_EMPTY
		if index>=last_orbs and index<filled:
			orb.pivot_offset = orb.size*.5
			orb.scale = Vector2.ONE*1.23
		orb.scale = orb.scale.lerp(Vector2.ONE,weight)
	last_orbs = filled
	for id in skill_buttons:
		var control: DemoButton = skill_buttons[id]
		var layers: Dictionary = skill_layers[id]
		var ready := running and rules.can_use(id)
		var charged: bool = id!="thrust" and running and rules.orbs()>=RULES.SKILLS[id].cost and rules.orb_lock<=0
		if charged and not layers.get("charged",false):
			ready_flashes[id] = .36
			chime = true
		layers.charged = charged
		control.disabled = not ready
		layers.base.visible = ready
		layers.icon.visible = ready
		layers.disabled.visible = not ready
		layers.effect.visible = ready and (ready_flashes[id]>0 or control.is_pressed())
		layers.effect.modulate.a = 1.0 if control.is_pressed() else ready_flashes[id]/.36
		for cost in layers.costs:cost.texture = ORB_FULL if charged else ORB_EMPTY
	if chime and sound_delay<=0:
		app.audio.cue("gain")
		sound_delay = .24

func update_camera(delta: float) -> void:
	var focus := Vector2(480,285).lerp(Vector2(495,305),approach)
	var target := zoom * lerpf(1.0,1.07,approach)
	if pose in ["strike","team"] and pose_clock < RULES.POSE_SECONDS:
		var accent := sin(pose_clock/RULES.POSE_SECONDS*PI)
		var center := hunters[0].position
		if pose=="team":
			for index in range(1,hunters.size()):center += hunters[index].position
			center /= hunters.size()
		focus = focus.lerp(center,.45*accent)
		target += .12*accent
	var weight := 1.0-exp(-delta*11.0)
	battlefield.scale = battlefield.scale.lerp(Vector2.ONE*target,weight)
	var anchor := Vector2(480,285).lerp(focus,clampf((battlefield.scale.x-1.0)*2.0,0.0,1.0))
	battlefield.position = battlefield.position.lerp(anchor-focus*battlefield.scale,weight)
	ground.scale = battlefield.scale
	ground.position = (size-size*ground.scale)*.5 + (battlefield.position + DESIGN*(battlefield.scale-Vector2.ONE)*.5)*canvas.scale
	ground.position = ground.position.clamp(size-size*ground.scale,Vector2.ZERO)

func update_actors(delta: float) -> void:
	if absf(camera_progress-approach)>.001:
		camera_progress = approach
		for hunter in hunters:
			hunter.camera.position.y = lerpf(7.45,5.7,approach)
			hunter.camera.look_at(Vector3(0,1.45,0))
			hunter.display.position = -hunter.camera.unproject_position(Vector3.ZERO)*hunter.display.scale
		deer.camera.position.y = lerpf(7.0,5.4,approach)
		deer.camera.look_at(Vector3(0,1,0))
		deer.update_geometry()
	var beat := sin(clampf(pose_clock/.52,0,1)*PI)
	var basic_attack := pose in ["thrust","auto_thrust"]
	for i in hunters.size():
		var hunter := hunters[i]
		var attack := running and pose_clock<.52 and pose!="counter" and (i==0 or pose=="team")
		var dodge := running and pose=="counter" and i==0
		var base := cell_center(ALLY_ORIGIN,assigned_cells[i]).lerp(HUNTER_SLOTS[i],approach)
		hunter.scale = Vector2.ONE*lerpf(.60,.76,approach)
		var lunge := 64 if basic_attack else 32
		hunter.position = base + Vector2((lunge if attack else -18 if dodge else 0)*beat,-5*beat if attack else 0)
		var heading := Vector2(1,.55).lerp(Vector2.RIGHT,approach)
		hunter.animate(delta,heading,pose_clock*12,dodge or transition_elapsed>=0,"" if not attack else "hunt",pose_clock,false)
		if attack:
			hunter.blend_bone("spine",Vector3(.10+beat*.12,0,-.08),.9)
			hunter.blend_bone("armR",Vector3(-.88-beat*.38,0,-.15),1)
			hunter.blend_bone("forearmR",Vector3(-.95+beat*.75,0,0),1)
		if not running and transition_elapsed<0:
			hunter.blend_bone("spine",Vector3(.21,0,-.09),.65)
			hunter.blend_bone("armR",Vector3(-.48,0,-.2),.65)
			hunter.blend_bone("forearmR",Vector3(-.63,0,0),.65)
		hunter.tool_3d.visible = true
		hunter.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var charge := running and pose=="counter"
	var deer_motion := Vector2(-29,-8) if charge else Vector2.ZERO if basic_attack else Vector2(23,-8)
	deer.position = cell_center(ENEMY_ORIGIN,4).lerp(DEER_SLOT,approach)+(deer_motion*beat if running else Vector2.ZERO)
	if basic_recoil>0:
		deer.position += Vector2(13,-3)*basic_recoil/BASIC_RECOIL_TIME
	deer.scale = Vector2.ONE*lerpf(.60,.86,approach)
	deer.walking = beat if running else 1.0 if transition_elapsed>=0 else 0.0
	deer.heading = lerp_angle(-PI*.34,-PI*.72,approach)
	deer.gait_phase = pose_clock*14
	deer.clock += delta
	deer.animate_rig(delta)
	prey_hud.position = deer.position + Vector2(0,-deer.world_height*deer.scale.y-17)
	prey_hud.visible = combat_layout

func draw_stage() -> void:
	if not combat_layout:return
	if basic_recoil>0:
		var hit := deer.position+Vector2(-24,-39)
		var fade := basic_recoil/BASIC_RECOIL_TIME
		for direction in [Vector2(-1,-.5),Vector2(-1,0),Vector2(-1,.5)]:
			battlefield.draw_line(hit+direction*4,hit+direction*(12+5*(1-fade)),Color(1,.89,.64,fade),2,true)


func show_result() -> void:
	result_shown = true
	rules.set_auto(false)
	update_toggles()
	result_timer = 1.6
	var panel := plaque(combat,Rect2(310,208,340,108),Color("503317"),Color("e2b273"))
	caption(panel,"사냥 성공" if rules.outcome=="win" else "사냥 실패",Rect2(Vector2.ZERO,panel.size),32)
