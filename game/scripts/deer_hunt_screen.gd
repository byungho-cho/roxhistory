extends Control

signal preparation_ready

const Timing := preload("res://scripts/motion_timing.gd")
const SkillHUD := preload("res://scripts/duel_skill_hud.gd")
const HeadHUD := preload("res://scripts/battle_head_hud.gd")
const StoneContact := preload("res://scripts/hunt_production_projectile_contact.gd")
const StoneGold := preload("res://scripts/hunt_duel_saebom_2p_effect.gd")
const BOM_PALM_ENTER := 30.0
const BOM_PALM_LEAVE := 36.0
const BOM_HOP_ENTER := 55.0
const BOM_HOP_LEAVE := 66.0
const BOM_HOP_MAX := 18.0
var bom_close := false
var bom_hop_close := false
var bom_shoving := false
var bom_hop_offset := Vector2.ZERO
var bom_hop_strength := 0.0
var bom_last_shove := ""
var bom_hand_previous := Vector3.INF
var bom_prey_pocket := Vector2.INF
var bom_prey_depart := Vector2.INF
var bom_prey_travel_from := Vector2.ZERO
const STONE_METRIC := 32.0
const STONE_HEAVY_NATIVE_RELEASE := 3.566667
var stone := StoneContact.new()
var stone_previous_capsule: Dictionary
var stone_trail := PackedVector2Array()
var stone_origin := Vector2.ZERO
var stone_hit_point := Vector2.ZERO
var stone_hit_direction := Vector2.RIGHT
var stone_hit_age := 2.0
var stone_trail_age := 2.0
var stone_last_result := ""
var stone_glow: GradientTexture2D
var stone_overlay: Control
const SaebomRig := preload("res://scripts/hunt_production_saebom_rig.gd")
const RallyBadge := preload("res://scripts/hunt_duel_bom_buff_badge.gd")
var head_headers:Array=[]
const MATCH := preload("res://scripts/hunt_match_art.gd")
const RULES := preload("res://scripts/deer_hunt_rules.gd")
const DESIGN := Vector2(960,540)
const CLEARING := preload("res://assets/ui/hunting-formation/clearing-dirt.png")
const ALLY_CELL := preload("res://assets/ui/hunting-formation/ally-cell.svg")
const ENEMY_CELL := preload("res://assets/ui/hunting-formation/enemy-cell.svg")
const NativeBoar := preload("res://scripts/hunt_production_boar_actor.gd")
const APPROVED_BOAR := preload("res://assets/ui/duel-hud/boar-selector.png")
const APPROVED_DEER := preload("res://assets/ui/hunting-combat/png/common/deer-approved.png")
const COMBAT_PREVIEW := preload("res://scripts/hunt_combat_preview.gd") # Legacy parry lab import.
const Frontline := preload("res://scripts/hunt_production_frontline_rig.gd")
const FRONTLINE_VISUAL_SCALE := 1.20
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
var adult_markers: Dictionary
var hunter_bar: TextureProgressBar
var deer_bar: TextureProgressBar
var running := false
var result_shown := false

var pose_clock := 1.0
var hunt_stride_phases: Array[float] = [0.,0.,0.]
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
		var hunter: HybridCharacter = Frontline.create("uram") if index == 1 else Frontline.create("hangyeol") if index==0 else SaebomRig.new()
		hunter.render_size_factor = .5
		actors.add_child(hunter)
		hunter.set_enabled(true)
		hunter.camera.position.y = 7.45
		hunter.camera.look_at(Vector3(0,1.45,0))
		hunter.display.position = -hunter.camera.unproject_position(Vector3.ZERO)*hunter.display.scale
		hunters.append(hunter)
	_setup_native_hunt_art(actors)
	if app.get("hunt_prey_id") in ["adult","forest"]:
		var adult := NativeBoar.new()
		adult.native_species = str(app.get("hunt_prey_id"))
		adult.world_height = 90
		adult.heading = -PI*.72
		adult.position = DEER_SLOT
		actors.add_child(adult)
		if adult.is_native_ready():
			deer = adult
			adult_markers = adult.native_markers()
		else:
			adult.queue_free()
			app.set("hunt_prey_id","forest")
	if not is_instance_valid(deer):
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

func _prey_is_adult() -> bool:
	return deer is NativeBoar and deer.native_species == "adult"

func _portrait_for_prey() -> Texture2D:
	return APPROVED_BOAR if _prey_is_adult() else APPROVED_DEER

func build_power_comparison() -> void:
	MATCH.picture(power_header,preload(PREP_ART+"power-comparison-background.svg"),Rect2(-195,2.5,390,82.5))
	prep_ally_portrait = app.picture(power_header,hunter_portrait(selected_hunter),Rect2(-101,15,52,52))
	# Reflect the actual runtime actor, including a safe asset fallback.
	app.picture(power_header,_portrait_for_prey(),Rect2(50,8,50,66))
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
	var deer_portrait: TextureRect = app.picture(enemy_hud,_portrait_for_prey(),Rect2(701,11,54,52))
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
		hud.enable_duel_ready_feedback()
		hud.requested.connect(_on_party_skill_requested.bind(index))
		party_cards.append({"hud":hud,"button":hud.chain_button,"portrait":hud.portrait,"charges":hud.orbs,"hp":hud.hp})
		var head:=NativeHud.create_head(combat_controls,true)
		head_headers.append(head)
		hunter_markers.append(head.panel)
		hunter_field_bars.append(head.bar)
	var enemy:=NativeHud.create_head(combat_controls,false)
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


const ManualHunt := preload("res://scripts/hunt_production_frontline_actions.gd")
const ChainWindow := preload("res://scripts/hunt_production_chain_window.gd")
const FrontFx := preload("res://scripts/hunt_production_frontline_vfx.gd")
const MANUAL_OWNERS := [&"hangyeol",&"uram",&"saebom"]
var chain_window := ChainWindow.new()
var manual_guard := ManualHunt.Guard.new()
var manual_pending: Array[Dictionary] = []
var manual_input_clock := 0.0
var manual_combat_clock := 0.0
var guard_active := false
var guard_started := -INF
var guard_prey_origin := Vector2.INF
var previous_prey_floor := Vector2.INF
var guard_generation := -1
var last_guard_contact: Dictionary = {}
var manual_tip_prev := Vector3.INF
var manual_prey_prev: Dictionary = {}
var previous_counter_muzzle := Vector3.INF
var previous_shield_face := Transform3D.IDENTITY
var manual_effects: Array[Dictionary] = []
var manual_front_fx := FrontFx.new()
var manual_art_ready := false

const PreyFx := preload("res://scripts/hunt_production_prey_effects.gd")
const RallyFx := preload("res://scripts/hunt_production_saebom_rally_vfx.gd")
var prey_art := PreyFx.new(HEAVY_HIT)
var rally_art := RallyFx.new()
var battle_vfx_under:Node2D
var battle_vfx_front:Node2D
var prey_wake: Array = []
var prey_dust: Array[Dictionary] = []
var prey_charge_progress := -1.0
var prey_fx_tip := Vector2.INF
var spear_wake := PackedVector2Array()


const NativeHud := preload("res://scripts/hunt_production_hunt_presentation.gd")
var native_hud := NativeHud.new(prey_art)
var first_blood_age := -INF
var cast_notices: Array = [null,null,null]
var ready_phase: Array[float] = [0.,0.,0.]
var ring_sizing: Array[Vector2] = []
var tracked_party_hp: Array[int] = []


func _mark_hunt_cast(index:int, linked:bool) -> void:
	if index>=0 and index<cast_notices.size() and index<party_cards.size():
		var hud=party_cards[index].hud
		cast_notices[index]={"texture":hud.chain_art.texture if linked else hud.badge_art.texture,"linked":linked,"age":0.0}


func _field_ring(actor,index:int) -> Rect2:
	# The phase-dependent camera is settled on start; invalidate at re-entry, not every redraw.
	if ring_sizing.size() != 4 or approach<1.0:
		var sized:=NativeHud.ground_rect(actor.camera,actor.position)
		return sized
	return Rect2(actor.position-ring_sizing[index]*.5,ring_sizing[index])


