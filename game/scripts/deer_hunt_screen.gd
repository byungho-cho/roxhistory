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
const OBJECTIVE := preload("res://assets/ui/hunting-v006/objective-parchment.png")
const NAME_BRUSH := preload("res://assets/ui/brush/resource-slot-brush@2x.png")
const TRANSITION_SECONDS := 0.8
const SPEAR := preload("res://assets/ui/hunting-v006/primary-spear.png")
const AXE := preload("res://assets/ui/hunting-v006/strong-attack.png")
const HERO_MARK := preload("res://assets/ui/hunting-v006/cooperative-disabled.png")
const HUNTER_SLOTS := [Vector2(434,322),Vector2(360,288),Vector2(350,347)]
const DEER_SLOT := Vector2(568,320)

var app: Node
var rules := RULES.new()
var canvas: Control
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
var versus: Control
var versus_letters: Array[TextureRect] = []
var deer_health_text: Label
var transition_elapsed := -1.0
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
const BASIC_IMPACT_TIME := 0.26
const BASIC_RECOIL_TIME := 0.19
var basic_recoil := 0.0
var actor_delta := 0.0
var pose := ""
var exit_button: DemoButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground: TextureRect = app.picture(self,CLEARING,Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = DESIGN
	add_child(canvas)
	canvas.draw.connect(draw_stage)
	placement_grid = layer()
	for i in 9:
		app.picture(placement_grid,ALLY_CELL,Rect2(cell_center(ALLY_ORIGIN,i)-CELL_SIZE*.5,CELL_SIZE))
		app.picture(placement_grid,ENEMY_CELL,Rect2(cell_center(ENEMY_ORIGIN,i)-CELL_SIZE*.5,CELL_SIZE))
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
	var roster: TextureRect = app.picture(preparation,preload("res://assets/ui/hunting-formation/roster.png"),Rect2(10,102.5,165,355))
	var ink := Color("49321e")
	caption(roster,"출전 편성",Rect2(26,78,141,20),17,ink)
	caption(roster,"%d / 3"%hunters.size(),Rect2(49,98,91,17),15,ink)
	for index in hunters.size():
		var card := make_button(roster,"",Rect2(49,114+59*index,80,56),select_hunter.bind(index))
		clear_button_art(card)
		card.name = "Hunter%d"%index
		var frame: TextureRect = app.picture(card,PORTRAIT_FRAME,Rect2(0,0,80,56))
		portrait_frames.append(frame)
		var portrait: TextureRect = app.picture(card,hunter_portrait(index),Rect2(5,2,70,51))
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		app.picture(card,preload("res://assets/ui/hunting-formation/swap.svg"),Rect2(61,37,19,19))
	select_hunter(0)
	FigmaArt.button(preparation,"gold",Rect2(700,452.5,240,67.5),"전투 시작",start_combat,app).name = "StartBattle"
	var quick := make_button(preparation,"빠른 출전",Rect2(525,462.5,160,55),func():pass)
	quick.disabled = true
	var plaque_art: TextureRect = app.picture(preparation,preload("res://assets/ui/hunting-v006/forest-title-wood.png"),Rect2(12,475,150,37))
	caption(plaque_art,"사냥 준비",Rect2(0,0,150,37),16)
	var bag := make_button(preparation,"",Rect2(138,464,56,62),app.inventory_summary)
	clear_button_art(bag)
	app.picture(bag,preload("res://assets/ui/hunting-formation/bag.png"),Rect2(2,0,52,48))
	app.picture(bag,NAME_BRUSH,Rect2(0,43,56,19))
	caption(bag,"가방",Rect2(4,41,48,19),13)

func clear_button_art(control: DemoButton) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state,StyleBoxEmpty.new())

func select_hunter(index: int) -> void:
	if transition_elapsed>=0 or running:return
	selected_hunter = index
	for i in portrait_frames.size():
		portrait_frames[i].texture = PORTRAIT_SELECTED if i==index else PORTRAIT_FRAME
	if duel_ally_portrait:
		duel_ally_portrait.texture = hunter_portrait(index)

