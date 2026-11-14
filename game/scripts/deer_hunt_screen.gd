extends Control

signal preparation_ready

const MATCH := preload("res://scripts/hunt_match_art.gd")
const RULES := preload("res://scripts/deer_hunt_rules.gd")
const DESIGN := Vector2(960,540)
const CLEARING := preload("res://assets/ui/hunting-formation/clearing-dirt.png")
const ALLY_CELL := preload("res://assets/ui/hunting-formation/ally-cell.svg")
const ENEMY_CELL := preload("res://assets/ui/hunting-formation/enemy-cell.svg")
const APPROVED_DEER := preload("res://assets/ui/hunting-combat/png/common/deer-approved.png")
const IMPACT_SECONDS := RULES.POSE_SECONDS * .5
const PORTRAITS := preload("res://assets/ui/hunting-formation/portraits.png")
# Final 1920×1080 placement centers expressed in the 960×540 game canvas.
const ALLY_CELLS := [Vector2(396.5,377.5),Vector2(422.75,321.75),Vector2(475.25,358.75),
	Vector2(449,266),Vector2(501.5,303),Vector2(554,340)]
const ENEMY_CELLS := [Vector2(686.5,172.5),Vector2(607.75,191.25),Vector2(660.25,228.25),
	Vector2(529,210),Vector2(581.5,247),Vector2(634,284)]
const CELL_SIZE := Vector2(87.74,62.52)
const NAME_BRUSH := preload("res://assets/ui/brush/resource-slot-brush@2x.png")
const MATCH_SEQUENCE := preload("res://scripts/hunt_match_sequence.gd")
const TRANSITION_SECONDS := 2.35
const HUNT_AUDIO := preload("res://scripts/hunt_audio.gd")
const HUNTER_BATTLE_CENTER := Vector2(521,279)
const FORMATION_CENTER := Vector2(473,325)
const DEER_SLOT := Vector2(598,245)

var app: Node
var rules := RULES.new()
var canvas: Control
var header: Control
var match_details: Control
var match_shade: ColorRect
var match_impact: TextureRect
var impact_atlas: AtlasTexture
var impact_sheets: Array[Texture2D] = []
var arrival_variant: int
var arrival_duration: float
var arrival_finished := false
var arrival_skip_pointer := -2
var match_vs: Dictionary
var match_deer: TextureRect
var match_home := Vector2.ZERO
var arrival_elapsed := 0.0
var hunter_markers: Array[Control] = []
var hunter_field_bars: Array[TextureProgressBar] = []
var roster_edge: Control
var footer_left: Control
var footer_right: Control
var header_left: Control
var header_right: Control
var power_header: Control
var battlefield: Control
var ground: TextureRect
var zoom := 1.0
var pan := Vector2.ZERO
var pan_pointer := -2
var pan_last := Vector2.ZERO
var pan_start := Vector2.ZERO
var pan_moved := false
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
var portrait_frames: Array[Panel] = []
var assigned_cells: Array[int] = [3,5]
var selected_hunter := 0
var drag_pointer := -2
var drag_start := Vector2.ZERO
var drag_cell := -1
var dragging := false
var drag_ghost: Sprite2D
var hunt_audio = HUNT_AUDIO.new()
var battle_music_started := false
var impact_pending := false
var last_step := -1
var approach := 0.0
var ally_hud: Control
var enemy_hud: Control
var duel_ally_portrait: TextureRect
var prep_ally_portrait: TextureRect
var battle_header: Control
var location_brush: TextureRect
var location_caption: Label
var versus: Control

var deer_health_text: Label
var hunter_health_text: Label
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

var pose_clock := 1.0
var female_approach_phase := 0.0
const BASIC_RECOIL_TIME := 0.19
var basic_recoil := 0.0
var actor_delta := 0.0
var pose := ""
var exit_button: DemoButton