func _tick_native_hud(elapsed:float) -> void:
	if ring_sizing.size() != 4 and approach>=1.0:
		ring_sizing.clear()
		for hero in hunters:
			ring_sizing.append(NativeHud.ground_rect(hero.camera,hero.position).size)
		ring_sizing.append(NativeHud.ground_rect(deer.camera,deer.position).size)
	if tracked_party_hp.size()==4:
		if not is_finite(first_blood_age) and (rules.deer_hp<tracked_party_hp[3] or rules.party_hp[0]<tracked_party_hp[0] or rules.party_hp[1]<tracked_party_hp[1] or rules.party_hp[2]<tracked_party_hp[2]):
			first_blood_age=0.0
	for i in 3:
		if cast_notices[i]!=null:
			cast_notices[i].age += elapsed
			if cast_notices[i].age>=NativeHud.CAST_SECONDS: cast_notices[i]=null
		var sp := rules.orbs(i)
		ready_phase[i] += elapsed * (2.0 if sp>=3 else 1.5) / 2.4
	if is_finite(first_blood_age):first_blood_age+=elapsed
	tracked_party_hp.assign([rules.party_hp[0],rules.party_hp[1],rules.party_hp[2],rules.deer_hp])


func _draw_native_weapon_and_notices(dest:Node2D) -> void:
	var inv := battlefield.get_global_transform().affine_inverse()
	var han := hunters[0] as Frontline.Han
	if rules.party_hp[0]>0 and is_instance_valid(han) and han.has_spear_anchor():
		var hand:Vector3 = han.skeleton.to_global(han.skeleton.get_bone_global_pose(han.hand_index).origin)
		native_hud.draw_spear_glow(dest, inv*han.spear_tip_world(), inv*han.display.to_global(han.camera.unproject_position(hand)),manual_combat_clock)
	var uram := hunters[1] as Frontline.Uram
	if rules.party_hp[1]>0 and is_instance_valid(uram):
		var marks := PackedVector2Array()
		for wp in NativeHud.club_head_samples(uram.club):marks.append(inv*uram.display.to_global(uram.camera.unproject_position(wp)))
		native_hud.draw_club_glow(dest,marks)
	var bom := hunters[RULES.SAEBOM] as SaebomRig
	if rules.party_hp[RULES.SAEBOM]>0 and is_instance_valid(bom):
		if stone.active:
			native_hud.draw_sling_glow(dest,_stone_render_point(stone.position))
		elif not (pose=="team" and pose_clock>=.2) and not (rally_art.active and rally_art.age>=.1 and rally_art.age<2.24):
			native_hud.draw_sling_glow(dest,inv*bom.stone_world())
	for i in cast_notices.size():
		var notice:Variant=cast_notices[i]
		if notice!=null and rules.party_hp[i]>0:
			native_hud.draw_cast_notice(dest,hunters[i].position-Vector2(0,64),hunter_markers[i],notice.texture,notice.linked,notice.age)


func _setup_native_hunt_art(actor_group:Node2D) -> void:
	manual_art_ready = manual_front_fx.prepare()
	battle_vfx_under = Node2D.new()
	battle_vfx_front = Node2D.new()
	battlefield.add_child(battle_vfx_under)
	battlefield.move_child(battle_vfx_under,actor_group.get_index())
	battlefield.add_child(battle_vfx_front)
	battle_vfx_front.z_index = 2
	battle_vfx_under.draw.connect(_draw_normal_hunt_art.bind(false))
	battle_vfx_front.draw.connect(_draw_normal_hunt_art.bind(true))
	rally_art.setup(battlefield, actor_group,hunters[RULES.SAEBOM] as SaebomRig)


func _update_native_hunt_art(elapsed:float,previous_pose_clock:float) -> void:
	if not is_instance_valid(battle_vfx_front):
		return
	var feet: Array[Vector2] = []
	var living: Array[bool] = []
	for i in hunters.size():
		feet.append(hunters[i].position)
		living.append(rules.party_hp[i] > 0)
	var rally_before:float = rally_art.age
	rally_art.tick(elapsed,feet,living)
	if rally_art.active and rally_before<.62 and rally_art.age>=.62:
		_start_camera_accent("rally",hunters[RULES.SAEBOM].position)
	for i in range(manual_effects.size()-1,-1,-1):
		manual_effects[i].age += elapsed
		if manual_effects[i].age >= 2.2:
			manual_effects.remove_at(i)
	for i in range(prey_dust.size()-1,-1,-1):
		prey_dust[i].age += elapsed
		if prey_dust[i].age >= 2.5:
			prey_dust.remove_at(i)
	var charging := pose == "counter" and pose_clock <= RULES.POSE_SECONDS
	prey_charge_progress = -1.0
	if charging:
		var takeoff := _native_takeoff_clock()
		prey_charge_progress = clampf(pose_clock/takeoff,0.0,1.05)
		var muzzle := _counter_muzzle()
		if muzzle.is_finite():
			prey_fx_tip = _stone_render_point(muzzle)
		if previous_pose_clock < takeoff and pose_clock >= takeoff:
			prey_dust.append({"age":0.0,"at":previous_prey_floor if previous_prey_floor.is_finite() else deer.position})
		if pose_clock > takeoff and pose_clock <= .29 and prey_fx_tip.is_finite():
			PreyFx.sample_wake(prey_wake,prey_fx_tip,deer.position,manual_combat_clock)
	previous_prey_floor = deer.position
	PreyFx.prune_wake(prey_wake,manual_combat_clock)
	if pose == ManualHunt.HAN_SPEAR_3 and pose_clock < _manual_duration(pose):
		var tip := _weapon_metric(0)
		if tip.is_finite():
			var at := _stone_render_point(tip)
			if spear_wake.is_empty() or at.distance_squared_to(spear_wake[0]) >= 4.0:
				spear_wake.insert(0,at)
				if spear_wake.size() > 9:
					spear_wake.resize(9)
	else:
		spear_wake.clear()
	battle_vfx_under.queue_redraw()
	battle_vfx_front.queue_redraw()


func _draw_normal_hunt_art(front:bool) -> void:
	if not combat_layout:
		return
	var dest := battle_vfx_front if front else battle_vfx_under
	if not front:
		for i in hunters.size():
			if rules.party_hp[i] > 0:
				var floor_rect := _field_ring(hunters[i],i)
				prey_art.draw_ground_ring(dest,floor_rect,true)
				var ready := _can_take_hunt_input() and (rules.can_use(RULES.PARTY_SKILLS[i]) if i == RULES.SAEBOM else rules.can_use_frontline_skill(i,2))
				native_hud.draw_ready_ring(dest,floor_rect,3 if _can_submit_manual_chain(i) else 2 if ready else 0,ready_phase[i])
		if rules.deer_hp > 0:
			prey_art.draw_ground_ring(dest,_field_ring(deer,3),false)
		for puff in prey_dust:
			prey_art.draw_dust(puff.at,puff.age,dest)
	if front:
		_draw_native_weapon_and_notices(dest)
	if front and prey_fx_tip.is_finite():
		prey_art.draw_charge(deer.position,prey_fx_tip,prey_charge_progress,pose == "counter" and pose_clock <= .29,prey_wake,manual_combat_clock,dest)
	if front and pose == ManualHunt.URAM_CLUB_2 and pose_clock < .3:
		var tip := _weapon_metric(1)
		if tip.is_finite():
			manual_front_fx.draw_uram_skill_windup(dest,prey_art.soft,_stone_render_point(tip),pose_clock/.3,1.0)
	if front and pose == ManualHunt.HAN_SPEAR_3 and pose_clock < _manual_duration(pose) and not spear_wake.is_empty():
		var foot := hunters[0].position
		manual_front_fx.draw_han_chain_cast(dest,prey_art.soft,foot,foot+Vector2(0,-20),foot.lerp(spear_wake[0],.54),spear_wake[0],pose_clock/_manual_duration(pose),spear_wake,.82)
	for effect in manual_effects:
		var position2:Vector2 = effect.pos
		match effect.kind:
			"gong":
				if front:
					manual_front_fx.draw_uram_gong(dest,prey_art.soft,position2,effect.axis,effect.age,1.0)
				else:
					manual_front_fx.draw_uram_gong_dust(dest,prey_art.soft,effect.floor,effect.age)
			ManualHunt.HAN_SPEAR_2:
				if front:
					manual_front_fx.draw_han_skill_hit(dest,position2,effect.axis,effect.age,.85)
			ManualHunt.HAN_SPEAR_3:
				if front:
					manual_front_fx.draw_han_chain_hit(dest,prey_art.soft,position2,effect.floor,effect.age,.85)
				else:
					manual_front_fx.draw_han_chain_ground(dest,prey_art.soft,effect.floor,effect.age,.85)
			ManualHunt.URAM_CLUB_2:
				if front:
					manual_front_fx.draw_uram_skill_hit(dest,prey_art.soft,position2,effect.floor,effect.axis,effect.age,1.0)
			"prey_hit":
				if front:
					prey_art.draw_impact({"center":position2,"floor_point":effect.floor},clampf(effect.age/.56,0.0,1.0),dest)


