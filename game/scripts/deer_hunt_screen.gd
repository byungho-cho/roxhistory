extends Control

signal preparation_ready

const Timing := preload("res://scripts/motion_timing.gd")
const SkillHUD := preload("res://scripts/duel_skill_hud.gd")
const HeadHUD := preload("res://scripts/battle_head_hud.gd")
var head_headers:Array=[]
const MATCH := preload("res://scripts/hunt_match_art.gd")
const RULES := preload("res://scripts/deer_hunt_rules.gd")
const DESIGN := Vector2(960,540)
const CLEARING := preload("res://assets/ui/hunting-formation/clearing-dirt.png")
const ALLY_CELL := preload("res://assets/ui/hunting-formation/ally-cell.svg")
const ENEMY_CELL := preload("res://assets/ui/hunting-formation/enemy-cell.svg")
const APPROVED_DEER := preload("res://assets/ui/hunting-combat/png/common/deer-approved.png")
const COMBAT_PREVIEW := preload("res://scripts/hunt_combat_preview.gd")
const IMPACT_ART := "res://assets/ui/hunt-impact/"
const BASIC_HIT := preload(IMPACT_ART+"basic-contact.svg")
const HEAVY_HIT := preload(IMPACT_ART+"heavy-contact.svg")
const GROUND_PULSE := preload(IMPACT_ART+"heavy-ground-pulse.svg")
const ALLY_RING := preload(IMPACT_ART+"team-ally-ellipse.svg")
const ENEMY_RING := preload(IMPACT_ART+"team-opponent-ellipse.svg")
var hit_age := 1.0
var hit_kind := ""
var hit_point := Vector2.ZERO
var hit_origin := Vector2.ZERO
var hit_damage := 0
var hit_on_hunter := false
var hit_label: Label
const IMPACT_SECONDS := RULES.POSE_SECONDS * .5
const HangyeolJump := preload("res://scripts/hangyeol_jump_preview.gd")
const JumpMotion := preload("res://scripts/res011_lab_preview.gd")
# Final 1920×1080 placement centers expressed in the 960×540 game canvas.
const ALLY_CELLS := [Vector2(396.5,377.5),Vector2(422.75,321.75),Vector2(475.25,358.75),
	Vector2(449,266),Vector2(501.5,303),Vector2(554,340)]
const ENEMY_CELLS := [Vector2(686.5,172.5),Vector2(607.75,191.25),Vector2(660.25,228.25),
	Vector2(529,210),Vector2(581.5,247),Vector2(634,284)]
const CELL_SIZE := Vector2(87.74,62.52)
const NAME_BRUSH := preload("res://assets/ui/brush/resource-slot-brush@2x.png")
const PREP_ART := "res://assets/ui/d0026/"
const CARD_ART := "res://assets/ui/d0027/"
const CARD_PORTRAITS := [preload(CARD_ART+"hangeul-portrait.png"),preload(CARD_ART+"uram-portrait.png"),preload(CARD_ART+"saebom-portrait.png")]
const CARD_SKILLS := [preload(CARD_ART+"skill-stab-A.png"),preload(CARD_ART+"skill-hit-B.png"),preload(CARD_ART+"skill-cooperation-A.png")]
const CHARGE_EMPTY := preload(CARD_ART+"charge-empty.png")
const CHARGE_FULL := preload(CARD_ART+"charge-filled.png")
const CARD_TRACK := preload(CARD_ART+"hp-shell.png")
const HEADS := preload(CARD_ART+"approved-three-heads-atlas.png")
const VS_CENTER := Vector2(480,250)
const VS_CONTACT := .63
const VS_SETTLED := 1.38
const TRANSITION_SECONDS := 2.35
const HUNT_AUDIO := preload("res://scripts/hunt_audio.gd")
const HUNTER_BATTLE_CENTER := Vector2(521,279)
const FORMATION_CENTER := Vector2(473,325)
const DEER_SLOT := Vector2(598,245)