func _ready() -> void:
	add_child(hunt_audio)
	mouse_filter = Control.MOUSE_FILTER_STOP
	ground = app.picture(self,CLEARING,Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = DESIGN
	add_child(canvas)
	battlefield = layer()
	build_scenery()
	battlefield.draw.connect(draw_stage)
	placement_grid = layer(battlefield)
	for i in ALLY_CELLS.size():
		app.picture(placement_grid,ALLY_CELL,Rect2(ALLY_CELLS[i]-CELL_SIZE*.5,CELL_SIZE))
		app.picture(placement_grid,ENEMY_CELL,Rect2(ENEMY_CELLS[i]-CELL_SIZE*.5,CELL_SIZE))
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	battlefield.add_child(actors)
	for model in [HybridCharacter.MESHY_HUNT_MODEL, "res://assets/characters/residents/sturdy_male.glb"]:
		var hunter := HybridCharacter.new()
		hunter.model_path = model
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
	build_arrival()

func build_scenery() -> void:
	# The supplied dirt painting already includes edge clouds and foliage.
	# This small rock uses a distinct unpainted location and remains independent.
	var rock := MATCH.picture(battlefield,preload("res://assets/environment/rock-v018.png"),Rect2(767,346,38,25))
	rock.name = "ReactiveRock"
	rock.pivot_offset = Vector2(rock.size.x*.5,rock.size.y*.85)


func fit_layout() -> void:
	var safe_start := Vector2.ZERO
	var safe_end := size
	if OS.has_feature("android"):
		var area := DisplayServer.get_display_safe_area()
		var physical := Vector2(DisplayServer.screen_get_size())
		if physical.x>0 and physical.y>0 and area.has_area():
			safe_start = (Vector2(area.position)*size/physical).clamp(Vector2.ZERO,size)
			safe_end = (Vector2(area.end)*size/physical).clamp(safe_start,size)
	var safe_size := safe_end-safe_start
	var fit := maxf(.1,minf(safe_size.x/DESIGN.x,safe_size.y/DESIGN.y))
	canvas.scale = Vector2.ONE*fit
	canvas.position = safe_start+(safe_size-DESIGN*fit)*.5
	var start := (safe_start-canvas.position)/fit
	var end := (safe_end-canvas.position)/fit
	var margin := Vector2.ONE*10.0
	header_left.position = start+margin-Vector2(3,0)
	header_right.position = Vector2(end.x-DESIGN.x-margin.x+3,start.y+margin.y-3)
	match_home = Vector2(240,start.y+margin.y)
	if arrival_finished:power_header.position = match_home
	match_shade.position = -canvas.position/fit
	match_shade.size = size/fit
	battle_header.position = Vector2(-45,start.y+margin.y-4)
	roster_edge.position = Vector2(start.x+margin.x,(start.y+end.y-330)*.5)
	footer_left.position = Vector2(start.x+margin.x-3,end.y-DESIGN.y-margin.y+2)
	footer_right.position = end-DESIGN-margin+Vector2(3,3)
	combat_controls.position = end-DESIGN
	fit_exit_shade()


func build_arrival() -> void:
	var forced := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hunt-match="):
			forced = arg.get_slice("=",1).to_int()
	var by_ground: Dictionary = ProjectSettings.get_setting("roxhistory/hunt/match_variants_by_ground",{})
	arrival_variant = MATCH_SEQUENCE.choose("forest_edge",forced,by_ground)
	arrival_duration = 5.55 if arrival_variant==1 else 6.30
	for effect in (["soft"] if arrival_variant==1 else ["medium","strong"]):
		impact_sheets.append(load("res://assets/ui/hunting-match/effects/impact_%s.png" % effect) as Texture2D)
	impact_atlas = AtlasTexture.new()
	impact_atlas.filter_clip = true
	match_impact = MATCH.picture(preparation,impact_atlas,Rect2(MATCH_SEQUENCE.CENTER-Vector2(120,120.25),Vector2(240,240)))
	match_impact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	match_impact.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	preparation.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	header.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	advance_arrival(0.0)

func advance_arrival(delta: float) -> void:
	if arrival_finished:
		return
	arrival_elapsed = minf(arrival_duration,arrival_elapsed+delta)
	MATCH_SEQUENCE.render(self)
	if arrival_elapsed>=arrival_duration:
		arrival_finished = true
		match_shade.hide()
		impact_atlas.atlas = null
		impact_sheets.clear()
		preparation.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		header.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		preparation_ready.emit()


func show_match_impact(index: int, elapsed: float) -> void:
	match_impact.visible = elapsed>=0.0 and elapsed<.42 and impact_sheets[index]!=null
	if match_impact.visible:
		var frame := floori(elapsed*30.0)
		impact_atlas.atlas = impact_sheets[index]
		impact_atlas.region = Rect2((frame%4)*320,floori(frame/4.0)*320,320,320)


func crop(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = rect
	result.filter_clip = true
	return result

func hunter_portrait(index: int) -> Texture2D:
	const REGIONS := [Rect2(15,0,675,710),Rect2(725,0,690,710),Rect2(1495,10,610,700)]
	return crop(PORTRAITS,REGIONS[2 if index == 0 else 1])

func build_preparation() -> void:
	preparation = layer()
	match_shade = ColorRect.new()
	match_shade.color = Color8(8,13,16,107)
	match_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation.add_child(match_shade)
	roster_edge = layer(preparation)
	footer_left = layer(preparation)
	footer_right = layer(preparation)
	power_header = layer(preparation)
	var roster := plaque(roster_edge,Rect2(6,0,152,330),Color(0.20,0.17,0.13,.92),Color("a07d50"))
	var ink := Color("49321e")
	caption(roster,"출전 편성",Rect2(11,16,130,25),17,Color("eed9b4"))
	caption(roster,"%d / 2"%hunters.size(),Rect2(31,42,90,21),15,Color("eed9b4"))
	for index in hunters.size():
		var card := make_button(roster,"",Rect2(28,67+85*index,95,77),select_hunter.bind(index))
		clear_button_art(card)
		card.name = "Hunter%d"%index
		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.size = Vector2(95,77)
		card.add_child(frame)
		style_portrait(frame,index==0)
		portrait_frames.append(frame)
		var portrait: TextureRect = app.picture(card,hunter_portrait(index),Rect2(5,2,85,72))
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		app.picture(card,preload("res://assets/ui/hunting-formation/swap.svg"),Rect2(71,53,24,24))
	var start := artwork_button(footer_right,Rect2(797,487,160,50),"사냥 시작","png/preparation/start-battle-background.png",start_combat,ink)
	start.name = "StartBattle"
	var quick := artwork_button(footer_right,Rect2(629,487,160,50),"빠른 출전","png/preparation/quick-sortie-background.png",func():pass)
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
	var positions := [Rect2(3,490.5,23.506,37),Rect2(26.506,490.5,101.99,37),Rect2(128.496,490.5,23.41,37)]
	for index in regions.size():
		var region: Rect2 = regions[index]
		var art: TextureRect = app.picture(footer_left,crop(ATLAS,Rect2(region.position*ATLAS.get_size(),region.size*ATLAS.get_size())),positions[index])
		art.stretch_mode = TextureRect.STRETCH_SCALE
	caption(footer_left,"사냥 준비",Rect2(3,490.5,150,37),16)
	var bag := make_button(footer_left,"",Rect2(112,476,56,62),app.inventory_summary)
	clear_button_art(bag)
	app.picture(bag,preload("res://assets/ui/hunting-formation/bag.png"),Rect2(5.2,6,45.6,48))
	var brush_art := preload("res://assets/ui/construction-side-v006/brush.png")
	var brush: TextureRect = app.picture(bag,crop(brush_art,Rect2(0,160,2172,410)),Rect2(0,43,56,17))
	brush.stretch_mode = TextureRect.STRETCH_SCALE
	brush.modulate.a = .8
	caption(bag,"가방",Rect2(4,43,48,17),12)

func build_power_comparison() -> void:
	power_header.pivot_offset = MATCH_SEQUENCE.PIVOT
	match_details = MATCH.layer(power_header,Vector2.ZERO)
	MATCH.backdrop(match_details)

	prep_ally_portrait = MATCH.picture(power_header,hunter_portrait(0),Rect2(MATCH_SEQUENCE.ALLY,Vector2(51.2,51.2)))
	match_deer = MATCH.picture(power_header,APPROVED_DEER,Rect2(MATCH_SEQUENCE.DEER,Vector2(48,63)))
	match_deer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	match_vs = MATCH.versus(power_header,Vector2(240,49),57.4)
	# Forest Edge Lv 1 preview values. The battle rules do not use these ratings.
	MATCH.power(match_details,Vector2(159.8,65),12300)
	MATCH.power(match_details,Vector2(321,65),8000,true)


func clear_button_art(control: DemoButton) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state,StyleBoxEmpty.new())

func style_portrait(frame: Panel, selected: bool) -> void:
	frame.add_theme_stylebox_override("panel",box(Color("146bc1") if selected else Color("202c38"),Color("55bdff") if selected else Color("53616b"),8))


func select_hunter(index: int) -> void:
	if not arrival_finished or transition_elapsed>=0 or running:return
	selected_hunter = index
	hunt_audio.cue("S02")
	for i in portrait_frames.size():
		style_portrait(portrait_frames[i],i==index)
	if prep_ally_portrait:
		prep_ally_portrait.texture = hunter_portrait(index)
	if duel_ally_portrait:
		duel_ally_portrait.texture = hunter_portrait(index)

func build_duel_header() -> void:
	header = layer()
	header_left = layer(header)
	header_right = layer(header)
	location_brush = app.picture(header_left,NAME_BRUSH,Rect2(3,0,220,56))
	location_caption = caption(location_brush,"숲 가장자리",Rect2(44,0,163,56),21)
	exit_button = make_button(header_left,"",Rect2(3,4,48,48),request_exit)
	exit_button.name = "ExitHunt"
	clear_button_art(exit_button)
	app.picture(exit_button,FigmaArt.texture("back"),Rect2(0,0,48,48))
	battle_header = layer(header)
	battle_header.hide()
	ally_hud = layer(battle_header)
	enemy_hud = layer(battle_header)
	hunter_bar = hp_bar(ally_hud,Rect2(339,32,160,32),true,true)
	deer_bar = hp_bar(enemy_hud,Rect2(552,32,160,32),false,true)
	hunter_health_text = caption(hunter_bar,"",Rect2(0,0,155,27),15,Color.WHITE)
	deer_health_text = caption(deer_bar,"",Rect2(0,0,155,27),15,Color.WHITE)
	for text in [hunter_health_text,deer_health_text]:
		text.add_theme_color_override("font_outline_color",Color("331a12"))
		text.add_theme_constant_override("outline_size",4)
	duel_ally_portrait = app.picture(ally_hud,hunter_portrait(selected_hunter),Rect2(303,13,46,49))
	duel_ally_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var deer_portrait: TextureRect = app.picture(enemy_hud,APPROVED_DEER,Rect2(701,11,54,52))
	deer_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# This first encounter uses the same level on both portraits.
	for badge in [[ally_hud,321],[enemy_hud,730]]:
		var brush: TextureRect = app.picture(badge[0],NAME_BRUSH,Rect2(badge[1]-28,57,56,16))
		brush.modulate.a = .8
		caption(brush,"Lv 1",Rect2(0,0,56,16),11)
	versus = MATCH.versus(battle_header,Vector2(525,48),36).root
	auto_button = toggle_control(header_right,Rect2(857,3,48,48),"AUTO","auto",toggle_auto)
	speed_button = toggle_control(header_right,Rect2(909,3,48,48),"X2","speed-2x",toggle_speed)
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
	hunt_audio.cue("S06")
	rules.set_auto(not rules.auto_enabled and transition_elapsed>=0 or running and not rules.auto_enabled)
	update_toggles()

func toggle_speed() -> void:
	if exit_popup or app.modal or result_shown:return
	hunt_audio.cue("S06")
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
	build_level(prey_hud,false)
	prey_hp = hp_bar(layer(prey_hud),Rect2(-29.6,3,59.2,11.84),false)
	for hunter in hunters:
		var marker := layer(battlefield)
		marker.hide()
		hunter_markers.append(marker)
		build_level(marker,true)
		hunter_field_bars.append(hp_bar(layer(marker),Rect2(-18.4,0,36.8,7.36),true))

func build_level(marker: Control, ally: bool) -> void:
	app.picture(marker,NAME_BRUSH,Rect2(-19,-16,38,13)).modulate.a = .8
	caption(marker,"Lv 1",Rect2(-12,-17,30,15),10)
	var badge := ColorRect.new()
	badge.color = Color("368b38") if ally else Color("ac3027")
	badge.position = Vector2(-21,-14)
	badge.size = Vector2(9,9)
	badge.pivot_offset = badge.size*.5
	badge.rotation = PI*.25
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(badge)
	app.picture(marker,preload("res://assets/ui/hunting-match/png/power/stone-spear.png") if ally else preload("res://assets/ui/hunting-match/png/power/deer-head.png"),Rect2(-22,-15,11,11))


func artwork_button(parent: Control, rect: Rect2, label: String, asset: String, action: Callable, ink := Color("fff0d0")) -> DemoButton:
	var button := make_button(parent,"",rect,action)
	clear_button_art(button)
	app.picture(button,load(ART+asset),Rect2(Vector2.ZERO,rect.size))
	caption(button,label,Rect2(Vector2.ZERO,rect.size),24,ink)
	return button

func request_exit() -> void:
	pan_pointer = -2
	clear_formation_drag()
	if not arrival_finished:
		app.close_hunt()
		return
	if transition_elapsed>=0:return
	if app.modal:
		app.close_modal()
		return
	if exit_popup:
		resume_battle()
		return
	if result_shown:return
	if not running and transition_elapsed < 0:
		app.close_hunt()
		return
	hunt_audio.cue("S07")
	exit_popup = layer()
	app.sync_audio()
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
	hunt_audio.paused = false
	hunt_audio.cue("S08")
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

func hp_bar(parent: Control, rect: Rect2, ally: bool, duel := false) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = RULES.MAX_HP if ally else rules.deer_max_hp
	bar.step = 0.0
	bar.value = bar.max_value
	bar.nine_patch_stretch = true
	if duel:
		var track := plaque(parent,rect,Color("523621"),Color("f5bf4f"))
		track.add_theme_stylebox_override("panel",box(Color("523621"),Color("f5bf4f"),8))
	else:
		app.picture(parent,preload("res://assets/ui/hunting-combat/png/common/hp-track.png"),rect)
	bar.texture_progress = preload("res://assets/ui/hunting-combat/png/common/hp-fill-ally.png") if ally else preload("res://assets/ui/hunting-combat/png/common/hp-fill-enemy.png")
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	var inset := Vector2.ONE*(2.5 if duel else minf(2.0,rect.size.y*.12))
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

func handle_arrival_skip(event: InputEvent) -> bool:
	var pointer := -2
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = -1
	if pointer == -2:return false
	if pointer == arrival_skip_pointer:
		if not event is InputEventScreenDrag and not event.pressed:
			arrival_skip_pointer = -2
		return true
	if arrival_finished or not app.application_active or app.modal or not event.is_pressed() or event.is_canceled():
		return false
	arrival_skip_pointer = pointer
	advance_arrival(arrival_duration)
	return true


func _input(event: InputEvent) -> void:
	if result_shown: return
	if handle_arrival_skip(event):
		get_viewport().set_input_as_handled()
		return
	if drag_pointer!=-2 and handle_formation_pointer(event,true):
		get_viewport().set_input_as_handled()
		return
	if pan_pointer!=-2 and event is InputEventMouse and handle_pan(event,event.position):
		get_viewport().set_input_as_handled()
		return
	if not arrival_finished or transition_elapsed>=0 or result_shown or exit_popup or app.modal or not app.application_active:
		pan_pointer = -2
		touch_points.clear()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size()>1:pan_pointer = -2
		else:
			touch_points.erase(event.index)
			if pan_pointer==event.index and handle_pan(event,event.position):
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_points.has(event.index):
		var previous: Vector2 = touch_points[event.index]
		touch_points[event.index] = event.position
		if touch_points.size()!=2:
			if pan_pointer==event.index and handle_pan(event,event.position):get_viewport().set_input_as_handled()
			return
		pan_pointer = -2
		var keys := touch_points.keys()
		var other: Vector2 = touch_points[keys[0] if keys[1]==event.index else keys[1]]
		var span := previous.distance_to(other)
		if span>1.0:
			zoom = clampf(zoom*event.position.distance_to(other)/span,1.0,1.30)
			for button in skill_buttons.values():button.clear()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not arrival_finished or exit_popup or not app.application_active or app.modal:return
	if transition_elapsed>=0 or result_shown:return
	if not running and handle_formation_pointer(event,false):
		accept_event()
		return
	if event is InputEventMagnifyGesture:
		zoom = clampf(zoom*event.factor,1.0,1.30)
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		zoom = clampf(zoom+(.10 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -.10),1.0,1.30)
		accept_event()
		return
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		if touch_points.size()<2 and handle_pan(event,get_global_transform()*event.position):
			accept_event()
			return
	if running or event.is_canceled():return
	var released: bool = (event is InputEventScreenTouch and not event.pressed) or (
		event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)
	if not released:return
	var at: Vector2 = battlefield.get_global_transform().affine_inverse() * (get_global_transform() * event.position)
	var index := formation_cell(at)
	if index>=0:
		move_hunter(index)
		accept_event()


func handle_pan(event: InputEvent, at: Vector2) -> bool:
	var pointer := -2
	var press := false
	var release := false
	if event is InputEventScreenTouch:
		pointer = event.index
		press = event.pressed
		release = not press
	elif event is InputEventScreenDrag:
		pointer = event.index
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		pointer = -1
		press = event.pressed
		release = not press
	elif event is InputEventMouseMotion:
		pointer = -1
	else:return false
	if not arrival_finished or transition_elapsed>=0 or result_shown or exit_popup or app.modal or not app.application_active:
		pan_pointer = -2
		return false
	if release:
		if pan_pointer!=pointer:return false
		pan_pointer = -2
		return pan_moved or running
	if press:
		if pan_pointer!=-2:return false
		pan_pointer = pointer
		pan_last = at
		pan_start = at
		pan_moved = false
		return true
	if pan_pointer!=pointer:return false
	if not pan_moved and at.distance_to(pan_start)<7.0:return true
	pan_moved = true
	var margin := Vector2(45,25)+DESIGN*(zoom-1.0)*.15
	pan = (pan+(at-pan_last)/canvas.scale).clamp(-margin,margin)
	pan_last = at
	return true


func formation_cell(at: Vector2) -> int:
	for index in ALLY_CELLS.size():
		var gap: Vector2 = (at-ALLY_CELLS[index]).abs()/(CELL_SIZE*.5)
		if gap.x+gap.y<=1.0:return index
	return -1


func handle_formation_pointer(event: InputEvent, global_coordinates: bool) -> bool:
	var pointer := -2
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		pointer = event.index
		pressed = event.pressed
		released = not pressed
	elif event is InputEventScreenDrag:
		pointer = event.index
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		pointer = -1
		pressed = event.pressed
		released = not pressed
	elif event is InputEventMouseMotion:
		pointer = -1
	else:return false
	if not arrival_finished or running or transition_elapsed>=0 or not app.application_active or app.modal:
		clear_formation_drag()
		return false
	var viewport_position: Vector2 = event.position if global_coordinates else get_global_transform()*event.position
	var at := battlefield.get_global_transform().affine_inverse()*viewport_position
	if drag_pointer==-2:
		if not pressed:return false
		for index in hunters.size():
			var feet: Vector2 = ALLY_CELLS[assigned_cells[index]]
			if Rect2(feet-Vector2(22,53),Vector2(44,58)).has_point(at):
				select_hunter(index)
				drag_pointer = pointer
				drag_start = at
				return true
		return false
	if pointer!=drag_pointer:return true
	if released:
		var target := formation_cell(at)
		if not event.is_canceled() and dragging:
			if target>=0 and not pointer_over_preparation_ui(viewport_position):move_hunter(target)
			else:hunt_audio.cue("S05")
		clear_formation_drag()
	elif not pressed:
		if not dragging and at.distance_to(drag_start)>=7:
			dragging = true
			hunt_audio.cue("S03")
		if dragging:
			drag_cell = -1 if pointer_over_preparation_ui(viewport_position) else formation_cell(at)
			update_drag_preview(at)
	return true


func pointer_over_preparation_ui(at: Vector2) -> bool:
	if roster_edge.get_child(0).get_global_rect().has_point(at):return true
	for group in [header_left,header_right,footer_left,footer_right]:
		for control in group.get_children():
			if control is DemoButton and control.get_global_rect().has_point(at):return true
	return false


func update_drag_preview(at: Vector2) -> void:
	var actor := hunters[selected_hunter]
	if not is_instance_valid(drag_ghost):
		drag_ghost = Sprite2D.new()
		drag_ghost.centered = false
		drag_ghost.texture = actor.display.texture
		drag_ghost.texture_filter = actor.display.texture_filter
		drag_ghost.scale = actor.display.scale * actor.scale
		drag_ghost.z_index = 25
		battlefield.add_child(drag_ghost)
	actor.modulate.a = .38
	var feet: Vector2 = ALLY_CELLS[drag_cell] if drag_cell >= 0 else at
	drag_ghost.position = feet + actor.display.position * actor.scale

func clear_formation_drag() -> void:
	if is_instance_valid(drag_ghost):
		drag_ghost.hide()
		drag_ghost.queue_free()
		drag_ghost = null
		for actor in hunters:
			actor.modulate.a = 1.0
	drag_pointer = -2
	drag_cell = -1
	dragging = false


func move_hunter(index: int) -> void:
	if index<0 or index>=ALLY_CELLS.size() or transition_elapsed>=0 or running:return
	if index==assigned_cells[selected_hunter]:return
	var occupying := assigned_cells.find(index)
	if occupying>=0:assigned_cells[occupying] = assigned_cells[selected_hunter]
	assigned_cells[selected_hunter] = index
	hunt_audio.cue("S04")

func start_combat() -> void:
	if not arrival_finished or running or transition_elapsed>=0 or not app.application_active or app.modal:return
	clear_formation_drag()
	pan_pointer = -2
	touch_points.clear()
	pan = Vector2.ZERO
	hunt_audio.cue("S12",2)
	battle_music_started = true
	app.sync_audio()
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
	approach = smoothstep(.06,.98,progress)
	var step := floori(transition_elapsed*4.0)
	if step!=last_step and approach>0.0 and approach<1.0:
		last_step = step
		hunt_audio.cue("S13",0)
		hunt_audio.cue("S14",0)
	var fade := 1.0-smoothstep(0.0,.38,progress)
	placement_grid.modulate.a = fade
	preparation.modulate.a = fade
	combat.modulate.a = smoothstep(.45,1.0,progress)
	battle_header.modulate.a = 1.0-fade
	var header_progress := 1.0-fade
	location_brush.position = Vector2(3,0).lerp(Vector2(3,3),header_progress)
	location_brush.size = Vector2(220,56).lerp(Vector2(198,41),header_progress)
	location_caption.position = Vector2(44,0).lerp(Vector2(21,0),header_progress)
	location_caption.size = Vector2(163,56).lerp(Vector2(160,41),header_progress)
	exit_button.position = Vector2(3,4).lerp(Vector2(3,3),header_progress)
	var matching := sin(progress*PI)*22.0
	ally_hud.position.x = -matching
	enemy_hud.position.x = matching
	if progress>=1.0:
		transition_elapsed = -1.0
		preparation.hide()
		placement_grid.hide()
		combat_layout = true
		running = true
func use_skill(id: String) -> void:
	if not running or result_shown or exit_popup or app.modal or not app.application_active:return
	if not rules.use_skill(id):
		hunt_audio.cue("S25")
		return
	play_pose(id)
	update_combat_ui()

func play_pose(id: String) -> void:
	pose = id
	pose_clock = 0.0
	impact_pending = true
	match id:
		"thrust","auto_thrust":hunt_audio.cue("S15",2)
		"strike":hunt_audio.cue("S17",2)
		"team":hunt_audio.cue("S19",2)

func _process(delta: float) -> void:
	hunt_audio.update(app.application_active and app.settings.get_value("app","sound",true),exit_popup!=null or app.modal)
	if not app.application_active or exit_popup or app.modal:
		clear_formation_drag()
		return
	if result_shown: return
	sound_delay = maxf(0.0,sound_delay-delta)
	if not arrival_finished:
		var before := arrival_elapsed
		advance_arrival(delta)
		var hits := [1.98] if arrival_variant==1 else [1.42,2.04]
		var vs_start := .83 if arrival_variant == 1 else 2.08
		var cues := [.28, vs_start] + hits
		cues.sort()
		for threshold in cues:
			if before<threshold and arrival_elapsed>=threshold:
				hunt_audio.cue("S09" if threshold==.28 else ("S10" if threshold==vs_start else "S11"),2)
	var elapsed := delta*speed
	pose_clock += elapsed
	basic_recoil = maxf(0.0,basic_recoil-elapsed)
	if transition_elapsed>=0:
		advance_transition(delta)
	elif running and not result_shown:
		if impact_pending and pose_clock >= IMPACT_SECONDS:
			rules.resolve_attack()
			impact_pending = false
			if pose=="counter":
				hunt_audio.cue("S21",2)
			else:
				basic_recoil = BASIC_RECOIL_TIME
				hunt_audio.cue("S18" if pose=="strike" else ("S20" if pose=="team" else "S16"),3)
				if pose!="team":hunt_audio.cue("S22",1)
		var move := rules.advance(elapsed)
		if not move.is_empty():play_pose(move)
	if running:
		for id in ready_flashes:ready_flashes[id] = maxf(0.0,ready_flashes[id]-elapsed)
		update_combat_ui(elapsed)
		if not result_shown and not rules.outcome.is_empty() and not impact_pending:show_result()
	if result_shown: return
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
	for bar in hunter_field_bars:bar.value = hunter_bar.value
	hunter_health_text.text = str(rules.hunter_hp)
	deer_health_text.text = str(rules.deer_hp)
	var filled := rules.orbs()
	var filled_now := filled>last_orbs or rules.orb_filled
	var chime := filled_now
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
	if filled_now:
		rules.orb_filled = false
		hunt_audio.cue("S23",2)
		sound_delay = .24
	elif chime and sound_delay<=0:
		hunt_audio.cue("S24",2)
		sound_delay = .24

func update_camera(delta: float) -> void:
	var focus := Vector2(480,285).lerp(Vector2(495,305),approach)
	var target := zoom
	if transition_elapsed>=0:
		target += .12*sin(approach*PI*.5)
	if pose in ["strike","team"] and pose_clock < RULES.POSE_SECONDS:
		var accent := sin(pose_clock/RULES.POSE_SECONDS*PI)
		var center: Vector2 = hunters[rules.attacker].position
		if pose=="team":
			center += hunters[1 - rules.attacker].position
			center /= hunters.size()
		focus = focus.lerp(center,.45*accent)
		target += .12*accent
	var weight := 1.0 if delta==0.0 or not arrival_finished or transition_elapsed>=0 else 1.0-exp(-delta*11.0)
	battlefield.scale = battlefield.scale.lerp(Vector2.ONE*target,weight)
	var anchor := Vector2(480,285).lerp(focus,clampf((battlefield.scale.x-1.0)*2.0,0.0,1.0))
	battlefield.position = battlefield.position.lerp(anchor-focus*battlefield.scale+pan,weight)
	ground.scale = battlefield.scale*1.10
	ground.position = (size-size*ground.scale)*.5 + (battlefield.position + DESIGN*(battlefield.scale-Vector2.ONE)*.5)*canvas.scale
	ground.position = ground.position.clamp(size-size*ground.scale,Vector2.ZERO)

func update_actors(delta: float) -> void:
	if absf(camera_progress-approach)>.001:
		camera_progress = approach
		for hunter in hunters:
			hunter.camera.position.y = lerpf(7.45,7.05,approach)
			hunter.camera.look_at(Vector3(0,1.45,0))
			hunter.display.position = -hunter.camera.unproject_position(Vector3.ZERO)*hunter.display.scale
		deer.camera.position.y = lerpf(7.0,6.65,approach)
		deer.camera.look_at(Vector3(0,1,0))
		deer.update_geometry()
	var beat := sin(clampf(pose_clock/RULES.POSE_SECONDS,0,1)*PI)
	var basic_attack := pose in ["thrust","auto_thrust"]
	for i in hunters.size():
		var hunter := hunters[i]
		var attack := running and pose_clock<RULES.POSE_SECONDS and pose in ["thrust","auto_thrust","strike","team"] and i == rules.attacker
		var dodge := running and pose=="counter" and pose_clock<RULES.POSE_SECONDS and i == rules.attacker
		var placed: Vector2 = ALLY_CELLS[assigned_cells[i]]
		var battle_target := HUNTER_BATTLE_CENTER+(placed-FORMATION_CENTER)*.62
		var base := placed.lerp(battle_target,approach)
		hunter.scale = Vector2.ONE*lerpf(.60,.56,approach)
		var lunge := 42 if basic_attack else 24
		var assisting := running and pose == "team" and pose_clock < RULES.POSE_SECONDS and not attack
		var attack_direction := base.direction_to(DEER_SLOT)
		var previous_position := hunter.position
		hunter.position = base + attack_direction*(lunge if attack else 10 if assisting else -18 if dodge else 0)*beat
		var heading := Vector2(1,.55).lerp(Vector2(1,.28),approach)
		var approaching := transition_elapsed >= 0.0 and approach > 0.0 and approach < 1.0
		var female := hunter.meshy_hunt_rig
		var phase := pose_clock * 12.0
		if female:
			if approaching:
				var travel := previous_position.distance_to(hunter.position)
				female_approach_phase = fposmod(female_approach_phase + travel / (hunter.stride_world_length() * hunter.scale.x) * TAU, TAU)
			phase = female_approach_phase if not dodge else pose_clock * 12.0
		hunter.animate(delta, heading, phase, dodge or approaching, "" if female or not attack else "hunt", pose_clock, false)
		if female or (not attack and not dodge):
			hunter.blend_bone("spine",Vector3(.21,0,-.09),.65)
			hunter.blend_bone("armR",Vector3(-.48,0,-.2),.65)
			hunter.blend_bone("forearmR",Vector3(-.63,0,0),.65)
		if attack and female:
			# Keep the spear attached to the right hand throughout the thrust.
			hunter.blend_bone("spine", Vector3(.34, -.21, -.09), beat)
			hunter.blend_bone("armR", Vector3(-1.39, 0.0, -.2), beat)
			hunter.blend_bone("forearmR", Vector3(-.14, 0.0, 0.0), beat)
			hunter.blend_bone("armL", Vector3(-.43*beat, 0.0, .25*beat), beat)
		elif attack:
			hunter.blend_bone("spine",Vector3(.10+beat*.12,0,-.08),.9)
			hunter.blend_bone("armR",Vector3(-.88-beat*.38,0,-.15),1)
			hunter.blend_bone("forearmR",Vector3(-.95+beat*.75,0,0),1)
		if assisting:
			hunter.blend_bone("spine", Vector3(.30, .08, -.09), beat)
			hunter.blend_bone("armL", Vector3(-.75, 0.0, .18), beat)
		hunter.tool_3d.visible = true
		hunter.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		hunter_markers[i].position = hunter.position+Vector2(0,-63)
		hunter_markers[i].visible = arrival_finished
		hunter_field_bars[i].get_parent().visible = approach>=1.0
	var charge := running and pose=="counter"
	var deer_motion := Vector2(-29,-8) if charge else Vector2.ZERO if basic_attack else Vector2(23,-8)
	deer.position = ENEMY_CELLS[4].lerp(DEER_SLOT,approach)+(deer_motion*beat if running else Vector2.ZERO)
	if basic_recoil>0:
		deer.position += Vector2(13,-3)*basic_recoil/BASIC_RECOIL_TIME
	deer.scale = Vector2.ONE*lerpf(.60,.63,approach)
	deer.walking = 1.0 if transition_elapsed>=0 and approach>0.0 and approach<1.0 else (beat if running and (charge or basic_recoil>0.0) else 0.0)
	deer.heading = lerp_angle(-PI*.34,-PI*.35,approach)
	deer.gait_phase = pose_clock*14
	deer.clock += delta
	deer.animate_rig(delta)
	prey_hud.position = deer.position + Vector2(0,-deer.world_height*deer.scale.y-15)
	prey_hud.visible = arrival_finished
	prey_hp.get_parent().visible = approach>=1.0

func draw_stage() -> void:
	if arrival_finished and transition_elapsed<0 and not combat_layout:
		var cell := drag_cell if dragging and drag_cell>=0 else assigned_cells[selected_hunter]
		var center: Vector2 = ALLY_CELLS[cell]
		var corners := PackedVector2Array([center-Vector2(0,CELL_SIZE.y*.5),center+Vector2(CELL_SIZE.x*.5,0),center+Vector2(0,CELL_SIZE.y*.5),center-Vector2(CELL_SIZE.x*.5,0)])
		battlefield.draw_colored_polygon(corners,Color(.1,.55,1,.35))
		corners.append(corners[0])
		battlefield.draw_polyline(corners,Color(.32,.78,1),2,true)
	if not combat_layout:return
	if basic_recoil>0:
		var hit := deer.position+Vector2(-24,-39)
		var fade := basic_recoil/BASIC_RECOIL_TIME
		for direction in [Vector2(-1,-.5),Vector2(-1,0),Vector2(-1,.5)]:
			battlefield.draw_line(hit+direction*4,hit+direction*(12+5*(1-fade)),Color(1,.89,.64,fade),2,true)


func show_result() -> void:
	if result_shown: return
	result_shown = true
	if rules.outcome == "win":
		app.record_hunt_win()
		hunt_audio.cue("monster_death",4)
	hunt_audio.cue("S26" if rules.outcome=="win" else "S27",4)
	rules.set_auto(false)
	update_toggles()
	running = false
	canvas.hide()
	for hunter in hunters: hunter.set_enabled(false)
	deer.hide()
	deer.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var result := preload("res://scripts/hunt_result.gd").new()
	result.app = app
	result.won = rules.outcome == "win"
	add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