func _can_take_hunt_input() -> bool:
	return running and not result_shown and exit_popup == null and not app.modal and app.application_active


func _uses_ordered_chain() -> bool:
	return chain_window.active() or (rules.party_hp[0] > 0 and rules.party_hp[1] > 0 and rules.party_hp[2] > 0)


func _guard_can_arm() -> bool:
	return not guard_active and rules.pending_counter and pose == "counter" and rules.attacker == 1 and pose_clock <= .106 and rules.orbs(1) >= 3 and rules.party_hp[1] > 0


func _can_submit_manual_chain(index: int) -> bool:
	if not _can_take_hunt_input() or not rules.can_reserve_manual(index,3):
		return false
	if _uses_ordered_chain() and chain_window.actionable() != MANUAL_OWNERS[index]:
		return false
	if index == 1:
		return _guard_can_arm()
	if _uses_ordered_chain():
		return true
	return rules.can_start_rally() if index == RULES.SAEBOM else rules.can_use_frontline_skill(index,3)


func _reserve_chain_step(hero: StringName) -> bool:
	var index := MANUAL_OWNERS.find(hero)
	return index >= 0 and (index != 1 or _guard_can_arm()) and rules.reserve_manual(index,3)


func _submit_manual_chain(index: int) -> void:
	if not _can_submit_manual_chain(index):
		return
	var generation := -1
	if _uses_ordered_chain():
		var step:Dictionary = chain_window.accept(MANUAL_OWNERS[index], manual_input_clock, _reserve_chain_step)
		if step.is_empty():
			return
		generation = int(step.generation)
	elif not rules.reserve_manual(index,3):
		return
	if index == 1:
		guard_active = manual_guard.arm(1,manual_combat_clock)
		guard_started = manual_combat_clock
		guard_prey_origin = deer.position
		guard_generation = generation
		last_guard_contact.clear()
		if guard_active: _mark_hunt_cast(1,true)
	else:
		manual_pending.append({"index":index,"id":"rally" if index == RULES.SAEBOM else ManualHunt.HAN_SPEAR_3})
		_execute_reserved_followup()
	update_combat_ui()


func _manual_duration(id: String) -> float:
	if id == ManualHunt.HAN_SPEAR_3: return .96
	return .68


func _start_frontline_paid(index: int, id: String) -> bool:
	var data := ManualHunt.describe(id,int(RULES.SKILLS[RULES.PARTY_SKILLS[index]].damage))
	if data.is_empty() or not rules.start_frontline_paid(index,int(data.damage),_manual_duration(id)):
		return false
	play_pose(id)
	return true


func _execute_reserved_followup() -> bool:
	if not rules.can_execute_manual():
		return false
	while not manual_pending.is_empty():
		var req:Dictionary = manual_pending.pop_front()
		var index := int(req.index)
		if rules.party_hp[index] <= 0:
			continue
		if req.id == "rally":
			if rules.start_rally_paid():
				play_pose("rally")
				return true
		elif _start_frontline_paid(index,str(req.id)):
			return true
	return false


func _reset_manual_contact() -> void:
	manual_tip_prev = Vector3.INF
	manual_prey_prev.clear()
	previous_counter_muzzle = Vector3.INF

func _counter_muzzle() -> Vector3:
	if deer is NativeBoar:
		return _stone_metric_point(deer.camera,deer.display,deer.native_muzzle())
	var rig:Skeleton3D = deer.rig
	var head := rig.find_bone("head") if is_instance_valid(rig) else -1
	if head < 0:
		var capsule := _deer_stone_capsule()
		return capsule.get("b",Vector3.INF)
	rig.force_update_all_bone_transforms()
	return _stone_metric_point(deer.camera,deer.display,rig.to_global(rig.get_bone_global_pose(head).origin))


func _shield_metric(uram:Frontline.Uram) -> Transform3D:
	var shield:Node3D = uram.shield
	var o := _stone_metric_point(uram.camera,uram.display,shield.global_position)
	var right := _stone_metric_point(uram.camera,uram.display,shield.to_global(Vector3.RIGHT)) - o
	var up := _stone_metric_point(uram.camera,uram.display,shield.to_global(Vector3.UP)) - o
	var front := _stone_metric_point(uram.camera,uram.display,shield.to_global(Vector3.BACK)) - o
	return Transform3D(Basis(right,up,front),o)


func _try_counter_guard(from_clock:float, to_clock:float, last_pose:float) -> void:
	var muzzle := _counter_muzzle()
	var uram := hunters[1] as Frontline.Uram
	if not is_instance_valid(uram) or not uram.has_shield_anchor() or not muzzle.is_finite():
		return
	var face := _shield_metric(uram)
	if guard_active and previous_counter_muzzle.is_finite():
		var boundary := inverse_lerp(last_pose,pose_clock,IMPACT_SECONDS) if pose_clock >= IMPACT_SECONDS else INF
		var event := manual_guard.step(from_clock,to_clock,rules.attacker,previous_counter_muzzle,muzzle,previous_shield_face,face,Vector2(.305,.38),pose_clock >= _native_takeoff_clock() and last_pose <= IMPACT_SECONDS,boundary,.18)
		if not event.is_empty() and rules.resolve_guard():
			last_guard_contact = event
			_start_camera_accent("parry",_stone_render_point(event.point))
			impact_pending = false
			guard_active = false
			chain_window.confirm_guard(manual_input_clock,guard_generation)
			var pos := _stone_render_point(event.point)
			manual_effects.append({"kind":"gong","age":0.0,"pos":pos,"floor":uram.position,"axis":uram.position.direction_to(deer.position)})
			hunt_audio.cue("S18",2)
	previous_counter_muzzle = muzzle
	previous_shield_face = face


func _weapon_metric(index:int) -> Vector3:
	var hero := hunters[index]
	if hero is Frontline.Han and hero.has_spear_anchor():
		hero.skeleton.force_update_all_bone_transforms()
		return _stone_metric_point(hero.camera,hero.display,hero.skeleton.global_transform*hero.skeleton.get_bone_global_pose(hero.hand_index)*hero.spear_tip_local)
	if hero is Frontline.Uram and hero.has_club_anchor():
		return _stone_metric_point(hero.camera,hero.display,hero.club.to_global(Vector3(hero.CLUB_SIZE.x*.34,0,0)))
	return Vector3.INF


func _manual_weapon_contact() -> void:
	var p := pose_clock / _manual_duration(pose)
	var tip := _weapon_metric(rules.attacker)
	var cap := _deer_stone_capsule()
	if p >= .25 and p <= .87 and tip.is_finite() and manual_tip_prev.is_finite() and not cap.is_empty():
		var skin:float = .14 if pose == ManualHunt.URAM_CLUB_2 else .06
		var shift := Vector3.ZERO
		if not manual_prey_prev.is_empty():
			shift = ((cap.a + cap.b) - (manual_prey_prev.a + manual_prey_prev.b))*.5
		var fraction := StoneContact.capsule_hit(manual_tip_prev+shift,tip,cap.a,cap.b,float(cap.radius)+skin)
		if is_finite(fraction):
			var contact := manual_tip_prev.lerp(tip,fraction)
			var before := rules.deer_hp
			rules.resolve_attack()
			hit_damage = before-rules.deer_hp
			hit_age = 0.0
			hit_kind = "native_manual"
			hit_on_hunter = false
			hit_point = _stone_render_point(contact)
			hit_label.text = "−%d" % hit_damage
			manual_effects.append({"kind":pose,"age":0.0,"pos":hit_point,"floor":deer.position,"axis":hunters[rules.attacker].position.direction_to(deer.position)})
			impact_pending = false
			basic_recoil = BASIC_RECOIL_TIME
			hunt_audio.cue("S18" if pose == ManualHunt.URAM_CLUB_2 else "S15",2)
	if impact_pending and p >= .87:
		rules.pending_damage = 0
		impact_pending = false
	manual_tip_prev = tip
	manual_prey_prev = cap