var app: Node
var rules := RULES.new()
var canvas: Control
var header: Control
var match_impact: TextureRect
var impact_atlas: AtlasTexture
var arrival_duration: float
var arrival_finished := false
var arrival_skip_pointer := -2
var match_vs: Dictionary
var header_spears: TextureRect
var roster_home: Vector2
var footer_left_home: Vector2
var footer_right_home: Vector2
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
var camera_progress := -1.0
var prey_hud: Control
var prey_hp: TextureProgressBar
var controls_gray: Shader
const ART := "res://assets/ui/hunting-combat/"
var preparation: Control
var combat: Control
var combat_controls: Control
var placement_grid: Control
var portrait_frames: Array[Panel] = []
var assigned_cells: Array[int] = [0,5,3]
var party_cards: Array[Dictionary] = []
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

var deer_health_text: Label
var hunter_health_text: Label
var transition_elapsed := -1.0
var combat_layout := false
var hunters: Array[HybridCharacter] = []
var deer: WorldAnimal
var hunter_bar: TextureProgressBar
var deer_bar: TextureProgressBar
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
	hit_label = app.label(battlefield,"",17,Color("ebf2f0"))
	hit_label.z_index = 3
	hit_label.add_theme_color_override("font_outline_color",Color("1a120f"))
	hit_label.add_theme_constant_override("outline_size",2)
	hit_label.hide()
	placement_grid = layer(battlefield)
	for i in ALLY_CELLS.size():
		app.picture(placement_grid,ALLY_CELL,Rect2(ALLY_CELLS[i]-CELL_SIZE*.5,CELL_SIZE))
		app.picture(placement_grid,ENEMY_CELL,Rect2(ENEMY_CELLS[i]-CELL_SIZE*.5,CELL_SIZE))
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	battlefield.add_child(actors)
	for index in 3:
		var hunter: HybridCharacter = COMBAT_PREVIEW.new() if index == 1 else HangyeolJump.new() if index==0 else HybridCharacter.new()
		if index == 2:hunter.model_path = HybridCharacter.MESHY_HUNT_MODEL
		hunter.render_size_factor = .5
		actors.add_child(hunter)
		hunter.set_enabled(true)
		if index != 1: hunter.use_training_spear()
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
	power_header.position = Vector2(480,start.y+margin.y)
	battle_header.position = Vector2(-45,start.y+margin.y-4)
	roster_home = Vector2(start.x+margin.x,(start.y+end.y-330)*.5)
	footer_left_home = Vector2(start.x+margin.x-3,end.y-DESIGN.y-margin.y+2)
	footer_right_home = end-DESIGN-margin+Vector2(3,3)
	roster_edge.position = roster_home
	footer_left.position = footer_left_home
	footer_right.position = footer_right_home
	combat_controls.position = Vector2(0,end.y-DESIGN.y)
	if combat_layout:
		header_right.position = end-DESIGN
	fit_exit_shade()


func build_arrival() -> void:
	arrival_duration = .97
	var vs_layer := layer()
	vs_layer.z_index = 4
	match_vs = MATCH.versus(vs_layer,VS_CENTER,156)
	match_vs.root.hide()
	impact_atlas = AtlasTexture.new()
	impact_atlas.atlas = preload(PREP_ART+"impact-soft.png")
	impact_atlas.filter_clip = true
	match_impact = MATCH.picture(vs_layer,impact_atlas,Rect2(VS_CENTER-Vector2(93,93),Vector2(186,186)))
	match_impact.hide()
	preparation.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	header.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	advance_arrival(0.0)

func advance_arrival(delta: float) -> void:
	if arrival_finished: return
	arrival_elapsed = minf(arrival_duration,arrival_elapsed+delta)
	for part: Control in [header,power_header,placement_grid]:
		part.modulate.a = smoothstep(0.0,.20,arrival_elapsed)
	var roster_progress := clampf((arrival_elapsed-.13)/.60,0,1)
	var footer_progress := clampf((arrival_elapsed-.29)/.68,0,1)
	roster_edge.modulate.a = smoothstep(0,.55,roster_progress)
	roster_edge.position.x = roster_home.x-22*(1.0-entry_ease(roster_progress))
	for part: Control in [footer_left,footer_right]:
		part.modulate.a = smoothstep(0,.55,footer_progress)
	footer_left.position.y = footer_left_home.y+18*(1.0-entry_ease(footer_progress))
	footer_right.position.y = footer_right_home.y+18*(1.0-entry_ease(footer_progress))
	if arrival_elapsed >= arrival_duration:
		arrival_finished = true
		preparation.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		header.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		fit_layout()
		preparation_ready.emit()

