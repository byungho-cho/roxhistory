extends Control
signal exited

const SkillHUD = preload("res://scripts/duel_skill_hud.gd")
const Rules = preload("res://scripts/hunt_duel_rules.gd")
const Actor = preload("res://scripts/model_test_actor.gd")
const ModelTest = preload("res://scripts/model_test.gd")
const Profile = preload("res://scripts/model_motion_profile.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const HuntArt = preload("res://scripts/hunt_match_art.gd")
const Presentation = preload("res://scripts/duel_motion_presenter.gd")
const SharedWorld = preload("res://scripts/duel_shared_world.gd")
const HeadHUD = preload("res://scripts/battle_head_hud.gd")
const Accent = preload("res://scripts/battle_presentation_accent.gd")
const Ground = preload("res://assets/ui/hunting-formation/clearing-dirt.png")
const UIFont = preload("res://assets/fonts/NotoSansKR.ttf")
const SceneSize := Vector2(960,540)
const Left := Hunt.HUNTER_BATTLE_CENTER+(Hunt.ALLY_CELLS[0]-Hunt.FORMATION_CENTER)*.62
const Right := Hunt.DEER_SLOT
# Preserve latest model proportions; these projection scales match the measured
# settled 1-1 Han/deer heights (63.885 / 67.540 logical pixels at 960x540).
const HANGYEOL_BATTLE_SCALE := .76588
const FOREST_BATTLE_SCALE := .82588
# Local experiment: only this default lab matchup opts into grouped movement.
const APPROACH_TRAVEL := .88
const APPROACH_END := 1.04
const REVIVAL_ENTRANCE_SCALE := 1.30
const SHARED_REVIVAL_DELAY := 1.38
const HAN_SKILL_WINDUP_RATE := 3.25
const HAN_SKILL_WINDUP_LIMIT := .73
var entrance_scale := 1.0
const START_GAP := 218.0
const SPOTLIGHT_DIM := .228
const ENGAGE_GAP := 66.0
const FIRST_BASIC := [.23,.38]
const BASIC_CADENCE := [3.05,3.43]
const BASIC_MAX_TRAVEL := 16.0
const SP_COST := {"skill":2,"chain":3}
const UramCounterWave=preload("res://scripts/duel_uram_counter_wave.gd")
const URAM_GROUND_THUMP=preload("res://assets/audio/uram-2sp-weight/uram-ground-thump.wav")
const SoundPath := "res://assets/audio/hunt-duel-lab/"
const URAM_PARRY_SOUND := preload("res://assets/audio/lab-uram-res009/parry-c.mp3")
const URAM_GUARD_OPEN := .03
const URAM_GUARD_CLOSE := .32
const BasicRope := preload("res://scripts/saebom_rope_sling_basic_presentation.gd")
var basic_rope_glow:=BasicRope.make_glow()
const SoundNames := {"hangyeol":"han", "uram":"uram", "saebom":"bom", "forest":"deer", "adult":"boar"}

var app: Node
var rules := Rules.new()
var local_formation:Node2D
var ordinary_knife_fx:Array[Dictionary]=[]
const MeleeKnife=preload("res://scripts/duel_saebom_stone_knife.gd")
const MeleeKnifeIcon=preload("res://assets/ui/saebom-melee/stone-knife-2sp.png")

var local_formation_button:Button
var show_final_test35 := false
var local_test_charge:Button
var local_formation_banner:Label
var local_distance_buttons:Dictionary={}
var local_top_hud_positions:Dictionary={}
var local_version_stamp:Label
var local_bottom_hud_shift:=0.0


func _play_ranged_drill_stone_contact(enemy:String)->void:
	_sound(SoundNames.get(enemy,"deer")+"_hit")

func _toggle_local_formation(distance_drill:String="")->void:
	if is_instance_valid(local_formation):
		_close_local_formation()
		return
	local_formation=preload("res://scripts/hunt_duel_local_squad.gd").new()
	local_formation.name="LocalHuntFormation"
	arena.add_child(local_formation)
	local_formation.setup(_draw_animal_launch_dust if wild_takeoff_dust else Callable(), _draw_uram_gong if uram_gong_test else Callable(), _draw_local_uram_contact if local_all_effects else Callable(), _draw_local_uram_windup if local_all_effects else Callable(), _draw_squad_authored if local_full_squad_effects else Callable(), _draw_silver_deer if local_squad_silver else Callable(), _draw_deer_impact if local_squad_silver else Callable(), _project_preview_ring if local_world_ring else Callable(), _draw_local_weapon_glow if local_shared_ranged else Callable(), 2.04 if local_melee_polish else (1.84 if local_shared_ranged else 1.15), _draw_bom_hit if local_saebom_latest else Callable(), _draw_bom_trail if local_saebom_latest else Callable(), _draw_bom_wings if local_saebom_latest else Callable(), _draw_bom_ally if local_saebom_latest else Callable(), _pose_bom_cast if local_saebom_latest else Callable(), local_melee_polish)
	if local_melee_polish:
		local_formation.configure_spotlight(_draw_local_parry_floor,_draw_local_parry_flash,_draw_parry_stars,LOCAL_PARRY_SLOW,.50)
		local_formation.configure_uram_ground(_draw_squad_uram_ground,_play_uram_ground_thump)
		local_formation.parry_spotlight_started.connect(_squad_spotlight_started)
		local_formation.uram_ordinary_impact.connect(_sound.bind("uram_basic"))
	if not distance_drill.is_empty():
		local_formation.configure_saebom_distance_drill(distance_drill)
		if distance_drill=="far":local_formation.ranged_alignment_contact=_play_ranged_drill_stone_contact
	local_formation.set_input_paused(paused)
	if local_melee_polish:local_formation.place_bottom_hud(local_bottom_hud_shift)
	for audio in audio_pool:audio.stop()
	field.hide()
	skill_hud.hide()
	cast_notice.clear()
	cast_notice_layer.visible=local_melee_polish
	cast_notice_layer.queue_redraw()
	for holder in overhead:holder.panel.hide()
	for hud in local_formation.huds:
		touch_buttons.append(hud.portrait_button)
		touch_buttons.append(hud.chain_button)
	local_formation_button.text="1:1"
	if distance_drill=="far":
		local_formation_banner.text="\uC6D0\uAC70\uB9AC  \uC2DC\uD5D8  /  \uC6B0\uB78C HP 50%"
	elif distance_drill=="near":
		local_formation_banner.text="\uADFC\uAC70\uB9AC  \uC2DC\uD5D8  /  \uC0C8\uBD04 vs \uAF43\uC0AC\uC2B4"
	else:
		local_formation_banner.text="3 : 3  \uC804\uD22C \uC2DC\uD5D8"
	local_formation_banner.show()
	_sync_local_distance_buttons()


func _close_local_formation()->void:
	if not is_instance_valid(local_formation):return
	for hud in local_formation.huds:
		touch_buttons.erase(hud.portrait_button)
		touch_buttons.erase(hud.chain_button)
	touch_target=null;touch_pointer=-1
	local_formation.hide()
	local_formation.queue_free()
	local_formation=null
	ground.self_modulate=Color.WHITE
	local_parry_caption.hide()

	local_formation_button.text="\uBAA8\uB450"
	local_formation_banner.hide()
	local_test_charge.show()
	field.show()
	skill_hud.show()
	cast_notice_layer.show()
	reset_round()


var arena := Control.new()
var field := Control.new()
var damage_numbers := preload("res://scripts/hunt_damage_numbers.gd").new()
var ground: TextureRect
# Reuse the campaign battle camera implementation, without adding its scene or rules to the tree.
var battle_camera := Hunt.new()
var paused := false
var pause_button: Button
var pause_icon: TextureRect
var pause_caption: Label
var name_labels: Array[Label] = []
var selection_frames: Dictionary = {}
var cast_from := Left
var presentation := Presentation.new()
var effects_layer := Node2D.new()
var ready_light_layer := Node2D.new()
var deer_skill_light_layer := Node2D.new()
var han_chain_light := Node2D.new()
const HAN_CHAIN_IMPACT_SECONDS := .70
const HAN_CHAIN_TAIL := .32
const AUTHORED_FRAME_COUNT := 21
const AUTHORED_FRAME_SECONDS := .70
const SAEBOM_SUPPORT_START := .16
const AUTHORED_FILES := {"uram":"uram_chain_impact","saebom":"saebom_chain_support"}
var authored_asset_size:=192
var authored_bold:=false
var authored_polished:=true
var uram_wave:=true
var uram_echo:=true
var saebom_hop:=true
# The authored 3.5-second cheer lift-off beat (three genuine jumps).
const SAEBOM_CHEER_NATIVE_SECONDS:=3.5
const SAEBOM_CHEER_LIFTS:=[.18,.88,1.58]
var saebom_aurora:=true
var saebom_aurora_origin:=Vector2.ZERO
const URAM_WAVE_ORIGIN:=Vector2(86,192)/384.0
const SAEBOM_AURORA_START:=.16
var han_authored_size:=192
var han_radial:=true
var han_radial_frames:Array[Texture2D]=[]
const HAN_RADIAL_EXTENT:=Vector2(557,201)
const HanGround = preload("res://scripts/hunt_han_3sp_ground.gd")
var han_ground := HanGround.new()
var han_ground_anchor := Vector2.INF
var han_ground_at := -INF
var han_2sp_enabled:=true
var han_2sp_frames:Array[Texture2D]=[]
const HAN_2SP_COUNT:=11
const HAN_2SP_DURATION:=11.0/30.0
const HAN_2SP_DISPLAY_SIZE:=288.0
const HAN_2SP_ORIGIN:=Vector2(90,117)
var authored_frames:Array[Texture2D]=[]
var authored_asset_hero:=""
var authored_load_us:=0
var cast_notice_layer:=Node2D.new()
var cast_notice_frames:Array[StyleBoxFlat]=[]
var cast_notice_anchor:=Vector2.ZERO
var cast_notice:Dictionary={}
var location_layer := Node2D.new()
var ring_halo:GradientTexture2D
var ring_band:GradientTexture2D
var floor_light_wash:GradientTexture2D
var floor_light_halo:GradientTexture2D
var floor_light_core:GradientTexture2D
var ground_wave_phase:=0.0
const GROUND_WAVE_SECONDS:=2.4
var ground_wave_span:=2.0
var hp_reveal_at := -1.0
var deer_wake:Array[Dictionary]=[]
const DEER_DUST_LIFETIME:=2.5
const LocalUramHeavy = preload("res://scripts/hunt_duel_uram_2p_effect.gd")
const Saebom2Vfx=preload("res://scripts/hunt_duel_saebom_2p_effect.gd")
const Saebom3Vfx=preload("res://scripts/hunt_duel_saebom_3p_effect.gd")
var bom_style:=Saebom3Vfx.new()
var local_melee_polish:=false
const RallyCloud := preload("res://scripts/saebom_rally_cloud.gd")
var local_bom_cloud_at:=-INF
var local_bom_cloud_origin:=Vector2.INF
var local_bom_cloud_fifths:=0
const RallySilver := preload("res://scripts/saebom_rally_silver_vfx.gd")
var local_bom_silver_cast_at:=-INF
var local_bom_rally_at:=-INF
var local_bom_rally_until:=-INF
var local_saebom_latest:=false
var local_shared_ranged:=false
var bom_path:=PackedVector2Array()
var bom_path_end:=-INF
var bom_path_action:=-1
var local_world_ring:=false
var local_squad_silver:=false
var local_full_squad_effects:=false
var local_all_effects:=false
var squad_saebom_frames:Array[Texture2D]=[]
var uram_generic_gong_test:=false
var uram_gong_test:=false
var wild_takeoff_dust:=false
var deer_dust_at:=-INF
var deer_dust_screen:=Vector2.ZERO
var deer_dust_is_world:=false
var deer_dust_world:=Vector3.ZERO
var a: Actor
var b: Actor
var motion: Array[String] = ["idle","idle"]
var age := [0.0,0.0]
var contact_at := [-1.0,-1.0]
var motion_contact := [-1.0,-1.0]
var frame_contact := [-1.0,-1.0]
var start_cast_at := -1.0
var execute_at := -1.0
var next_attack := [0.4,1.6]
var animal_attack_count := 0
var visual_clock := 0.0
const LOCAL_PARRY_SLOW:=2.4
var local_parry_clock:=-1.0
var local_parry_focus:=Vector2.ZERO
const APPROVED_PARRY_ASSET_DIR:="res://assets/effects/duel-uram-approved/"
var local_parry_sheets:Array[Texture2D]=[]
var local_parry_thump:AudioStreamPlayer
var local_parry_caption:Label
var local_guard_action:=-1
var ordinary_counter_target:Actor
var ordinary_counter_spent:=false
const UramCombined := preload("res://scripts/hunt_uram_3sp_combined.gd")
var uram_combined := UramCombined.new()
var uram_short_counter_fan:Dictionary={}
var ordinary_counter_wave:Dictionary={}
var fx: Array[Dictionary] = []
var controls: Dictionary = {}
var timer: Label
var bars: Array[TextureProgressBar] = []
var skill_hud: SkillHUD
var skill_button: Button
var chain_button: Button
var audio_pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var cues: Array[String] = []
var pool_index := 0
var closing := false
var approach_active := false
var shared_world:SharedWorld
var overhead:Array=[]
var deer_hud_anchor:=Vector2.INF
var accent:=Accent.new()
var camera_base_scale:=Vector2.ONE
var camera_base_position:=Vector2.ZERO
var chain_impact_frames:Array[Texture2D]=[]
var contact_glow:GradientTexture2D
var tip_trail:Array[Vector2]=[]

func _prototype_duel()->bool:
	return rules.ally_id=="hangyeol" and rules.enemy_id=="forest"

func _saebom_duel()->bool:
	return rules.ally_id=="saebom" and (rules.enemy_id=="forest" or (local_shared_ranged and rules.enemy_id=="adult"))

func _uram_duel()->bool:
	return rules.ally_id=="uram" and (rules.enemy_id=="adult" or _uram_deer_close())

func _local_ram_busy()->bool:
	if not (_uram_deer_close() and is_instance_valid(shared_world)):return false
	if local_parry_clock>=0.:return true
	return shared_world.action_name[1]=="skill" and motion[1] in ["skill","hit","walk"]

const URAM_BORDER_LEAD:=.50
const URAM_BORDER_RATE:=3.0

func _local_guard_pre_cue()->bool:
	return _uram_deer_close() and is_instance_valid(shared_world) and rules.living() and not paused and not approach_active and motion[1]=="skill" and not shared_world.consumed[1] and age[1]>=SharedWorld.FOREST_PLANT_AT-URAM_BORDER_LEAD

func _local_guard_accepting()->bool:
	return _uram_deer_close() and is_instance_valid(shared_world) and rules.living() and not paused and not approach_active and motion[1]=="skill" and not shared_world.consumed[1] and age[1]>=SharedWorld.FOREST_PLANT_AT

func uram_guard_active()->bool:
	if not (_uram_duel() and rules.living() and motion[0]=="chain" and motion[1]=="skill"):return false
	if _uram_deer_close() and is_instance_valid(shared_world):
		# Pending input is keyed to this exact ram and stays raised until it resolves.
		return local_guard_action==shared_world.action_id[1]
	return age[0]>=URAM_GUARD_OPEN and age[0]<=URAM_GUARD_CLOSE

func _duel_anchor(side:int,gap:float)->Vector2:
	return (Left+Right)*.5+Left.direction_to(Right)*gap*.5*(-1.0 if side==0 else 1.0)

func _han_fallback()->bool:
	return local_all_effects and rules.ally_id=="hangyeol" and rules.enemy_id=="adult" and not is_instance_valid(shared_world)

func _han_boar_latest()->bool:return local_melee_polish and _han_fallback()
func _uram_deer_close()->bool:return local_melee_polish and rules.ally_id=="uram" and rules.enemy_id=="forest"
func _settled_anchor(side:int)->Vector2:
	if _uram_deer_close():return _duel_anchor(side,76.0)
	if _han_fallback():return _duel_anchor(side,82.0)
	if _prototype_duel():
		return _duel_anchor(side,ENGAGE_GAP)
	return Left if side==0 else Right
var touch_pointer := -1
var touch_target: Button
var touch_buttons: Array[Button] = []

func _ready() -> void:
	local_melee_polish=show_final_test35 or "--duel-local-test=35" in OS.get_cmdline_user_args()
	if local_melee_polish:
		_load_approved_parry_asset()
		RallySilver.prepare()
	if local_melee_polish and "--duel-start-boar" in OS.get_cmdline_user_args():rules.enemy_id="adult"
	local_saebom_latest=local_melee_polish or "--duel-local-test=34" in OS.get_cmdline_user_args()
	local_shared_ranged=local_saebom_latest or "--duel-local-test=33" in OS.get_cmdline_user_args()
	local_world_ring=local_shared_ranged or "--duel-local-test=32" in OS.get_cmdline_user_args()
	local_squad_silver=local_world_ring or "--duel-local-test=31" in OS.get_cmdline_user_args()
	local_full_squad_effects=local_squad_silver or "--duel-local-test=30" in OS.get_cmdline_user_args()
	local_all_effects=local_full_squad_effects or "--duel-local-test=29" in OS.get_cmdline_user_args()
	uram_generic_gong_test=local_all_effects or "--duel-local-test=28" in OS.get_cmdline_user_args()
	uram_gong_test=uram_generic_gong_test or "--duel-local-test=27" in OS.get_cmdline_user_args()
	wild_takeoff_dust=uram_gong_test or "--duel-local-test=26" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg=="--duel-3sp-polished=1":authored_polished=true
		if arg=="--uram-3sp-wave=1":uram_wave=true
		if arg=="--uram-3sp-echo=1":uram_echo=true
		if arg=="--saebom-3sp-hop=1":saebom_hop=true
		if arg=="--saebom-3sp-aurora=1":saebom_aurora=true
		if arg=="--duel-3sp-bold=1":
			authored_bold=true
		if arg.begins_with("--duel-3sp-asset-size="):
			var requested:=int(arg.get_slice("=",1))
			if requested in [0,192]:authored_asset_size=requested
		if arg=="--han-3sp-radial=1":han_radial=true
		if arg=="--han-2sp-authored=1":
			han_2sp_enabled=true
		if arg.begins_with("--han-3sp-asset-size="):
			var requested:=int(arg.get_slice("=",1))
			if requested in [192,384]:han_authored_size=requested
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	var bold:=FontVariation.new();bold.base_font=UIFont
	bold.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):700.0}
	theme.default_font = bold
	var backdrop := ColorRect.new()
	backdrop.color = Color("#1d1712")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(arena)
	arena.size = SceneSize
	arena.clip_contents = false
	arena.mouse_filter=MOUSE_FILTER_IGNORE
	field.mouse_filter=MOUSE_FILTER_IGNORE
	arena.add_child(field)
	damage_numbers.z_index = 12
	field.add_child(damage_numbers)
	rules.hp_lost.connect(_show_duel_hp_loss)
	ground=HuntArt.picture(self,Hunt.CLEARING,Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	move_child(ground,backdrop.get_index()+1)
	battle_camera.canvas=arena;battle_camera.battlefield=field;battle_camera.ground=ground
	battle_camera.arrival_finished=true;battle_camera.approach=1.0
	field.add_child(location_layer)
	var ring_material:=CanvasItemMaterial.new()
	ring_material.blend_mode=CanvasItemMaterial.BLEND_MODE_MIX
	location_layer.material=ring_material
	ring_halo=_new_ring_light(PackedFloat32Array([0,.28,.46,.61,.76,.91,1]),PackedFloat32Array([.10,.12,.15,.27,.18,.035,0]))
	ring_band=_new_ring_light(PackedFloat32Array([0,.53,.60,.65,.68,.72,.79,1]),PackedFloat32Array([0,0,.035,.22,.91,.30,.035,0]))
	floor_light_wash=_new_ring_light(PackedFloat32Array([0,.24,.45,.58,.70,.82,1]),PackedFloat32Array([.14,.17,.28,.46,.37,.12,0]))
	floor_light_halo=_new_ring_light(PackedFloat32Array([0,.41,.55,.62,.70,.83,1]),PackedFloat32Array([0,.03,.14,.55,.40,.11,0]))
	floor_light_core=_new_ring_light(PackedFloat32Array([0,.54,.59,.612,.631,.65,.71,1]),PackedFloat32Array([0,0,.05,.83,.88,.19,0,0]))
	location_layer.draw.connect(_draw_han_radial)
	location_layer.draw.connect(_draw_saebom_aurora)
	location_layer.draw.connect(_draw_location_rings)
	location_layer.draw.connect(_draw_local_uram_floor)
	location_layer.draw.connect(_draw_uram_field_ground)
	field.add_child(effects_layer)
	effects_layer.z_index = 10
	effects_layer.draw.connect(_draw_effects)
	field.add_child(ready_light_layer)
	ready_light_layer.z_index=9
	var glow_material:=CanvasItemMaterial.new()
	glow_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	ready_light_layer.material=glow_material
	ready_light_layer.draw.connect(_draw_duel_lights)
	field.add_child(deer_skill_light_layer)
	deer_skill_light_layer.z_index=10
	deer_skill_light_layer.draw.connect(_draw_silver_deer_skill_lights)
	field.add_child(han_chain_light)
	han_chain_light.z_index=11
	han_chain_light.material=glow_material
	han_chain_light.draw.connect(_draw_han_chain_light)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		audio_pool.append(player)
	arena.add_child(cast_notice_layer)
	cast_notice_layer.z_index=31
	local_parry_caption=_label("받아치기 성공",Rect2(43,82,214,32),24)
	local_parry_caption.z_index=32
	local_parry_caption.add_theme_color_override("font_color",Color("ffdda1"))
	local_parry_caption.add_theme_color_override("font_outline_color",Color("4a2f1e"))
	local_parry_caption.add_theme_constant_override("outline_size",6)
	local_parry_caption.hide()
	for tint in [Color("ffd179"),Color("87ddff")]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("101d2c",.93)
		style.border_color=tint
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		cast_notice_frames.append(style)
	cast_notice_layer.draw.connect(func():_draw_cast_notice(cast_notice_anchor))

	_setup_ui()
	if app!=null and ResourceLoader.exists("res://gahui_trial/gahui_hunt_test.tscn"):
		var gahui_button := _button("가희 모션",Rect2(603,16,108,34),func():app.call_deferred("open_gahui_hunt_from_lab"))
		gahui_button.name="GahuiMotionEntry"
		gahui_button.add_theme_font_size_override("font_size",16)
	for i in 21:
		var stem:="res://assets/effects/d0071-chain/han_chain_impact_%02d.png"%i
		var half:="res://assets/effects/duel-3sp-authored/hangyeol/192/han_chain_impact_%02d.png"%i
		chain_impact_frames.append(load(half if han_authored_size==192 and ResourceLoader.exists(half) else stem))
	if not han_ground.prepare() and han_radial:
		for i in 21:
			var folder:="duel-3sp-polished" if authored_polished else "duel-3sp-directional"
			var radial:="res://assets/effects/%s/hangyeol/192/han_3sp_radial_%02d.png"%[folder,i]
			var texture:=ResourceLoader.load(radial,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D if ResourceLoader.exists(radial) else null
			if texture==null or texture.get_size()!=Vector2(192,192):
				push_warning("Missing or invalid Han radial 3 SP frame: "+radial)
				han_radial_frames.clear()
				break
			han_radial_frames.append(texture)
	if han_2sp_enabled:
		for i in HAN_2SP_COUNT:
			var path:="res://assets/effects/duel-2sp-authored/han_2sp_impact_%02d.png"%i
			if not ResourceLoader.exists(path):
				push_warning("Missing Han 2 SP visual trial frame: "+path)
				han_2sp_frames.clear()
				break
			var frame:=ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			if frame==null or frame.get_size()!=Vector2(192,192):
				push_warning("Invalid Han 2 SP visual trial frame: "+path)
				han_2sp_frames.clear()
				break
			han_2sp_frames.append(frame)
	resized.connect(_fit)
	_fit()
	reset_round()

func _fit() -> void:
	var safe_start:=Vector2.ZERO
	var safe_end:=size
	if OS.has_feature("android"):
		var area:=DisplayServer.get_display_safe_area()
		var physical:=Vector2(DisplayServer.screen_get_size())
		if physical.x>0 and physical.y>0 and area.has_area():
			safe_start=(Vector2(area.position)*size/physical).clamp(Vector2.ZERO,size)
			safe_end=(Vector2(area.end)*size/physical).clamp(safe_start,size)
	var safe_size:=safe_end-safe_start
	var fit := minf(safe_size.x/SceneSize.x,safe_size.y/SceneSize.y)
	arena.scale = Vector2.ONE * fit
	arena.position = safe_start+(safe_size - SceneSize*fit)*.5
	battle_camera.size=size
	if local_melee_polish and fit>.0001:_place_expanded_test_hud(safe_size.y/fit,fit)
	# Refit the painted ground without snapping the current combat camera ease.
	battle_camera.update_camera(.000000000001)

func _place_expanded_test_hud(visible_height:float,fit:float)->void:
	# Battle presentation stays tied to the original centered 960x540 field.
	# Only independent interactive controls can use the taller safe area.
	var gutter:=maxf(0.,(visible_height-SceneSize.y)*.5)
	const SAFE_INSET:=6.
	var logical_to_physical:=float(get_window().size.y)/maxf(1.,get_viewport_rect().size.y)
	var physical_per_unit:=maxf(.001,fit*logical_to_physical)
	var top_shift:=minf(39./physical_per_unit,maxf(0.,gutter+10.-SAFE_INSET))
	for control:Control in local_top_hud_positions:
		control.position=Vector2(local_top_hud_positions[control])-Vector2(0.,top_shift)
	const CARD_TOP:=406.
	const CARD_VISUAL_BOTTOM:=531.
	local_bottom_hud_shift=minf(50./physical_per_unit,maxf(0.,SceneSize.y+gutter-CARD_VISUAL_BOTTOM-SAFE_INSET))
	if is_instance_valid(skill_hud):skill_hud.position.y=CARD_TOP+local_bottom_hud_shift
	if is_instance_valid(local_formation):local_formation.place_bottom_hud(local_bottom_hud_shift)
	if is_instance_valid(local_test_charge) and is_instance_valid(local_version_stamp):
		var tools_shift:=minf(local_bottom_hud_shift,maxf(0.,SceneSize.y+gutter-533.-SAFE_INSET))
		local_test_charge.position.y=448.+tools_shift
		local_version_stamp.position.y=509.+tools_shift

func _label(value: String, rect: Rect2, font_size: int) -> Label:
	var item := Label.new()
	item.position = rect.position
	item.size = rect.size
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color",Color("fff2d6"))
	item.add_theme_color_override("font_shadow_color",Color(0,0,0,.5))
	item.add_theme_constant_override("outline_size",0)
	item.add_theme_constant_override("shadow_offset_y", 1)
	arena.add_child(item)
	return item

func _button(value: String, rect: Rect2, pressed: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.position = rect.position
	item.size = rect.size
	item.pressed.connect(pressed)
	item.focus_mode=Control.FOCUS_NONE
	var texture=preload("res://assets/ui/duel-hud/control-round-gold.svg")
	if value in ["×","↻",""]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style:=StyleBoxTexture.new();style.texture=texture
			item.add_theme_stylebox_override(state,style)
	arena.add_child(item)
	touch_buttons.append(item)
	return item

func _plaque(rect:Rect2)->Panel:
	var panel:=Panel.new();panel.position=rect.position;panel.size=rect.size;panel.mouse_filter=MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color(.12,.086,.055,.76);style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",style);arena.add_child(panel);return panel

func _button_art(button:Button,texture:Texture2D,span:float)->TextureRect:
	return HuntArt.picture(button,texture,Rect2((button.size-Vector2.ONE*span)*.5,Vector2.ONE*span))

func _setup_ui() -> void:
	var first_top:=arena.get_child_count()
	# Local backplates only; no full-width title/header covers the battlefield.
	_plaque(Rect2(68,10,304,52))
	_plaque(Rect2(774,17,66,30))
	timer=_label("00:00",Rect2(774,17,66,30),13)
	timer.add_theme_color_override("font_color",Color("fff2d6"))
	var exit_button:=_button("",Rect2(16,16,36,36),_exit)
	exit_button.name="DuelClose"
	exit_button.tooltip_text="닫기"
	_button_art(exit_button,preload("res://assets/ui/duel-hud/close-ivory.svg"),20)
	var reset:=_button("",Rect2(900,16,36,36),reset_round)
	reset.name="DuelReset";reset.tooltip_text="같은 조합으로 다시 시작"
	_button_art(reset,preload("res://assets/ui/duel-hud/restart-ivory.svg"),20)
	pause_button=_button("",Rect2(850,16,36,36),toggle_pause)
	pause_button.name="DuelPause"
	pause_icon=_button_art(pause_button,preload("res://assets/ui/duel-hud/pause-ivory.svg"),20)
	pause_caption=_label("▶",Rect2(0,0,36,36),18);pause_caption.reparent(pause_button,false)
	pause_caption.add_theme_color_override("font_color",Color("fff2d6"))
	var ids := ["hangyeol","uram","saebom","forest","adult"]
	for i in ids.size():
		var key:String=ids[i]
		var item:=_button("",Rect2(78+54*i+(14 if i>=3 else 0),14,44,44),_select.bind(key,i>=3))
		item.name="Select_"+key;item.toggle_mode=true
		item.tooltip_text=["한결","우람","새봄","꽃사슴","큰 멧돼지"][i]
		var icon=ModelTest.portrait(key) if i<3 else preload("res://assets/ui/duel-hud/deer-selector.png") if i==3 else preload("res://assets/ui/duel-hud/boar-selector.png")
		var picture:=_button_art(item,icon,33)
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/duel_selector_crop.gdshader");picture.material=material
		selection_frames[key]=HuntArt.picture(item,preload("res://assets/ui/duel-hud/selection-gold.svg"),Rect2(0,0,44,44))
		controls[key]=item
	if local_melee_polish:
		for index in range(first_top,arena.get_child_count()):
			var control:Control=arena.get_child(index)
			local_top_hud_positions[control]=control.position
	for i in 2:
		var header:=HeadHUD.create_compact(arena,i==0);overhead.append(header);name_labels.append(header.label);bars.append(header.bar)
	skill_hud=SkillHUD.new();skill_hud.position=Vector2(447,437);arena.add_child(skill_hud);skill_hud.enable_duel_ready_feedback()
	if local_melee_polish:
		skill_hud.enable_portrait_damage_feedback()
		skill_hud.place_local_combat_hud(480.0)
	skill_hud.requested.connect(_try_player);skill_button=skill_hud.portrait_button;chain_button=skill_hud.chain_button
	touch_buttons.append(chain_button);touch_buttons.append(skill_button)
	if wild_takeoff_dust or "--duel-local-test=25" in OS.get_cmdline_user_args() or "--duel-local-test=24" in OS.get_cmdline_user_args() or "--duel-local-test=23" in OS.get_cmdline_user_args() or "--duel-local-test=21" in OS.get_cmdline_user_args():
		var test_stamp:=_label("0.2.294" if local_melee_polish else "TEST 34" if local_saebom_latest else "TEST 33" if local_shared_ranged else "TEST 32" if local_world_ring else "TEST 31" if local_squad_silver else "TEST 30" if local_full_squad_effects else "TEST 29" if local_all_effects else "TEST 28" if uram_generic_gong_test else "TEST 27" if uram_gong_test else "TEST 26" if wild_takeoff_dust else "TEST 25" if "--duel-local-test=25" in OS.get_cmdline_user_args() else "TEST 24" if "--duel-local-test=24" in OS.get_cmdline_user_args() else "TEST 23" if "--duel-local-test=23" in OS.get_cmdline_user_args() else "TEST 21",Rect2(846,509,94,24),13)
		test_stamp.add_theme_color_override("font_shadow_color",Color.BLACK)
		test_stamp.add_theme_constant_override("shadow_offset_y",1)
		test_stamp.mouse_filter=Control.MOUSE_FILTER_IGNORE
		local_version_stamp=test_stamp
		var test_charge:=_button("",Rect2(881,448,60,60),_refill_local_test_sp)
		test_charge.name="DuelTestCharge"
		test_charge.add_theme_font_size_override("font_size",15)
		for state in ["normal","hover","pressed","focus","disabled"]:test_charge.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var orb:=_button_art(test_charge,SkillHUD.ORB_FULL,60)
		orb.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var caption:=_label("\uCDA9\uC804",Rect2(0,0,60,60),15)
		caption.reparent(test_charge,false)
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		caption.add_theme_constant_override("outline_size",3)
		caption.add_theme_color_override("font_outline_color",Color("113655"))
		test_charge.mouse_entered.connect(func():orb.self_modulate=Color(1.13,1.13,1.13))
		test_charge.mouse_exited.connect(func():orb.self_modulate=Color.WHITE)
		local_test_charge=test_charge
		if wild_takeoff_dust or "--duel-local-test=25" in OS.get_cmdline_user_args() or "--duel-local-test=24" in OS.get_cmdline_user_args():
			var formation_panel:=_plaque(Rect2(379,16,78,39))
			if local_melee_polish:local_top_hud_positions[formation_panel]=formation_panel.position
			local_formation_button=_button("\uBAA8\uB450",Rect2(381,17,74,37),_toggle_local_formation)
			local_formation_button.name="DuelTestAll"
			local_formation_button.add_theme_font_size_override("font_size",16)
			local_formation_banner=_label("3 : 3  \uC804\uD22C \uC2DC\uD5D8",Rect2(365,78,230,25),16)
			local_formation_banner.hide()
			if local_melee_polish:
				local_top_hud_positions[local_formation_button]=local_formation_button.position
				local_top_hud_positions[local_formation_banner]=local_formation_banner.position
			if local_melee_polish:
				for mode in ["far","near"]:
					var label:="\uC6D0\uAC70\uB9AC" if mode=="far" else "\uADFC\uAC70\uB9AC"
					var left:=468.0 if mode=="far" else 560.0
					var choice:=_button(label,Rect2(left,17,86,37),_start_saebom_distance_drill.bind(mode))
					choice.name="SaebomDistanceFar" if mode=="far" else "SaebomDistanceNear"
					choice.toggle_mode=true
					choice.add_theme_font_size_override("font_size",16)
					local_distance_buttons[mode]=choice
					local_top_hud_positions[choice]=choice.position
					choice.hide()

func _sync_local_distance_buttons()->void:
	var active:=""
	if is_instance_valid(local_formation):active=local_formation.saebom_distance_drill
	for mode in local_distance_buttons:
		var choice:Button=local_distance_buttons[mode]
		choice.visible=rules.ally_id=="saebom" and (active!="" or not is_instance_valid(local_formation))
		choice.set_pressed_no_signal(active==mode)

func _start_saebom_distance_drill(mode:String)->void:
	if not local_melee_polish or rules.ally_id!="saebom" or mode not in ["far","near"]:return
	if is_instance_valid(local_formation):_close_local_formation()
	_toggle_local_formation(mode)

func _refill_local_test_sp()->void:
	if is_instance_valid(local_formation):
		local_formation.grant_sp()
		return
	if not rules.living():return
	rules.sp=Rules.MAX_SP
	_refresh()

func toggle_pause()->void:
	paused=not paused
	if is_instance_valid(local_formation):local_formation.set_input_paused(paused)
	touch_pointer=-1;touch_target=null
	for player in audio_pool:player.stream_paused=paused
	if is_instance_valid(local_parry_thump):local_parry_thump.stream_paused=paused
	_refresh()

func _exit_tree() -> void:
	# Unparented camera driver never runs campaign processing.
	battle_camera.hunt_audio.free()
	battle_camera.free()
	for player in audio_pool:
		player.stop()
		player.stream = null
	sounds.clear()

func _exit() -> void:
	if closing:
		return
	closing = true
	set_process(false)
	if app==null:
		get_tree().quit()
	else:
		exited.emit()

func _input(event: InputEvent) -> void:
	# Consume touch once before mouse emulation: a linked-icon release must
	# never be replayed as a portrait tap after SP/UI changes.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_pointer<0:
			for target in touch_buttons:
				var inside:=target.get_global_rect().has_point(event.position)
				if target==skill_button and skill_hud.badge.visible:
					inside=inside or skill_hud.badge.get_global_rect().has_point(event.position)
				if target.is_visible_in_tree() and not target.disabled and inside:
					touch_pointer=event.index;touch_target=target
					get_viewport().set_input_as_handled();return
		elif not event.pressed and event.index==touch_pointer:
			var target:=touch_target
			touch_pointer=-1;touch_target=null
			get_viewport().set_input_as_handled()
			var inside:=target.get_global_rect().has_point(event.position)
			if target==skill_button and skill_hud.badge.visible:
				inside=inside or skill_hud.badge.get_global_rect().has_point(event.position)
			if not event.canceled and target.is_visible_in_tree() and not target.disabled and inside:target.pressed.emit()
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_exit()

func _select(key: String, enemy: bool) -> void:
	_close_local_formation()
	if enemy:
		rules.enemy_id = key
	else:
		rules.ally_id = key
	reset_round()

func _prepare_authored_frames()->void:
	var name:="uram" if _uram_duel() else "saebom" if _saebom_duel() or (local_all_effects and rules.ally_id=="saebom") else ""
	var key:=name if authored_asset_size>0 else ""
	if key==authored_asset_hero:return
	authored_asset_hero=key
	authored_frames.clear()
	authored_load_us=0
	if key.is_empty():return
	var start:=Time.get_ticks_usec()
	var prefix:String=AUTHORED_FILES[key]
	for i in AUTHORED_FRAME_COUNT:
		var directional:bool=authored_asset_size==192 and ((key=="uram" and uram_wave) or (key=="saebom" and saebom_aurora))
		var asset_root:="duel-3sp-authored"
		if directional:
			if (key=="uram" and uram_echo) or (key=="saebom" and saebom_hop):
				asset_root="duel-3sp-rhythm"
			else:asset_root="duel-3sp-polished" if authored_polished else "duel-3sp-directional"
		elif authored_bold and authored_asset_size==192:asset_root="duel-3sp-bold"
		var path:="res://assets/effects/%s/%s/%d/%s_%02d.png"%[asset_root,key,authored_asset_size,prefix,i]
		if not ResourceLoader.exists(path):
			push_warning("Missing authored 3 SP frame: "+path)
			authored_frames.clear()
			return
		var frame:=ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if frame==null or frame.get_size()!=Vector2.ONE*authored_asset_size:
			push_warning("Invalid authored 3 SP frame: "+path)
			authored_frames.clear()
			return
		authored_frames.append(frame)
	authored_load_us=Time.get_ticks_usec()-start

func _draw_authored_frames(origin:Vector2,elapsed:float,screen_size:float)->void:
	if elapsed<0 or elapsed>=AUTHORED_FRAME_SECONDS or authored_frames.is_empty():return
	var frame_index:=clampi(floori(elapsed*30.0),0,authored_frames.size()-1)
	# Both source resolutions use the same art origin and on-screen footprint.
	var anchor:=Vector2(192.0,243.0)*(screen_size/384.0)
	effects_layer.draw_texture_rect(authored_frames[frame_index],Rect2(origin-anchor,Vector2.ONE*screen_size),false)

func reset_round(after_fade:=false) -> void:
	if local_melee_polish and rules.ally_id == "uram":uram_combined.prepare()
	uram_short_counter_fan.clear()
	ordinary_knife_fx.clear()
	if is_instance_valid(local_formation):
		var mode:String=local_formation.saebom_distance_drill
		_close_local_formation()
		_toggle_local_formation(mode)
		return
	entrance_scale=REVIVAL_ENTRANCE_SCALE if after_fade else 1.0
	deer_hud_anchor=Vector2.INF
	deer_wake.clear()
	bom_path.clear();bom_path_end=-INF;bom_path_action=-1
	local_bom_silver_cast_at=-INF;local_bom_rally_at=-INF;local_bom_rally_until=-INF
	local_bom_cloud_at=-INF;local_bom_cloud_origin=Vector2.INF;local_bom_cloud_fifths=0
	if local_saebom_latest:bom_style.restore_sling()
	deer_dust_at=-INF
	deer_dust_world=Vector3.ZERO
	deer_dust_screen=Vector2.ZERO
	deer_dust_is_world=false
	cast_notice.clear()
	cast_notice_layer.queue_redraw()
	hp_reveal_at=-1.0
	ground_wave_phase=0.0
	ground_wave_span=2.0
	accent.reset()
	local_parry_clock=-1.0
	if is_instance_valid(local_parry_thump):local_parry_thump.stop()
	local_parry_focus=Vector2.ZERO
	local_guard_action=-1
	_clear_ordinary_counter()
	if is_instance_valid(local_parry_caption):local_parry_caption.hide()
	ground.self_modulate=Color.WHITE
	han_chain_light.queue_redraw()
	touch_pointer=-1;touch_target=null
	damage_numbers.clear()
	rules.reset(rules.ally_id,rules.enemy_id)
	_prepare_authored_frames()
	for item in audio_pool:
		item.stop()
		item.stream_paused=paused
	if a == null or b == null or a.key != rules.ally_id or b.key != rules.enemy_id:
		if is_instance_valid(shared_world):
			shared_world.detach();shared_world.queue_free();shared_world=null
		for actor in [a,b]:
			if actor != null:
				actor.preview.hide()
				actor.death_effect.hide()
				actor.preview.queue_free()
		a = Actor.new()
		b = Actor.new()
		a.create(field,rules.ally_id)
		b.create(field,rules.enemy_id)
		a.configure(true)
		b.configure(true)
		a.preview.scale = Vector2.ONE * (HANGYEOL_BATTLE_SCALE if a.key=="hangyeol" else 1.08 if a.key=="uram" else .90)
		b.preview.scale = Vector2.ONE * (FOREST_BATTLE_SCALE if b.key=="forest" else .92)
	motion = ["idle","idle"]
	age = [0.0,0.0]
	contact_at = [-1.0,-1.0]
	motion_contact = [-1.0,-1.0]
	frame_contact = [-1.0,-1.0]
	start_cast_at = -1.0
	execute_at = -1.0
	visual_clock = 0.0
	approach_active = _prototype_duel() or _uram_duel() or _saebom_duel() or _han_boar_latest() or _uram_deer_close()
	next_attack = FIRST_BASIC.duplicate() if (_prototype_duel() or _uram_duel() or _saebom_duel()) else [0.4,1.6]
	animal_attack_count = 0
	han_ground_anchor = Vector2.INF
	fx.clear()
	tip_trail.clear()
	a.play("idle")
	b.play("idle")
	a.preview.position = _position(0)
	b.preview.position = _position(1)
	cast_from=_settled_anchor(0)
	presentation.reset(rules.hp)
	presentation.grounded_spear=_prototype_duel() or _han_boar_latest()
	if _prototype_duel() or _uram_duel() or _saebom_duel():
		if _prototype_duel():
			presentation.cache_spear(a)
			a.preview.set_meta("duel_presenter",presentation)
		if not is_instance_valid(shared_world):
			shared_world=SharedWorld.new();shared_world.name="SharedDuelWorld";field.add_child(shared_world)
			shared_world.configure(a,b,(Left+Right)*.5,local_shared_ranged,_uram_deer_close())
		shared_world.local_melee_polish=local_melee_polish
		shared_world.reset()
	elif a.key=="hangyeol":
		a.play("attack")
		presentation.prepare_spear(a,_settled_anchor(0),_settled_anchor(1)-Vector2(0,33),a.duration*.55,0.0 if approach_active else 78.0)
		a.play("idle")
		if _prototype_duel():presentation.prepare_ready(a,_settled_anchor(0),_settled_anchor(1))
	if approach_active:
		motion = ["run","run"]
		a.play("run");b.play("run")
	_start_battle_camera()
	skill_hud.reset(a.key)
	_render_actors()
	cues.clear()
	effects_layer.queue_redraw()
	_refresh()

func _refresh(delta := 0.0) -> void:
	timer.text = rules.elapsed_label()
	presentation.update_hp(rules.hp,delta)
	for i in 2:
		bars[i].max_value = rules.full_hp(i)
		bars[i].value = presentation.hp[i]
	skill_hud.chain_border_speed=URAM_BORDER_RATE if _local_guard_pre_cue() else 1.0
	if local_melee_polish and is_instance_valid(shared_world) and shared_world.saebom_pair:
		skill_hud.set_saebom_distance_icon(shared_world.bom_near_skill if motion[0]=="skill" else shared_world.bom_shove if motion[0]=="attack" else shared_world.bom_close,MeleeKnifeIcon)
	skill_hud.sync(rules.sp,rules.hp[0],rules.full_hp(0),rules.living(),_can_request(),delta)
	skill_hud.hp.value=presentation.hp[0]
	pause_caption.visible=paused;pause_icon.visible=not paused
	pause_button.tooltip_text="재개" if paused else "일시정지"
	name_labels[0].text=ModelTest.NAMES[rules.ally_id]
	name_labels[1].text="꽃사슴" if rules.enemy_id=="forest" else "큰 멧돼지"
	_update_head_hud(delta)
	_advance_ground_wave(delta)
	ready_light_layer.queue_redraw()
	deer_skill_light_layer.queue_redraw()
	location_layer.queue_redraw()
	for key in controls:
		var chosen:bool=key in [rules.ally_id,rules.enemy_id]
		controls[key].set_pressed_no_signal(chosen)
		selection_frames[key].visible=chosen
	_sync_local_distance_buttons()

func _show_duel_hp_loss(side:int,before:int,after:int)->void:
	if a==null or b==null:return
	var anchor := presentation.bone_point(a,"head") if side==0 else _position(1)-Vector2(0,54)
	if side==1 and is_instance_valid(shared_world):
		var height := 1.65 if _uram_duel() else 2.02
		var depth := .56 if _uram_duel() else .48
		anchor=shared_world.project(shared_world.bodies[1].position+Vector3.UP*height-shared_world.direction*depth)
	damage_numbers.show_loss(side,before,after,anchor-Vector2(0,20),side==0)

func _update_head_hud(delta:float)->void:
	if a==null or b==null:return
	var ally_anchor:=presentation.bone_point(a,"head")
	var deer_anchor:=_position(1)-Vector2(0,54)
	if is_instance_valid(shared_world) and _uram_duel():
		deer_anchor=shared_world.project(shared_world.bodies[1].position+Vector3.UP*1.65-shared_world.direction*.56)
	elif is_instance_valid(shared_world):
		var nominal_head:Vector3=shared_world.bodies[1].position+Vector3.UP*2.02-shared_world.direction*.48
		deer_anchor=shared_world.project(nominal_head)
	# Smooth only real body travel before applying the current camera transform.
	if deer_hud_anchor==Vector2.INF:
		deer_hud_anchor=deer_anchor
	elif deer_hud_anchor.distance_squared_to(deer_anchor)>16.0 and delta>0:
		deer_hud_anchor=deer_hud_anchor.lerp(deer_anchor,1.0-exp(-12.0*delta))
	var transform:=field.get_transform()
	var points:=[transform*ally_anchor,transform*deer_hud_anchor]
	HeadHUD.layout_compact(overhead,points,Rect2(8,66,944,350))
	cast_notice_anchor=points[0]
	cast_notice_layer.queue_redraw()
	var reveal:=smoothstep(0,.27,visual_clock-hp_reveal_at) if hp_reveal_at>=0 else 0.0
	for side in overhead.size():
		var alpha:=reveal
		if rules.hp[side]<=0:
			alpha=minf(alpha,1.0-smoothstep(.13,.58,age[side]))
		var panel:Panel=overhead[side].panel
		panel.modulate.a=alpha
		panel.visible=alpha>.001

func _sync_squad_bom_notice() -> void:
	var caster:Dictionary=local_formation.units[2]
	if caster.hp>0 and caster.move=="chain":
		var start:=float(local_formation.elapsed)-float(caster.age)
		if cast_notice.is_empty() or absf(start-float(cast_notice.at))>.025:
			cast_notice={"key":"chain","at":start,"icon":local_formation.huds[2].chain_art.texture,"bom_buff":true}
	cast_notice_layer.queue_redraw()


func _bom_notice_sample(anchor:Vector2)->Dictionary:
	var clock:=rules.elapsed
	var deadline:=local_bom_rally_until
	var alive:=rules.ally_id=="saebom" and rules.hp[0]>0
	var casting:=motion[0]=="chain"
	var baseline_y:=anchor.y-17.
	if is_instance_valid(local_formation):
		var caster:Dictionary=local_formation.units[2]
		clock=local_formation.elapsed
		deadline=float(caster.rally)
		alive=caster.hp>0
		casting=caster.move=="chain"
		anchor=local_formation.get_transform()*Vector2(caster.feet)
		baseline_y=anchor.y-95.
	else:
		var panel:Control=overhead[0].panel
		if panel.visible:baseline_y=minf(baseline_y,panel.position.y-12.)
	if not alive:return {}
	var elapsed:=maxf(0.,clock-float(cast_notice.at))
	var has_deadline:=is_finite(deadline) and deadline>float(cast_notice.at)
	var remaining:=deadline-clock if has_deadline else INF
	if not has_deadline and not casting:return {}
	if has_deadline and remaining<=-.26:return {}
	var p:=clampf(elapsed/.74,0.,1.)
	var side:=lerpf(24.,29.,smoothstep(0.,.24,p))
	var alpha:=smoothstep(0.,.08,p)
	var rise:=21.*smoothstep(0.,.78,p)
	if has_deadline and remaining>0.:
		var final_beat:=remaining<=1.
		var cycles:float=(1.-remaining)*3. if final_beat else (5.-remaining)*.75
		var phase:=fposmod(cycles,1.)
		var dip:=smoothstep(.19,.37,phase)*(1.-smoothstep(.64,.82,phase))
		var steady:=lerpf(.93 if final_beat else .85,.14 if final_beat else .22,dip)
		alpha=lerpf(alpha,steady,smoothstep(0.,.20,5.-remaining))
	elif has_deadline:
		var exit:=smoothstep(0.,.26,-remaining)
		alpha=.93*(1.-exit)
		side*=lerpf(1.,1.5,exit)
		rise+=7.*exit
	return {"center":Vector2(anchor.x,maxf(70.,baseline_y-rise)),"side":side,"alpha":alpha,"remaining":remaining}


func _draw_bom_buff_notice(anchor:Vector2) -> void:
	var sample:=_bom_notice_sample(anchor)
	if sample.is_empty() or cast_notice.icon==null:return
	var size:=Vector2.ONE*float(sample.side)
	var box:=Rect2(Vector2(sample.center)-size*.5,size)
	cast_notice_layer.draw_texture_rect(ring_halo,box.grow(13.),false,Color(Color("58b9ff"),.72))
	cast_notice_layer.draw_style_box(cast_notice_frames[1],box)
	cast_notice_layer.draw_texture_rect(cast_notice.icon,box.grow(-2.),false,Color.WHITE)
	cast_notice_layer.modulate.a=float(sample.alpha)


func _draw_cast_notice(anchor:Vector2)->void:
	if cast_notice.get("bom_buff",false):
		_draw_bom_buff_notice(anchor)
		return
	if cast_notice.is_empty() or rules.hp[0]<=0:return
	var elapsed:=visual_clock-float(cast_notice.at)
	if elapsed>=.74:return
	var p:=clampf(elapsed/.74,0.0,1.0)
	var linked:bool=cast_notice.key=="chain"
	var tint:=Color("58b9ff") if linked else Color("ffd179")
	var alpha:float=smoothstep(0.0,.08,p)*(1.0-smoothstep(.65,1.0,p))
	var side:=lerpf(24.0,29.0,smoothstep(0,.24,p)) if linked else lerpf(20.0,24.0,smoothstep(0,.24,p))
	side*=lerpf(1.0,1.5,smoothstep(.65,1.0,p))
	var panel:Control=overhead[0].panel
	var center:=Vector2(anchor.x,minf(anchor.y-17.0,panel.position.y-12.0) if panel.visible else anchor.y-17.0)
	center.y=maxf(70.0,center.y-lerpf(0.0,21.0,smoothstep(0,.78,p)))
	var extent:=Vector2.ONE*side
	var box:=Rect2(center-extent*.5,extent)
	cast_notice_layer.draw_texture_rect(ring_halo,box.grow(13.0),false,Color(tint,.72))
	cast_notice_layer.draw_style_box(cast_notice_frames[1 if linked else 0],box)
	cast_notice_layer.draw_texture_rect(cast_notice.icon,box.grow(-2.0),false,Color.WHITE)
	cast_notice_layer.modulate.a=alpha


func _can_request()->bool:
	return not paused and not approach_active and rules.living() and motion[0] in ["idle","walk","run","attack","hit"]

func _try_player(key: String) -> void:
	# SP-ready activation is always reachable. Only a click in the current ram
	# window may attach a guard token, so an early/late press is never a parry.
	var honest_guard:=key=="chain" and _local_guard_accepting()
	if key=="skill" and _local_ram_busy():return
	if not SP_COST.has(key) or not _can_request() or not rules.spend(int(SP_COST[key])):
		return
	if _uram_deer_close() and is_instance_valid(shared_world):shared_world.restore_uram_outgoing_display()
	cast_from=_position(0)
	contact_at[0]=-1.0 # Cancel the interrupted automatic contact; never land it twice.
	if key=="chain" and local_melee_polish and _uram_duel() and is_instance_valid(shared_world):
		_clear_ordinary_counter()
		ordinary_counter_target=b
	if key=="chain" and _uram_deer_close() and is_instance_valid(shared_world):
		# Plant the current stance when the player braces, not a prior hit slide.
		shared_world.knockback[0]=Vector3.ZERO
		local_guard_action=shared_world.action_id[1] if honest_guard else -1
		if honest_guard:shared_world.capture_forest_shield_input_face()
	_act(0,"counter" if key=="chain" and _uram_deer_close() and not honest_guard else key)
	if local_melee_polish and key=="chain" and rules.ally_id=="saebom":cast_notice={"key":key,"at":rules.elapsed,"icon":skill_hud.chain_art.texture,"bom_buff":true}
	else:
		var icon:Texture2D=skill_hud.chain_art.texture if key=="chain" else skill_hud.badge_art.texture
		if key=="skill" and local_melee_polish and is_instance_valid(shared_world) and shared_world.saebom_pair:
			skill_hud.set_saebom_distance_icon(shared_world.bom_near_skill,MeleeKnifeIcon)
			icon=skill_hud.badge_art.texture
		cast_notice={"key":key,"at":visual_clock,"icon":icon}
	_render_actors()
	if is_instance_valid(shared_world):shared_world.present_saebom_deer_stop(motion[1])
	_refresh() # Consume SP and hide readiness in the same input frame.

func _act(side: int, key: String) -> void:
	if side==0:_sync_saebom_knife_latch()
	var actor := a if side == 0 else b
	motion[side] = key
	age[side] = 0.0
	frame_contact[side]=-1.0
	actor.play(key)
	var duration: float = actor.duration
	contact_at[side] = duration * (.55 if key == "attack" else .63)
	if is_instance_valid(shared_world):shared_world.begin_action(side,key)
	if local_melee_polish and side==0 and key=="chain" and actor.key=="saebom":
		local_bom_rally_at=rules.elapsed+.96
		local_bom_silver_cast_at=rules.elapsed
	if side==0 and key=="chain" and _saebom_aurora_active():
		saebom_aurora_origin=_position(0)
	if _prototype_duel() and is_instance_valid(shared_world) and side==0 and key=="chain" and not _uram_deer_close():accent.chain_started(duration)
	if not is_instance_valid(shared_world) and side==0 and actor.key=="hangyeol" and key in ["attack","skill"]:
		var travel := 0.0 if _prototype_duel() else 78.0
		presentation.prepare_spear(actor,_settled_anchor(0),_position(1)-Vector2(0,33),contact_at[side],travel)
	if _prototype_duel() and not is_instance_valid(shared_world) and side==0 and key=="chain":
		presentation.prepare_spear(actor,_settled_anchor(0),_position(1)-Vector2(0,33),contact_at[0],0)
	if side == 0 and key != "attack":
		start_cast_at = rules.elapsed
	if side == 1 and key == "skill":
		contact_at[side] = minf(duration-.03,float(Profile.CONTACT[actor.key]))
		execute_at = float(actor.preview.length("req046_skill_anticipation"))
		if not _uram_deer_close():_sound("warning")
		if not (uram_generic_gong_test and _silver_deer_active()):_flash(_settled_anchor(1),"boss_gather" if b.key=="adult" else "gather",Color("#61bbff"),execute_at)
	else:
		var kind := "basic" if key == "attack" else key
		if not _prototype_duel() and not _uram_duel() and not (_saebom_duel() and key in ["attack","skill"]):
			_sound(SoundNames[actor.key]+"_"+kind)
		if key != "attack" and not ((_prototype_duel() or _uram_duel()) and side==0):
			var ground := _settled_anchor(side)
			var name := "chain_"+actor.key if key == "chain" else "cast_"+actor.key
			if local_all_effects and side==0 and ((actor.key=="uram" and key=="skill") or _han_fallback() or (actor.key=="saebom" and key=="chain" and _saebom_aurora_active())):pass
			elif uram_generic_gong_test and side==0 and key=="chain" and actor.key=="uram" and not is_instance_valid(shared_world):
				_flash(ground,"uram_gong_cast",_ally_color(),1.76)
				fx[-1]["forward"]=_position(0).direction_to(_position(1))
			else:
				_flash(ground,name,_ally_color(), duration if key == "chain" else minf(1.25,duration*.8))
	# A support cast and the shield preview have no fictitious target damage.
	if side == 0 and key == "chain" and actor.key != "hangyeol":
		contact_at[side] = -1.0
	var interval:float=BASIC_CADENCE[side] if _prototype_duel() else Rules.BASIC_EVERY
	next_attack[side] = rules.elapsed+maxf(interval,duration+.26)
	motion_contact[side]=contact_at[side]

func _ally_color() -> Color:
	return Color({"hangyeol":"#8bd7ff","uram":"#ef781e","saebom":"#ffe073"}[a.key])

func _sound(key: String) -> void:
	if key=="uram_ground_thump":sounds[key]=URAM_GROUND_THUMP
	elif key=="uram_parry":sounds[key]=URAM_PARRY_SOUND
	if not sounds.has(key):
		var path := SoundPath+key+".wav"
		sounds[key] = load(path) if ResourceLoader.exists(path) else null
	if sounds[key] == null:
		return
	cues.append(key)
	if cues.size()>128:
		cues.pop_front()
	var player := audio_pool[pool_index]
	pool_index = (pool_index+1)%audio_pool.size()
	for bus in ["Combat","SFX"]:
		if AudioServer.get_bus_index(bus) >= 0:
			player.bus = bus
			break
	player.stream = sounds[key]
	player.play()

func _uram_parry(contact:Dictionary)->void:
	if not uram_guard_active():return
	# Successful timed collision owns the existing guarded counter, not the
	# ordinary guaranteed-contact lane, and remains the only combo opener.
	_clear_ordinary_counter()
	var point:=shared_world.project(contact.point)
	if local_melee_polish:_start_uram_short_counter_fan(point, true)
	if _uram_deer_close():
		local_parry_clock=0.
		local_parry_focus=shared_world.project(Vector3(contact.point.x,0.,contact.point.z))
		if is_instance_valid(local_parry_thump):local_parry_thump.play()
	else:accent.parry_contact()
	_sound("uram_parry")
	var authored:=authored_asset_hero=="uram" and not authored_frames.is_empty()
	_flash(point,"uram_shield_contact",Color("62e4cb"),1.6 if uram_gong_test else (AUTHORED_FRAME_SECONDS if authored else .46))
	var floor_contact:Vector3=contact.point
	floor_contact.y=0.0
	fx[-1]["floor_point"]=shared_world.project(floor_contact) if _uram_deer_close() else _position(0).lerp(_position(1),.35)
	fx[-1]["forward_angle"]=_position(0).direction_to(_position(1)).angle()
	execute_at=-1
	next_attack[1]=maxf(next_attack[1],rules.elapsed+1.20 if _uram_deer_close() else rules.elapsed+.95)
	_react(1,"hit")
	if _uram_deer_close():
		shared_world.knockback[0]=Vector3.ZERO
		var away:Vector3=shared_world.bodies[1].position-floor_contact
		away.y=0.0
		shared_world.knockback[1]=away.normalized()*2.75
		_flash(point,"uram_deer_stun",Color.WHITE,1.15)
	_act(0,"counter")

const OrdinaryHitAccent = preload("res://scripts/hunt_ordinary_hit_accent.gd")
var ordinary_resting_hit:=[false,false]

func _land(side: int, key: String,contact:Dictionary={}) -> void:
	if approach_active or not rules.living():
		return
	if is_instance_valid(shared_world) and contact.is_empty():return
	if contact.get("kind","")=="shield":
		_uram_parry(contact)
		return
	var knife:bool=contact.get("kind","")=="saebom_knife"
	if knife:
		if motion[0]!="skill" or not shared_world.knife_skill_active(motion[0]) or int(contact.action)!=int(shared_world.action_id[0]):return
		ordinary_knife_fx.append({"at":visual_clock,"point":shared_world.project(contact.point),"feet":shared_world.body_screen(1),"beat":int(contact.beat)})
		if int(contact.beat)<MeleeKnife.BEAT_DAMAGE.size()-1:
			# The first three blows use their existing arcs and no extra hit-stun,
			# root shove or heavy reaction. They can still genuinely defeat prey.
			if hp_reveal_at<0:hp_reveal_at=visual_clock
			var early_damage:=MeleeKnife.damage_at(int(contact.beat),rules.elapsed<local_bom_rally_until)
			if rules.damage(1,early_damage):_die(1)
			return
	if side==0 and key=="counter" and ordinary_counter_target!=null:
		if ordinary_counter_spent or ordinary_counter_target!=b or rules.hp[1]<=0:return
		ordinary_counter_spent=true
		if ordinary_counter_wave.is_empty():_start_uram_short_counter_fan(shared_world.project(a.preview.shield.global_position))
		ordinary_counter_wave.clear()
	var defender := 1-side
	var impact_point := _position(defender)-Vector2(0,33)
	if is_instance_valid(shared_world):impact_point=shared_world.project(contact.point)
	elif side==0 and a.key=="hangyeol" and (key in ["attack","skill"] or (_prototype_duel() and key=="chain")):
		# The calibrated mesh tip and the body's actual contact location coincide.
		impact_point=presentation.spear_point(a)
	var skill := key != "attack"
	if is_instance_valid(shared_world):
		motion_contact[side]=age[side] # Existing D0070 charge/impact FX now use contact time.
		shared_world.apply_hit(defender,contact.normal,skill)
		if _prototype_duel() and side==0 and key=="chain":
			accent.chain_contact()
			var floor_contact:Vector3=contact.point
			floor_contact.y=0.0
			var floor_point:=shared_world.project(floor_contact)
			_flash(impact_point,"han_chain_impact",Color.WHITE,HAN_CHAIN_IMPACT_SECONDS)
			fx[-1]["floor_point"]=floor_point
			han_ground_anchor = floor_point
			han_ground_at = visual_clock
			# The authored descending stroke persists briefly through the exact hit,
			# instead of disappearing in the frame where the impact art starts.
			var wake_start:=impact_point
			for sample in tip_trail:
				var extent:=sample.distance_to(impact_point)
				if extent>110.0:
					wake_start=impact_point+(sample-impact_point).limit_length(110.0)
					break
				if extent>wake_start.distance_to(impact_point):wake_start=sample
			fx[-1]["wake_start"]=wake_start
			_flash(floor_point,"han_chain_afterglow",Color.WHITE,HAN_CHAIN_IMPACT_SECONDS+HAN_CHAIN_TAIL)
	# Forward approach moves the actor to its strike distance. Check the
	# simulation positions at contact instead of firing a hit from a timer alone.
	var origin := _position(side)
	var target := _position(defender)
	var reach := 180.0 if (side==0 and a.key=="saebom") else 104.0
	if not is_instance_valid(shared_world) and origin.distance_to(target) > reach:
		return
	if local_saebom_latest and side==0 and a.key=="saebom" and key=="skill" and contact.get("kind","")=="projectile":
		_flash(impact_point,"local_bom_skill_hit",Color.WHITE,1.24)
		var axis:=origin.direction_to(target)
		if bom_path.size()>1:axis=bom_path[bom_path.size()-2].direction_to(impact_point)
		fx[-1]["forward"]=axis if axis.length_squared()>.0001 else origin.direction_to(target)
	if local_all_effects and side==0 and a.key=="uram" and key=="skill" and not (local_melee_polish and is_instance_valid(shared_world)):
		_flash(impact_point,"local_uram_2p",Color.WHITE,2.04 if local_melee_polish else (1.84 if local_shared_ranged else 1.15))
		fx[-1]["floor_point"]=_position(1)
		fx[-1]["forward"]=origin.direction_to(target)
	if _han_fallback() and side==0:
		if _han_boar_latest():
			var muzzle:=_deer_visual_tip()
			if key=="chain":impact_point=muzzle
			else:impact_point=muzzle.lerp(impact_point,.38) if muzzle.distance_to(impact_point)<45.0 else muzzle
		if key=="chain" and not chain_impact_frames.is_empty():
			_flash(impact_point,"han_chain_impact",Color.WHITE,HAN_CHAIN_IMPACT_SECONDS)
			fx[-1]["floor_point"]=_position(1)
			fx[-1]["wake_start"]=presentation.spear_point(a)
			han_ground_anchor = _position(1)
			han_ground_at = visual_clock
			if _han_boar_latest():
				for mark in tip_trail:
					if mark.distance_to(impact_point)>15.0:
						fx[-1]["wake_start"]=impact_point+(mark-impact_point).limit_length(110.0)
						break
				_flash(_position(1),"han_chain_afterglow",Color.WHITE,HAN_CHAIN_IMPACT_SECONDS+HAN_CHAIN_TAIL)
		elif key in ["attack","skill"]:
			var authored:=key=="skill" and han_2sp_frames.size()==HAN_2SP_COUNT
			_flash(impact_point,"local_han_2p" if authored else "local_han_hit",Color.WHITE,HAN_2SP_DURATION if authored else .32)
			fx[-1]["floor_point"]=_position(1)
			fx[-1]["spear_axis"]=origin.direction_to(target).angle()+.57
			fx[-1]["basic"]=key=="attack"
			if _han_boar_latest() and authored:fx[-1]["han_2sp_authored"]=true
	var uram_deer_inbound:=side==1 and _uram_deer_close() and not is_instance_valid(shared_world)
	if uram_deer_inbound:
		# Reuse the deer's silver impact language; anchor it to the visible contact
		# between the projected antlers and defender torso, not the spawn slot.
		var torso:=presentation.bone_point(a,"spine")
		if torso==Vector2.INF:torso=a.preview.position-Vector2(0,30)
		var nose:=_deer_visual_tip()
		impact_point=torso+(nose-torso).limit_length(22.0)*.82
		_flash(impact_point,"silver_deer_contact",Color("e3f6ff"),.67 if skill else .30)
		fx[-1]["floor_point"]=a.preview.position
		fx[-1]["basic"]=not skill
		fx[-1]["axis"]=origin.direction_to(target)
	elif side == 1 and skill:
		if _silver_deer_active() and not is_instance_valid(shared_world):
			_flash(impact_point,"silver_deer_contact",Color("e3f5ec"),.67)
			fx[-1]["floor_point"]=_position(0)
		elif not (uram_generic_gong_test and _silver_deer_active()):
			_flash(_position(0),"burst",Color("#ffad26"),.40)
	if skill:
		if _prototype_duel() and side==0:_sound("han_"+key)
		if _uram_duel() and side==0 and key=="skill" and not (local_melee_polish and is_instance_valid(shared_world)):_sound("uram_skill")
		if _uram_duel() and side==0 and key=="counter":_sound("uram_basic")
		_sound("ally_hit" if defender==0 else SoundNames[b.key]+"_hit")
	if _prototype_duel() or _uram_duel() or _saebom_duel():
		presentation.recoil[defender]=origin.direction_to(target)*(6.0 if skill else 3.0)
		presentation.recoil_age[defender]=.025
		var hold:=.48 if skill else .16
		var authored_2sp:=_prototype_duel() and is_instance_valid(shared_world) and side==0 and key=="skill" and han_2sp_frames.size()==HAN_2SP_COUNT
		if is_instance_valid(shared_world) and side==0:
			if key=="attack":hold=.23
			elif key=="skill":hold=HAN_2SP_DURATION if authored_2sp else .68
		if is_instance_valid(shared_world) and side==1 and key=="skill":hold=.67
		_flash(impact_point,"local_uram_contact_silent" if local_all_effects and side==0 and a.key=="uram" and key=="skill" else "contact_"+key,tone_for_contact(side),hold)
		fx[-1]["attacker"]=side
		if side==0 and key=="attack" and a.key=="saebom" and contact.get("kind","")=="projectile":
			fx[-1]["basic_rope_impact"]=true
			fx[-1]["duration"]=.30
		if authored_2sp:
			fx[-1]["han_2sp_authored"]=true
			fx[-1]["spear_axis"]=(target-origin).angle()+.57
		if is_instance_valid(shared_world) and (key=="skill" or (_uram_duel() and key=="counter")):
			var ground_point:Vector3=contact.point
			ground_point.y=0
			fx[-1]["floor_point"]=shared_world.project(ground_point)
	# Han is a light glint, Uram dust, Saebom stone fragments. The inbound
	# ordinary hit reads as the agreed short white glint.
	var tone := Color("#fff5df") if defender == 0 or a.key=="hangyeol" else Color("#cf9862")
	if not skill:
		if _prototype_duel() or _uram_duel() or _saebom_duel():
			if not (_saebom_duel() and side==0):_sound(SoundNames[(a if side==0 else b).key]+"_basic")
			else:_sound("deer_hit")
		if not _prototype_duel() and not _uram_duel() and not _saebom_duel() and not uram_deer_inbound:_flash(impact_point,"hit",tone,.21)
	if hp_reveal_at<0:hp_reveal_at=visual_clock
	var amount:int=38 if key=="chain" else 18 if _uram_duel() and key=="counter" else 27 if skill else RallyCloud.SOLO_BASE if side==0 else 13
	if knife:
		amount=MeleeKnife.damage_at(int(contact.beat),rules.elapsed<local_bom_rally_until)
	elif local_melee_polish and side==0 and a.key=="saebom" and rules.elapsed<local_bom_rally_until:
		amount=roundi(float(amount)*1.2)
	if key!="attack":
		var receiver=a if defender==0 else b
		OrdinaryHitAccent.clear(receiver.preview.skeleton)
		ordinary_resting_hit[defender]=false
	var hp_before:=rules.hp[defender]
	var defeated:=rules.damage(defender,amount)
	var saebom_charge_hit:=defender==0 and key=="skill" and rules.hp[0]<hp_before and local_melee_polish and is_instance_valid(shared_world) and shared_world.saebom_pair and b.key=="forest"
	if saebom_charge_hit:shared_world.mark_saebom_deer_stop()
	var saebom_switch_hit:=false
	if defender==0 and rules.hp[0]<hp_before and local_melee_polish and is_instance_valid(shared_world) and shared_world.saebom_pair and not shared_world.bom_close:
		shared_world.remember_saebom_proximity()
		shared_world.saebom_switch_hit_until=visual_clock+OrdinaryHitAccent.END
		saebom_switch_hit=shared_world.saebom_melee_pending
	if defeated:
		_die(defender)
		return
	if local_melee_polish and _uram_duel() and side==0 and key=="counter" and ordinary_counter_target!=null and ordinary_counter_spent:
		# Charged shield strike, not parry: only actual strike contact interrupts.
		if motion[1]=="skill" and not shared_world.consumed[1]:
			shared_world.consumed[1]=true
			execute_at=-1.
		next_attack[1]=maxf(next_attack[1],rules.elapsed+1.15)
		_react(1,"hit")
		_flash(impact_point,"uram_deer_stun",Color.WHITE,1.15)
		return
	var existing_uram_intake:=_uram_deer_close() and is_instance_valid(shared_world) and defender==0
	ordinary_resting_hit[defender]=(key=="attack" or saebom_switch_hit or saebom_charge_hit) and not existing_uram_intake and (motion[defender]=="idle" or (defender==1 and motion[defender]=="walk" and is_instance_valid(shared_world)))
	if (key=="attack" or saebom_switch_hit or saebom_charge_hit) and not existing_uram_intake:
		var receiver=a if defender==0 else b
		OrdinaryHitAccent.on_hit(receiver.preview.skeleton,visual_clock,ordinary_resting_hit[defender],saebom_charge_hit)
	if _uram_deer_close() and is_instance_valid(shared_world):
		if side==0 and key=="attack":shared_world.mark_uram_outgoing_contact(visual_clock)
		elif side==1:
			var traded:bool=shared_world.maybe_mark_uram_trade(visual_clock,motion[0],age[0])
			if not traded and motion[0] in ["idle","walk"]:
				shared_world.mark_uram_intake(visual_clock,key=="attack")
	# Do not cut off a concurrently committed attack for a cosmetic reaction.
	if motion[defender] == "idle" or (defender==1 and motion[defender]=="walk" and is_instance_valid(shared_world)):
		if defender==0 and key=="skill" and motion[defender]=="idle" and _uram_deer_close() and is_instance_valid(shared_world):
			shared_world.capture_uram_ram_hit_pose()
		_react(defender,"hit")

func _clear_ordinary_counter()->void:
	ordinary_counter_target=null
	ordinary_counter_spent=false
	ordinary_counter_wave.clear()

func _ordinary_counter_live()->bool:
	return ordinary_counter_target!=null and ordinary_counter_target==b and not ordinary_counter_spent and rules.living()

func _counter_world_tip()->Vector3:
	var hurt:=shared_world.hurt_capsule(1)
	return (Vector3(hurt.a)+Vector3(hurt.b))*.5

func _start_uram_short_counter_fan(shield:Vector2, parried:=false)->void:
	var ground:Vector2=shared_world.body_screen(0)
	var dest:Vector2=shared_world.body_screen(1)
	var axis:=ground.direction_to(dest)
	if axis.is_zero_approx():return
	var reach:=UramCounterWave.fan_range(ground,dest,true)
	var combined := not parried and uram_combined.frames.size() == UramCombined.FRAME_COUNT
	uram_short_counter_fan={"from":shield,"ground":ground,"axis":axis,"reach":reach,"at":visual_clock,"span":UramCombined.SECONDS if combined else UramCounterWave.FIELD_SECONDS,"combined":combined}

func _draw_uram_field_ground()->void:
	if uram_short_counter_fan.is_empty():return
	var fan:=uram_short_counter_fan
	var progress:float=(visual_clock-float(fan.at))/float(fan.span)
	if bool(fan.get("combined", false)):
		uram_combined.draw(location_layer,fan.from,fan.axis,visual_clock-float(fan.at))
	elif progress<1.:UramCounterWave.draw_fan(location_layer,fan.from,fan.ground,fan.axis,fan.reach,progress,false,true)

func _advance_ordinary_counter()->void:
	if ordinary_counter_target==null or ordinary_counter_spent:return
	if not _ordinary_counter_live():
		_clear_ordinary_counter()
		return
	if motion[0]!="counter":return
	if ordinary_counter_wave.is_empty():
		# Let the original authored physical counter have the first chance.
		# After its final real contact edge, use one visible target-locked wake.
		if age[0]<.60:return
		var shield:MeshInstance3D=a.preview.shield
		var muzzle:Vector2=shared_world.project(shield.global_position)
		var target:Vector2=shared_world.project(_counter_world_tip())
		_start_uram_short_counter_fan(muzzle)
		ordinary_counter_wave={"from":muzzle,"start":rules.elapsed,"span":UramCounterWave.duration(muzzle,target)}
		return
	var t:=rules.elapsed-float(ordinary_counter_wave.start)
	if t+1e-6<float(ordinary_counter_wave.span):return
	var target:=_counter_world_tip()
	var normal:Vector3=shared_world.bodies[0].position.direction_to(shared_world.bodies[1].position)
	_flash(shared_world.project(target),"uram_counter_outreach_hit",Color.WHITE,.23)
	_land(0,"counter",{"kind":"body","point":target,"normal":normal,"local_outreach":true})

func _react(side: int, key: String) -> void:
	if side==0 and _uram_deer_close() and is_instance_valid(shared_world):
		shared_world.mark_uram_outgoing_recovery(motion[0],key,visual_clock)
	if side==0 and key=="idle" and motion[0]=="hit" and _uram_deer_close() and is_instance_valid(shared_world):
		shared_world.mark_uram_intake_recovery(visual_clock)
	var actor := a if side==0 else b
	motion[side] = key
	age[side] = 0.0
	frame_contact[side]=-1.0
	if key=="death" and is_instance_valid(shared_world):
		var player:AnimationPlayer=actor.preview.animator if actor.key=="uram" else actor.preview.animation
		if is_instance_valid(player):player.pause()
		actor.death_effect.clear()
	else:
		actor.play(key)
		if key=="walk" and side==0 and _uram_deer_close() and is_instance_valid(shared_world) and shared_world.uram_basic_anchor:
			# Sampling walk's first pose cannot undo the validated half-step on the transition frame.
			shared_world.render_poses(self,0.)
			shared_world._limit_uram_visible_boots()
	if _prototype_duel() and not is_instance_valid(shared_world) and side==0 and key=="idle":
		presentation.prepare_ready(a,_settled_anchor(0),_position(1))

func tone_for_contact(side:int)->Color:
	if _uram_duel() and side==0:return Color("7ff4d5")
	return Color("bcefff") if side==0 else Color("fff4df")

func _die(side: int) -> void:
	if is_instance_valid(shared_world):
		rules.revive_at[side]=rules.elapsed+SHARED_REVIVAL_DELAY
	_react(side,"death")
	contact_at = [-1.0,-1.0]
	execute_at = -1.0
	_sound("ally_death" if side==0 else "enemy_death")

func _visual_age(side:int)->float:
	return float(frame_contact[side]) if float(frame_contact[side])>=0 else float(age[side])

func _position(side: int) -> Vector2:
	if is_instance_valid(shared_world):return shared_world.body_screen(side)
	var place := _settled_anchor(side)
	if approach_active:
		var goal:=82.0 if _han_boar_latest() else 76.0 if _uram_deer_close() else ENGAGE_GAP
		return _duel_anchor(side,lerpf(START_GAP,goal,smoothstep(0.0,APPROACH_TRAVEL,visual_clock)))
	if _prototype_duel() and motion[side]=="attack" and side==1:
		return place
	if motion[side] not in ["attack","skill","chain"]:
		return place
	if side==0 and a.key=="saebom":
		return place
	if side==0 and motion[side]=="chain" and a.key=="uram":
		return place
	var elapsed := _visual_age(side)
	var duration := a.duration if side==0 else b.duration
	var impact := float(motion_contact[side])
	if impact <= 0.0:
		impact = duration*.59 if side==0 or motion[side]!="skill" else float(Profile.CONTACT[b.key])
	var windup := float(b.preview.length("req046_skill_anticipation")) if side==1 and motion[side]=="skill" else 0.0
	var p := (elapsed-windup)/maxf(.04,impact-windup) if elapsed < impact else 1.0-(elapsed-impact)/maxf(.04,duration-impact)
	var direction := Left.direction_to(Right)*(1.0 if side==0 else -1.0)
	if _prototype_duel():
		if side==0:
			var correction:Vector2=(presentation.thrust_peak+_position(1)-presentation.thrust_target).limit_length(BASIC_MAX_TRAVEL)
			var result:=place+correction*smoothstep(.05,.96,clampf(p,0,1))
			if motion[0] in ["skill","chain"]:result+=(cast_from-place)*(1.0-smoothstep(0,.18,elapsed))
			return result
		# A deer cannot lunge its body past the actual defender either.
		return place+direction*maxf(0,place.distance_to(_settled_anchor(0))-35.0)*smoothstep(.05,.96,clampf(p,0,1))
	var point:=place + direction*78.0*smoothstep(0.05,0.96,clampf(p,0,1))
	if side==0 and a.key=="hangyeol" and motion[0] in ["attack","skill"]:
		var correction := presentation.thrust_peak+_position(1)-presentation.thrust_target
		if _prototype_duel() and motion[0]=="attack":
			correction=correction.limit_length(BASIC_MAX_TRAVEL)
		point=place+correction*smoothstep(0.05,0.96,clampf(p,0,1))
	if _han_fallback():point=place+(point-place).limit_length(23.0 if side==0 else 38.0)
	if _uram_deer_close():point=place+(point-place).limit_length(12.0 if side==0 else 20.0)
	if side==0 and motion[0] in ["skill","chain"]:point+=(cast_from-_settled_anchor(0))*(1.0-smoothstep(0,.18,elapsed))
	return point

func _process(delta: float) -> void:
	if app != null and not app.application_active:
		return
	advance(delta)

func advance(delta: float) -> void:
	if is_instance_valid(local_formation):
		local_formation.tick(delta,paused)
		if local_melee_polish:
			ground.self_modulate=Color.WHITE.lerp(Color.BLACK,local_formation.spotlight_dim())
			_show_squad_spotlight_caption(local_formation.spotlight_clock)
		if local_melee_polish:_sync_squad_bom_notice()
		var secs:=int(local_formation.elapsed)
		timer.text="%02d:%02d"%[secs/60,secs%60]
		return
	if paused:return
	if is_instance_valid(shared_world):
		_advance_shared(delta)
		return
	if approach_active:
		var used:=minf(delta,APPROACH_END-visual_clock)
		visual_clock+=used
		if visual_clock>=APPROACH_TRAVEL and motion[0]=="run":
			_react(0,"idle");_react(1,"idle")
		else:
			for side in 2:
				age[side]+=used
		_render_actors(used)
		if visual_clock+.000001<APPROACH_END:
			return
		approach_active=false
		_refresh()
		delta-=used
		if delta<=.000001:
			return
	visual_clock += delta
	var revived := rules.advance(delta)
	if not revived.is_empty():
		reset_round()
		return
	if wild_takeoff_dust and not approach_active and rules.living() and motion[1]=="skill" and contact_at[1]>=0.0:
		var windup:float=b.preview.length("req046_skill_anticipation")
		if windup>0 and float(age[1])<windup and float(age[1])+delta>=windup:
			deer_dust_screen=_position(1)
			deer_dust_is_world=false
			deer_dust_at=visual_clock-delta+windup-float(age[1])
	for side in 2:
		age[side]+=delta
		# On a low-FPS frame crossing contact, show the actual contact pose once
		# instead of skipping straight to recovery. Simulation time is untouched.
		frame_contact[side]=contact_at[side] if float(contact_at[side])>=0 and float(age[side])>=float(contact_at[side]) else -1.0
	# Sample both participants at this frame before evaluating contact, so FX,
	# reactions and display HP start from the same visible hit frame.
	_render_actors(delta)
	if _silver_deer_active():_sample_deer_wake()
	for side in 2:
		if side==1 and execute_at>=0.0 and float(age[side])>=execute_at:
			_sound(SoundNames[b.key]+"_skill")
			execute_at = -1.0
	var order: Array[int] = [0,1]
	# Preserve chronological order if a single frame crosses both impacts.
	if _prototype_duel() and frame_contact[0]>=0.0 and frame_contact[1]>=0.0:
		if float(age[1])-float(frame_contact[1])>float(age[0])-float(frame_contact[0]):
			order.reverse()
	for side in order:
		if frame_contact[side]>=0.0 and contact_at[side]>=0.0:
			_land(side,motion[side])
			contact_at[side]=-1.0
	for side in 2:
		var actor := a if side==0 else b
		if motion[side] not in ["idle","death"] and float(age[side])>=actor.duration:
			_react(side,"idle")
	if rules.living():
		if motion[0]=="idle" and rules.elapsed>=float(next_attack[0]):
			_act(0,"attack")
		if motion[1]=="idle" and rules.elapsed>=float(next_attack[1]):
			animal_attack_count += 1
			_act(1,"skill" if animal_attack_count%3==0 else "attack")
	_render_actors()
	effects_layer.queue_redraw()
	_refresh(delta)

func _start_battle_camera()->void:
	# Pre-roll only the production VS camera (not AI, SP, audio or rewards).
	# This preserves the real first battle frame's residual zoom, followed by
	# the same production-camera easing, instead of forcing a settled frame.
	field.scale=Vector2.ONE;field.position=Vector2.ZERO
	battle_camera.pose="";battle_camera.approach=0; battle_camera.transition_elapsed=0
	battle_camera.update_camera(0)
	var time:=0.0
	while time<Hunt.TRANSITION_SECONDS:
		time+=1.0/60.0
		battle_camera.approach=smoothstep(.06,.98,clampf(time/Hunt.TRANSITION_SECONDS,0,1))
		battle_camera.transition_elapsed=-1.0 if time>=Hunt.TRANSITION_SECONDS else time
		battle_camera.update_camera(1.0/60.0)
	camera_base_scale=field.scale;camera_base_position=field.position

func _sync_saebom_knife_latch()->void:
	if not is_instance_valid(shared_world) or not local_melee_polish or not shared_world.saebom_pair:return
	var threat:String=motion[1]
	# A warning without a strike never starts the post-hit hold. A genuine miss
	# unlocks as soon as the same swept-contact window has closed.
	var incoming:bool=not shared_world.consumed[1] and ((threat=="attack" and age[1]<=b.duration*.70) or (threat=="skill" and age[1]<=b.duration*.94))
	shared_world.update_knife_latch(motion[0],visual_clock,incoming)

func _render_actors(delta:=0.0)->void:
	_sync_saebom_knife_latch()
	if is_instance_valid(a) and is_instance_valid(b):
		for i in 2:
			var actor=a if i==0 else b
			if is_instance_valid(actor.preview):
				OrdinaryHitAccent.display(actor.preview.skeleton,visual_clock,rules.hp[i]>0,ordinary_resting_hit[i] and motion[i]=="hit",visual_clock-float(age[i]))
	# Repaint on pose placement, including entrance frames which skip HUD refresh.
	location_layer.queue_redraw()
	if is_instance_valid(shared_world):
		var saebom_pose_mismatch:=false
		if shared_world.saebom_pair and local_melee_polish:
			var key:String=motion[0]
			var blade_expected:bool=shared_world.bom_shove if key=="attack" else shared_world.bom_near_skill if key=="skill" else shared_world.bom_close and key in ["idle","walk","run","hit"]
			saebom_pose_mismatch=blade_expected!=a.preview.has_meta("saebom_melee_blade")
		if delta==0 or saebom_pose_mismatch:shared_world.render_poses(self,0)
		a.preview.position=_position(0);b.preview.position=_position(1)
		if local_saebom_latest and a.key=="saebom":_pose_bom_cast(a,float(age[0]) if motion[0]=="chain" and rules.hp[0]>0 else -1.0)
		a.place_effect();b.place_effect()
		if _prototype_duel() and motion[0] in ["skill","chain"] and delta>0:
			tip_trail.push_front(presentation.spear_point(a))
			if tip_trail.size()>7:tip_trail.pop_back()
		elif motion[0] not in ["skill","chain"]:tip_trail.clear()
		battle_camera.hunters.assign([a.preview]);battle_camera.rules.attacker=0
		battle_camera.pose="strike" if start_cast_at>=0 and rules.elapsed-start_cast_at<.70 and accent.kind.is_empty() and not (_uram_duel() and motion[0] in ["chain","counter"]) else ""
		battle_camera.pose_clock=(rules.elapsed-start_cast_at)/.70*Hunt.RULES.POSE_SECONDS
		field.scale=camera_base_scale;field.position=camera_base_position
		if delta>0:battle_camera.update_camera(delta)
		camera_base_scale=field.scale;camera_base_position=field.position
		var focus:Vector2=(_position(0)+_position(1))*.5
		if _prototype_duel() and accent.kind=="chain":focus.y-=27.0
		ground.self_modulate=_duel_skill_ground_tint()
		if local_parry_clock>=0.:
			var dim:=SPOTLIGHT_DIM*smoothstep(0.,.22,local_parry_clock)*(1.-smoothstep(1.57,LOCAL_PARRY_SLOW,local_parry_clock))
			ground.self_modulate=ground.self_modulate.lerp(Color.BLACK,dim)
		han_chain_light.queue_redraw()
		field.scale=camera_base_scale*accent.zoom
		field.position=camera_base_position+camera_base_scale*focus*(1-accent.zoom)
		if delta>0 and accent.zoom>1:
			var center:Vector2=arena.position+(camera_base_position+camera_base_scale*focus)*arena.scale
			ground.position=center+(ground.position-center)*accent.zoom;ground.scale*=accent.zoom
		if local_parry_clock>=0.:
			var t:=local_parry_clock
			var zoom:=1.+.066*smoothstep(0.,.145,t)*(1.-smoothstep(.30,.96,t))
			var amp:=8.*exp(-12.*t)*(1.-exp(-160.*t))*.75 if t<=.42 else 0.
			var shake:=Vector2(sin(81.*t)+.28*sin(136.*t),.75*sin(109.*t))*amp
			var pivot:=field.position+field.scale*local_parry_focus
			field.scale*=zoom
			field.position=pivot+(field.position-pivot)*zoom+shake
			if delta>0.:
				var ground_pivot:=arena.position+pivot*arena.scale
				ground.position=ground_pivot+(ground.position-ground_pivot)*zoom+shake*arena.scale
				ground.scale*=zoom
		return
	a.preview.position=_position(0);b.preview.position=_position(1)
	if a.key=="hangyeol":
		var run_heading:=atan2((Right-Left).x,(Right-Left).y)
		var settle:=smoothstep(APPROACH_TRAVEL,APPROACH_END,visual_clock)
		var heading:=lerp_angle(run_heading,presentation.thrust_yaw,settle) if approach_active else presentation.thrust_yaw
		if _prototype_duel() and motion[0] in ["idle","hit","death"]:heading=presentation.ready_yaw
		a.preview.pivot.rotation.y=run_heading if motion[0]=="chain" and not _prototype_duel() else heading
	if _han_boar_latest() or _uram_deer_close():
		var direction:=a.preview.position.direction_to(b.preview.position)
		if _uram_deer_close() or motion[0] in ["run","walk","idle","hit","chain"]:
			a.preview.pivot.rotation.y=_local_floor_heading(a.preview.camera,direction)
		b.preview.pivot.rotation.y=_local_floor_heading(b.preview.camera,-direction)
	presentation.sample(a,0,motion[0],_visual_age(0),INF if approach_active else float(next_attack[0])-rules.elapsed,delta)
	presentation.sample(b,1,motion[1],_visual_age(1),INF if approach_active else float(next_attack[1])-rules.elapsed,delta)
	if _han_boar_latest():han_chain_light.queue_redraw()
	if _prototype_duel() or _han_boar_latest():
		# Ground depth controls the compositing of independent 3D viewports.
		a.preview.z_index=2 if a.preview.position.y>=b.preview.position.y else 1
		b.preview.z_index=1 if a.preview.z_index==2 else 2
		for side in 2:
			presentation.recoil_age[side]+=delta
			var q:=clampf(presentation.recoil_age[side]/.28,0,1)
			var actor:=a if side==0 else b
			actor.preview.position+=presentation.recoil[side]*sin(PI*q)*(1-q)
		if motion[0] in ["skill","chain"]:
			if delta>0:
				tip_trail.push_front(presentation.spear_point(a))
				if tip_trail.size()>7:tip_trail.pop_back()
		else:tip_trail.clear()
	a.place_effect();b.place_effect()
	battle_camera.hunters.assign([a.preview]);battle_camera.rules.attacker=0
	battle_camera.pose="strike" if start_cast_at>=0 and rules.elapsed-start_cast_at<.70 else ""
	battle_camera.pose_clock=(rules.elapsed-start_cast_at)/.70*Hunt.RULES.POSE_SECONDS
	if delta>0:battle_camera.update_camera(delta)

func _advance_shared(delta:float)->void:
	# Render rate-independent continuous body/weapon integration. No timer can
	# call _land on this path: only a swept 3D hurt-volume contact can do so.
	shared_world.capture_uram_visible_return(motion[0])
	shared_world.restore_uram_outgoing_display()
	shared_world.restore_uram_intake_display()
	shared_world.restore_uram_ram_display()
	while delta>.0000001:
		var wall:=minf(delta,SharedWorld.FIXED_STEP);delta-=wall
		var rate:=1.0
		if local_parry_clock>=0.:
			var slowed:=clampf(LOCAL_PARRY_SLOW-local_parry_clock,0.,wall)
			rate=1.-.75*slowed/wall
			local_parry_clock+=wall
			if local_parry_clock>=LOCAL_PARRY_SLOW:local_parry_clock=-1.
		var dt:=wall*rate
		visual_clock+=dt
		accent.advance(dt)
		if is_instance_valid(local_parry_caption):
			var title_alpha:=smoothstep(.08,.28,local_parry_clock)*(1.-smoothstep(1.63,2.14,local_parry_clock)) if local_parry_clock>=0. else 0.
			local_parry_caption.visible=title_alpha>.005
			local_parry_caption.modulate.a=title_alpha
		if approach_active:
			for side in 2:age[side]+=dt
			shared_world.step(self,dt)
			if visual_clock>=APPROACH_TRAVEL*entrance_scale and motion[0]=="run":_react(0,"idle");_react(1,"idle")
			if visual_clock+.000001>=APPROACH_END*entrance_scale:approach_active=false
			_advance_ground_wave(dt)
			_render_actors(dt);_refresh();continue
		if not rules.advance(wall).is_empty():reset_round(true);return
		var prior_han_age:float=age[0]
		var prior_deer_age:float=age[1]
		for side in 2:
			age[side]+=dt;frame_contact[side]=-1.0
		if _prototype_duel() and motion[0]=="skill" and not shared_world.consumed[0]:
			var windup_end:=minf(HAN_SKILL_WINDUP_LIMIT,a.duration*.55)
			var sped_time:=clampf((windup_end-prior_han_age)/HAN_SKILL_WINDUP_RATE,0,dt)
			age[0]+=sped_time*(HAN_SKILL_WINDUP_RATE-1)
		var release_count:=shared_world.projectile_releases.size()
		if _uram_deer_close() and motion[1]=="skill" and prior_deer_age<SharedWorld.FOREST_PLANT_AT and age[1]>=SharedWorld.FOREST_PLANT_AT:
			_sound("warning")
		if (_prototype_duel() or wild_takeoff_dust) and motion[1]=="skill" and rules.living() and not shared_world.consumed[1]:
			var windup:=maxf(.01,b.preview.length("req046_skill_anticipation"))
			if prior_deer_age<windup and age[1]>=windup:
				deer_dust_is_world=true
				deer_dust_world=shared_world.bodies[1].position
				deer_dust_at=visual_clock
		if local_melee_polish and is_finite(local_bom_rally_at) and rules.elapsed>=local_bom_rally_at:
			if rules.living() and motion[0]=="chain":_release_bom_cloud()
			local_bom_rally_at=-INF
		var events:=shared_world.step(self,dt,prior_han_age)
		if local_saebom_latest and _saebom_duel():_sample_local_bom_path(events)
		if _saebom_duel() and shared_world.projectile_releases.size()>release_count:
			_sound("bom_skill" if shared_world.projectile_releases[-1].motion=="skill" else "bom_basic")
		if _silver_deer_active():_sample_deer_wake()
		for event in events:_land(int(event.side),event.motion,event)
		_advance_ordinary_counter()
		if execute_at>=0 and age[1]>=execute_at:
			_sound(SoundNames[b.key]+"_skill");execute_at=-1
		for side in 2:
			var actor:=a if side==0 else b
			if _uram_deer_close() and motion[side]=="run":
				if shared_world.local_basic_in_range(side):_react(side,"idle")
			elif _saebom_duel() and side==0 and shared_world.bom_close and motion[0]=="run":
				if shared_world.bodies[0].position.distance_to(shared_world.bodies[1].position)<=SharedWorld.SAEBOM_MELEE_GAP:
					_react(0,"idle")
			elif _saebom_duel() and side==1 and motion[1]=="run":
				if shared_world.bodies[0].position.distance_to(shared_world.bodies[1].position)<=SharedWorld.SAEBOM_DEER_APPROACH_GAP+.006:
					animal_attack_count+=1;_act(1,"skill" if animal_attack_count%3==0 else "attack")
			elif _uram_deer_close() and side==0 and motion[0]=="walk":
				if shared_world.uram_attack_return_offset().length()<.01 or age[0]>=.85:
					_react(0,"idle")
			elif side==1 and motion[1]=="walk":
				if shared_world.deer_return_offset().length()<.005 or age[1]>=1.2:
					_react(1,"idle")
			elif motion[side] not in ["idle","death"] and age[side]>=(MeleeKnife.DURATION if side==0 and shared_world.knife_skill_active(motion[0]) else float(actor.duration))+_uram_floor_recovery(side):
				if side==0 and motion[0]=="counter" and _ordinary_counter_live():continue
				if side==0 and motion[0]=="chain" and (_uram_deer_close() or _ordinary_counter_live()):
					local_guard_action=-1
					_act(0,"counter")
				elif _uram_deer_close() and side==0 and motion[0] in ["attack","skill"] and rules.living() and motion[1]!="skill" and shared_world.uram_attack_return_offset().length()>.10:
					_react(0,"walk")
				elif side==1 and rules.living() and motion[1] in ["attack","skill","hit"] and shared_world.action_name[1] in ["attack","skill"] and shared_world.deer_return_offset().length()>.045:
					# The lunge and backwards hoof steps are one committed move.
					# Only the lunge has a contact window.
					_react(1,"walk")
				else:
					_react(side,"idle")
		if rules.living() and local_parry_clock<0.:
			# Do not run a routine step-in/return underneath the deer charge warning.
			var deer_ram_due:bool=_uram_deer_close() and motion[1]=="idle" and rules.elapsed>=next_attack[1] and (animal_attack_count+1)%3==0
			if motion[0]=="idle" and rules.elapsed>=next_attack[0] and not (_local_ram_busy() or deer_ram_due):
				if _uram_deer_close() and not shared_world.local_basic_in_range(0):
					if shared_world.local_basic_too_far(0):_react(0,"run")
				elif _saebom_duel() and shared_world.bom_close and shared_world.bodies[0].position.distance_to(shared_world.bodies[1].position)>SharedWorld.SAEBOM_MELEE_GAP:
					_react(0,"run")
				else:_act(0,"attack")
			if motion[1]=="idle" and rules.elapsed>=next_attack[1] and not (deer_ram_due and motion[0]!="idle"):
				if (_saebom_duel() and shared_world.bodies[0].position.distance_to(shared_world.bodies[1].position)>SharedWorld.SAEBOM_DEER_APPROACH_GAP+.006) or (_uram_deer_close() and not deer_ram_due and not shared_world.local_basic_in_range(1)):
					_react(1,"run")
				else:
					animal_attack_count+=1;_act(1,"skill" if animal_attack_count%3==0 else "attack")
		_render_actors(dt);_refresh(dt)
	shared_world.present_saebom_deer_stop(motion[1])
	shared_world.present_uram_ram_hit_pose(motion[0],age[0])
	if _uram_deer_close():
		if DisplayServer.get_name()=="headless":_present_uram_intake_overlay(shared_world,visual_clock,motion[0],age[0])
		else:_present_uram_intake_overlay.call_deferred(shared_world,visual_clock,motion[0],age[0])
	effects_layer.queue_redraw()

func _present_uram_intake_overlay(world,stamp:float,key:String,pose_age:float)->void:
	if not is_instance_valid(world) or world!=shared_world:return
	world.present_uram_intake(stamp,key)
	world.present_uram_outgoing(stamp,key,pose_age)
	location_layer.queue_redraw()

func _flash(center: Vector2, key: String, tint: Color, duration: float) -> void:
	fx.append({"center":center,"name":key,"color":tint,"duration":duration,"at":visual_clock})

func _soft_light(center:Vector2,extent:Vector2,tint:Color,alpha:float,layer:Node2D=null)->void:
	if alpha<=0:return
	if not contact_glow:
		contact_glow=GradientTexture2D.new();contact_glow.width=64;contact_glow.height=64
		contact_glow.fill=GradientTexture2D.FILL_RADIAL;contact_glow.fill_from=Vector2(.5,.5);contact_glow.fill_to=Vector2(1,.5)
		var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,.18,.48,1])
		gradient.colors=PackedColorArray([Color(1,1,1,.95),Color(1,1,1,.65),Color(1,1,1,.18),Color(1,1,1,0)])
		contact_glow.gradient=gradient
	var target:=effects_layer if layer==null else layer
	target.draw_texture_rect(contact_glow,Rect2(center-extent*.5,extent),false,Color(tint,alpha))

func _location_ring(side:int)->PackedVector2Array:
	var path:=PackedVector2Array()
	if a==null or b==null or rules.hp[side]<=0:return path
	var actor:=a if side==0 else b
	# Match the rendered ground origin instead of the simulated slot or an animated bone.
	var preview:=actor.preview
	var center:=preview.position
	if not is_instance_valid(shared_world):
		center+=(preview.display.position+preview.camera.unproject_position(Vector3.ZERO)*preview.display.scale)*preview.scale
		if local_world_ring:return _project_preview_ring(preview,center)
	var origin:=Vector3.ZERO
	if is_instance_valid(shared_world):
		origin=shared_world.bodies[side].position
		if side==0 and a.key=="uram":
			# Preserve the floor plane, but use the rendered boots instead of
			# the collision pelvis to keep the ring under the same-frame pose.
			origin=(shared_world.bone_world(side,"foot.L")+shared_world.bone_world(side,"foot.R"))*.5
			origin.y=0.
		if local_world_ring:origin.y=0.0
	for j in 41:
		var angle:=TAU*float(j)/40.0
		var unit:=Vector2.from_angle(angle)
		if is_instance_valid(shared_world):
			var radius:=.64
			path.append(shared_world.project(origin+Vector3(unit.x*radius,.025,unit.y*radius)))
		else:
			var span:=Vector2(24,9)
			path.append(center+unit*span)
	return path

func _new_ring_light(stops:PackedFloat32Array,levels:PackedFloat32Array)->GradientTexture2D:
	var gradient:=Gradient.new()
	gradient.offsets=stops
	var colors:=PackedColorArray()
	for alpha in levels:colors.append(Color(1,1,1,alpha))
	gradient.colors=colors
	var texture:=GradientTexture2D.new()
	texture.width=128;texture.height=128
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
	texture.gradient=gradient
	return texture

func _ground_wave_profile()->Vector2:
	if not _can_request():return Vector2.ZERO
	if skill_hud.chain_ready:return Vector2(3.0,2.0)
	if skill_hud.normal_ready:return Vector2(2.0,1.5)
	return Vector2.ZERO

func _advance_ground_wave(delta:float)->void:
	if paused or delta<=0:return
	var profile:=_ground_wave_profile()
	if profile==Vector2.ZERO:
		ground_wave_phase=0.0
		ground_wave_span=2.0
		return
	ground_wave_phase=fposmod(ground_wave_phase+delta*profile.y/GROUND_WAVE_SECONDS,1.0)
	ground_wave_span=lerpf(ground_wave_span,profile.x,1.0-exp(-15.0*delta))

func _inward_ring_scale(phase:float,start:float=1.2)->float:
	return lerpf(start,.035,smoothstep(0.0,1.0,phase))

func _draw_location_rings()->void:
	for side in 2:
		var path:=_location_ring(side)
		if path.is_empty():continue
		var bounds:=Rect2(path[0],Vector2.ZERO)
		for point in path:bounds=bounds.expand(point)
		var center:=bounds.get_center()
		var tint:=HeadHUD.duel_team_color(side==0)
		var settled:=bounds.size*1.08
		var ring_box:=bounds.size/.68
		if (_prototype_duel() and is_instance_valid(shared_world)) or _han_boar_latest() or (rules.ally_id=="uram" and rules.enemy_id in ["forest","adult"]):
			var rich:=Color("1b9df0") if side==0 else Color("e33830")
			var core:=Color("c2f6ff") if side==0 else Color("ffbeb1")
			var spread:=bounds.size/.62
			var disk:=Rect2(center-spread*.5,spread)
			location_layer.draw_texture_rect(floor_light_wash,disk,false,Color(rich,.86))
			location_layer.draw_texture_rect(floor_light_halo,disk,false,Color(rich,.90))
			location_layer.draw_texture_rect(floor_light_core,disk,false,Color(core,.96))
		else:
			location_layer.draw_texture_rect(ring_halo,Rect2(center-settled*.5,settled),false,Color(tint,.54))
			location_layer.draw_texture_rect(ring_band,Rect2(center-ring_box*.5,ring_box),false,Color(tint,.97))
		if side!=0 or _ground_wave_profile()==Vector2.ZERO:continue
		var phase:=ground_wave_phase
		var closing_size:=ring_box*_inward_ring_scale(phase,ground_wave_span)
		var opacity:=.72*smoothstep(0,.14,phase)*(1.0-smoothstep(.86,1.0,phase))
		location_layer.draw_texture_rect(ring_band,Rect2(center-closing_size*.5,closing_size),false,Color(tint.lightened(.25),opacity))
		var focus:=smoothstep(.71,.93,phase)*(1.0-smoothstep(.95,1.0,phase))
		var dot_size:=Vector2(10,7)*lerpf(.6,1,focus)
		if focus>0:
			location_layer.draw_texture_rect(ring_halo,Rect2(center-dot_size*.5,dot_size),false,Color(tint.lightened(.45),focus*.84))

func _han_tip_light_position()->Vector2:
	if local_melee_polish and rules.ally_id!="hangyeol":return Vector2.INF
	if (not is_instance_valid(shared_world) and not _han_fallback()) or rules.hp[0]<=0:return Vector2.INF
	return presentation.spear_point(a)

func _silver_deer_active()->bool:
	return _prototype_duel() or (uram_generic_gong_test and b!=null and (b.key=="forest" or (local_world_ring and b.key=="adult")))

func _deer_visual_tip()->Vector2:
	if is_instance_valid(shared_world):return shared_world.project(shared_world.weapon_point(1))
	var view:=b.preview
	var sk:Skeleton3D=view.skeleton
	var idx:=sk.find_bone("head")
	if idx<0:return _position(1)-Vector2(0,25)
	var world:=sk.to_global(sk.get_bone_global_pose(idx)*(Vector3(0,.07,.34) if local_world_ring and b.key=="adult" else Vector3(0,.05,.23)))
	return view.position+(view.display.position+view.camera.unproject_position(world)*view.display.scale)*view.scale

func _sample_deer_wake()->void:
	while not deer_wake.is_empty() and visual_clock-float(deer_wake[0].at)>.59:
		deer_wake.pop_front()
	if motion[1]!="skill" or not rules.living():return
	var anticipation:float=b.preview.length("req046_skill_anticipation")
	if age[1]<anticipation:return
	var foot:=b.preview.position if _uram_deer_close() else _position(1)
	var tip:=_deer_visual_tip()
	if not deer_wake.is_empty() and visual_clock-float(deer_wake[-1].at)>.12:
		deer_wake.clear()
	if not deer_wake.is_empty():
		var last:Vector2=deer_wake[-1].foot
		if foot.distance_squared_to(last)<8.0 and (not local_world_ring or tip.distance_squared_to(deer_wake[-1].tip)<1.25):return
	deer_wake.append({"foot":foot,"at":visual_clock,"tip":tip})
	if deer_wake.size()>20:deer_wake.pop_front()

func _draw_duel_lights()->void:
	var tip:=_han_tip_light_position()
	if tip!=Vector2.INF:
		var breath:=.88+.12*sin(visual_clock*TAU*.75)
		var hand:=presentation.bone_point(a,"hand.R")
		var blade:=tip-hand
		var blade_length:=clampf(blade.length()*.24,10,21)
		var blade_center:=tip-blade.normalized()*blade_length*.42
		ready_light_layer.draw_set_transform(blade_center,blade.angle(),Vector2.ONE)
		_soft_light(Vector2.ZERO,Vector2(blade_length*1.68,13),Color("389fff"),.31*breath,ready_light_layer)
		_soft_light(Vector2(1,0),Vector2(blade_length*1.24,5.5),Color("96dcff"),.34*breath,ready_light_layer)
		ready_light_layer.draw_set_transform(Vector2.ZERO)
	_draw_other_weapon_glow()
	if not _silver_deer_active():_draw_deer_skill_lights()

func _draw_other_weapon_glow()->void:
	while not ordinary_knife_fx.is_empty() and visual_clock-float(ordinary_knife_fx[0].at)>MeleeKnife.ECHO_SECONDS:ordinary_knife_fx.pop_front()
	for ev in ordinary_knife_fx:MeleeKnife.draw_event(ready_light_layer,int(ev.beat),ev.point,ev.feet,visual_clock-float(ev.at))
	if not is_instance_valid(a) or rules.hp[0]<=0:return
	if local_shared_ranged and a.key in ["uram","saebom"]:
		var in_flight:=Vector2.INF
		var expired:=false
		if a.key=="saebom" and is_instance_valid(shared_world):
			if a.preview.has_meta("saebom_melee_blade"):
				MeleeKnife.draw_blade(ready_light_layer,a.preview)
				if shared_world.projectile.is_empty():return
			if local_saebom_latest and motion[0]=="chain" and _bom_prop_hidden(age[0]):return
			if not shared_world.projectile.is_empty():
				if local_saebom_latest and shared_world.projectile.motion=="skill":return
				if shared_world.projectile.motion=="attack":
					BasicRope.draw_stone(ready_light_layer,basic_rope_glow,shared_world.project(Vector3(shared_world.projectile.position)),float(shared_world.projectile.flight_age))
					return
				in_flight=shared_world.project(Vector3(shared_world.projectile.position))
			expired=motion[0] in ["attack","skill"] and (shared_world.consumed[0] or (local_melee_polish and age[0]>=SharedWorld.sling_release_seconds(motion[0])))
		if a.key=="saebom" and motion[0] not in ["skill","chain"]:
			if not shared_world.basic_rope_empty and not shared_world.bom_shove and not expired:
				var anchor:=BasicRope.stone_world(a.preview)
				if anchor.is_finite():BasicRope.draw_stone(ready_light_layer,basic_rope_glow,shared_world.project(anchor),0.)
			return
		_draw_local_weapon_glow(a,in_flight,expired,ready_light_layer,shared_world)
		return
	var at:=Vector2.INF
	var near:=Vector2.INF
	var tint:=Color("73f1d0")
	var core:=Color("c5ffea")
	if rules.ally_id=="uram" and is_instance_valid(a.preview.club):
		var club:MeshInstance3D=a.preview.club
		var box:=club.get_aabb()
		var front:=club.to_global(Vector3(box.end.x*.86,0,0))
		var shoulder:=club.to_global(Vector3(lerpf(box.position.x,box.end.x,.64),0,0))
		at=shared_world.project(front) if is_instance_valid(shared_world) else a.preview.position+(a.preview.display.position+a.preview.camera.unproject_position(front)*a.preview.display.scale)*a.preview.scale
		near=shared_world.project(shoulder) if is_instance_valid(shared_world) else a.preview.position+(a.preview.display.position+a.preview.camera.unproject_position(shoulder)*a.preview.display.scale)*a.preview.scale
	elif rules.ally_id=="saebom":
		tint=Color("e9bc64")
		core=Color("fff0b8")
		if is_instance_valid(shared_world):
			at=shared_world.bone_screen(0,"sling_pouch")
			near=shared_world.bone_screen(0,"hand.R")
		else:
			at=presentation.bone_point(a,"sling_pouch")
			near=presentation.bone_point(a,"hand.R")
	if at==Vector2.INF or near==Vector2.INF:return
	var axis:=at-near
	var breath:=.87+.13*sin(visual_clock*TAU*.72)
	var length_px:=clampf(axis.length()*.9,8,16)
	ready_light_layer.draw_set_transform(at.lerp(near,.23),axis.angle(),Vector2.ONE)
	_soft_light(Vector2.ZERO,Vector2(length_px*1.85,11),tint,.33*breath,ready_light_layer)
	_soft_light(Vector2.ZERO,Vector2(length_px*1.24,4.2),core,.29*breath,ready_light_layer)
	ready_light_layer.draw_set_transform(Vector2.ZERO)

func _draw_deer_skill_lights()->void:
	if not is_instance_valid(shared_world):return
	for j in deer_wake.size():
		var entry:=deer_wake[j]
		var elapsed:float=visual_clock-float(entry.at)
		var fade:=1.0-smoothstep(.01,.59,elapsed)
		var foot:Vector2=entry.foot
		if j>0:
			var prev:Vector2=deer_wake[j-1].foot
			ready_light_layer.draw_line(prev,foot,Color(1,.52,.13,.24*fade),lerpf(13,28,fade),true)
			ready_light_layer.draw_line(prev,foot,Color(1,.88,.46,.42*fade),lerpf(3,9,fade),true)
		_soft_light(foot,Vector2(lerpf(77,35,fade),lerpf(30,16,fade)),Color("ff8f22"),fade*.48,ready_light_layer)
		_soft_light(foot,Vector2(45,17),Color("ffc86a"),fade*.44,ready_light_layer)
	if motion[1]!="skill" or rules.hp[1]<=0:return
	var warning:float=maxf(.01,b.preview.length("req046_skill_anticipation"))
	var progress:=clampf(float(age[1])/warning,0,1)
	var drive:=float(age[1])>=warning
	var swell:=smoothstep(.02,.80,progress)
	var beat:=.77+.23*sin(float(age[1])*TAU*2.2)
	var intensity:=lerpf(.24,1.0,swell)*beat if not drive else 1.0
	var hoof:=_position(1)
	var head:=shared_world.bone_screen(1,"head")
	var sk:Skeleton3D=b.preview.skeleton
	var antlers:=sk.get_bone_global_pose(sk.find_bone("head"))
	for sign_x in [-1.0,1.0]:
		# The mesh has no antler bones; the two sockets follow its head pose.
		var socket:Vector3=sk.to_global(antlers*Vector3(.21*sign_x,.36,.06))
		var glow:=shared_world.project(socket)
		_soft_light(glow,Vector2(34,27),Color("ff9f2a"),intensity*.49,ready_light_layer)
		_soft_light(glow,Vector2(11,9),Color("ffdfa1"),intensity*.47,ready_light_layer)

	if drive:
		_soft_light(shared_world.project(shared_world.weapon_point(1)),Vector2(49,39),Color("ffd573"),.53,ready_light_layer)
		return
	var wave:=fposmod(float(age[1])*1.55,1.0)

	for j in 9:
		var angle:=float(j)*2.39996+float(age[1])*1.8
		var stream:=fposmod(wave+float(j)*.113,1.0)
		var point:=hoof.lerp(head,stream*.76)+Vector2(cos(angle)*58,sin(angle)*15)*(1-stream)
		_soft_light(point,Vector2(14,11),Color("fff0be"),sin(PI*stream)*intensity*.82,ready_light_layer)

func _draw_deer_launch_dust(layer:Node2D=null)->void:
	if not is_finite(deer_dust_at):return
	if deer_dust_is_world and not is_instance_valid(shared_world):return
	var origin:=shared_world.project(deer_dust_world) if deer_dust_is_world else deer_dust_screen
	_draw_animal_launch_dust(origin,visual_clock-deer_dust_at,deer_skill_light_layer if layer==null else layer)

func _draw_animal_launch_dust(origin:Vector2,elapsed:float,layer:Node2D)->void:
	if elapsed<0 or elapsed>=DEER_DUST_LIFETIME:return
	var linger:=smoothstep(.14,.58,elapsed)*(1.0-smoothstep(1.86,DEER_DUST_LIFETIME,elapsed))
	if linger>.001:
		var settle:=clampf(elapsed/DEER_DUST_LIFETIME,0,1)
		_soft_light(origin+Vector2(settle*10,0),Vector2(172,35)*lerpf(.75,1.15,settle),Color("7d5b3e"),linger*.67,layer)
		for k in 10:
			var theta:=float(k)*2.39996
			var puff:=Vector2(cos(theta)*lerpf(26,66,settle),sin(theta)*lerpf(7,13,settle))
			var tone:=Color("8a6648").lerp(Color("dcaf78"),float(k%4)/3.0)
			_soft_light(origin+puff,Vector2(44,17)*lerpf(.82,1.23,settle),tone,linger*.61,layer)
	if elapsed>=.86:return
	var t:=elapsed/.86
	var dusty:=smoothstep(0,.060,elapsed)*(1.0-smoothstep(.38,.86,elapsed))
	_soft_light(origin,Vector2(155,49)*lerpf(.40,1.04,sqrt(t)),Color("674632"),dusty*.77,layer)
	_soft_light(origin+Vector2(7,-6),Vector2(125,32)*lerpf(.43,1.17,sqrt(t)),Color("ce965d"),dusty*.92,layer)
	for k in 20:
		var theta:=float(k)*2.39996
		var ray:=Vector2(cos(theta),sin(theta)*.34)
		var reach:=lerpf(5,48+float(k%4)*8,sqrt(t))
		var center:=origin+ray*reach+Vector2(0,-(14+float(k%4)*4.5)*sin(t*2.2))
		var puff:=Vector2(26,19)*lerpf(.70,1.54,t)
		var a0:=dusty*(.67+.28*sin(float(k)*1.39))
		_soft_light(center+Vector2(0,3),puff*1.55,Color("634632"),a0*.91,layer)
		var tone:=Color("a77651").lerp(Color("f0c586"),float(k%5)/4.0)
		_soft_light(center+Vector2(-2,-2),puff*1.15,tone,a0,layer)
	for k in 22:
		var theta:=float(k)*2.39996
		var radius:=lerpf(8,53+float(k%5)*7,sqrt(t))
		var grit:=origin+Vector2(cos(theta),sin(theta)*.37)*radius+Vector2(0,-sin(t*PI)*float(k%5)*8)
		layer.draw_circle(grit,lerpf(2.1,.75,t),Color("886146",dusty*.78),true,-1,true)

func _draw_silver_deer_skill_lights()->void:
	if not _uram_deer_close():_draw_deer_launch_dust()
	if not _silver_deer_active():return
	var windup:=maxf(.01,b.preview.length("req046_skill_anticipation"))
	var live:=motion[1]=="skill" and rules.hp[1]>0
	var armed:bool=not shared_world.consumed[1] if is_instance_valid(shared_world) else contact_at[1]>=0.0
	var begin:=SharedWorld.FOREST_PLANT_AT if _uram_deer_close() else 0.0
	var progress:=clampf((float(age[1])-begin)/maxf(.01,windup-begin),0.,1.) if live and age[1]>=begin else -1.0
	_draw_silver_deer(_position(1),_deer_visual_tip(),progress,armed,deer_wake,visual_clock,deer_skill_light_layer)

func _draw_silver_deer(hoof:Vector2,tip:Vector2,progress:float,armed:bool,wake:Array,clock:float,layer:Node2D)->void:
	var jade:=Color("619cbf") if local_world_ring else Color("5ba98d")
	var silver:=Color("e3f6ff") if local_world_ring else Color("e3f5ec")
	for j in wake.size():
		var sample:Dictionary=wake[j]
		var elapsed:=clock-float(sample.at)
		var fade:=1.0-smoothstep(.02,.53,elapsed)
		if local_parry_clock>=0.:fade*=1.-smoothstep(.02,.33,local_parry_clock)
		var foot:Vector2=sample.foot
		var point:Vector2=sample.tip
		if j>0:
			var prev:Vector2=wake[j-1].tip
			layer.draw_line(prev,point,Color(jade,.44*fade),14.0*fade+1.0,true)
			layer.draw_line(prev,point,Color(silver,.91*fade),3.5*fade+.7,true)
		_soft_light(point,Vector2(31,20),jade,fade*.44,layer)
		_soft_light(foot,Vector2(49,14),jade,fade*.26,layer)
		if j%2==0:
			var dust:=point+Vector2(sin(float(j)*2.2)*8,-elapsed*22)
			_soft_light(dust,Vector2(9,6),silver,.57*fade,layer)
	if progress<0:return
	if progress>=1.0:
		if armed:
			_soft_light(tip,Vector2(37,24),jade,.70,layer)
			_soft_light(tip,Vector2(14,10),silver,.91,layer)
		return
	var power:=smoothstep(.01,.20,progress)
	var scale_r:=lerpf(1.0,0.04,smoothstep(.07,.65,progress))
	var r:=Vector2(68,26)*scale_r
	var alpha:=power*(1.0-smoothstep(.59,.68,progress))
	layer.draw_texture_rect(ring_halo,Rect2(hoof-r*.8,r*1.6),false,Color(jade,alpha*.78))
	layer.draw_texture_rect(ring_band,Rect2(hoof-r*.5,r),false,Color(silver,alpha*.90))
	var focus:=smoothstep(.56,.66,progress)
	var flight:=hoof
	_soft_light(flight,Vector2(24,18),jade,focus*.72,layer)
	_soft_light(flight,Vector2(40,30)*lerpf(1.0,1.4,smoothstep(.94,1.0,progress)),silver,focus*.94,layer)
	for j in 13:
		var a0:=float(j)*2.39996+progress*.7
		var drift:=Vector2(cos(a0),sin(a0)*.32)*scale_r*(36.0+float(j%3)*9.0)
		var speck:=hoof+drift+Vector2(0,-sin(progress*PI)*float(j%4)*3)
		_soft_light(speck,Vector2(8,5),silver,power*(1.0-focus)*(.45+.28*cos(float(j)+progress*9)),layer)

func _draw_deer_impact(effect:Dictionary,p:float,layer:Node2D=null)->void:
	if layer==null:layer=effects_layer
	var at:Vector2=effect.center
	var fade:=1.0-smoothstep(.02,1.0,p)
	var peak:=1.0-smoothstep(.01,.38,p)
	var jade:=Color("79b6d8") if local_world_ring else Color("69ba97")
	var sil:=Color("eefaff") if local_world_ring else Color("eefff6")
	if effect.get("basic",false):
		# A short concentrated hit confirms a regular antler strike.
		_soft_light(at,Vector2(53,38),jade,fade*.72,layer)
		var extent:=Vector2(37,28)
		layer.draw_texture_rect(Hunt.BASIC_HIT,Rect2(at-extent*.5,extent),false,Color(sil,peak))
		var axis:Vector2=effect.get("axis",Vector2.RIGHT)
		for j in 4:
			var dir:=axis.rotated(lerpf(-.6,.6,float(j)/3.0))
			var edge:=at+dir*lerpf(10.0,29.0,p)
			layer.draw_line(edge-dir*lerpf(8.0,2.0,p),edge,Color(sil,fade*.68),1.7,true)
		return
	_soft_light(at,Vector2(124,85),jade,fade*.68,layer)
	_soft_light(at,Vector2(46,34),sil,peak*.99,layer)
	var extent:=Vector2(78,57)
	layer.draw_texture_rect(Hunt.HEAVY_HIT,Rect2(at-extent*.5,extent),false,Color(sil,peak*.88))
	var feet:Vector2=effect.floor_point
	var span:=Vector2(lerpf(35,118,p),lerpf(14,39,p))
	layer.draw_texture_rect(ring_band,Rect2(feet-span*.5,span),false,Color(jade,fade*.58))
	for j in 14:
		var direction:=Vector2.from_angle(float(j)*2.39996)*Vector2(1,.57)
		var reach:=lerpf(5,48+float(j%3)*13,sqrt(p))
		_soft_light(at+direction*reach,Vector2(11,8),sil,fade*.75,layer)

func _draw_han_skill_light(tip:Vector2,charge:float)->void:
	var hand:=presentation.bone_point(a,"hand.R")
	var foot:=_position(0)+Vector2(0,2)
	var power:=smoothstep(.03,.68,charge)
	_soft_light(foot,Vector2(78,28),Color("319cfd"),power*.56)
	_soft_light(hand,Vector2(44,39),Color("4ac5ff"),power*.66)
	for j in range(1,5):
		var f:=float(j)/5.0
		_soft_light(hand.lerp(tip,f),Vector2(29,18),Color("8ce8ff"),power*(.2+f*.18))
	for j in tip_trail.size():
		var tail:=1.0-float(j)/maxf(1,tip_trail.size())
		_soft_light(tip_trail[j],Vector2(49,27)*tail,Color("65bbff"),tail*power*.57)
	_soft_light(tip,Vector2(85,64),Color("56c6ff"),power*.96)
	_soft_light(tip,Vector2(35,31),Color("e3fbff"),power)

func _draw_han_impact(effect:Dictionary,p:float,basic:bool)->void:
	var at:Vector2=effect.center
	var flare:=1.0-smoothstep(.02,.67,p)
	var glow:=1.0-smoothstep(.05,1.0,p)
	var extent:=Vector2(37,25) if basic else Vector2(116,78)
	_soft_light(at,extent*(1.83 if basic else 2.0),Color("46baff"),glow*.91)
	_soft_light(at,extent*.82,Color("ebfdff"),flare)
	if basic:
		effects_layer.draw_texture_rect(Hunt.BASIC_HIT,Rect2(at-extent*.5,extent),false,Color("d7f5ff",flare))
		return
	var axis:=(_position(1)-_position(0)).angle()
	effects_layer.draw_set_transform(at,axis,Vector2.ONE)
	_soft_light(Vector2(-14,0),Vector2(145,24),Color("369cff"),flare*.90)
	_soft_light(Vector2(-10,0),Vector2(80,9),Color("d8f6ff"),flare*.94)
	_soft_light(Vector2(0,0),Vector2(24,29),Color("ecfbff"),flare*.86)
	effects_layer.draw_set_transform(Vector2.ZERO)
	var ground_mark:Vector2=effect.floor_point
	var spread:=Vector2(lerpf(62,178,p),lerpf(20,50,p))
	effects_layer.draw_texture_rect(Hunt.GROUND_PULSE,Rect2(ground_mark-spread*.5,spread),false,Color(.45,.81,1,glow*.8))
	_soft_light(ground_mark,spread*.89,Color("49b5ff"),glow*.63)
	for j in 15:
		var angle:=float(j)*2.39996
		var spark:=at+Vector2(cos(angle),sin(angle)*.62)*lerpf(9,59+float(j%3)*7,sqrt(p))
		_soft_light(spark,Vector2(14,10)*lerpf(1,.4,p),Color("b8eeff"),glow*.72)

func _duel_skill_ground_tint()->Color:
	if _prototype_duel():
		return Color.WHITE.lerp(Color("aebad3"),_han_chain_contrast())
	if not authored_polished:return Color.WHITE
	if _uram_duel() and uram_wave and not authored_frames.is_empty() and accent.kind=="parry":
		var progress:float=accent.age
		var exposure:=smoothstep(0.0,.042,progress)*(1.0-smoothstep(.14,.45,progress))
		return Color.WHITE.lerp(Color("c0c7c7"),exposure*.83)
	if _saebom_aurora_active() and motion[0]=="chain" and not local_saebom_latest:
		var elapsed:float=float(age[0])-SAEBOM_AURORA_START
		if saebom_hop:
			var clock:=_saebom_cheer_age()
			var exposure:=0.0
			for lift:float in SAEBOM_CHEER_LIFTS:
				var local:=clock-lift
				exposure=maxf(exposure,smoothstep(0,.095,local)*(1.0-smoothstep(.30,.73,local)))
			return Color.WHITE.lerp(Color("bcc9c3"),exposure*.76)
		var exposure:=smoothstep(-.05,.12,elapsed)*(1.0-smoothstep(.33,.66,elapsed))
		return Color.WHITE.lerp(Color("bcc9c3"),exposure*.76)
	return Color.WHITE

func _han_chain_contrast()->float:
	if not _prototype_duel() or accent.kind!="chain":return 0.0
	var t:float=accent.age
	var lift:=smoothstep(.16*accent.duration,.40*accent.duration,t)
	if accent.impact_at<0:
		return lift*.77*(1.0-smoothstep(.68*accent.duration,.91*accent.duration,t))
	var from_hit:float=t-accent.impact_at
	return maxf(.77*lift,1.0-smoothstep(0,.11,from_hit))*(1.0-smoothstep(.14,.81,from_hit))

func _chain_ray(from:Vector2,to:Vector2,width:float,strength:float)->void:
	if strength<=.001 or from.distance_to(to)<1.0:return
	var distance:=from.distance_to(to)
	var axis:Vector2=(to-from)/distance
	var flank:=axis.orthogonal()
	han_chain_light.draw_set_transform(from,axis.angle())
	_soft_light(Vector2(distance*.60,0),Vector2(distance*1.26,width*2.7),Color("23aafe"),strength*.85,han_chain_light)
	han_chain_light.draw_set_transform(Vector2.ZERO)
	var knots:=PackedFloat32Array([0,.22,.55,.82,1])
	var widths:=PackedFloat32Array([.02,.20,.41,.52,.07])
	var energies:=PackedFloat32Array([0,.23,.63,.83,.94])
	for k in range(knots.size()-1):
		var a0:=from.lerp(to,knots[k])
		var b0:=from.lerp(to,knots[k+1])
		var c0:=Color("70cfff",strength*energies[k])
		var c1:=Color("b4eaff",strength*energies[k+1])
		for side in [-1.0,1.0]:
			var a1:=a0+flank*width*widths[k]*float(side)
			var b1:=b0+flank*width*widths[k+1]*float(side)
			han_chain_light.draw_polygon(PackedVector2Array([a0,b0,b1,a1]),PackedColorArray([c0,c1,Color(c1,0),Color(c0,0)]))

func _draw_han_radial()->void:
	if not (_prototype_duel() or _han_fallback()):return
	for effect in fx:
		if effect.name!="han_chain_impact":continue
		var elapsed:=visual_clock-float(effect.at)
		if elapsed<0 or elapsed>=HAN_CHAIN_IMPACT_SECONDS:continue
		var center:Vector2=effect.floor_point
		var after:=smoothstep(.015,.075,elapsed)*(1.0-smoothstep(.17,.63,elapsed))
		_soft_light(center,Vector2(175,55),Color("238cff"),after*.46,location_layer)
		if han_ground.frames.is_empty() and han_radial_frames.size() == 21:
			var idx:=clampi(floori(elapsed*30.0),0,han_radial_frames.size()-1)
			location_layer.draw_texture_rect(han_radial_frames[idx],Rect2(center-HAN_RADIAL_EXTENT*.5,HAN_RADIAL_EXTENT),false)
	if han_ground_anchor.is_finite():
		han_ground.draw(location_layer, han_ground_anchor, visual_clock - han_ground_at)

func _draw_han_charge_gather(foot:Vector2,tip:Vector2,phase:float)->void:
	var peak:=smoothstep(.07,.19,phase)*(1.0-smoothstep(.43,.54,phase))
	if peak<=.001:return
	for i in 11:
		var side:=Vector2.from_angle(float(i)*TAU/11.0+.21)
		var offset:=side*Vector2(76.0+float(i%3)*11.0,31.0+float(i%3)*10.0)
		var start:Vector2=foot+offset+Vector2(0,-11.0*float(i%4))
		var t:=clampf((phase-.03-.036*float(i%4))/.38,0,1)
		var bend:=start.lerp(tip,smoothstep(0,1,t))+side*7.0*sin(PI*t)
		var tail:=start.lerp(tip,smoothstep(0,1,maxf(0,t-.12)))
		var spark:=peak*sin(PI*t)
		_soft_light(bend,Vector2(19,15)*lerpf(.72,1.25,t),Color("48caff"),spark*.8,han_chain_light)
		han_chain_light.draw_line(tail,bend,Color("7edcff",spark*.60),1.7,true)
		_soft_light(bend,Vector2(7,6),Color("e4fbff"),spark*.93,han_chain_light)
	_soft_light(tip,Vector2(88,65),Color("2a9cff"),peak*smoothstep(.21,.39,phase)*.58,han_chain_light)

func _draw_han_chain_light()->void:
	if not ((_prototype_duel() and is_instance_valid(shared_world)) or _han_boar_latest()):return
	var waiting:bool=not shared_world.consumed[0] if is_instance_valid(shared_world) else contact_at[0]>=0.0
	if motion[0]=="chain" and waiting:
		var phase:=_visual_age(0)/maxf(a.duration,.001)
		var power:=smoothstep(.035,.21,phase)*(1.0-smoothstep(.70,.86,phase))
		var foot:=_position(0)
		var chest:=a.screen_anchor()
		var hand:=presentation.bone_point(a,"hand.R")
		var tip:=presentation.spear_point(a)
		var charge:=power*(1.0-smoothstep(.22,.39,phase))
		if han_radial_frames.size()==21 or not han_ground.frames.is_empty():_draw_han_charge_gather(foot,tip,phase)
		_soft_light(foot,Vector2(111,40),Color("1ba3ff"),charge*.76,han_chain_light)
		_soft_light(foot,Vector2(49,19),Color("b8f3ff"),charge*.66,han_chain_light)
		for i in 5:
			var rise:=clampf((phase-.052-float(i)*.026)/.23,0,1)
			var point:=foot.lerp(chest,rise*2.0) if rise<.5 else chest.lerp(hand,(rise-.5)*2.0)
			_soft_light(point,Vector2(31,31),Color("5cd5ff"),sin(PI*rise)*charge*.69,han_chain_light)
		var spear:=power*smoothstep(.20,.38,phase)
		_chain_ray(hand.lerp(tip,.36),tip,8.0,spear*.70)
		_soft_light(tip,Vector2(61,49),Color("33a9ff"),spear*.85,han_chain_light)
		_soft_light(tip,Vector2(21,19),Color("e5fbff"),spear,han_chain_light)
		var descent:=power*smoothstep(.415,.53,phase)
		if descent>.001 and tip_trail.size()>1:
			var path_from:Vector2=tip
			for i in range(1,tip_trail.size()):
				var sample:Vector2=tip_trail[i]
				if sample.distance_to(tip)>81.0:break
				path_from=sample
				var weight:=1.0-float(i)/float(tip_trail.size())
				_soft_light(sample,Vector2(31,28)*lerpf(.53,1.0,weight),Color("40b8ff"),descent*weight*.65,han_chain_light)
			_chain_ray(path_from,tip,18.0,descent)
	for effect in fx:
		var elapsed:float=visual_clock-float(effect.at)
		if effect.name=="han_chain_impact":
			var center:Vector2=effect.center
			var peak:=1.0-smoothstep(.025,.155,elapsed)
			var stroke:=1.0-smoothstep(.015,.145,elapsed)
			_chain_ray(effect.wake_start,center,22.0,stroke)
			var floor_point:Vector2=effect.floor_point
			var wave_alpha:=smoothstep(.01,.095,elapsed)*(1.0-smoothstep(.20,.52,elapsed))
			var wave_size:=Vector2(58,18).lerp(Vector2(143,48),clampf(elapsed/.52,0,1))
			if han_radial_frames.size()!=21 and han_ground.frames.is_empty():
				han_chain_light.draw_texture_rect(Hunt.GROUND_PULSE,Rect2(floor_point-wave_size*.5,wave_size),false,Color("6ac7ff",wave_alpha*.67))
			_soft_light(center,Vector2(93,70),Color("36afff"),peak*.85,han_chain_light)
			_soft_light(center,Vector2(28,24),Color("f2fcff"),peak,han_chain_light)
		elif effect.name=="han_chain_afterglow":
			var fade:=smoothstep(.08,.19,elapsed)*(1.0-smoothstep(.15,HAN_CHAIN_IMPACT_SECONDS+HAN_CHAIN_TAIL,elapsed))
			var spread:=clampf(elapsed/(HAN_CHAIN_IMPACT_SECONDS+HAN_CHAIN_TAIL),0,1)
			_soft_light(effect.center,Vector2(89,33).lerp(Vector2(184,67),spread),Color("3296ff"),fade*.38,han_chain_light)
		elif effect.get("han_2sp_authored",false):
			var bloom:=1.0-smoothstep(.018,.17,elapsed)
			_soft_light(effect.center,Vector2(139,102),Color("167bff"),bloom*.79,han_chain_light)
			_soft_light(effect.center,Vector2(53,44),Color("d8fbff"),bloom*.75,han_chain_light)

func _draw_contact_effects()->void:
	if _prototype_duel() and motion[0]=="skill" and is_instance_valid(shared_world):
		var tip:=presentation.spear_point(a)
		var p:=clampf(_visual_age(0)/maxf(.01,motion_contact[0]),0,1)
		var release:=1.0 if not shared_world.consumed[0] else 1.0-smoothstep(motion_contact[0],motion_contact[0]+.29,age[0])
		if release>0:_draw_han_skill_light(tip,p*release)
	for i in range(fx.size()-1,-1,-1):
		var effect:=fx[i]
		var p:float=(visual_clock-float(effect.at))/float(effect.duration)
		if p>=1:fx.remove_at(i);continue
		if _draw_local_skill_effect(effect,p):continue
		if effect.name=="han_chain_impact":
			var index:=clampi(floori((visual_clock-float(effect.at))*30),0,chain_impact_frames.size()-1)
			const FACTOR:=.50
			effects_layer.draw_texture_rect(chain_impact_frames[index],Rect2(effect.center-Vector2(192,243)*FACTOR,Vector2(384,384)*FACTOR),false)
			continue
		if effect.name=="uram_deer_stun":
			_draw_uram_deer_stun(p)
			continue
		if effect.name=="uram_shield_contact" and uram_gong_test:
			var elapsed:=visual_clock-float(effect.at)
			if _uram_deer_close():
				if local_parry_clock>=0.:_draw_local_parry_flash(effect.center,Vector2.from_angle(effect.forward_angle),local_parry_clock)
			else:_draw_uram_gong(effect.center,Vector2.from_angle(effect.forward_angle),elapsed,effects_layer)
			continue
		if effect.name=="uram_shield_contact" and authored_asset_hero=="uram" and not authored_frames.is_empty():
			var elapsed:=visual_clock-float(effect.at)
			if uram_wave and authored_asset_size==192:
				_draw_uram_wave(effect,elapsed)
				continue
			if authored_bold and authored_asset_size==192:
				var flash:=1.0-smoothstep(.022,.16,elapsed)
				_soft_light(effect.center,Vector2(180,111),Color("38e8ce"),flash*.74)
				_soft_light(effect.center,Vector2(61,50),Color("fffbd9"),flash*.84)
			_draw_authored_frames(effect.center,elapsed,310.0 if authored_bold and authored_asset_size==192 else 207.0)
			continue
		if _uram_deer_close() and effect.get("attacker",-1)==1 and effect.name=="contact_attack":
			_draw_deer_impact({"center":effect.center,"basic":true,"axis":_position(1).direction_to(_position(0))},clampf(p,0,1))
			continue
		if local_world_ring and _silver_deer_active() and effect.get("attacker",-1)==1 and effect.name=="contact_skill":
			_draw_deer_impact(effect,clampf(p,0,1))
			continue
		if effect.name=="uram_shield_contact" or (_uram_duel() and effect.get("attacker",-1)==0):
			_draw_uram_contact(effect,p)
			continue
		if not String(effect.name).begins_with("contact_"):continue
		var basic:bool=effect.name=="contact_attack"
		var strong:bool=effect.name=="contact_chain"
		if _silver_deer_active() and is_instance_valid(shared_world) and effect.get("attacker",-1)==1 and effect.name=="contact_skill":
			_draw_deer_impact(effect,clampf(p,0,1))
			continue
		if _saebom_duel() and effect.get("attacker",-1)==0 and (basic or effect.name=="contact_skill"):
			if local_saebom_latest and not basic:continue
			if effect.get("basic_rope_impact",false):
				BasicRope.draw_impact(effects_layer,basic_rope_glow,effect.center,visual_clock-float(effect.at))
				continue
			_draw_sling_contact(effect,p,basic)
			continue
		if is_instance_valid(shared_world) and effect.get("attacker",-1)==0 and (basic or effect.name=="contact_skill"):
			if effect.get("han_2sp_authored",false):
				var elapsed:=visual_clock-float(effect.at)
				var idx:=clampi(floori(elapsed*30.0),0,HAN_2SP_COUNT-1)
				var scale_factor:=HAN_2SP_DISPLAY_SIZE/192.0
				effects_layer.draw_set_transform(effect.center,float(effect.spear_axis))
				effects_layer.draw_texture_rect(han_2sp_frames[idx],Rect2(-HAN_2SP_ORIGIN*scale_factor,Vector2.ONE*HAN_2SP_DISPLAY_SIZE),false)
				effects_layer.draw_set_transform(Vector2.ZERO)
			else:_draw_han_impact(effect,clampf(p,0,1),basic)
			continue
		if strong and is_instance_valid(shared_world):continue # Replace only the shared-world pilot impact.
		var at:Vector2=effect.center
		var fade:=1.0-smoothstep(.05,1,p)
		var extent:=Vector2(22,19) if basic else Vector2(74,58) if strong else Vector2(51,38)
		var texture:Texture2D=Hunt.BASIC_HIT if basic else Hunt.HEAVY_HIT
		if is_instance_valid(shared_world):
			extent*=1.28
			_soft_light(at,extent*1.75,effect.color,fade*.65)
		effects_layer.draw_texture_rect(texture,Rect2(at-extent*.5,extent),false,Color(effect.color,fade))
		if not basic:
			_soft_light(at,extent*1.35,Color("74c9ff"),fade*.55)
			if strong:
				var ground_size:=Vector2(96,34)*lerpf(.55,1.4,p)
				effects_layer.draw_texture_rect(Hunt.GROUND_PULSE,Rect2(_position(1)-ground_size*.5,ground_size),false,Color(.65,.85,1,fade))

func _draw_uram_exchange()->void:
	if motion[0]=="skill" and not shared_world.consumed[0]:
		var t:=clampf(age[0]/maxf(.01,motion_contact[0]),0.0,1.0)
		var club_tip:=shared_world.project(shared_world.weapon_point(0))
		var hand:=shared_world.bone_screen(0,"hand.R")
		var power:=smoothstep(.12,.89,t)
		if local_all_effects:_draw_local_uram_windup(club_tip,t,effects_layer)
		else:_soft_light(club_tip,Vector2(68,43),Color("ffc16d"),power*.61)
		_soft_light(club_tip,Vector2(24,15),Color("fff0be"),power*.83)
		for j in range(1,5):
			var along:=float(j)/5.0
			_soft_light(hand.lerp(club_tip,along),Vector2(18,11),Color("ffbf75"),power*along*.48)
	if motion[1]=="skill" and not shared_world.consumed[1] and not local_world_ring:
		var prep:float=b.preview.length("req046_skill_anticipation")
		var t:=clampf(age[1]/maxf(.01,prep),0,1)
		var runup:=1.0-smoothstep(prep,prep+.45,age[1])
		var feet:=_position(1)
		var snout:=shared_world.project(shared_world.weapon_point(1))
		var energy:float=runup*(.25+.50*t+.13*sin(age[1]*18.0))
		_soft_light(feet,Vector2(100,31),Color("f6773f"),energy)
		_soft_light(snout,Vector2(50,29),Color("ffc681"),energy*.73)
		var span:=Vector2(lerpf(86,52,t),lerpf(30,17,t))
		effects_layer.draw_texture_rect(Hunt.GROUND_PULSE,Rect2(feet-span*.5,span),false,Color("f28f62",energy*.75))
	var guard_close:=1.16 if _uram_deer_close() else URAM_GUARD_CLOSE
	if motion[0]=="chain" and not approach_active and age[0]<=guard_close+.12:
		var shield:=shared_world.project(a.preview.shield.global_position)
		var envelope:=smoothstep(0,.12,age[0])*(1.0-smoothstep(guard_close,guard_close+.12,age[0]))
		if uram_gong_test:
			if _uram_deer_close():
				_soft_light(shield,Vector2(36,29),Color("e88842"),envelope*.46)
				_soft_light(shield,Vector2(16,12),Color("ffe4a4"),envelope*.73)
				return
			_soft_light(shield,Vector2(114,99),Color("d74828"),envelope*.53)
			_soft_light(shield,Vector2(72,64),Color("f87934"),envelope*.53)
			_soft_light(shield,Vector2(39,35),Color("ffb458"),envelope*.43)
			_soft_light(shield,Vector2(17,15),Color("ffe493"),envelope*.76)
			return
		_soft_light(shield,Vector2(75,57),Color("37e3c2"),envelope*.69)
		_soft_light(shield,Vector2(39,31),Color("b9fff1"),envelope*.63)
		var facing:=_position(0).direction_to(_position(1)).angle()
		effects_layer.draw_set_transform(shield,facing,Vector2(.72,1.0))
		effects_layer.draw_arc(Vector2.ZERO,24.0,-1.02,1.02,20,Color("65edda",envelope*.52),5.0,true)
		effects_layer.draw_arc(Vector2.ZERO,24.0,-.97,.97,20,Color("d8fff5",envelope*.69),1.55,true)
		effects_layer.draw_set_transform(Vector2.ZERO)

func _draw_uram_contact(effect:Dictionary,p:float)->void:
	var at:Vector2=effect.center
	var block:bool=effect.name=="uram_shield_contact"
	if effect.name=="contact_skill":
		_draw_uram_club_skill_contact(effect,p)
		return
	if effect.name=="contact_counter" and _uram_deer_close():
		var flash:=1.0-smoothstep(.02,.25,p)
		_soft_light(at,Vector2(44,32),Color("ed9a55"),flash*.65)
		_soft_light(at,Vector2(21,16),Color("fff8dc"),flash*.94)
		return
	var light:=1.0-smoothstep(.04,.85,p)
	var basic:bool=effect.name=="contact_attack"
	var tint:=Color("58dfc7") if block else Color("ecb176")
	var radius:=Vector2(85,60) if block else Vector2(32,24) if basic else Vector2(69,46)
	_soft_light(at,radius*2.1,tint,light*.94)
	_soft_light(at,radius*.52,Color("fff8dc"),light)
	var texture:Texture2D=Hunt.BASIC_HIT
	effects_layer.draw_texture_rect(texture,Rect2(at-radius*.5,radius),false,Color("fff3ce",light*.86))
	if basic:return
	var floor_point:Vector2=effect.get("floor_point",at+Vector2(0,18))
	var span:=Vector2(lerpf(38,145,sqrt(p)),lerpf(13,42,sqrt(p)))
	_soft_light(floor_point,span,tint,light*.63)
	for j in 12:
		var a0:=float(j)*2.39996
		var mote:=at+Vector2(cos(a0),sin(a0)*.56)*lerpf(7,52,sqrt(p))
		_soft_light(mote,Vector2(14,10)*(1-p*.4),Color("ffdf9c"),light*.8)

func _draw_uram_club_skill_contact(effect:Dictionary,p:float)->void:
	var center:Vector2=effect.center
	var flash:=1.0-smoothstep(.03,.50,p)
	var after:=1.0-smoothstep(.05,1.0,p)
	var forward:=_position(0).direction_to(_position(1)).angle()
	_soft_light(center,Vector2(134,92),Color("ee8e36"),after*.77)
	_soft_light(center,Vector2(62,43),Color("ffdc82"),flash*.93)
	_soft_light(center,Vector2(28,19),Color("fff6d6"),flash)
	effects_layer.draw_set_transform(center,forward,Vector2(1.0,.74))
	for j in 3:
		var radius:=lerpf(18.0,94.0,sqrt(p))+float(j)*8.0
		var fade:=after*(1.0-float(j)*.23)
		effects_layer.draw_arc(Vector2(-7,0),radius,-1.12+float(j)*.18,1.10-float(j)*.18,31,Color("eeb24c",fade*.36),6.5,true)
		effects_layer.draw_arc(Vector2(-7,0),radius,-.85,.80,24,Color("fff0b5",fade*.78),1.6,true)
	for j in 15:
		var angle:float=lerpf(-1.16,1.16,float(j)/14.0)+.10*sin(float(j)*7.1)
		var direction:=Vector2.from_angle(angle)
		var reach:=lerpf(9.0,74.0+float(j%4)*9.0,sqrt(p))
		effects_layer.draw_line(direction*(reach-8.0),direction*reach,Color("ffdc92",after*.84),2.0,true)
	effects_layer.draw_set_transform(Vector2.ZERO)
	var feet:Vector2=effect.get("floor_point",center+Vector2(0,18))
	_soft_light(feet,Vector2(152,35),Color("ed8b39"),after*.41)

func _draw_effects() -> void:
	if not uram_short_counter_fan.is_empty():
		var fan:=uram_short_counter_fan
		var progress:float=(visual_clock-float(fan.at))/float(fan.span)
		if progress<1. and not bool(fan.get("combined", false)):UramCounterWave.draw_fan(effects_layer,fan.from,fan.ground,fan.axis,fan.reach,progress,true,false)
	for impact in fx:
		if impact.name=="uram_counter_outreach_hit":UramCounterWave.draw_pop(effects_layer,impact.center,visual_clock-float(impact.at))
	if _prototype_duel() or _uram_duel() or _saebom_duel():
		if _uram_duel() and is_instance_valid(shared_world):_draw_uram_exchange()
		if _saebom_duel() and is_instance_valid(shared_world):_draw_sling_exchange()
		_draw_contact_effects()
		return
	if local_all_effects and a.key=="uram" and motion[0]=="skill" and contact_at[0]>=0:
		_draw_local_uram_windup(_local_club_tip(),clampf(age[0]/maxf(.01,motion_contact[0]),0,1),effects_layer)
	if _han_fallback() and motion[0]=="skill" and contact_at[0]>=0:
		_draw_han_skill_light(presentation.spear_point(a),clampf(age[0]/maxf(.01,motion_contact[0]),0,1))
	for i in range(fx.size()-1,-1,-1):
		var effect := fx[i]
		var p := (visual_clock-float(effect.at))/maxf(.01,float(effect.duration))
		if p>=1.0:
			fx.remove_at(i)
			continue
		var color: Color = effect.color
		var center: Vector2 = effect.center
		if _draw_local_skill_effect(effect,p):continue
		if effect.name=="silver_deer_contact":
			_draw_deer_impact(effect,clampf(p,0,1))
			continue
		if effect.name=="uram_gong_cast":
			var stage:=visual_clock-float(effect.at)-.16
			if stage>=0.0 and not effect.has("shield_origin"):
				var view:=a.preview
				var shield:Node3D=view.shield
				var marker:=_position(0)-Vector2(0,25)
				if is_instance_valid(shield):
					marker=view.position+(view.display.position+view.camera.unproject_position(shield.global_position)*view.display.scale)*view.scale
				effect["shield_origin"]=marker
			if effect.has("shield_origin"):
				_draw_uram_gong(effect.shield_origin,effect.forward,stage,effects_layer)
			continue
		if effect.name in ["cast_hangyeol","cast_uram","cast_saebom"]:
			var alpha := sin(PI*p)
			var hand := center+Vector2(29,-40)
			match effect.name:
				"cast_hangyeol":
					# Weapon trail follows the sampled mesh; no unrelated down-right beam.
					if a.key=="hangyeol" and motion[0]=="skill":
						var head:=presentation.spear_point(a)
						var tail:=head+head.direction_to(_position(0))*12.0
						effects_layer.draw_line(tail,head,Color(color,alpha*.5),3.0*alpha,true)
				"cast_uram":
					var at := hand+Vector2(18,2)
					effects_layer.draw_arc(at,41,lerpf(-2.2,-.4,p),lerpf(-.8,1.3,p),30,Color(color,alpha*.55),16.0*alpha,true)
					effects_layer.draw_arc(at,41,lerpf(-2.2,-.4,p),lerpf(-.8,1.3,p),30,Color(color,alpha),4.0*alpha,true)
				"cast_saebom":
					var at := hand+Vector2(-33,-17)
					if p < .72:
						var begin := TAU*2.0*pow(p/.72,1.7)
						effects_layer.draw_arc(at,25.0,begin,begin+3.9,30,Color("#ef5553",alpha*.85),6.0*alpha,true)
					else:
						var head := at+Vector2(35+125*((p-.72)/.28),18)
						effects_layer.draw_line(at,head,Color("#ef5553",alpha),7.0*alpha,true)
		elif effect.name in ["gather","boss_gather"] or String(effect.name).begins_with("chain_"):
			var chain := String(effect.name).begins_with("chain_")
			var boss: bool = effect.name=="boss_gather"
			var phase := clampf(p/.45,0,1) if chain else p
			if chain and p > .43:
				var lift := (p-.43)/.57
				var tip := center+Vector2(28,-53)
				if effect.name=="chain_hangyeol":
					tip = center+Vector2(37,-100*sin(PI*lift)-29)
				var body := center.lerp(tip,clampf(lift*1.7,0,1))
				effects_layer.draw_line(center.lerp(body,.25),body,Color(color,.37*(1-lift)),15,true)
				effects_layer.draw_circle(body,lerpf(17,39,lift),Color(color,.62*(1-lift)))
			if boss:
				var beat := fposmod(p*3.0,1.0)
				for j in 22:
					var dir := Vector2.from_angle(float(j)*TAU/22.0)
					var trail := dir * lerpf(182.0,14.0,beat)
					effects_layer.draw_line(center+trail,center+trail*.80,Color("#ed6962",.58*(1.0-p*.35)),2.4,true)
			for j in 12:
				var dir := Vector2.from_angle(float(j)*TAU/12.0)
				var offset := dir * lerpf(138 if boss else 86,6,phase) * Vector2(1,.35)
				effects_layer.draw_circle(center+offset,2.0+2.0*p,Color(color,.6))
			effects_layer.draw_set_transform(center,0,Vector2(1,.36))
			effects_layer.draw_arc(Vector2.ZERO,lerpf(82 if boss else 49,10,phase),0,TAU,38,Color(color,.55),3.0,true)
			effects_layer.draw_set_transform(Vector2.ZERO)
		else:
			var radius := lerpf(6,(67 if b.key=="adult" else 43) if effect.name=="burst" else 21,p)
			effects_layer.draw_circle(center,radius,Color(color,.33*(1.0-p)))
			for j in 11:
				var dir := Vector2.from_angle(float(j)*TAU/7.0+.16)
				effects_layer.draw_line(center+dir*radius*.5,center+dir*radius,Color(color,1.0-p),3.0*(1.0-p),true)

func _draw_uram_wave(effect:Dictionary,elapsed:float)->void:
	if elapsed<0 or elapsed>=AUTHORED_FRAME_SECONDS:return
	var center:Vector2=effect.center
	var flash:=1.0-smoothstep(.028,.13,elapsed)
	_soft_light(center,Vector2(154,92),Color("48dcca"),flash*.76)
	_soft_light(center,Vector2(58,40),Color("e2fff4"),flash*.75)
	var floor_point:Vector2=effect.floor_point
	var t:=clampf(elapsed/AUTHORED_FRAME_SECONDS,0,1)
	var fading:=1.0-smoothstep(.12,.70,elapsed)
	_soft_light(floor_point,Vector2(lerpf(55.0,162.0,t),lerpf(20.0,37.0,t)),Color("3dcbb9"),fading*.42)
	var extent:=Vector2(396,260)
	var frame_index:=clampi(floori(elapsed*30.0),0,authored_frames.size()-1)
	effects_layer.draw_set_transform(center,float(effect.forward_angle))
	effects_layer.draw_texture_rect(authored_frames[frame_index],Rect2(-extent*URAM_WAVE_ORIGIN,extent),false)
	effects_layer.draw_set_transform(Vector2.ZERO)

func _saebom_aurora_active()->bool:
	return saebom_aurora and authored_asset_size==192 and authored_asset_hero=="saebom" and not authored_frames.is_empty()

func _saebom_cheer_age()->float:
	return float(age[0])*SAEBOM_CHEER_NATIVE_SECONDS/maxf(.01,a.duration)

func _release_bom_cloud()->void:
	local_bom_rally_until=rules.elapsed+5.0
	local_bom_cloud_origin=_position(0);local_bom_cloud_at=visual_clock
	var wind:=RallyCloud.accrue(local_bom_cloud_fifths,RallyCloud.SOLO_BASE)
	local_bom_cloud_fifths=wind.y
	if rules.damage(1,wind.x):_die(1)

func _draw_saebom_aurora()->void:
	RallyCloud.draw(location_layer,local_bom_cloud_origin,visual_clock-local_bom_cloud_at)
	if local_saebom_latest and a!=null and a.key=="saebom":
		if rules.hp[0]>0:
			if local_melee_polish:
				RallySilver.wings(location_layer,_position(0),rules.elapsed-local_bom_silver_cast_at)
				RallySilver.aura(location_layer,_position(0),local_bom_rally_until-rules.elapsed,5.0)
			elif motion[0]=="chain":_draw_bom_wings(_position(0),age[0],location_layer)
		return
	if not _saebom_aurora_active() or motion[0]!="chain" or rules.hp[0]<=0:return
	if saebom_hop:
		var clock:=_saebom_cheer_age()
		for i in SAEBOM_CHEER_LIFTS.size():
			_draw_saebom_hop_wave(clock-float(SAEBOM_CHEER_LIFTS[i]),i)
		return
	var elapsed:float=float(age[0])-SAEBOM_AURORA_START
	if elapsed<0 or elapsed>=AUTHORED_FRAME_SECONDS:return
	var idx:=clampi(floori(elapsed*30.0),0,authored_frames.size()-1)
	var extent:=Vector2(488,171)
	var origin:=saebom_aurora_origin
	var rise:=1.0-smoothstep(.045,.21,elapsed)
	_soft_light(origin,Vector2(90,29),Color("68edbb"),rise*.52,location_layer)
	location_layer.draw_texture_rect(authored_frames[idx],Rect2(origin-extent*.5,extent),false)

func _draw_saebom_hop_wave(t:float,beat:int)->void:
	if t<0 or t>=.94:return
	var extent:=Vector2(488,171)
	var origin:=saebom_aurora_origin
	var warm:=Color("ffecd2") if beat%2==1 else Color.WHITE
	# Keep a trembling afterwave alive under the next hop rather than cutting to blank.
	if t>.27:
		var span:=extent*lerpf(.92,1.08,smoothstep(.28,.89,t))
		var quiver:=.5+.5*sin((t-.27)*TAU*5.45)
		var shimmer:=smoothstep(.28,.39,t)*(1.0-smoothstep(.57,.94,t))*(.18+.15*quiver)
		var after_idx:=clampi(floori(lerpf(11.0,17.0,smoothstep(.31,.86,t))),11,17)
		location_layer.draw_texture_rect(authored_frames[after_idx],Rect2(origin-span*.5,span),false,Color(warm,shimmer))
	if t<.65:
		var idx:=clampi(floori(t*21.0/.65),0,authored_frames.size()-1)
		var lift:=1.0-smoothstep(.025,.13,t)
		_soft_light(origin,Vector2(100,34),Color("7afed2"),lift*.68,location_layer)
		location_layer.draw_texture_rect(authored_frames[idx],Rect2(origin-extent*.5,extent),false,warm)

func _draw_sling_exchange()->void:
	if rules.hp[0]<=0:return
	if local_saebom_latest:
		var lag:=visual_clock-bom_path_end
		if bom_path.size()>1 and lag<.13:_draw_bom_trail(bom_path,1.0-smoothstep(.025,.13,lag),effects_layer)
		return
	var stone:=shared_world.project(shared_world.sling_point())
	if motion[0]=="skill" and not shared_world.consumed[0] and age[0]<SharedWorld.sling_release_seconds("skill"):
		var charge:=smoothstep(.16,.65,age[0])
		var pouch:=shared_world.bone_screen(0,"sling_pouch")
		var hand:=shared_world.bone_screen(0,"hand.R")
		effects_layer.draw_line(hand,pouch,Color(1,.23,.15,.58*charge),2.5,true)
		_soft_light(pouch,Vector2(29,24),Color("d32118"),.50*charge)
		_soft_light(stone,Vector2(17,16),Color("ff544a"),.84*charge)
		effects_layer.draw_circle(stone,2.0,Color(1,.77,.67,charge),true,-1,true)
	if motion[0]=="chain" and not _saebom_aurora_active():
		var phase:=clampf(age[0]/maxf(.01,a.duration),0,1)
		var pulse:=sin(PI*phase)
		var ground_point:=_position(0)
		var palms:=shared_world.bone_screen(0,"hand.R").lerp(shared_world.bone_screen(0,"hand.L"),.5)
		_soft_light(ground_point,Vector2(66,20),Color("66cfa1"),pulse*.58)
		var use_authored:=authored_asset_hero=="saebom" and not authored_frames.is_empty()
		if use_authored:
			var elapsed:float=float(age[0])-SAEBOM_SUPPORT_START
			if authored_bold and authored_asset_size==192:
				var swell:=smoothstep(.045,.27,elapsed)*(1.0-smoothstep(.35,.67,elapsed))
				var transfer:=smoothstep(.22,.34,elapsed)*(1.0-smoothstep(.35,.53,elapsed))
				_soft_light(ground_point,Vector2(144,54),Color("31dfb6"),swell*.56)
				_soft_light(palms,Vector2(105,83),Color("fff0a6"),transfer*.70)
			_draw_authored_frames(ground_point,elapsed,298.0 if authored_bold and authored_asset_size==192 else 207.0)
		# Keep the original windup as the setup for the authored ribbon.
		var draw_in:=clampf(phase/.45,0,1)
		if use_authored:
			pulse*=1.0-smoothstep(SAEBOM_SUPPORT_START,SAEBOM_SUPPORT_START+.20,age[0])
		var rim:=lerpf(49.0,10.0,draw_in)
		for i in 12:
			var direction:=Vector2.from_angle(float(i)*TAU/12.0)
			var offset:=direction*lerpf(86.0,6.0,draw_in)*Vector2(1,.35)
			effects_layer.draw_circle(ground_point+offset,2.0+2.0*phase,Color(.40,.81,.64,pulse*.54))
		effects_layer.draw_set_transform(ground_point,0,Vector2(1,.36))
		effects_layer.draw_arc(Vector2.ZERO,rim,0,TAU,38,Color(.54,.91,.72,pulse*.52),3.0,true)
		effects_layer.draw_set_transform(Vector2.ZERO)
		_soft_light(ground_point.lerp(palms,smoothstep(.08,.65,phase)),Vector2(29,31),Color("88e8ba"),pulse*.62)
		_soft_light(palms,Vector2(30,25),Color("b1f6ca"),pulse*.62*smoothstep(.27,.68,phase))
	if not shared_world.projectile.is_empty():
		var shot:Dictionary=shared_world.projectile
		if shot.motion=="attack" and local_shared_ranged:return
		var point:Vector3=shot.position
		var velocity:Vector3=shot.velocity
		var tip:=shared_world.project(point)
		var tail:=shared_world.project(point-velocity*(.063 if shot.motion=="skill" else .029))
		var color:=Color("f34937") if shot.motion=="skill" else Color("c99575")
		var strong:bool=shot.motion=="skill"
		var beam:=tip-tail
		var scale:=1.0 if strong else .62
		for i in range(1,8):
			var u:=float(i)/8.0
			var width:=lerpf(17.0,7.0,u)*scale
			_soft_light(tip-beam*u,Vector2(width,width*.78),color,(1.0-u)*(1.0-u)*(.86 if strong else .62))
		_soft_light(tip,Vector2(25,20)*scale,color,.78)
		_soft_light(tip,Vector2(9,8)*scale,Color("fff1d9"),.92)

func _draw_sling_contact(effect:Dictionary,p:float,basic:bool)->void:
	var center:Vector2=effect.center
	var life:=1.0-smoothstep(.09,.74,p)
	var warm:=Color("e9b794") if basic else Color("f55a45")
	_soft_light(center,Vector2(34,25) if basic else Vector2(70,50),warm,life*.77)
	for i in (5 if basic else 9):
		var ray:=Vector2.from_angle(float(i)*2.39+.3)
		var distance:=lerpf(2.0,18.0 if basic else 34.0,p)
		var at:=center+ray*distance
		var tail:=at-ray*(4.0 if basic else 7.0)
		effects_layer.draw_line(tail,at,Color(warm,life*.74),2.2,true)
	_soft_light(center,Vector2(17,15),Color("fff2d6"),life*.82)


# TEST 27: one shield-contact wave. Ripple distorts the same shell, not a new wave.
func _draw_uram_gong(center:Vector2,forward:Vector2,elapsed:float,layer:Node2D)->void:
	if elapsed<0.0 or elapsed>=1.6:return
	var core:=1.0-smoothstep(.045,.33,elapsed)
	_soft_light(center,Vector2(127,89),Color("df4c23"),core*.82,layer)
	_soft_light(center,Vector2(74,53),Color("ff9f48"),core*.90,layer)
	_soft_light(center,Vector2(31,24),Color("ffe7a0"),core,layer)
	var opening:=1.0-exp(-elapsed*3.15)
	var radius:=(16.0+397.0*opening)*.44
	var strength:=smoothstep(0.0,.065,elapsed)*(1.0-smoothstep(.23,1.6,elapsed))
	var ring:=sin(elapsed*15.0)*exp(-elapsed*2.7)
	var across:=forward.orthogonal()
	for j in 40:
		var theta:=lerpf(-1.52,1.52,float(j)/39.0)
		var envelope:=pow(maxf(0.0,cos(theta)),.72)
		var warp:=sin(theta*7.0+elapsed*3.0)*(8.0+opening*12.0)+sin(theta*3.8+.9)*opening*29.0+ring*sin(theta*3.0)*17.0
		var ray:=forward*cos(theta)+across*sin(theta)*.84
		var point:=center+ray*(radius+warp*.44)
		if j%2==0:
			_soft_light(point,Vector2(75,49)*(1.0+opening*.42),Color("ec6826"),strength*envelope*(.30+.10*ring),layer)
		_soft_light(point,Vector2(46,31),Color("ff9f48"),strength*envelope*.22*(.8+.2*sin(theta*13.0+1.0)),layer)
		_soft_light(point-ray*(30.0+opening*50.0)*.44,Vector2(59,37),Color("d56a36"),strength*envelope*.15,layer)




func _local_club_tip()->Vector2:
	var view:=a.preview
	var club:MeshInstance3D=view.club
	if not is_instance_valid(club):return _position(0)-Vector2(0,25)
	var tip:=club.to_global(Vector3(club.get_aabb().end.x*.89,0,0))
	return view.position+(view.display.position+view.camera.unproject_position(tip)*view.display.scale)*view.scale

func _uram_floor_recovery(side:int)->float:
	if side==0 and _uram_duel() and local_melee_polish and motion[0]=="skill" and shared_world.uram_floor_emitted:
		return SharedWorld.URAM_FLOOR_HOLD
	return 0.

func _play_uram_ground_thump()->void:
	_sound("uram_ground_thump")

func _uram_ground_contact(world_origin:Vector3,target:Vector3)->void:
	var origin:=shared_world.project(world_origin)
	var finish:=shared_world.project(target*Vector3(1,0,1))
	_flash(origin,"uram_ground_wave",Color.WHITE,1.04)
	# Ground projection supplies exact direction/scale; the visual aftershock
	# never supplies damage or a new target.
	fx[-1]["end"]=origin+(finish-origin).limit_length(126.0)
	_play_uram_ground_thump()

func _draw_squad_uram_ground(origin:Vector2,finish:Vector2,t:float,layer:Node2D)->void:
	_soft_light(origin,Vector2.ONE,Color.WHITE,.001,layer)
	LocalUramHeavy.draw_ground_wave(layer,contact_glow,origin,finish,t,SharedWorld.URAM_FLOOR_TRAVEL,false)

func _draw_local_uram_windup(tip:Vector2,p:float,layer:Node2D)->void:
	_soft_light(tip,Vector2.ONE,Color.WHITE,.001,layer)
	LocalUramHeavy.draw_windup(layer,contact_glow,tip,p)

func _draw_local_uram_contact(at:Vector2,ground:Vector2,forward:Vector2,t:float,layer:Node2D)->void:
	_soft_light(at,Vector2.ONE,Color.WHITE,.001,layer)
	LocalUramHeavy.draw(layer,contact_glow,at,ground,forward,t,1.0,1.60 if local_shared_ranged else 1.0,local_melee_polish)

func _squad_spotlight_started()->void:
	if is_instance_valid(local_parry_thump):local_parry_thump.play()

func _show_squad_spotlight_caption(t:float)->void:
	var alpha:=smoothstep(.08,.28,t)*(1.-smoothstep(1.63,2.14,t)) if t>=0. else 0.
	local_parry_caption.visible=alpha>.005
	local_parry_caption.modulate.a=alpha

func _draw_uram_deer_stun(progress:float)->void:
	if not is_instance_valid(shared_world) or rules.hp[1]<=0:return
	_draw_parry_stars(shared_world.bone_screen(1,"head")-Vector2(0,28),progress,effects_layer)

func _draw_parry_stars(top:Vector2,progress:float,layer:Node2D)->void:
	var life:=1.0-smoothstep(.68,1.0,progress)
	for i in 3:
		var phase:=progress*TAU*1.3+float(i)*TAU/3.0
		var depth:=sin(phase)
		var point:=top+Vector2(cos(phase)*20.0,depth*6.6)
		var scale:=lerpf(.68,1.08,(depth+1.0)*.5)
		var size:=Vector2(36,30)*scale
		_soft_light(point,size,Color("ee9c35"),life*.70,layer)
		var tint:=Color("f6bd55",life*lerpf(.67,1.0,(depth+1.0)*.5))
		var points:=PackedVector2Array([point+Vector2(0,-4),point+Vector2(1.3,-1.1),point+Vector2(4,0),point+Vector2(1.3,1.1),point+Vector2(0,4),point+Vector2(-1.3,1.1),point+Vector2(-4,0),point+Vector2(-1.3,-1.1)])
		for n in points.size():points[n]=point+(points[n]-point)*(2.0*scale)
		layer.draw_colored_polygon(points,tint)

func _draw_local_uram_floor()->void:
	if not local_melee_polish:return
	if _uram_deer_close():
		if local_parry_clock<0.:
			_draw_deer_launch_dust(location_layer)
		elif deer_dust_is_world:
			# Let the pre-impact dirt settle as a soft ground haze on a block.
			var foot:=shared_world.project(deer_dust_world)
			var life:=1.-smoothstep(.15,1.13,local_parry_clock)
			var r:=lerpf(.78,1.25,smoothstep(0.,1.13,local_parry_clock))
			_soft_light(foot,Vector2(66,24)*r,Color("987758"),.29*life,location_layer)
			_soft_light(foot+Vector2(2.,-1.),Vector2(74,20)*r,Color("d99d60"),.19*life,location_layer)
	for effect in fx:
		var forward:Vector2
		if effect.name=="uram_ground_wave":
			_soft_light(effect.center,Vector2.ONE,Color.WHITE,.001,location_layer)
			LocalUramHeavy.draw_ground_wave(location_layer,contact_glow,effect.center,effect.end,visual_clock-float(effect.at),SharedWorld.URAM_FLOOR_TRAVEL,false)
			continue
		elif effect.name=="local_uram_2p":forward=effect.forward
		elif effect.name=="uram_shield_contact" and _uram_deer_close():
			if local_parry_clock>=0.:_draw_local_parry_floor(effect.floor_point,Vector2.from_angle(effect.forward_angle),local_parry_clock)
			continue
		else:continue
		_soft_light(effect.floor_point,Vector2.ONE,Color.WHITE,.001,location_layer)
		LocalUramHeavy.draw_readable_floor(location_layer,contact_glow,effect.floor_point,forward,visual_clock-float(effect.at))

func _draw_local_parry_flash(center:Vector2,forward:Vector2,t:float,layer:Node2D=null)->void:
	var paint:=effects_layer if layer==null else layer
	var power:=1.-smoothstep(.072,.39,t)
	if power<.005:return
	_soft_light(center,Vector2(94,65),Color("db791f"),power*.83,paint)
	_soft_light(center,Vector2(51,36),Color("ffb448"),power*.97,paint)
	_soft_light(center,Vector2(27,20),Color("fff0a9"),power,paint)
	_soft_light(center,Vector2(13,12),Color("fffdf0"),power,paint)
	paint.draw_circle(center,3.1,Color(1.,.99,.88,power),true,-1.,true)
	for i in 7:
		var theta:=forward.angle()+(i-3)*.55
		var ray:=Vector2.from_angle(theta)
		var point:=center+ray*(5.+t*86.)
		paint.draw_line(point,point+ray*(8.+float(i%3)*5.),Color(1.,.82,.49,power*.68),1.1,true)

func _load_approved_parry_asset()->void:
	for index in 5:
		var texture_path:=APPROVED_PARRY_ASSET_DIR+"uram_parry_dust_atlas_%d.png"%index
		var texture:Texture2D=load(texture_path) if ResourceLoader.exists(texture_path,"Texture2D") else null
		if texture==null and OS.has_feature("editor"):
			var raw:=Image.load_from_file(texture_path)
			if raw!=null and not raw.is_empty():texture=ImageTexture.create_from_image(raw)
		if texture==null:
			local_parry_sheets.clear()
			push_warning("Approved Uram dust is missing; no substitute will be drawn.")
			break
		local_parry_sheets.append(texture)
	var audio_path:=APPROVED_PARRY_ASSET_DIR+"uram_parry_dust_thump.wav"
	var sample:AudioStream=load(audio_path) if ResourceLoader.exists(audio_path,"AudioStream") else null
	if sample==null and OS.has_feature("editor"):sample=AudioStreamWAV.load_from_file(audio_path)
	if sample!=null:
		local_parry_thump=AudioStreamPlayer.new()
		local_parry_thump.stream=sample
		local_parry_thump.volume_db=linear_to_db(.82)
		for bus in ["Combat","SFX"]:
			if AudioServer.get_bus_index(bus)>=0:
				local_parry_thump.bus=bus
				break
		add_child(local_parry_thump)

func _draw_local_parry_floor(point:Vector2,_forward:Vector2,t:float,layer:Node2D=null)->void:
	if local_parry_sheets.size()!=5 or t<0. or t>=2.4:return
	const CELL:=Vector2(433.,251.)
	const DRAW_SCALE:=1.5
	var id:=floori(t*30.+.00001)
	var cell:=id%16
	var sheet:Texture2D=local_parry_sheets[id/16]
	var area:=Rect2(Vector2(cell%4,cell/4)*CELL,CELL)
	var destination:=Rect2(point-Vector2(206.,137.5)*DRAW_SCALE,CELL*DRAW_SCALE)
	var paint:=location_layer if layer==null else layer
	paint.draw_texture_rect_region(sheet,destination,area,Color.WHITE,false,true)


func _draw_local_skill_effect(effect:Dictionary,p:float)->bool:
	if not local_all_effects:return false
	match effect.name:
		"local_bom_skill_hit":_draw_bom_hit(effect.center,effect.forward,visual_clock-float(effect.at),effects_layer)
		"local_uram_contact_silent":return true
		"local_uram_2p":
			if local_melee_polish:
				_soft_light(effect.center,Vector2.ONE,Color.WHITE,.001,effects_layer)
				LocalUramHeavy.draw_readable_flash(effects_layer,contact_glow,effect.center,effect.forward,visual_clock-float(effect.at))
			else:
				_draw_local_uram_contact(effect.center,effect.floor_point,effect.forward,visual_clock-float(effect.at),effects_layer)
		"local_han_hit":_draw_han_impact(effect,p,effect.basic)
		"local_han_2p":
			var elapsed:=visual_clock-float(effect.at)
			var idx:=clampi(floori(elapsed*30.0),0,HAN_2SP_COUNT-1)
			var factor:=HAN_2SP_DISPLAY_SIZE/192.0
			effects_layer.draw_set_transform(effect.center,float(effect.spear_axis))
			effects_layer.draw_texture_rect(han_2sp_frames[idx],Rect2(-HAN_2SP_ORIGIN*factor,Vector2.ONE*HAN_2SP_DISPLAY_SIZE),false)
			effects_layer.draw_set_transform(Vector2.ZERO)
		"han_chain_impact":
			if not _han_fallback():return false
			var index:=clampi(floori((visual_clock-float(effect.at))*30),0,chain_impact_frames.size()-1)
			var extent:=Vector2(384,384)*.50
			effects_layer.draw_texture_rect(chain_impact_frames[index],Rect2(effect.center-Vector2(192,243)*.50,extent),false)
		_:return false
	return true



func _draw_squad_authored(tag:String,point:Vector2,axis:Vector2,t:float,layer:Node2D)->void:
	match tag:
		"han_chain":
			if chain_impact_frames.is_empty() or t>=HAN_CHAIN_IMPACT_SECONDS:return
			var idx:=clampi(floori(t*30),0,chain_impact_frames.size()-1)
			layer.draw_texture_rect(chain_impact_frames[idx],Rect2(point-Vector2(96,121.5),Vector2(192,192)),false)
		"han_skill":
			if han_2sp_frames.size()!=HAN_2SP_COUNT or t>=HAN_2SP_DURATION:return
			var idx:=clampi(floori(t*30),0,HAN_2SP_COUNT-1)
			layer.draw_set_transform(point,axis.angle()+.57)
			layer.draw_texture_rect(han_2sp_frames[idx],Rect2(-HAN_2SP_ORIGIN*(HAN_2SP_DISPLAY_SIZE/192.0),Vector2.ONE*HAN_2SP_DISPLAY_SIZE),false)
			layer.draw_set_transform(Vector2.ZERO)
		"saebom_hit":
			if t>=.31:return
			var decay:=1.0-smoothstep(.015,.31,t)
			_soft_light(point,Vector2(68,51),Color("f1a46d"),decay*.64,layer)
			_soft_light(point,Vector2(26,18),Color("fff0c3"),decay*.93,layer)
		"saebom_chain":
			if squad_saebom_frames.is_empty():
				for i in AUTHORED_FRAME_COUNT:
					var frame:=load("res://assets/effects/duel-3sp-rhythm/saebom/192/saebom_chain_support_%02d.png"%i) as Texture2D
					if not frame:squad_saebom_frames.clear();return
					squad_saebom_frames.append(frame)
			for i in SAEBOM_CHEER_LIFTS.size():
				var dt:=t-float(SAEBOM_CHEER_LIFTS[i])
				if dt<0.0 or dt>=.94:continue
				var extent:=Vector2(405,141)
				var shimmer:=smoothstep(.28,.39,dt)*(1.0-smoothstep(.57,.94,dt))*(.255+.075*sin((dt-.27)*TAU*5.45))
				if shimmer>.005:
					var idx:=clampi(floori(lerpf(11.0,17.0,smoothstep(.31,.86,dt))),11,17)
					layer.draw_texture_rect(squad_saebom_frames[idx],Rect2(point-extent*.5,extent),false,Color(1,1,1,shimmer))
				if dt<.65:
					var idx:=clampi(floori(dt*21.0/.65),0,squad_saebom_frames.size()-1)
					layer.draw_texture_rect(squad_saebom_frames[idx],Rect2(point-extent*.5,extent),false)


func _project_preview_ring(view:HybridCharacter,center:Vector2)->PackedVector2Array:
	var path:=PackedVector2Array()
	var cam:=view.camera
	var anchor:=cam.unproject_position(Vector3.ZERO)
	# Project points on XZ independently of the body and animation root.
	# Normalize the apparent X span so ring size remains common across unit models.
	var max_x:=0.0
	for j in 41:
		var angle:=TAU*float(j)/40.0
		var sample:=cam.unproject_position(Vector3(cos(angle)*.64,0.0,sin(angle)*.64))-anchor
		path.append(sample)
		max_x=maxf(max_x,absf(sample.x))
	var fit:=23.0/maxf(1.0,max_x)
	for j in path.size():path[j]=center+path[j]*fit
	return path


func _draw_local_weapon_glow(actor:Actor,in_flight:Vector2,expired:bool,layer:Node2D,world=null)->void:
	var view:=actor.preview
	if actor.key=="saebom":
		var mark:=in_flight
		if mark==Vector2.INF:
			if expired:return
			if is_instance_valid(world):mark=world.project(world.sling_point())
			else:
				var sk:Skeleton3D=view.skeleton
				var idx:=sk.find_bone("sling_stone")
				if idx<0:return
				var point:=sk.to_global(sk.get_bone_global_pose(idx).origin)
				mark=_preview_project(view,point)
		_soft_light(mark,Vector2(24,20),Color("f5a93a"),.42,layer)
		_soft_light(mark,Vector2(9,8),Color("ffe497"),.79,layer)
		return
	var club:MeshInstance3D=view.club
	if not is_instance_valid(club):return
	var box:=club.get_aabb()
	var center:=box.get_center()
	for i in 8:
		var phase:=TAU*float(i)/8.0
		var local:=Vector3(box.end.x-box.size.x*.11,center.y+box.size.y*.43*cos(phase),center.z+box.size.z*.43*sin(phase))
		var p:=club.to_global(local)
		var mark:Vector2=world.project(p) if is_instance_valid(world) else _preview_project(view,p)
		_soft_light(mark,Vector2(13,11),Color("e96c23"),.24,layer)
		_soft_light(mark,Vector2(5,4),Color("ffbc64"),.33,layer)

func _preview_project(view:HybridCharacter,p:Vector3)->Vector2:
	return view.position+(view.display.position+view.camera.unproject_position(p)*view.display.scale)*view.scale


func _sample_local_bom_path(events:Array)->void:
	var p:Dictionary=shared_world.projectile
	if not p.is_empty() and p.motion=="skill":
		if int(p.action)!=bom_path_action:
			bom_path.clear()
			bom_path_action=int(p.action)
			var release:Vector3=shared_world.projectile_releases[-1].position
			bom_path.append(shared_world.project(release))
		var next:=shared_world.project(Vector3(p.position))
		if bom_path.is_empty() or next.distance_squared_to(bom_path[-1])>.30:bom_path.append(next)
		while bom_path.size()>16:bom_path.remove_at(0)
		bom_path_end=visual_clock
	for event in events:
		if int(event.side)==0 and event.motion=="skill" and event.get("kind","")=="projectile":
			bom_path.append(shared_world.project(event.point))
			bom_path_end=visual_clock

func _draw_bom_hit(point:Vector2,dir:Vector2,t:float,layer:Node2D)->void:
	_soft_light(point,Vector2.ONE,Color.WHITE,.001,layer)
	Saebom2Vfx.draw_hit(layer,contact_glow,point,dir,t)

func _draw_bom_trail(points:PackedVector2Array,alpha:float,layer:Node2D)->void:
	if points.is_empty() or alpha<=0:return
	_soft_light(points[-1],Vector2.ONE,Color.WHITE,.001,layer)
	Saebom2Vfx.draw_trail(layer,contact_glow,points,alpha)

func _draw_bom_wings(feet:Vector2,t:float,layer:Node2D)->void:
	_soft_light(feet,Vector2.ONE,Color.WHITE,.001,layer)
	bom_style.draw_wings(layer,contact_glow,feet-Vector2(0,53),t,.34,false)
	bom_style.draw_wings(layer,contact_glow,feet-Vector2(0,53),t,.34,true)

func _draw_bom_ally(feet:Vector2,t:float,layer:Node2D)->void:
	_soft_light(feet,Vector2.ONE,Color.WHITE,.001,layer)
	bom_style.draw_ally(layer,contact_glow,feet,t,.60,false)
	bom_style.draw_ally(layer,contact_glow,feet,t,.60,true)

func _bom_prop_hidden(t:float)->bool:return t>=.10 and t<2.24

func _pose_bom_cast(actor:Actor,t:float)->void:
	bom_style.sync_sling(actor.preview.pivot,_bom_prop_hidden(t))
	if t>=0.0 and t<2.24:bom_style.pose_cast(actor,t)
	elif t>=2.24:
		# Keep the relaxed pose after the authored wings; do not fall back to the old gesture.
		actor.resident_sample("idle",.63+.05*sin(t*2.3))



func _local_floor_heading(cam:Camera3D,screen_dir:Vector2)->float:
	var anchor:=cam.unproject_position(Vector3.ZERO)
	var x:=cam.unproject_position(Vector3.RIGHT)-anchor
	var z:=cam.unproject_position(Vector3.BACK)-anchor
	var det:=x.cross(z)
	if absf(det)<.0001:return atan2(screen_dir.x,screen_dir.y)
	var world:=Vector2(screen_dir.cross(z),x.cross(screen_dir))/det
	return atan2(world.x,world.y)