var han_chain_travel := Vector2.ZERO
var han_chain_facing := Vector2.RIGHT

func _sample_han_chain_travel() -> void:
	han_chain_travel=Vector2.ZERO
	var hero := hunters[0] as Frontline.Han
	var cap := _deer_stone_capsule()
	if not is_instance_valid(hero) or cap.is_empty():
		return
	var home := hero.position
	var best := INF
	var fallback_best := INF
	var fallback := Vector2.ZERO
	var heading := Vector2(sin(hero.heading),cos(hero.heading))
	han_chain_facing=heading
	var peer: Array[Vector2] = []
	for i in range(1,hunters.size()):
		if rules.party_hp[i]>0: peer.append(hunters[i].position)
	for time in [.54,.5666667,.60,.6266667]:
		if not hero.resident_sample("chain",hero.clip_duration("chain")*time/_manual_duration(ManualHunt.HAN_SPEAR_3)):
			continue
		var tip := _weapon_metric(0)
		if not tip.is_finite():
			continue
		var capsule_a:Vector3=cap.a
		var capsule_b:Vector3=cap.b
		for j in range(33):
			var hit := capsule_a.lerp(capsule_b,float(j)/32.0)
			var gap := hit-tip
			if absf(gap.y)>=float(cap.radius)+.035:
				continue
			var exact := Vector2(gap.x,gap.z)*STONE_METRIC
			for option in [Vector2(-.025,4.5),Vector2(-.025,6.),Vector2(-.025,8.),Vector2(.048,3.),Vector2(.048,4.)]:
				var interior := maxf(.075,float(cap.radius)+option.x)
				var allowed := sqrt(maxf(0.0,interior*interior-gap.y*gap.y))*STONE_METRIC
				var offset := exact.normalized()*minf(exact.length(),maxf(0.0,exact.length()-allowed)+option.y)
				var endpoint := home+offset
				if offset.length()>(74.0 if option.x > 0.0 else 64.0) or endpoint.distance_to(deer.position)<24.0 or not Rect2(24.,95.,912.,335.).has_point(endpoint):
					continue
				if tip.distance_to(hit-Vector3(offset.x/STONE_METRIC,0.,offset.y/STONE_METRIC))>float(cap.radius)+.045:
					continue
				var safe := true
				for here in peer:
					var segment := Geometry2D.get_closest_point_to_segment(here,home,endpoint)
					if segment.distance_to(here)<minf(home.distance_to(here),19.5)-.1:
						safe=false
						break
				if option.x>0.0:
					if safe and offset.length_squared()<fallback_best:
						fallback_best=offset.length_squared()
						fallback=offset
				elif safe and offset.length_squared()<best:
					best=offset.length_squared()
					han_chain_travel=offset
	if best==INF: han_chain_travel=fallback
	hero.animate(0.0,heading,0.0,false,"chain",0.0,false)


func _is_native_manual(id:String) -> bool:
	return id in [ManualHunt.HAN_SPEAR_2,ManualHunt.HAN_SPEAR_3,ManualHunt.URAM_CLUB_2]


func _on_party_skill_requested(action: String, index: int) -> void:
	if not _can_take_hunt_input():
		return
	if action == "chain":
		_submit_manual_chain(index)
		return
	if index == RULES.SAEBOM:
		var previous_charge:float = rules.charges[index]
		use_skill(RULES.PARTY_SKILLS[index],2)
		if rules.charges[index]<previous_charge: _mark_hunt_cast(index,false)
	elif rules.can_use_frontline_skill(index,2) and rules.reserve_manual(index,2):
		_start_frontline_paid(index,ManualHunt.HAN_SPEAR_2 if index == 0 else ManualHunt.URAM_CLUB_2)
		update_combat_ui()

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
	_reset_manual_contact()
	pose = id
	guard_prey_origin = Vector2.INF
	if id == "rally":
		rally_art.start(RULES.SAEBOM)
		_mark_hunt_cast(RULES.SAEBOM,true)
	elif _is_native_manual(id):
		_mark_hunt_cast(rules.attacker,id == ManualHunt.HAN_SPEAR_3)
	pose_clock = 0.0
	if id == ManualHunt.HAN_SPEAR_3: _sample_han_chain_travel()
	impact_pending = true
	_update_saebom_prey_pocket(id)
	_begin_saebom_close_action(id)
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
	var actors_sampled := false
	var previous_pose_clock := pose_clock
	var previous_manual_clock := manual_combat_clock
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
		var active_visual := delta/maxf(Engine.time_scale,.0001)
		manual_input_clock += active_visual
		camera_accent_age += active_visual
		if pose == ManualHunt.HAN_SPEAR_3 and previous_pose_clock < .40 and pose_clock >= .40:
			_start_camera_accent("han_chain",hunters[0].position.lerp(deer.position,.52))
		manual_combat_clock += elapsed
		chain_window.advance(manual_input_clock)
		if impact_pending and (pose == "counter" or _is_native_manual(pose)):
			update_actors(actor_delta+elapsed)
			actor_delta = 0.0
			actors_sampled = true
			if pose == "counter":
				_try_counter_guard(previous_manual_clock,manual_combat_clock,previous_pose_clock)
			else:
				_manual_weapon_contact()
		if guard_active and manual_combat_clock >= guard_started + ManualHunt.GUARD_CLOSE:
			guard_active = false
			manual_guard.cancel()
		# Tick existing boosts before a contact; a new release starts at a full five seconds.
		rules.advance_rally_clock(elapsed)
		var rally_releases := impact_pending and pose == "rally" and pose_clock >= IMPACT_SECONDS
		var sling_pending := impact_pending and pose == "team" and rules.attacker == RULES.SAEBOM
		var palm_pending := impact_pending and pose == "auto_thrust" and rules.attacker == RULES.SAEBOM and bom_shoving
		if sling_pending or palm_pending:
			update_actors(actor_delta+elapsed)
			actor_delta = 0.0
			actors_sampled = true
			if sling_pending: _update_saebom_stone(elapsed, previous_pose_clock)
			else: _update_saebom_shove()
		if impact_pending and not sling_pending and not palm_pending and pose != "rally" and not _is_native_manual(pose) and pose_clock >= (JumpMotion.JUMP_CONTACT_SECONDS if pose=="thrust" else IMPACT_SECONDS):
			var before_hp := rules.hunter_hp if pose == "counter" else rules.deer_hp
			rules.resolve_attack()
			hit_damage = before_hp - (rules.hunter_hp if pose == "counter" else rules.deer_hp)
			if hit_damage > 0:
				hit_age = 0.0
				hit_kind = pose
				hit_on_hunter = pose == "counter"
				var attacker := hunters[rules.attacker]
				hit_origin = _hunter_contact_canvas(attacker)
				hit_point = hit_origin if hit_on_hunter else deer.position+Vector2(-18,-37)
				hit_label.text = "−%d" % hit_damage
			impact_pending = false
			if pose=="thrust": hunt_audio.cue("S15",2)
			if pose=="strike": hunt_audio.cue("S18",2)
			if pose=="team": hunt_audio.cue("S20",2)
			if pose=="counter":
				hunt_audio.cue("S21",2)
				if hit_damage > 0:
					manual_effects.append({"kind":"prey_hit","age":0.0,"pos":hit_point,"floor":hunters[rules.attacker].position,"axis":Vector2.ZERO})
			else:
				basic_recoil = BASIC_RECOIL_TIME
				if pose=="auto_thrust":
					hunt_audio.cue("S16",3)
					hunt_audio.cue("S22",1)
		var move := rules.advance(elapsed, false, not manual_pending.is_empty())
		if rally_releases:
			var positions: Array[Vector2] = []
			for hunter in hunters:
				positions.append(hunter.position)
			if rules.apply_rally(positions):
				var affected: Array[int] = []
				for i in hunters.size():
					if rules.party_hp[i] > 0 and positions[RULES.SAEBOM].distance_squared_to(positions[i]) <= RULES.RALLY_RADIUS*RULES.RALLY_RADIUS:
						affected.append(i)
				rally_art.release(affected)
			impact_pending = false
			hunt_audio.cue("S20",2)
		if not move.is_empty():play_pose(move)
		_execute_reserved_followup()
	if running:
		update_combat_ui(elapsed)
		if not result_shown and not rules.outcome.is_empty() and _finish_visual_ready():show_result()
	if result_shown: return
	if not actors_sampled:
		actor_delta += elapsed
	if actor_delta>=1.0/30.0:
		update_actors(actor_delta)
		actor_delta = 0.0
	update_camera(delta)
	if running:
		_tick_native_hud(elapsed)
		_update_native_hunt_art(elapsed, previous_pose_clock)
	stone_hit_age += elapsed
	stone_trail_age += elapsed
	if is_instance_valid(stone_overlay): stone_overlay.queue_redraw()
	battlefield.queue_redraw()