func entry_ease(progress: float) -> float:
	return Tween.interpolate_value(0.0,1.0,progress,1.0,Tween.TRANS_BACK,Tween.EASE_OUT)

func animate_battle_vs(before: float, time: float) -> void:
	var root: Control = match_vs.root
	root.visible = time < VS_SETTLED
	var arrive := smoothstep(.15,VS_CONTACT,time)
	var dock := smoothstep(.78,VS_SETTLED,time)
	root.modulate.a = smoothstep(.15,.38,time)
	root.position = VS_CENTER.lerp(power_header.position+header_spears.get_rect().get_center(),dock)-root.pivot_offset
	root.scale = Vector2.ONE*lerpf(156.0/164.0,44.0/164.0,dock)
	header_spears.visible = not root.visible
	for i in 2:
		var spear: TextureRect = match_vs.spears[i]
		spear.position.x = -18+(1.0-arrive)*(-125 if i==0 else 125)
	var letters: Control = match_vs.letter_layer
	letters.modulate.a = smoothstep(.40,VS_CONTACT,time)*(1.0-smoothstep(1.05,VS_SETTLED,time))
	letters.scale = Vector2.ONE*lerpf(1.18,1.0,smoothstep(VS_CONTACT,.78,time))
	show_match_impact(time-VS_CONTACT)
	match_impact.modulate.a = 1.0-smoothstep(.05,.35,time-VS_CONTACT)
	if before < VS_CONTACT and time >= VS_CONTACT: hunt_audio.cue("S11",2)

func show_match_impact(elapsed: float) -> void:
	match_impact.visible = elapsed>=0.0 and elapsed<.42
	if match_impact.visible:
		var frame := floori(elapsed*30.0)
		impact_atlas.region = Rect2((frame%4)*320,floori(frame/4.0)*320,320,320)