func build_duel_header() -> void:
	var header := layer()
	var place: TextureRect = app.picture(header,NAME_BRUSH,Rect2(25,18,198,41))
	caption(place,"숲 가장자리",Rect2(21,0,160,41),20)
	exit_button = make_button(header,"",Rect2(10,12,48,48),app.close_hunt)
	exit_button.name = "ExitHunt"
	exit_button.tooltip_text = "뒤로가기"
	clear_button_art(exit_button)
	app.picture(exit_button,FigmaArt.texture("back"),Rect2(0,0,48,48))
	ally_hud = layer(header)
	enemy_hud = layer(header)
	hunter_bar = hp_bar(ally_hud,Rect2(339,32,160,32),Color("83b914"))
	deer_bar = hp_bar(enemy_hud,Rect2(552,32,160,32),Color("dc3218"))
	deer_health_text = caption(deer_bar,"",Rect2(0,0,160,32),15)
	deer_health_text.add_theme_color_override("font_outline_color",Color("331a12"))
	deer_health_text.add_theme_constant_override("outline_size",4)
	var ally_icon := plaque(ally_hud,Rect2(297,24,48,48),Color("1c291f"),Color("f2bd4d"))
	duel_ally_portrait = app.picture(ally_icon,hunter_portrait(selected_hunter),Rect2(2,2,44,44))
	var deer_icon := plaque(enemy_hud,Rect2(706,24,48,48),Color("331a12"),Color("f2bd4d"))
	var atlas := preload("res://assets/ui/hunting-formation/deer-head.png")
	var deer_crop := Rect2(456.94/603.33*2172,15.28/201.11*724,100.0/603.33*2172,100.0/201.11*724)
	app.picture(deer_icon,crop(atlas,deer_crop),Rect2(2,2,44,44))
	versus = layer(header)
	app.picture(versus,preload("res://assets/ui/hunting-formation/vs-backdrop.svg"),Rect2(507,30,36,36))
	versus_letters.append(app.picture(versus,preload("res://assets/ui/hunting-formation/vs-v.svg"),Rect2(510,37,18,22.5)))
	versus_letters.append(app.picture(versus,preload("res://assets/ui/hunting-formation/vs-s.svg"),Rect2(522.3,37,18,22.5)))
	for letter in versus_letters:letter.pivot_offset = letter.size*.5
	var auto := plaque(header,Rect2(840,24,48,48),Color("0e0f11"),Color("8c8f94"))
	var speed := plaque(header,Rect2(894,24,48,48),Color("0e0f11"),Color("8c8f94"))
	for control in [auto,speed]:
		control.add_theme_stylebox_override("panel",box(Color("0e0f11"),Color("8c8f94"),24))
	app.picture(auto,preload("res://assets/ui/hunting-formation/auto.svg"),Rect2(10,10,28,28))
	caption(speed,"×2",Rect2(0,0,48,48),21)
func build_combat() -> void:
	combat = layer()
	combat.hide()
	combat_controls = layer(combat)
	var objective: TextureRect = app.picture(combat_controls,OBJECTIVE,Rect2(338,477,300,36))
	var objective_text := caption(objective,"사슴을 처치하세요",Rect2(Vector2.ZERO,objective.size),21)
	objective_text.add_theme_color_override("font_outline_color",Color("492f1b"))
	objective_text.add_theme_constant_override("outline_size",5)
	# Secondary controls are added above the primary control for overlapping taps.
	add_skill("thrust",Rect2(819,399,110,110),SPEAR)
	add_skill("strike",Rect2(833,341,66,66),AXE)
	add_skill("team",Rect2(775,383,63,63),HERO_MARK)
	var gauge_plate: TextureRect = app.picture(combat_controls,preload("res://assets/ui/hunting-v006/charge-value-plate.svg"),Rect2(827,511,93,23))
	gauge_text = caption(gauge_plate,"0 / 100",Rect2(Vector2.ZERO,gauge_plate.size),17)

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
	for style in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	var icon: TextureRect = app.picture(control,texture,Rect2(Vector2.ZERO,rect.size))
	var grayscale := Shader.new()
	grayscale.code = "shader_type canvas_item; uniform bool gray = false; uniform bool team = false; void fragment(){vec4 c=COLOR; if(gray){c.rgb=vec3(dot(c.rgb,vec3(0.299,0.587,0.114)));} else if(team){c.rgb*=vec3(1.0,0.83,0.52);} COLOR=c;}"
	var material := ShaderMaterial.new()
	material.shader = grayscale
	material.set_shader_parameter("team",id=="team")
	icon.material = material
	skill_icons[id] = material
	caption(control,str(info.cost),Rect2(0,rect.size.y*.71,rect.size.x,22),17)
	skill_buttons[id] = control
	ready_flashes[id] = 0.0

func _gui_input(event: InputEvent) -> void:
	if transition_elapsed>=0 or running or not app.application_active or app.modal:return
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