## Do not alter target selection, incoming counter HP, attack clocks or AI.
## Only an already scheduled counter into a genuinely near Saebom may occupy
## the safe finish pocket; the next different target releases it smoothly.
func _update_saebom_prey_pocket(id:String) -> void:
	if id != "counter" or approach < 1.0 or not is_instance_valid(deer):
		return
	bom_prey_depart = Vector2.INF
	if rules.attacker != RULES.SAEBOM or rules.party_hp[RULES.SAEBOM] <= 0:
		if bom_prey_pocket.is_finite(): bom_prey_depart = deer.position
		bom_prey_pocket = Vector2.INF
		return
	var her_feet:Vector2 = hunters[RULES.SAEBOM].position
	if her_feet.distance_to(deer.position) > 68.0:
		return
	var side := -1.0 if deer.position.x < her_feet.x else 1.0
	var pocket := her_feet + (Vector2(28.0*side,-8.0) if _prey_is_adult() else Vector2(22.0*side,-11.0))
	for i in [0,1]:
		if rules.party_hp[i] > 0 and pocket.distance_to(hunters[i].position) < 34.0:
			return
	if not Rect2(120,100,730,280).has_point(pocket):
		return
	bom_prey_travel_from = deer.position
	bom_prey_pocket = pocket

func _begin_saebom_close_action(id:String) -> void:
	bom_shoving = false
	bom_hop_offset = Vector2.ZERO
	bom_hop_strength = 0.0
	bom_hand_previous = Vector3.INF
	if rules.attacker != RULES.SAEBOM or id not in ["auto_thrust","team"]:
		return
	var her_feet:Vector2 = hunters[RULES.SAEBOM].position
	var gap := her_feet.distance_to(deer.position)
	bom_close = gap <= (BOM_PALM_LEAVE if bom_close else BOM_PALM_ENTER)
	bom_hop_close = gap <= (BOM_HOP_LEAVE if bom_hop_close else BOM_HOP_ENTER)
	if id == "auto_thrust" and bom_close:
		bom_shoving = true
		bom_last_shove = "windup"
	elif id == "team" and bom_hop_close:
		var away := deer.position.direction_to(her_feet)
		if away.is_zero_approx(): away = Vector2.LEFT
		var proposed := her_feet + away * clampf(72.0-gap,0.0,BOM_HOP_MAX)
		var endpoint := _saebom_safe_position(her_feet,proposed)
		bom_hop_offset = endpoint-her_feet
		bom_hop_strength = clampf(bom_hop_offset.length() / BOM_HOP_MAX,0.0,1.0)

func _saebom_safe_position(base:Vector2, desired:Vector2) -> Vector2:
	var candidate := Vector2(clampf(desired.x,50.0,910.0),clampf(desired.y,85.0,452.0))
	for i in range(3):
		if i == RULES.SAEBOM or rules.party_hp[i] <= 0: continue
		var buddy:Vector2 = hunters[i].position
		var min_gap := minf(25.0,base.distance_to(buddy))
		if candidate.distance_to(buddy) < min_gap-.1: return base
	var min_deer_gap := minf(32.0,base.distance_to(deer.position))
	if candidate.distance_to(deer.position) < min_deer_gap-.1: return base
	return candidate

static func _saebom_hop_envelope(phase:float) -> float:
	return smoothstep(.09,.34,phase)*(1.0-smoothstep(.81,1.0,phase))

func _saebom_palm_metric(hero:SaebomRig) -> Vector3:
	if not hero.has_anchor("hand.R"): return Vector3.INF
	var rig:Skeleton3D = hero.skeleton
	rig.force_update_all_bone_transforms()
	var palm := rig.find_bone("hand.R")
	return _stone_metric_point(hero.camera,hero.display,rig.to_global(rig.get_bone_global_pose(palm).origin))

func _pose_saebom_palm(hero:SaebomRig, p:float) -> void:
	var rig:Skeleton3D = hero.skeleton
	var palm := rig.find_bone("hand.R")
	if palm<0: return
	hero.resident_sample("guard",minf(p,.99)*.32)
	var pulse := smoothstep(.12,.44,p)*(1.0-smoothstep(.57,.92,p))
	for pair in [["upper.R",-.58],["forearm.R",.72]]:
		var j := rig.find_bone(pair[0])
		if j>=0: rig.set_bone_pose_rotation(j,rig.get_bone_pose_rotation(j)*Quaternion(Vector3.RIGHT,float(pair[1])*pulse))
	rig.force_update_all_bone_transforms()
	var capsule := _deer_stone_capsule()
	if capsule.is_empty() or pulse < .02: return
	var hand := _saebom_palm_metric(hero)
	var a:Vector3 = capsule.a
	var axis:Vector3 = capsule.b-a
	var nearest := a+axis*clampf((hand-a).dot(axis)/maxf(axis.length_squared(),.0001),0.0,1.0)
	var desired := nearest+nearest.direction_to(hand)*float(capsule.radius)*.65
	var camera:Camera3D = hero.camera
	var display:Sprite2D = hero.display
	var visual := display.to_local(battlefield.get_global_transform() * _stone_render_point(desired))
	var native_height_scale := (_stone_metric_point(camera,display,Vector3.UP)-_stone_metric_point(camera,display,Vector3.ZERO)).y
	var ray := camera.project_ray_normal(visual)
	if absf(ray.y)<.01 or absf(native_height_scale)<.01: return
	var origin := camera.project_ray_origin(visual)
	var destination := rig.to_local(origin+ray*((desired.y/native_height_scale-origin.y)/ray.y))
	var elbow := rig.get_bone_parent(palm)
	var upper := rig.find_bone("upper.R")
	for attempt in range(4):
		for joint in [elbow,upper,elbow]:
			if joint<0: continue
			var joint_pose := rig.get_bone_global_pose(joint)
			var current := rig.get_bone_global_pose(palm).origin-joint_pose.origin
			var strand := destination-joint_pose.origin
			if current.length_squared()<.00001 or strand.length_squared()<.00001: continue
			var turn := Quaternion.IDENTITY.slerp(Quaternion(current.normalized(),strand.normalized()),pulse*.71)
			joint_pose.basis = Basis(turn)*joint_pose.basis
			rig.set_bone_global_pose(joint,joint_pose)
			rig.force_update_all_bone_transforms()

func _update_saebom_shove() -> void:
	var hero := hunters[RULES.SAEBOM] as SaebomRig
	var phase := pose_clock / RULES.POSE_SECONDS
	var now := _saebom_palm_metric(hero) if is_instance_valid(hero) else Vector3.INF
	var capsule := _deer_stone_capsule()
	if phase >= .30 and phase <= .77 and now.is_finite() and not capsule.is_empty():
		var previous := bom_hand_previous if bom_hand_previous.is_finite() else now
		var hit := StoneContact.capsule_hit(previous,now,capsule.a,capsule.b,float(capsule.radius)+.08)
		if hit != INF:
			var hp := rules.deer_hp
			rules.resolve_attack()
			impact_pending = false
			bom_last_shove = "hit"
			hit_damage = hp-rules.deer_hp
			hit_age = 0.0
			hit_kind = "auto_thrust"
			hit_on_hunter = false
			hit_point = _stone_render_point(previous.lerp(now,hit))
			hit_origin = hit_point
			hit_label.text = "-%d" % hit_damage
			basic_recoil = BASIC_RECOIL_TIME
			hunt_audio.cue("S16",3)
			return
	bom_hand_previous = now
	if phase >= .77:
		rules.pending_damage = 0
		impact_pending = false
		bom_last_shove = "miss"