func crop(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = rect
	result.filter_clip = true
	return result

func hunter_portrait(index: int) -> Texture2D:
	return crop(HEADS,Rect2(724*index,0,724,724))

func build_preparation() -> void:
	preparation = layer()
	roster_edge = layer(preparation)
	footer_left = layer(preparation)
	footer_right = layer(preparation)
	power_header = MATCH.layer(canvas,Vector2.ZERO)
	var roster := plaque(roster_edge,Rect2(6,0,152,330),Color(0.20,0.17,0.13,.92),Color("a07d50"))
	var ink := Color("49321e")
	caption(roster,"출전 편성",Rect2(11,16,130,25),17,Color("eed9b4"))
	caption(roster,"%d / %d"%[hunters.size(),RULES.PARTY_HP.size()],Rect2(31,42,90,21),15,Color("eed9b4"))
	for index in hunters.size():
		var card := make_button(roster,"",Rect2(28,65+82*index,95,77),select_hunter.bind(index))
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
	var start := prep_action("사냥 시작",Rect2(797,487,160,50),preload(PREP_ART+"common-gold-default.svg"),start_combat,ink)
	start.name = "StartBattle"
	var quick := prep_action("빠른 출전",Rect2(625,487,160,50),preload(PREP_ART+"common-sapphire-default.svg"),func():pass,Color("fff5df"))
	quick.disabled = true
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
	MATCH.picture(power_header,preload(PREP_ART+"power-comparison-background.svg"),Rect2(-195,2.5,390,82.5))
	prep_ally_portrait = app.picture(power_header,hunter_portrait(selected_hunter),Rect2(-101,15,52,52))
	# This encounter's actual opponent is the deer instantiated above.
	app.picture(power_header,APPROVED_DEER,Rect2(50,8,50,66))
	header_spears = app.picture(power_header,preload(PREP_ART+"header-crossed-spears.png"),Rect2(-22,26,44,42))
	# There is no stored rating. Read the real HP and basic damage for a display-only comparison.
	var ratings := [RULES.MAX_HP*int(RULES.SKILLS.thrust.damage),rules.deer_max_hp*RULES.COUNTER_DAMAGE]
	for i in ratings.size():
		var number := caption(power_header,MATCH.format_power(ratings[i]),Rect2(-130+150*i,55,110,25),21,Color("ffd278"))
		number.add_theme_color_override("font_outline_color",Color("35200e"))
		number.add_theme_constant_override("outline_size",3)

func prep_action(label: String, rect: Rect2, texture: Texture2D, action: Callable, ink: Color) -> DemoButton:
	var button := make_button(footer_right,"",rect,action)
	clear_button_art(button)
	MATCH.picture(button,texture,Rect2(0,9,160,32))
	caption(button,label,Rect2(Vector2.ZERO,rect.size),18,ink)
	return button


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
	app.picture(exit_button,preload(PREP_ART+"back-arrow-alpha.svg"),Rect2(0,0,48,48))
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
	for index in hunters.size():
		var hud:=SkillHUD.new()
		hud.position=Vector2(354.6+92.4*index,437)
		combat_controls.add_child(hud)
		hud.reset(["hangyeol","uram","saebom"][index])
		hud.requested.connect(func(action:String):use_skill(RULES.PARTY_SKILLS[index],2 if action=="skill" else 3))
		party_cards.append({"hud":hud,"button":hud.chain_button,"portrait":hud.portrait,"charges":hud.orbs,"hp":hud.hp})
		var head:=HeadHUD.create(combat_controls,["한결","우람","새봄"][index],true)
		head_headers.append(head)
		hunter_markers.append(head.panel)
		hunter_field_bars.append(head.bar)
	var enemy:=HeadHUD.create(combat_controls,"꽃사슴",false)
	head_headers.append(enemy)
	prey_hud=enemy.panel
	prey_hp=enemy.bar
	prey_hp.max_value=rules.deer_max_hp

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
	app.animate_popup(panel)
	caption(panel,"전투를 종료할까요?",Rect2(0,24,438,48),25,Color("49321e"))
	artwork_button(panel,Rect2(40,85,170,52),"종료","png/popup/exit-button-background.png",app.close_hunt).name = "ExitBattle"
	artwork_button(panel,Rect2(227,85,170,52),"계속","png/popup/continue-button-background.png",resume_battle,Color("49321e")).name = "ContinueBattle"
	# A touch that began before the popup must not activate an underlying skill.
	for card in party_cards:card.hud.reset(card.hud.character)

func fit_exit_shade() -> void:
	if not is_instance_valid(exit_shade):return
	exit_shade.position = -canvas.position/canvas.scale
	exit_shade.size = size/canvas.scale

func resume_battle() -> void:
	hunt_audio.paused = false
	hunt_audio.cue("S08")
	app.stop_popup_openings(exit_popup)
	exit_popup.hide()
	exit_popup.queue_free()
	exit_popup = null

func layer(parent: Control = null) -> Control:
	var result := Control.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(canvas if parent==null else parent).add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

func make_button(parent: Control, title: String, rect: Rect2, callback: Callable, click_cue := "ui") -> DemoButton:
	var button: DemoButton = app.button(parent,title,callback,false,"",click_cue)
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
			for card in party_cards:card.hud.reset(card.hud.character)
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
	battle_music_started = true
	app.sync_audio()
	transition_elapsed = 0.0
	header_spears.hide()
	preparation.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	combat.show()
	combat.modulate.a = 0.0
	update_toggles()

func advance_transition(delta: float) -> void:
	var before := transition_elapsed
	transition_elapsed += delta
	animate_battle_vs(before,transition_elapsed)
	var progress := clampf(transition_elapsed/TRANSITION_SECONDS,0,1)
	approach = smoothstep(.06,.98,progress)
	var step := floori(transition_elapsed*4.0)
	if step!=last_step and approach>0.0 and approach<1.0:
		last_step = step
		if transition_elapsed > VS_CONTACT+.28:
			hunt_audio.cue("S13",0)
			hunt_audio.cue("S14",0)
	var fade := 1.0-smoothstep(0.0,.50,transition_elapsed)
	placement_grid.modulate.a = fade
	preparation.modulate.a = fade
	roster_edge.position.y = roster_home.y+18*(1.0-fade)
	footer_left.position.y = footer_left_home.y+18*(1.0-fade)
	footer_right.position.y = footer_right_home.y+18*(1.0-fade)
	combat.modulate.a = smoothstep(VS_SETTLED,TRANSITION_SECONDS,transition_elapsed)
	var header_progress := 1.0-fade
	location_brush.position = Vector2(3,0).lerp(Vector2(3,3),header_progress)
	location_brush.size = Vector2(220,56).lerp(Vector2(198,41),header_progress)
	location_caption.position = Vector2(44,0).lerp(Vector2(21,0),header_progress)
	location_caption.size = Vector2(163,56).lerp(Vector2(160,41),header_progress)
	exit_button.position = Vector2(3,4).lerp(Vector2(3,3),header_progress)
	if progress>=1.0:
		transition_elapsed = -1.0
		preparation.hide()
		placement_grid.hide()
		combat_layout = true
		running = true
		location_brush.hide()
		for i in 2:
			var control: DemoButton = [auto_button,speed_button][i]
			control.position = Vector2(890,420+57*i)
			control.size = Vector2(50,50)
			var icon := control.get_child(0) as TextureRect
			icon.size = control.size
			icon.texture = [preload(CARD_ART+"auto.png"),preload(CARD_ART+"x2.png")][i]
		fit_layout()
func use_skill(id: String, required_sp:int=3) -> void:
	if not running or result_shown or exit_popup or app.modal or not app.application_active:return
	var index := RULES.PARTY_SKILLS.find(id)
	if index<0 or rules.orbs(index)<required_sp:return
	if not rules.use_skill(id):
		hunt_audio.cue("S25")
		return
	play_pose(id)
	update_combat_ui()

func play_pose(id: String) -> void:
	pose = id
	pose_clock = 0.0
	impact_pending = true
	if id=="thrust":
		rules.action_lock = maxf(rules.action_lock,JumpMotion.JUMP_SECONDS)
	match id:
		"auto_thrust":hunt_audio.cue("S15",2)

func _process(delta: float) -> void:
	hunt_audio.update(app.application_active and app.settings.get_value("app","sound",true),exit_popup!=null or app.modal)
	if not app.application_active or exit_popup or app.modal:
		clear_formation_drag()
		return
	if result_shown: return
	if not arrival_finished:
		advance_arrival(delta)
	var elapsed := delta*speed
	pose_clock += elapsed
	basic_recoil = maxf(0.0,basic_recoil-elapsed)
	hit_age += elapsed
	hit_label.visible = hit_damage > 0 and hit_age < .42
	if hit_label.visible:
		hit_label.position = hit_point+Vector2(18,-22-40*hit_age)
		hit_label.modulate.a = 1.0-smoothstep(.18,.42,hit_age)
	if transition_elapsed>=0:
		advance_transition(delta)
	elif running and not result_shown:
		if impact_pending and pose_clock >= (JumpMotion.JUMP_CONTACT_SECONDS if pose=="thrust" else IMPACT_SECONDS):
			var before_hp := rules.hunter_hp if pose == "counter" else rules.deer_hp
			rules.resolve_attack()
			hit_damage = before_hp - (rules.hunter_hp if pose == "counter" else rules.deer_hp)
			if hit_damage > 0:
				hit_age = 0.0
				hit_kind = pose
				hit_on_hunter = pose == "counter"
				var attacker := hunters[rules.attacker]
				hit_origin = attacker.contact_point() if attacker is COMBAT_PREVIEW or attacker is HangyeolJump else attacker.position + (attacker.tool_contact_world()-attacker.global_position)*attacker.scale
				hit_point = hit_origin if hit_on_hunter else deer.position+Vector2(-18,-37)
				hit_label.text = "−%d" % hit_damage
			impact_pending = false
			if pose=="thrust": hunt_audio.cue("S15",2)
			if pose=="strike": hunt_audio.cue("S18",2)
			if pose=="team": hunt_audio.cue("S20",2)
			if pose=="counter":
				hunt_audio.cue("S21",2)
			else:
				basic_recoil = BASIC_RECOIL_TIME
				if pose=="auto_thrust":
					hunt_audio.cue("S16",3)
					hunt_audio.cue("S22",1)
		var move := rules.advance(elapsed)
		if not move.is_empty():play_pose(move)
	if running:
		update_combat_ui(elapsed)
		if not result_shown and not rules.outcome.is_empty() and not impact_pending and (pose!="thrust" or pose_clock>=JumpMotion.JUMP_SECONDS):show_result()
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
	for i in hunter_field_bars.size():
		hunter_field_bars[i].max_value = RULES.PARTY_HP[i]
		hunter_field_bars[i].value = rules.party_hp[i]
	hunter_health_text.text = str(rules.hunter_hp)
	deer_health_text.text = str(rules.deer_hp)
	for i in party_cards.size():
		party_cards[i].hud.sync(rules.orbs(i),rules.party_hp[i],RULES.PARTY_HP[i],rules.party_hp[i]>0,running and rules.can_use(RULES.PARTY_SKILLS[i]),delta)

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
	var movement_beat := sin(clampf(pose_clock/RULES.POSE_SECONDS,0,1)*PI)
	var beat := sin(Timing.combat_phase(pose_clock/RULES.POSE_SECONDS)*PI)
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
		var assisting := running and pose == "team" and pose_clock < RULES.POSE_SECONDS and not attack and rules.party_hp[i]>0
		var attack_direction := base.direction_to(DEER_SLOT)
		var previous_position := hunter.position
		if hunter is HangyeolJump:
			if running and pose=="thrust" and pose_clock<JumpMotion.JUMP_SECONDS:
				hunter.position = base
				hunter.show_jump(base.direction_to(deer.position),pose_clock)
				hunter_markers[i].position = base+Vector2(0,-63)
				hunter_markers[i].visible = arrival_finished
				hunter_field_bars[i].get_parent().visible = approach>=1.0
				continue
			hunter.stop_jump()
		hunter.position = base + attack_direction*(lunge if attack else 10 if assisting else -18 if dodge else 0)*movement_beat
		var heading := Vector2(1,.55).lerp(Vector2(1,.28),approach)
		var approaching := transition_elapsed >= 0.0 and approach > 0.0 and approach < 1.0
		if hunter is COMBAT_PREVIEW:
			var clip := "Spear_Thrust" if attack or assisting else "Hit_Reaction" if dodge and hit_on_hunter and hit_age < .26 else "Combat_Idle"
			var progress := Timing.combat_phase(pose_clock/RULES.POSE_SECONDS) if clip=="Spear_Thrust" else clampf(hit_age/.26,0,1) if clip=="Hit_Reaction" else fposmod(hunter.clock,1.8)/1.8
			hunter.clock += delta
			hunter.show_combat_pose(hunter.position.direction_to(deer.position) if attack or assisting else heading,clip,progress)
			hunter.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			hunter_markers[i].position = hunter.position+Vector2(0,-63)
			hunter_markers[i].visible = arrival_finished
			hunter_field_bars[i].get_parent().visible = approach>=1.0
			continue
		var female := hunter.meshy_hunt_rig
		var phase := pose_clock * 12.0
		if female:
			if approaching:
				var travel := previous_position.distance_to(hunter.position)
				female_approach_phase = fposmod(female_approach_phase + travel / (hunter.stride_world_length() * hunter.scale.x) * TAU, TAU)
			phase = female_approach_phase if not dodge else pose_clock * 12.0
		hunter.animate(delta, heading, phase, dodge or approaching, "" if female or not attack else "hunt", Timing.combat_phase(pose_clock/RULES.POSE_SECONDS)*HeroMotion.CYCLE if attack else pose_clock, false)
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
	deer.position = ENEMY_CELLS[4].lerp(DEER_SLOT,approach)+(deer_motion*movement_beat if running else Vector2.ZERO)
	if basic_recoil>0:
		deer.position += Vector2(13,-3)*basic_recoil/BASIC_RECOIL_TIME
	deer.scale = Vector2.ONE*lerpf(.60,.63,approach)
	deer.walking = 1.0 if transition_elapsed>=0 and approach>0.0 and approach<1.0 else (movement_beat if running and (charge or basic_recoil>0.0) else 0.0)
	deer.heading = lerp_angle(-PI*.34,-PI*.35,approach)
	deer.gait_phase = pose_clock*14
	deer.clock += delta
	deer.animate_rig(delta)
	prey_hud.position = deer.position + Vector2(0,-deer.world_height*deer.scale.y-15)
	prey_hud.visible = arrival_finished
	var points:Array=[]
	var transform:=combat_controls.get_global_transform().affine_inverse()*battlefield.get_global_transform()
	for hunter in hunters:points.append(transform*(hunter.position+Vector2(0,-63)))
	points.append(transform*(deer.position+Vector2(0,-deer.world_height*deer.scale.y-15)))
	HeadHUD.layout(head_headers,points,Rect2(8,70,944,350))
	for head in head_headers:head.panel.visible=arrival_finished and approach>=1.0
	hunter_bar.hide()
	deer_bar.hide()

func draw_stage() -> void:
	if arrival_finished and transition_elapsed<0 and not combat_layout:
		var cell := drag_cell if dragging and drag_cell>=0 else assigned_cells[selected_hunter]
		var center: Vector2 = ALLY_CELLS[cell]
		var corners := PackedVector2Array([center-Vector2(0,CELL_SIZE.y*.5),center+Vector2(CELL_SIZE.x*.5,0),center+Vector2(0,CELL_SIZE.y*.5),center-Vector2(CELL_SIZE.x*.5,0)])
		battlefield.draw_colored_polygon(corners,Color(.1,.55,1,.35))
		corners.append(corners[0])
		battlefield.draw_polyline(corners,Color(.32,.78,1),2,true)
	if not combat_layout:return
	for hunter in hunters:
		battlefield.draw_texture_rect(ALLY_RING,Rect2(hunter.position-Vector2(21.25,8.5),Vector2(42.5,17)),false)
	battlefield.draw_texture_rect(ENEMY_RING,Rect2(deer.position-Vector2(26,10.25),Vector2(52,20.5)),false)
	if hit_on_hunter or hit_damage <= 0: return
	var duration := .28 if hit_kind == "team" else .24 if hit_kind == "strike" else .16
	if hit_age >= duration: return
	var fade := 1.0-hit_age/duration
	if hit_kind == "team":
		for hunter in hunters:
			var from: Vector2 = hunter.contact_point() if hunter is COMBAT_PREVIEW else hunter.position+(hunter.tool_contact_world()-hunter.global_position)*hunter.scale
			var direction := from.direction_to(hit_point)
			var tail := hit_point-direction*minf(50,from.distance_to(hit_point))
			battlefield.draw_line(tail,hit_point,Color(.25,.91,.87,.26*fade),6,true)
			battlefield.draw_line(tail,hit_point,Color(.7,1,.96,.8*fade),2,true)
	elif hit_kind == "strike":
		var pulse_size := Vector2(84,29)*lerpf(.5,1.2,1.0-fade)
		battlefield.draw_texture_rect(GROUND_PULSE,Rect2(deer.position-pulse_size*.5,pulse_size),false,Color(1,1,1,fade))
		battlefield.draw_set_transform(hit_point,hit_origin.angle_to_point(hit_point))
		battlefield.draw_texture_rect(HEAVY_HIT,Rect2(-48.5,-33,103,67.5),false,Color(1,1,1,fade))
		battlefield.draw_set_transform(Vector2.ZERO)
	else:
		battlefield.draw_texture_rect(BASIC_HIT,Rect2(hit_point-Vector2(17,20),Vector2(44.5,34.5)),false,Color(1,1,1,fade))


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