func advance_transition(delta: float) -> void:
	transition_elapsed += delta
	var progress := clampf(transition_elapsed/TRANSITION_SECONDS,0,1)
	approach = smoothstep(.16,1.0,progress)
	var fade := 1.0-smoothstep(0.0,.38,progress)
	placement_grid.modulate.a = fade
	preparation.modulate.a = fade
	combat.modulate.a = smoothstep(.45,1.0,progress)
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
	if not running or not app.application_active or not rules.use_skill(id):return
	play_pose(id)
	update_combat_ui()

func play_pose(id: String) -> void:
	pose = id
	pose_clock = 0.0

func _process(delta: float) -> void:
	if not app.application_active:return
	pose_clock += delta
	basic_recoil = maxf(0.0,basic_recoil-delta)
	if transition_elapsed>=0:advance_transition(delta)
	if running and not result_shown:
		for move in rules.advance(delta):
			play_pose(move)
		if pose_clock>=BASIC_IMPACT_TIME and rules.resolve_basic_impact():
			basic_recoil = BASIC_RECOIL_TIME
			app.audio.cue("hunt_impact")
		for id in ready_flashes:
			ready_flashes[id] = maxf(0,ready_flashes[id]-delta)
		update_combat_ui()
		if not rules.outcome.is_empty():show_result()
	if result_shown:
		result_timer -= delta
		if result_timer<=0:
			app.close_hunt()
			return
	actor_delta += delta
	if actor_delta>=1.0/30.0:
		update_actors(actor_delta)
		actor_delta = 0.0
	canvas.queue_redraw()

func update_combat_ui() -> void:
	hunter_bar.value = rules.hunter_hp
	deer_bar.value = rules.deer_hp
	deer_health_text.text = "%d / %d"%[rules.deer_hp,RULES.MAX_HP]
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
	var basic_attack := pose in ["thrust","auto_thrust"]
	for i in hunters.size():
		var hunter := hunters[i]
		var attack := running and pose_clock<.52 and pose!="counter" and (i==0 or pose=="team")
		var dodge := running and pose=="counter" and i==0
		var base := cell_center(ALLY_ORIGIN,assigned_cells[i]).lerp(HUNTER_SLOTS[i],approach)
		hunter.scale = Vector2.ONE*lerpf(.60,.89,approach)
		var lunge := 64 if basic_attack else 32
		hunter.position = base + Vector2((lunge if attack else -18 if dodge else 0)*beat,-5*beat if attack else 0)
		var heading := Vector2(1,-.65).lerp(Vector2.RIGHT,approach)
		hunter.animate(delta,heading,pose_clock*12,dodge or transition_elapsed>=0,"" if not attack else "hunt",pose_clock,false)
		if attack:
			hunter.blend_bone("spine",Vector3(.10+beat*.12,0,-.08),.9)
			hunter.blend_bone("armR",Vector3(-.88-beat*.38,0,-.15),1)
			hunter.blend_bone("forearmR",Vector3(-.95+beat*.75,0,0),1)
		hunter.tool_3d.visible = true
		hunter.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var charge := running and pose=="counter"
	var deer_motion := Vector2(-29,-8) if charge else Vector2.ZERO if basic_attack else Vector2(23,-8)
	deer.position = cell_center(ENEMY_ORIGIN,4).lerp(DEER_SLOT,approach)+(deer_motion*beat if running else Vector2.ZERO)
	if basic_recoil>0:
		deer.position += Vector2(13,-3)*basic_recoil/BASIC_RECOIL_TIME
	deer.scale = Vector2.ONE*lerpf(.67,1.0,approach)
	deer.walking = beat if running else 1.0 if transition_elapsed>=0 else 0.0
	deer.gait_phase = pose_clock*14

func draw_stage() -> void:
	if not combat_layout:return
	if basic_recoil>0:
		var hit := deer.position+Vector2(-24,-39)
		var fade := basic_recoil/BASIC_RECOIL_TIME
		for direction in [Vector2(-1,-.5),Vector2(-1,0),Vector2(-1,.5)]:
			canvas.draw_line(hit+direction*4,hit+direction*(12+5*(1-fade)),Color(1,.89,.64,fade),2,true)
	var center := Vector2(874,454)+combat_controls.position
	canvas.draw_arc(center,59,-1.24,1.31,38,Color("15272b"),9,true)
	if rules.gauge>0:
		canvas.draw_arc(center,59,-1.24,lerpf(-1.24,1.31,rules.gauge/RULES.MAX_GAUGE),38,Color("57deff"),6,true)
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