## Reduce each independent orthographic actor viewport to the same battlefield
## coordinates: horizontal pixel, height above projected ground, ground depth.
## This is a visible/anatomical proxy, not a shared Godot PhysicsServer world.
func _stone_metric_point(camera:Camera3D, display:Sprite2D, world_point:Vector3) -> Vector3:
	var inv := battlefield.get_global_transform().affine_inverse()
	var visual := inv * display.to_global(camera.unproject_position(world_point))
	var floor_point := inv * display.to_global(camera.unproject_position(Vector3(world_point.x,0.0,world_point.z)))
	return Vector3(visual.x, floor_point.y - visual.y, floor_point.y) / STONE_METRIC

func _stone_render_point(metric:Vector3) -> Vector2:
	return Vector2(metric.x,metric.z-metric.y)*STONE_METRIC

func _deer_stone_capsule() -> Dictionary:
	if not is_instance_valid(deer) or rules.deer_hp <= 0 or not is_instance_valid(deer.rig):
		return {}
	var rig: Skeleton3D = deer.rig
	var points:Dictionary = {}
	if deer is NativeBoar:
		points = deer.native_body_points()
	else:
		var rear := rig.find_bone("body")
		var front := rig.find_bone("neck")
		if rear < 0 or front < 0: return {}
		rig.force_update_all_bone_transforms()
		points = {"a":rig.to_global(rig.get_bone_global_pose(rear).origin),
			"b":rig.to_global(rig.get_bone_global_pose(front).origin)}
	if points.is_empty(): return {}
	var a := _stone_metric_point(deer.camera,deer.display,points.a)
	var b := _stone_metric_point(deer.camera,deer.display,points.b)
	if not a.is_finite() or not b.is_finite() or (a.y+b.y) <= .05:
		return {}
	var radius := clampf(a.distance_to(b)*.30,.32,.62) if _prey_is_adult() else clampf(a.distance_to(b)*.30,.21,.43)
	return {"a":a, "b":b, "radius":radius}

func _ensure_stone_overlay() -> void:
	if is_instance_valid(stone_overlay):
		return
	stone_overlay = layer(battlefield)
	stone_overlay.z_index = 2
	stone_overlay.draw.connect(_draw_saebom_stone)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,.25,.57,1.0])
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.65),Color(1,1,1,.15),Color(1,1,1,0)])
	stone_glow = GradientTexture2D.new()
	stone_glow.width = 128
	stone_glow.height = 128
	stone_glow.fill = GradientTexture2D.FILL_RADIAL
	stone_glow.fill_from = Vector2(.5,.5)
	stone_glow.fill_to = Vector2(1,.5)
	stone_glow.gradient = gradient

func _finish_saebom_stone(struck:bool, point:Vector2=Vector2.ZERO) -> void:
	stone.cancel()
	stone_previous_capsule = {}
	impact_pending = false
	stone_last_result = "hit" if struck else "miss"
	stone_trail_age = 0.0
	if not struck:
		rules.pending_damage = 0
		return
	var before_hp := rules.deer_hp
	rules.resolve_attack()
	hit_damage = before_hp - rules.deer_hp
	if hit_damage <= 0:
		return
	hit_age = 0.0
	hit_kind = "sling_contact"
	hit_on_hunter = false
	hit_origin = stone_origin
	hit_point = point
	stone_hit_point = point
	stone_hit_direction = stone_origin.direction_to(point)
	stone_hit_age = 0.0
	hit_label.text = "-%d" % hit_damage
	basic_recoil = BASIC_RECOIL_TIME
	hunt_audio.cue("S20",2)

func _update_saebom_stone(delta:float, previous_time:float) -> void:
	var current := _deer_stone_capsule()
	var elapsed := delta
	if not stone.active:
		var rig := hunters[RULES.SAEBOM] as SaebomRig
		if not is_instance_valid(rig) or not rig.has_anchor("sling_stone"):
			_finish_saebom_stone(false)
			return
		var length:float = rig.animation.get_animation("sling_heavy").length
		var release_time := RULES.POSE_SECONDS * STONE_HEAVY_NATIVE_RELEASE / maxf(STONE_HEAVY_NATIVE_RELEASE,length)
		if pose_clock < release_time:
			return
		if current.is_empty():
			_finish_saebom_stone(false)
			return
		rig.sample_native_release("skill",STONE_HEAVY_NATIVE_RELEASE)
		var skeleton:Skeleton3D = rig.skeleton
		var native:Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("sling_stone")).origin)
		var origin := _stone_metric_point(rig.camera,rig.display,native)
		var aim:Vector3 = (current.a+current.b)*.5
		if not stone.launch(origin,aim,14.0,7.0,{},.54,5.2,.065):
			_finish_saebom_stone(false)
			return
		_ensure_stone_overlay()
		stone_origin = _stone_render_point(origin)
		stone_trail = PackedVector2Array([stone_origin])
		stone_trail_age = 0.0
		stone_previous_capsule = current
		stone_last_result = "flight"
		elapsed = minf(delta,maxf(0.0,pose_clock-maxf(previous_time,release_time)))
	var result := stone.step(elapsed,stone_previous_capsule,current)
	stone_previous_capsule = current
	var endpoint := _stone_render_point(stone.position)
	if stone_trail.is_empty() or endpoint.distance_to(stone_trail[-1]) > 1.5:
		stone_trail.append(endpoint)
		if stone_trail.size() > 9: stone_trail.remove_at(0)
	if not result.is_empty():
		var struck:bool = result.kind == "hit"
		_finish_saebom_stone(struck,_stone_render_point(result.point) if struck else Vector2.ZERO)

func _draw_saebom_stone() -> void:
	if stone.active or stone_trail_age < .20:
		StoneGold.draw_trail(stone_overlay,stone_glow,stone_trail,1.0 if stone.active else 1.0-stone_trail_age/.20)
	if stone_hit_age <= 1.35:
		StoneGold.draw_hit(stone_overlay,stone_glow,stone_hit_point,stone_hit_direction,stone_hit_age)

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
		var hud: Control = party_cards[i].hud
		hud.sync(rules.orbs(i),rules.party_hp[i],RULES.PARTY_HP[i],rules.party_hp[i]>0,_can_take_hunt_input() and (rules.can_use(RULES.PARTY_SKILLS[i]) if i == RULES.SAEBOM else rules.can_use_frontline_skill(i,2)),delta,_can_submit_manual_chain(i))
		if i == RULES.SAEBOM:
			RallyBadge.sync(hud, rules.rally_remaining[i] if rules.party_hp[i] > 0 else 0.0)

const CAMERA_ACCENT_S := .54
const CAMERA_ACCENT_LOCK_S := .69
var camera_accent_age := INF
var camera_accent_point := Vector2.ZERO
var camera_accent_source := ""


func _start_camera_accent(source:String,point:Vector2) -> bool:
	if not running or result_shown or camera_accent_age<CAMERA_ACCENT_LOCK_S or not point.is_finite():
		return false
	camera_accent_age=0.0
	camera_accent_point=point
	camera_accent_source=source
	return true


func update_camera(delta: float) -> void:
	var focus := Vector2(480,285).lerp(Vector2(495,305),approach)
	var target := zoom
	if transition_elapsed>=0:
		target += .12*sin(approach*PI*.5)
	if camera_accent_age<CAMERA_ACCENT_S:
		var accent := smoothstep(0.0,.12,camera_accent_age)*(1.0-smoothstep(.18,CAMERA_ACCENT_S,camera_accent_age))
		focus=focus.lerp(camera_accent_point,.33*accent)
		target+=.065*accent
	var weight := 1.0 if delta==0.0 or not arrival_finished or transition_elapsed>=0 else 1.0-exp(-delta*11.0)
	battlefield.scale = battlefield.scale.lerp(Vector2.ONE*target,weight)
	var anchor := Vector2(480,285).lerp(focus,clampf((battlefield.scale.x-1.0)*2.0,0.0,1.0))
	battlefield.position = battlefield.position.lerp(anchor-focus*battlefield.scale+pan,weight)
	ground.scale = battlefield.scale*1.10
	ground.position = (size-size*ground.scale)*.5 + (battlefield.position + DESIGN*(battlefield.scale-Vector2.ONE)*.5)*canvas.scale
	ground.position = ground.position.clamp(size-size*ground.scale,Vector2.ZERO)

func _hunter_contact_canvas(actor:HybridCharacter) -> Vector2:
	var world:Vector2 = actor.tool_contact_world()
	if actor is Frontline.Han or actor is Frontline.Uram:
		world = actor.contact_point()
	elif actor is SaebomRig:
		world = actor.stone_world()
	return battlefield.get_global_transform().affine_inverse()*world

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
	var basic_attack := pose in ["thrust","auto_thrust"]
	for i in hunters.size():
		var hunter := hunters[i]
		var side_han_jump := i == 0 and running and pose in ["thrust",ManualHunt.HAN_SPEAR_3] and pose_clock < (JumpMotion.JUMP_SECONDS if pose == "thrust" else _manual_duration(pose))
		var native_manual := running and i == rules.attacker and _is_native_manual(pose) and pose_clock < _manual_duration(pose)
		var use_guard_pose := running and i == 1 and guard_active
		var attack := running and pose_clock<RULES.POSE_SECONDS and pose in ["thrust","auto_thrust","strike","team"] and i == rules.attacker
		var dodge := running and pose=="counter" and pose_clock<RULES.POSE_SECONDS and i == rules.attacker
		var placed: Vector2 = ALLY_CELLS[assigned_cells[i]]
		var battle_target := HUNTER_BATTLE_CENTER+(placed-FORMATION_CENTER)*.62
		var base := placed.lerp(battle_target,approach)
		hunter.scale = Vector2.ONE*lerpf(.60,.56,approach)*(1.0 if i == RULES.SAEBOM else FRONTLINE_VISUAL_SCALE)
		var lunge := 42 if basic_attack else 24
		var assisting := running and pose == "team" and pose_clock < RULES.POSE_SECONDS and not attack and rules.party_hp[i]>0
		var attack_direction := base.direction_to(DEER_SLOT)
		var previous_position := hunter.position
		var shift := 0.0
		if not side_han_jump and i != RULES.SAEBOM:
			if attack: shift = lunge
			elif assisting: shift = 10.0
		if native_manual and not side_han_jump: shift = 34.0
		if dodge and not use_guard_pose: shift = -18.0
		hunter.position = base + attack_direction*shift*movement_beat
		if native_manual and not side_han_jump and not _prey_is_adult():
			hunter.position.y -= (17.0 if i == 0 else 13.0)*sin(PI*clampf(pose_clock/_manual_duration(pose),0.,1.))
		if native_manual and side_han_jump:
			var travel_beat:=smoothstep(.05,.52,pose_clock)*(1.0-smoothstep(.64,.96,pose_clock))
			hunter.position+=han_chain_travel*travel_beat
		var arrival_heading := Vector2(1,.55).lerp(Vector2(1,.28),approach)
		var approaching := transition_elapsed >= 0.0 and approach > 0.0 and approach < 1.0
		var close_phase := clampf(pose_clock / RULES.POSE_SECONDS, 0.0, 1.0)
		if approaching:
			var travel := previous_position.distance_to(hunter.position)
			hunt_stride_phases[i] = fposmod(hunt_stride_phases[i]+travel/maxf(1.0,42.0*hunter.scale.x)*TAU,TAU)
		var approach_phase := hunt_stride_phases[i] if approaching else pose_clock*12.0
		var facing := han_chain_facing if native_manual and side_han_jump else hunter.position.direction_to(deer.position) if approach >= 1.0 else arrival_heading
		if i != RULES.SAEBOM:
			var motion := ""
			if use_guard_pose: motion = "counter"
			elif side_han_jump: motion = "chain"
			elif native_manual: motion = "skill"
			elif attack: motion = "skill" if pose == "strike" else "basic"
			elif assisting: motion = "basic"
			elif dodge: motion = "hit" if hit_on_hunter and hit_age < .26 else "guard"
			var duration:float = hunter.clip_duration(motion)
			var motion_time := duration*clampf(pose_clock/JumpMotion.JUMP_SECONDS,0.0,1.0) if side_han_jump and not native_manual else duration*close_phase
			if native_manual: motion_time = duration*clampf(pose_clock/_manual_duration(pose),0.0,1.0)
			if use_guard_pose: motion_time = duration*clampf((manual_combat_clock-guard_started)/ManualHunt.GUARD_CLOSE,0.0,1.0)
			hunter.animate(delta,facing,approach_phase,approaching,motion,motion_time,false)
		elif hunter is SaebomRig:
			if pose == "team" and rules.attacker == RULES.SAEBOM and not bom_hop_offset.is_zero_approx():
				hunter.position = _saebom_safe_position(base, base + bom_hop_offset * _saebom_hop_envelope(close_phase))
			var motion := "skill" if attack and pose == "team" else "attack" if attack or assisting else ""
			var motion_time: float = close_phase * hunter.motion_duration(motion)
			hunter.animate(delta, facing, approach_phase, dodge or approaching, motion, motion_time, false)
			if pose == "team" and rules.attacker == RULES.SAEBOM and bom_hop_strength > 0.0:
				var crouch := smoothstep(0.0,.09,close_phase)*(1.0-smoothstep(.09,.18,close_phase))
				var land := smoothstep(.31,.36,close_phase)*(1.0-smoothstep(.36,.49,close_phase))
				var rise := sin(PI*clampf((close_phase-.10)/.26,0.0,1.0))
				var return_lift := sin(PI*clampf((close_phase-.83)/.17,0.0,1.0))
				hunter.pivot.position.y += bom_hop_strength*(.18*rise+.065*return_lift-.07*(crouch+land))
			if attack and pose == "auto_thrust" and bom_shoving:
				_pose_saebom_palm(hunter, close_phase)
			rally_art.pose_after_actor_sample(not attack and not assisting and not dodge)
		hunter.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		hunter_markers[i].position = hunter.position+Vector2(0,-63)
		hunter_markers[i].visible = arrival_finished
		hunter_field_bars[i].get_parent().visible = approach>=1.0
	var charge := running and pose=="counter"
	var deer_motion := Vector2(-29,-8) if charge else Vector2.ZERO if basic_attack else Vector2(23,-8)
	deer.position = ENEMY_CELLS[4].lerp(DEER_SLOT,approach)+(deer_motion*movement_beat if running else Vector2.ZERO)
	var deer_close_travel := false
	if running and bom_prey_pocket.is_finite():
		var close_progress := smoothstep(.06,.70,pose_clock/RULES.POSE_SECONDS) if charge and rules.attacker == RULES.SAEBOM else 1.0
		deer.position = bom_prey_travel_from.lerp(bom_prey_pocket,close_progress)
		deer_close_travel = close_progress > 0.0 and close_progress < 1.0
	elif running and bom_prey_depart.is_finite() and charge:
		var leave := smoothstep(.04,.93,pose_clock/RULES.POSE_SECONDS)
		deer.position = bom_prey_depart.lerp(deer.position,leave)
		deer_close_travel = leave > 0.0 and leave < 1.0
		if leave >= 1.0: bom_prey_depart = Vector2.INF
	if basic_recoil>0:
		deer.position += Vector2(13,-3)*basic_recoil/BASIC_RECOIL_TIME
	deer.scale = Vector2.ONE*lerpf(.60,.63,approach)
	deer.walking = 1.0 if transition_elapsed>=0 and approach>0.0 and approach<1.0 else (movement_beat if running and (charge or basic_recoil>0.0) else 0.0)
	if deer_close_travel: deer.walking = maxf(deer.walking,.74)
	deer.heading = lerp_angle(-PI*.34,-PI*.35,approach)
	deer.gait_phase = pose_clock*14
	deer.clock += delta
	if deer is NativeBoar: _pose_adult_boar(deer,charge)
	else: deer.animate_rig(delta)
	if charge and rules.attacker == 1 and guard_prey_origin.is_finite(): _align_uram_guard()
	prey_hud.position = deer.position + Vector2(0,-deer.world_height*deer.scale.y-15)
	prey_hud.visible = arrival_finished
	var points:Array=[]
	var transform:=combat_controls.get_global_transform().affine_inverse()*battlefield.get_global_transform()
	for hunter in hunters:points.append(transform*(hunter.position+Vector2(0,-63)))
	points.append(transform*(deer.position+Vector2(0,-deer.world_height*deer.scale.y-15)))
	NativeHud.sync_heads(head_headers,points,Rect2(8,70,944,350),first_blood_age if arrival_finished and approach>=1.0 else -INF)
	hunter_bar.hide()
	deer_bar.hide()

## Align authored wildlife windup/execute to the existing production strike clock.
func _native_contact_mark() -> float:
	if adult_markers.is_empty(): return IMPACT_SECONDS
	var lead := .14 if _prey_is_adult() else .22
	return clampf(maxf(float(adult_markers.charge_release)+lead,float(adult_markers.charge_contact_reference)),0.0,float(adult_markers.charge_end))

func _native_takeoff_clock() -> float:
	if adult_markers.is_empty(): return .122
	return clampf(IMPACT_SECONDS*float(adult_markers.charge_release)/maxf(.01,_native_contact_mark()),.09,.194 if _prey_is_adult() else .180)

func _native_charge_elapsed(seconds:float) -> float:
	var launch_t := _native_takeoff_clock()
	var release := float(adult_markers.charge_release)
	var contact := _native_contact_mark()
	if seconds <= launch_t: return release*clampf(seconds/launch_t,0.0,1.0)
	if seconds <= IMPACT_SECONDS: return lerpf(release,contact,inverse_lerp(launch_t,IMPACT_SECONDS,seconds))
	return lerpf(contact,float(adult_markers.charge_end),clampf(inverse_lerp(IMPACT_SECONDS,RULES.POSE_SECONDS,seconds),0.0,1.0))

## Uses the real visible shield plane. For a given muzzle height and signed
## depth, solve for the nearest point on that plane with that fixed height.
func _shield_reference_at_height(face:Transform3D,y:float,z:float) -> Vector3:
	var half := Vector2(.305,.38)
	var weight := Vector2(face.basis.x.y*half.x,face.basis.y.y*half.y)
	if weight.length_squared() < .0001: return Vector3.INF
	var local := weight*(y-face.origin.y-face.basis.z.y*z)/weight.length_squared()
	if local.length() > .95: return Vector3.INF
	return face*Vector3(local.x*half.x,local.y*half.y,z)

func _align_uram_guard() -> void:
	var uram := hunters[1] as Frontline.Uram
	if not is_instance_valid(uram) or not uram.has_shield_anchor(): return
	var bow := smoothstep(.02,.14,pose_clock)*(1.0-smoothstep(.27,.45,pose_clock))
	if bow <= .001: return
	var toward := uram.position.direction_to(guard_prey_origin)
	if toward.is_zero_approx(): return
	var pose_span := uram.clip_duration("counter")
	var brace := .88 if _prey_is_adult() else .66
	if pose_span > 0.0: uram.sample_native("counter",pose_span*lerpf(clampf(pose_clock/.32,0.0,1.0),brace,bow))
	var muzzle := _counter_muzzle()
	if not muzzle.is_finite(): return
	var shield:Node3D=uram.shield
	var raw:Transform3D=shield.global_transform
	var old_face := _shield_metric(uram)
	var vertical := (_stone_metric_point(uram.camera,uram.display,raw.origin+Vector3.UP)-old_face.origin).y
	if absf(vertical) < .001: return
	var desired_lift := clampf((muzzle.y-old_face.origin.y)/vertical,-.34,.55)*bow
	# Nudge the real elbow/wrist in its existing pose before orienting the shield.
	var rig:Skeleton3D=uram.skeleton
	var wrist: int = uram.left_hand_bone
	var elbow: int = uram.shield_bone
	var upper := rig.get_bone_parent(elbow) if elbow >= 0 else -1
	if wrist >= 0 and upper >= 0 and elbow >= 0:
		var want := rig.to_local(rig.to_global(rig.get_bone_global_pose(wrist).origin)+Vector3.UP*desired_lift)
		for repeat in range(3):
			for joint in [upper,elbow]:
				var t := rig.get_bone_global_pose(joint)
				var now := rig.get_bone_global_pose(wrist).origin-t.origin
				var goal := want-t.origin
				if now.length_squared()<.0001 or goal.length_squared()<.0001: continue
				t.basis=Basis(Quaternion.IDENTITY.slerp(Quaternion(now.normalized(),goal.normalized()),.62))*t.basis
				rig.set_bone_global_pose(joint,t)
				rig.force_update_all_bone_transforms()
		uram.update_equipment()
		raw=shield.global_transform
	var normal := Vector3(toward.x,.12,toward.y/.65).normalized()
	var right := Vector3.UP.cross(normal).normalized()
	var up := normal.cross(right).normalized()
	shield.global_transform=raw.interpolate_with(Transform3D(Basis(right,up,normal),raw.origin),bow)
	var face:=_shield_metric(uram)
	var takeoff:=_native_takeoff_clock()
	var punch:=smoothstep(takeoff-.013,IMPACT_SECONDS-.022,pose_clock)
	var z:=lerpf(.48,-.055,punch)
	var reference:=_shield_reference_at_height(face,muzzle.y,z)
	if not reference.is_finite(): return
	var correction:=Vector2(reference.x-muzzle.x,reference.z-muzzle.z)*STONE_METRIC
	var endpoint:=deer.position+correction
	var steering:=smoothstep(.055,takeoff+.005,pose_clock)*(1.0-smoothstep(.27,.50,pose_clock))
	if endpoint.distance_to(guard_prey_origin)>54.0 or endpoint.distance_to(uram.position)<24.0: return
	for i in [0,2]:
		if rules.party_hp[i]>0 and endpoint.distance_to(hunters[i].position)<25.0: return
	deer.position=deer.position.lerp(endpoint,steering)

## Marks drive clips, never damage or scheduling.
func _pose_adult_boar(adult:NativeBoar, charge:bool) -> void:
	if adult_markers.is_empty():
		return
	if charge and pose_clock < RULES.POSE_SECONDS:
		adult.sample_native_phase("charge",_native_charge_elapsed(pose_clock))
	elif basic_recoil>0.0:
		adult.sample_native_phase("hit", (1.0-basic_recoil/BASIC_RECOIL_TIME)*float(adult_markers.hit))
	elif deer.walking>.20:
		adult.sample_native_phase("approach",fposmod(deer.clock,float(adult_markers.approach)))
	else:
		adult.sample_native_phase("idle",fposmod(deer.clock,float(adult_markers.idle)))

func draw_stage() -> void:
	if arrival_finished and transition_elapsed<0 and not combat_layout:
		var cell := drag_cell if dragging and drag_cell>=0 else assigned_cells[selected_hunter]
		var center: Vector2 = ALLY_CELLS[cell]
		var corners := PackedVector2Array([center-Vector2(0,CELL_SIZE.y*.5),center+Vector2(CELL_SIZE.x*.5,0),center+Vector2(0,CELL_SIZE.y*.5),center-Vector2(CELL_SIZE.x*.5,0)])
		battlefield.draw_colored_polygon(corners,Color(.1,.55,1,.35))
		corners.append(corners[0])
		battlefield.draw_polyline(corners,Color(.32,.78,1),2,true)
	if not combat_layout:return
	if hit_on_hunter or hit_damage <= 0 or hit_kind in ["sling_contact","native_manual"]: return
	var duration := .28 if hit_kind == "team" else .24 if hit_kind == "strike" else .16
	if hit_age >= duration: return
	var fade := 1.0-hit_age/duration
	if hit_kind == "team":
		for hunter in hunters:
			var from: Vector2 = _hunter_contact_canvas(hunter)
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


func _finish_visual_ready() -> bool:
	if not impact_pending and pose == "thrust" and pose_clock < JumpMotion.JUMP_SECONDS:
		return false
	if rules.outcome != "win":
		return not impact_pending
	var span := 0.0
	var age := hit_age
	match pose:
		ManualHunt.HAN_SPEAR_3: span = 1.20
		ManualHunt.HAN_SPEAR_2: span = .56
		ManualHunt.URAM_CLUB_2: span = 1.90
		"team":
			if hit_kind == "sling_contact":
				span = 1.22
				age = stone_hit_age
	if span > 0.0:
		deer.modulate.a=1.0-smoothstep(maxf(.16,span-.5),span,age)
		return not impact_pending and age>=span
	return not impact_pending


func show_result() -> void:
	if result_shown: return
	result_shown = true
	rally_art.cancel()
	manual_guard.cancel()
	chain_window.reset()
	manual_pending.clear()
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
