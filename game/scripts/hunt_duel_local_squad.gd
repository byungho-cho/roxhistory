extends Node2D

const BasicRope := preload("res://scripts/saebom_rope_sling_basic_presentation.gd")
var basic_rope_glow:=BasicRope.make_glow()
var basic_rope_hit:=Vector2.INF
var basic_rope_hit_at:=-INF

signal parry_spotlight_started
signal uram_ordinary_impact

const Actor = preload("res://scripts/model_test_actor.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const Presenter = preload("res://scripts/duel_motion_presenter.gd")
const HUD = preload("res://scripts/duel_skill_hud.gd")
const UramCounterWave=preload("res://scripts/duel_uram_counter_wave.gd")
const Head = preload("res://scripts/battle_head_hud.gd")
const CastHud=preload("res://scripts/hunt_production_hunt_presentation.gd")
const CastArt=preload("res://scripts/hunt_production_prey_effects.gd")
const HEROES := ["hangyeol","uram","saebom"]
# Empty is the existing lab mode. A production caller may supply the named
# Chapter One encounter before setup without routing to the lab screen.
var story_encounter: Dictionary = {}
var story_outcome := ""
const STORY_JOIN_SECONDS := 2.5
const STORY_CUTIN_SECONDS := 1.42
var story_join_slot := -1
# Already-mapped native ground positions, in Han / Uram / Saebom order.
var story_allied_placement := PackedVector2Array()
var story_entry_clock := 0.0
var story_entry_done := false
var story_first_charge_resolved := false
var story_auto_parry_used := false
var story_taught_parry := false

func _story_teaching_first_charge() -> bool:
	if story_encounter.is_empty() or story_first_charge_resolved or units.size() < 4:
		return false
	return int(story_encounter.number) in [5, 6] and bool(story_encounter.get("first_visit", true)) and units[1].hp > 0 and units[3].hp > 0

func _story_opening_charge(i: int) -> float:
	match int(story_encounter.number):
		2: return 2.0 if i == 0 else 0.0
		3: return 2.0 if i == 1 else 0.0
		4: return 2.0 if i == 2 else 0.0
		5, 6: return 3.0 if i == 1 and bool(story_encounter.get("first_visit", true)) else 0.0
	return 0.0

func configure_story_encounter(row: Dictionary) -> bool:
	if not units.is_empty() or not story_encounter.is_empty():
		return false
	var stage_number := int(row.get("number", 0))
	var party: Array = row.get("party", [])
	var prey: Array = row.get("prey", [])
	if stage_number < 2 or stage_number > 10 or party not in [["han"], ["han","uram"], ["han","uram","saebom"]] or prey.is_empty() or prey.size() > 3:
		return false
	for species: String in prey:
		if species not in ["forest", "stag", "juvenile", "adult"]:
			return false
	var opening: Array = row.get("opening_party",party)
	var joins: Array = row.get("story_join",[])
	if opening.is_empty() or opening != party.slice(0,opening.size()) or joins != party.slice(opening.size()) or joins.size() > 1:
		return false
	if not joins.is_empty(): story_join_slot = opening.size()
	story_encounter = row.duplicate(true)
	return true

func story_allows(i: int, move: String) -> bool:
	if story_encounter.is_empty():
		return true
	var number := int(story_encounter.number)
	if move == "skill":
		if _story_teaching_first_charge():
			return false
		if number == 2 and i == 0 and bool(story_encounter.get("first_visit", true)) and units.size() > 3:
			var target := _target(i)
			# Teach the existing range, don't change actual contact authority.
			return target >= 0 and units[i].feet.distance_to(units[target].feet) <= _gap(i) + 8.0
		return number >= [2, 3, 4][i]
	if move != "chain":
		return false
	if number == 5:
		return i == 1 and _squad_guard_candidate() >= 0
	return number >= 6

func _story_enemy_can_use_skill(unit: Dictionary) -> bool:
	if story_encounter.is_empty():
		return true
	return (story_encounter.enemy_skill == "juvenile_charge" and unit.id == "juvenile") or (story_encounter.enemy_skill == "adult_successive_charge" and unit.id == "adult")
const HERO_SLOTS := [0,5,3]
const DEER_SLOTS := [4,2,3]
const MAX_HP := 100
const STEP := 1.0/120.0
const SaebomMelee=preload("res://scripts/duel_shared_world.gd")
const Knife=preload("res://scripts/duel_saebom_stone_knife.gd")
var knife_events:Array[Dictionary]=[]
const HAN_3SP_SPLASH_FRACTION:=.60
const NEAR_SAE_2SP=preload("res://assets/ui/saebom-melee/stone-knife-2sp.png")
var local_melee_polish:=false
var saebom_distance_drill:=""
var ranged_alignment_contact:=Callable()
var units:Array[Dictionary]=[]
var huds:Array=[]
var missiles:Array[Dictionary]=[]
var hits:Array[Dictionary]=[]
var glints:Array[Dictionary]=[]
var gong_draw:Callable
var authored_draw:Callable
var ring_project:Callable
var weapon_draw:Callable
var bom_hit_draw:Callable
var bom_trail_draw:Callable
const RallyCloud := preload("res://scripts/saebom_rally_cloud.gd")
var bom_cloud_origin:=Vector2.INF
var bom_cloud_at:=-INF
const RallySilver := preload("res://scripts/saebom_rally_silver_vfx.gd")
var rally_silver_back:Node2D
var rally_silver_cast_at:=-INF
var bom_wings_draw:Callable
var bom_ally_draw:Callable
var bom_pose:Callable
var group_bom_hits:Array[Dictionary]=[]
var group_bom_ally_events:Array[Dictionary]=[]
var heavy_visual_length:=1.15
var silver_draw:Callable
var silver_impact:Callable
var silver_hits:Array[Dictionary]=[]
var deer_wakes:Array[Array]=[[],[],[]]
var authored_events:Array[Dictionary]=[]
var heavy_draw:Callable
var heavy_windup:Callable
var heavy_events:Array[Dictionary]=[]
var gong_events:Array[Dictionary]=[]
var last_gong_cast:=-INF
var elapsed:=0.0
var acc:=0.0
var ended:=false
const URAM_GUARD_EARLIEST:=.62
const URAM_GUARD_LATEST:=.07
const URAM_BORDER_LEAD:=.50
const URAM_BORDER_RATE:=3.0
var uram_ground_draw:=Callable()
var uram_ground_sound:=Callable()
var uram_ground_events:Array[Dictionary]=[]
var uram_ordinary_wave:Dictionary={}
const UramCombined := preload("res://scripts/hunt_uram_3sp_combined.gd")
var uram_combined := UramCombined.new()
var uram_short_fans:Array[Dictionary]=[]
const URAM_SPLASH_DAMAGE:=9
const URAM_STUN_SECONDS:=1.15
var uram_wave_pop:Dictionary={}
var uram_ground_layer:Node2D
var input_paused:=false
var hud_parent:Control
const HanGround = preload("res://scripts/hunt_han_3sp_ground.gd")
var han_ground := HanGround.new()
var han_ground_layer: Node2D
var han_ground_events: Array[Dictionary] = []
var paint:Node2D
var bars_paint:Node2D
var cast_notice_paint:Node2D
var damage_numbers := preload("res://scripts/hunt_damage_numbers.gd").new()
var cast_notice_style:RefCounted
var cast_notices:Dictionary={}
var parry_front:Node2D
var parry_ground:Node2D
var parry_dust:Callable
var parry_light:Callable
var parry_stars:Callable
var spotlight_clock:=-1.0
var spotlight_duration:=2.4
var spotlight_strength:=.228
var spotlight_attacker:=-1
var spotlight_defender:=-1
var spotlight_floor:=Vector2.ZERO
var spotlight_contact:=Vector2.ZERO
var spotlight_forward:=Vector2.RIGHT
var combo_opener:=-1
var squad_stuns:Dictionary={}

var aim:=Presenter.new()
var spear_forward_bias:Dictionary={}
var launch_dust_draw:Callable
var launch_dust_layer:Node2D
var launch_dust_events:Array[Dictionary]=[]

func setup(dust_draw:Callable=Callable(),gong:Callable=Callable(), heavy:Callable=Callable(), windup:Callable=Callable(),authored:Callable=Callable(),silver:Callable=Callable(),impact:Callable=Callable(),ring_projection:Callable=Callable(),weapon:Callable=Callable(),heavy_seconds:=1.15,bom_hit:Callable=Callable(),bom_trail:Callable=Callable(),bom_wings:Callable=Callable(),bom_ally:Callable=Callable(),bom_pose_hook:Callable=Callable(),melee_polish:=false)->void:
	local_melee_polish=melee_polish
	uram_combined.prepare() # The squad includes Uram; retain textures for this encounter.
	bom_hit_draw=bom_hit
	bom_trail_draw=bom_trail
	bom_wings_draw=bom_wings
	bom_ally_draw=bom_ally
	bom_pose=bom_pose_hook
	weapon_draw=weapon
	heavy_visual_length=heavy_seconds
	ring_project=ring_projection
	silver_draw=silver
	silver_impact=impact
	authored_draw=authored
	heavy_draw=heavy
	heavy_windup=windup
	gong_draw=gong
	launch_dust_draw=dust_draw
	if launch_dust_draw.is_valid():
		launch_dust_layer=Node2D.new()
		add_child(launch_dust_layer)
		launch_dust_layer.draw.connect(_draw_launch_dust)
	han_ground.prepare()
	han_ground_layer = Node2D.new()
	add_child(han_ground_layer)
	han_ground_layer.draw.connect(_draw_han_ground)
	if local_melee_polish:RallySilver.prepare()
	rally_silver_back=Node2D.new()
	add_child(rally_silver_back)
	rally_silver_back.draw.connect(_paint_rally_silver_wings)
	paint=Node2D.new();paint.z_index=600;add_child(paint)
	paint.draw.connect(_paint)
	bars_paint=Node2D.new();bars_paint.z_index=601;add_child(bars_paint)
	bars_paint.draw.connect(_paint_bars)
	damage_numbers.z_index = 604
	add_child(damage_numbers)
	if local_melee_polish:
		cast_notice_style=CastHud.new(CastArt.new())
		cast_notice_paint=Node2D.new()
		cast_notice_paint.name="SquadTransientCastNotices"
		cast_notice_paint.z_index=603
		add_child(cast_notice_paint)
		cast_notice_paint.draw.connect(_paint_cast_notices)
	for i in 6:
		var ally:=i<3
		if not story_encounter.is_empty() and not ally and i - 3 >= story_encounter.prey.size():
			break
		var id:String=HEROES[i] if ally else "forest" if story_encounter.is_empty() else story_encounter.prey[i - 3]
		var dormant: bool = not story_encounter.is_empty() and ally and i >= story_encounter.get("opening_party",story_encounter.party).size()
		var home:Vector2
		if ally:
			home=Hunt.HUNTER_BATTLE_CENTER+(Hunt.ALLY_CELLS[HERO_SLOTS[i]]-Hunt.FORMATION_CENTER)*.62
			if not story_encounter.is_empty() and story_allied_placement.size()==3:
				home=story_allied_placement[i]
		else:home=Hunt.DEER_SLOT+Vector2(111,-9)+(Hunt.ENEMY_CELLS[DEER_SLOTS[i-3]]-Hunt.ENEMY_CELLS[4])*.86
		var actor:=Actor.new();actor.create(self,id);actor.configure(true)
		actor.preview.scale=Vector2.ONE*[.76588,1.08,.90,.82588,.82588,.82588][i]
		var ring:=Line2D.new();ring.width=1.65;ring.antialiased=true;ring.default_color=Head.duel_team_color(ally)
		for j in 41:ring.add_point(Vector2.from_angle(TAU*float(j)/40)*Vector2(22,8))
		add_child(ring)
		var u:Dictionary={"actor":actor,"id":id,"home":home,"feet":home,"hp":MAX_HP,"sp":1.0,"move":"idle","age":0.0,"next":.52+float(i%3)*.17,"contact":-1.0,"victim":-1,"ring":ring,"rally":0.0}
		if not story_encounter.is_empty():
			u.story_dormant = dormant
			# Keep the previous ordinary encounter's total HP budget while
			# splitting 1-2's two same-tier deer into independent targets.
			u.max_hp = [34,33,33][i] if ally else (MAX_HP / 2 if int(story_encounter.number) == 2 else MAX_HP)
			u.hp = 0 if dormant else u.max_hp
			u.sp = _story_opening_charge(i) if ally and not dormant else 0.0
			if i == 2: u.bom_close = false
		units.append(u)
		_play(u,"idle")
	_calibrate_han()
	hud_parent=Control.new();hud_parent.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hud_parent)
	for i in 3:
		var hud:=HUD.new();hud.position=Vector2(359+88*i,437);hud_parent.add_child(hud)
		hud.enable_duel_ready_feedback();hud.reset(HEROES[i])
		if local_melee_polish:
			hud.enable_portrait_damage_feedback()
			hud.place_local_combat_hud(480.+128.*float(i-1))
		hud.requested.connect(_request.bind(i))
		if not story_encounter.is_empty():
			hud.visible = not bool(units[i].get("story_dormant", false))
			var visible_count: int = story_encounter.get("opening_party",story_encounter.party).size()
			if story_encounter.party.size()==1 and i==0:
				hud.position.x=447.
			if story_join_slot>=0:
				hud.place_local_combat_hud(480.+128.*(float(i)-float(visible_count-1)*.5))
		huds.append(hud)
	_draw_pose(0.0)

func configure_spotlight(dust:Callable,flash:Callable,stars:Callable,duration:float,strength:float)->void:
	parry_dust=dust;parry_light=flash;parry_stars=stars
	spotlight_duration=duration;spotlight_strength=strength
	parry_ground=Node2D.new();add_child(parry_ground);move_child(parry_ground,0)
	parry_ground.draw.connect(_paint_parry_ground)
	parry_front=Node2D.new();parry_front.z_index=602;add_child(parry_front)
	parry_front.draw.connect(_paint_parry_front)

func configure_uram_ground(draw_wave:Callable,thump:Callable=Callable())->void:
	uram_ground_draw=draw_wave
	uram_ground_sound=thump
	uram_ground_layer=Node2D.new()
	add_child(uram_ground_layer);move_child(uram_ground_layer,0)
	uram_ground_layer.draw.connect(_paint_uram_ground)

func _paint_uram_ground()->void:
	for fan in uram_short_fans:
		if bool(fan.get("combined", false)):
			uram_combined.draw(uram_ground_layer,fan.from,fan.axis,elapsed-float(fan.at))
		else:UramCounterWave.draw_fan(uram_ground_layer,fan.from,fan.ground,fan.axis,fan.reach,(elapsed-float(fan.at))/float(fan.span),false,true)
	for event in uram_ground_events:
		uram_ground_draw.call(event.origin,event.end,elapsed-float(event.at),uram_ground_layer)

func _pose_uram_ground(u:Dictionary,actor)->void:
	var view:HybridCharacter=actor.preview
	if not is_instance_valid(view.club):return
	var target:Vector2=units[u.victim].feet
	var heading:=_ground_heading(view.camera,u.feet.direction_to(target))
	var axis:=Vector3(sin(heading),0.,cos(heading))
	var clock:float=u.age
	var sk:Skeleton3D=view.skeleton
	var visible_at:=SaebomMelee.uram_floor_visible_age(clock,float(u.get("floor_impact_age",-1.)),actor.duration)
	if absf(visible_at-clock)>.00001:actor.sample(visible_at,false)
	SaebomMelee.weight_uram_floor_pose(view,visible_at)
	var pins:Dictionary=u.get("floor_pins",{})
	var inverse:=sk.global_transform.affine_inverse()
	for joint in pins:
		sk.set_bone_global_pose(joint,inverse*pins[joint])
		sk.force_update_all_bone_transforms()
	view.update_equipment()
	var ground_y:float=u.get("floor_y",view.pivot.global_position.y)
	SaebomMelee.aim_uram_floor_club(view,axis,visible_at,ground_y)
	var tip:Vector3=view.club.to_global(Vector3(view.club.get_aabb().end.x*.85,0.,0.))
	if clock<SaebomMelee.URAM_FLOOR_CONTACT or float(u.get("floor_cast_at",-1.))>=0.:return
	u.floor_cast_at=elapsed
	u.floor_impact_age=clock
	if uram_ground_sound.is_valid():uram_ground_sound.call()
	tip=SaebomMelee.uram_ground_screen_mark(view.camera,tip,ground_y)
	var floor_mark:=view.position+(view.display.position+view.camera.unproject_position(tip)*view.display.scale)*view.scale
	# Preserve the legacy single target/range rule in _resolve. Draw direction
	# from the grounded club only, not a second impact flash at the receiver.
	uram_ground_events.append({"origin":floor_mark,"end":floor_mark+(target-floor_mark).limit_length(77.0),"at":elapsed})

func spotlight_dim()->float:
	if spotlight_clock<0.:return 0.
	return spotlight_strength*smoothstep(0.,.22,spotlight_clock)*(1.-smoothstep(1.57,spotlight_duration,spotlight_clock))

func _spotlight_parry(attacker:int,defender:int,contact_point:Vector2)->void:
	if not parry_dust.is_valid() or spotlight_clock>=0.:return
	spotlight_attacker=attacker;spotlight_defender=defender
	var incoming:Vector2=units[attacker].feet
	var held:Vector2=units[defender].feet
	spotlight_floor=held.lerp(incoming,.35)
	spotlight_contact=contact_point
	spotlight_forward=held.direction_to(incoming)
	spotlight_clock=0.
	combo_opener=attacker
	parry_spotlight_started.emit()

func _paint_parry_ground()->void:
	if spotlight_clock<0.:return
	parry_dust.call(spotlight_floor,spotlight_forward,spotlight_clock,parry_ground)

func _paint_parry_front()->void:
	if spotlight_clock>=0.:
		parry_light.call(spotlight_contact,spotlight_forward,spotlight_clock,parry_front)
		var attacker:=units[spotlight_attacker]
		if int(attacker.hp)>0 and squad_stuns.has(spotlight_attacker):
			parry_stars.call(_deer_tip(attacker)-Vector2(6.,25.),clampf(spotlight_clock/2.25,0.,1.),parry_front)
	for index in squad_stuns:
		if index!=spotlight_attacker and int(units[index].hp)>0:
			parry_stars.call(_deer_tip(units[index])-Vector2(6.,25.),clampf((elapsed-float(squad_stuns[index]))/1.15,0.,1.),parry_front)

func configure_saebom_distance_drill(mode:String)->void:
	# Preset only: all points, hits, death and target movement still use the squad rules.
	damage_numbers.clear()
	saebom_distance_drill=mode
	units[2].bom_close=false
	units[2].saebom_melee_pending=false
	units[2].saebom_switch_hit_until=-INF
	var far:=mode=="far"
	var points:=[Vector2.ZERO,Vector2(526,260),Vector2(452,301) if far else Vector2(486,272),Vector2(576,231) if far else Vector2(529,251),Vector2.ZERO,Vector2.ZERO]
	for i in units.size():
		var u:=units[i]
		var included:=i in [2,3] or (far and i==1)
		u.home=points[i];u.feet=points[i]
		u.hp=(roundi(MAX_HP*.5) if i==1 else MAX_HP) if included else 0
		u.actor.preview.visible=included
		u.actor.death_effect.hide()
		_play(u,"idle")
		if i<3:
			huds[i].visible=included
			huds[i].clear_portrait_damage_feedback()
	_update_saebom_range()
	_draw_pose(0.)

func place_bottom_hud(shift:float)->void:
	if not local_melee_polish:return
	for hud in huds:hud.position.y=406.+shift

func _update_saebom_range()->void:
	if not local_melee_polish or units[2].hp<=0:return
	var target:=_target(2)
	if target<0:return
	var u:=units[2]
	_sample_saebom_mode(u,target)
	if u.move in ["attack","skill","chain"]:
		huds[2].set_saebom_distance_icon(bool(u.get("bom_shove",false)) if u.move=="attack" else bool(u.get("bom_near_skill",false)) if u.move=="skill" else bool(u.get("bom_close",false)),NEAR_SAE_2SP)
		return
	huds[2].set_saebom_distance_icon(bool(u.get("bom_close",false)),NEAR_SAE_2SP)

const SAEBOM_MELEE_ENTER := 65.0

func _remember_saebom_proximity(u:Dictionary,target:int)->void:
	if not bool(u.get("saebom_melee_pending",false)) and target>=3 and target<units.size():
		u.saebom_melee_pending=(u.feet as Vector2).distance_to(units[target].feet)<=SAEBOM_MELEE_ENTER

func _sample_saebom_mode(u:Dictionary,target:int)->void:
	if bool(u.get("bom_close",false)) or u.move=="death":return
	_remember_saebom_proximity(u,target)
	if not bool(u.get("saebom_melee_pending",false)) or float(u.get("saebom_switch_hit_until",-INF))>elapsed or u.move not in ["idle","walk","run"]:return
	for stone in missiles:
		if int(stone.from)==2:return # A released sling shot may outlast its caster pose.
	for j in range(3,units.size()):
		var foe:=units[j]
		if foe.hp>0 and foe.victim==2 and foe.move in ["attack","skill"] and foe.contact>=0.:return
	u.bom_close=true

func set_input_paused(value:bool)->void:
	input_paused=value
	_draw_pose(0.0)

func grant_sp()->void:
	for i in 3:
		if units[i].hp>0:units[i].sp=3.0
	_draw_pose(0.0)

func _play(u:Dictionary,key:String)->void:
	u.actor.play(key);u.move=key;u.age=0.0;u.contact=-1.0
	if local_melee_polish and u.id=="saebom" and key=="chain":rally_silver_cast_at=elapsed
	if u.id=="saebom" and key not in ["attack","skill"]:
		u.bom_shove=false;u.bom_near_skill=false

func _free_to_cast(i:int)->bool:
	return not input_paused and not story_entry_active() and not ended and units[i].hp>0 and units[i].move in ["idle","run","walk","attack","hit"]

func _request(key:String,i:int)->void:
	var cost:=2 if key=="skill" else 3
	if not story_allows(i, key) or not _free_to_cast(i) or units[i].sp+0.000001<float(cost):return
	var target:=_target(i)
	if target<0:return
	units[i].sp-=float(cost)
	if is_instance_valid(cast_notice_paint):
		if i==2 and key=="chain":
			cast_notices.erase(i) # The distinct five-second support badge is drawn by the lab.
		else:
			var hud=huds[i]
			var skill_icon:Texture2D=hud.chain_art.texture if key=="chain" else hud.badge_art.texture
			cast_notices[i]={"at":elapsed,"linked":key=="chain","icon":skill_icon}
		cast_notice_paint.queue_redraw()
	if local_melee_polish and i==1 and key=="chain":
		var guard_index:=_squad_guard_candidate()
		_begin(i,"chain" if guard_index>=0 else "counter",target)
		units[i].guard_source=guard_index
	else:_begin(i,key,target)
	if i==2 and key=="skill":
		_update_saebom_range()
		if cast_notices.has(i):cast_notices[i].icon=huds[2].badge_art.texture
	_draw_pose(0.0)

func _squad_guard_candidate(lead:=0.0)->int:
	var id:=-1
	var delay:=URAM_GUARD_EARLIEST+lead
	for i in range(3,units.size()):
		var u:=units[i]
		var remaining:=float(u.contact)-float(u.age)
		if u.hp>0 and u.victim==1 and u.move in ["skill","attack"] and remaining>URAM_GUARD_LATEST and remaining<delay:
			delay=remaining
			id=i
	return id

func _target(i:int)->int:
	if not saebom_distance_drill.is_empty():
		if i<3:return 3 if units[3].hp>0 else -1
		if units[1].hp>0:return 1
		return 2 if units[2].hp>0 else -1
	if i>=3:
		if i == 3 and _story_teaching_first_charge():
			return 1
		return _local_enemy_target(i)
	if i == 1 and _story_teaching_first_charge():
		return 3
	# Allied targeting keeps its original opening lane and nearest fallback.
	var initial:=[3,4,5]
	if initial[i] < units.size() and units[initial[i]].hp > 0: return initial[i]
	var best:=-1
	var nearest:=INF
	for j in range(3,units.size()):
		if units[j].hp<=0:continue
		var d:float=units[i].feet.distance_squared_to(units[j].feet)
		if d<nearest:nearest=d;best=j
	return best

func _begin(i:int,key:String,target:int)->void:
	var u:=units[i]
	if i==2 and local_melee_polish and target>=0:_sample_saebom_mode(u,target)
	if i==1 and key=="skill" and uram_ground_draw.is_valid():
		var view:HybridCharacter=u.actor.preview
		var sk:Skeleton3D=view.skeleton
		var pins:Dictionary={}
		for name in ["foot.L","foot.R"]:
			var foot:=sk.find_bone(name)
			if foot<0:continue
			var knee:=sk.get_bone_parent(foot)
			var hip:=sk.get_bone_parent(knee) if knee>=0 else -1
			for joint in [hip,knee,foot]:
				if joint>=0:pins[joint]=sk.global_transform*sk.get_bone_global_pose(joint)
		u["floor_pins"]=pins
		u["floor_y"]=view.pivot.global_position.y
	_play(u,key)
	u.victim=target
	var dur:float=u.actor.duration
	u.contact=dur*.54
	if local_melee_polish and i==1:
		if key=="chain":
			u.guarded=false
			u.contact=minf(URAM_GUARD_EARLIEST,dur)
		elif key=="counter":u.contact=minf(.46,dur)
	if i==1 and key=="skill" and uram_ground_draw.is_valid():
		u["floor_cast_at"]=-1.0;u["floor_impact_age"]=-1.0
	if i>=3 and key=="skill":
		u.contact=float(u.actor.preview.length("req046_skill_anticipation"))+.14
	if i==2 and key!="chain":u.contact=dur*.61
	if i==2 and local_melee_polish and target>=0:
		var gap:float=u.feet.distance_to(units[target].feet)
		u.bom_shove=key=="attack" and u.bom_close
		u.bom_hop=clampf(82.-gap,0.,24.) if key=="skill" and u.bom_close else 0.
		u.bom_near_skill=key=="skill" and u.bom_close
		u.bom_strike=0
		if u.bom_near_skill:
			u.bom_hop=0.
			u.contact=Knife.contacts[0]
			dur=Knife.DURATION
		u.bom_origin=u.feet
		var away:Vector2=u.feet-units[target].feet
		u.bom_dir=away.normalized()
		if u.bom_shove:
			u.contact=dur*.48
			u["close_basic_edge"]=Vector2.INF
	if i==2:
		u.basic_rope_windup=key=="attack" and not bool(u.get("bom_shove",false))
		if key in ["skill","chain"]:u.basic_rope_empty=false
	u.next=elapsed+maxf(dur+.28,1.26)

func _gap(i:int)->float:
	return (59.0 if bool(units[2].get("bom_close",false)) else 124.0) if i==2 else 59.0 if i==0 else 49.0

const AGGRO_ROLE_RADIUS := 98.0 # Twice the existing 49 px enemy basic standoff.
const AGGRO_MIN_DISTANCE := .01
const AGGRO_ROLE_WEIGHTS := {"uram":1.2,"hangyeol":1.1,"saebom":1.0}
const AGGRO_SLOT_GAP := 48.0

func _within_uram_aggro(i:int)->bool:
	return units[1].hp>0 and (units[i].feet as Vector2).distance_to(units[1].feet)<=AGGRO_ROLE_RADIUS

func _local_enemy_target(i:int)->int:
	var feet:Vector2=units[i].feet
	var best:=-1
	var highest:=-INF
	for ally in [1,0,2]:
		var candidate:=units[ally]
		if candidate.hp<=0:continue
		var distance:=feet.distance_to(candidate.feet)
		var weight:=float(AGGRO_ROLE_WEIGHTS.get(candidate.id,1.)) if distance<=AGGRO_ROLE_RADIUS else 1.
		var score:=weight/maxf(AGGRO_MIN_DISTANCE,distance)
		if score>highest:
			best=ally
			highest=score
	return best

const AGGRO_CLEARANCE := 34.0

func _enemy_slot(i:int,target:int)->Vector2:
	# Hold three fixed lanes on the enemy-facing side. The upper and lower
	# spawn lanes approach each flank without crossing the middle route.
	var angle:float=[.96,0.,-.96][i-3]
	return (units[target].feet as Vector2)+Vector2.RIGHT.rotated(angle)*AGGRO_SLOT_GAP

func _enemy_slot_ready(i:int,target:int)->bool:
	var feet:Vector2=units[i].feet
	return feet.distance_to(units[target].feet)<=_gap(i)+2. and feet.distance_to(_enemy_slot(i,target))<=12.

func _approach_enemy_slot(i:int,target:int,dt:float)->void:
	var u:=units[i]
	var feet:Vector2=u.feet
	var delta:=_enemy_slot(i,target)-feet
	var step:=minf(104.*dt,delta.length())
	var forward:=delta.normalized()
	# Take the direct step if it fits; if blocked, skirt the blocker. Prefer
	# the flank's outside so two deer do not both choose the middle gap.
	var outside:=1. if i==3 else -1.
	for angle in [0.,.55*outside,-.55*outside,1.05*outside,-1.05*outside,1.55*outside,-1.55*outside,1.9*outside,-1.9*outside]:
		var candidate:=feet+forward.rotated(angle)*step
		var clear:=true
		for j in units.size():
			if j==i or units[j].hp<=0:continue
			var other:Vector2=units[j].feet
			# If an allied step put the bodies close, permit only separation.
			var minimum:=minf(AGGRO_CLEARANCE,feet.distance_to(other))
			if candidate.distance_to(other)<minimum-.001:
				clear=false
				break
		if clear:
			u.feet=candidate
			return

func _approach(i:int,target:Vector2,dt:float)->void:
	var u:=units[i]
	var delta:Vector2=target-u.feet
	var intended:Vector2=u.feet+delta.normalized()*minf((98.0 if i<3 else 104.0)*dt,maxf(0.0,delta.length()-_gap(i)))
	# Do not let six ground anchors walk through one another.
	for j in units.size():
		if j==i or units[j].hp<=0:continue
		var diff:Vector2=intended-units[j].feet
		if diff.length_squared()<34.0*34.0 and diff.length_squared()>.0001:
			intended=units[j].feet+diff.normalized()*34.0
	u.feet=intended

func tick(delta:float,paused:bool,real_delta:float=-1.0)->void:
	if paused:return
	if _tick_story_entry(delta if real_delta < 0.0 else real_delta):return
	acc+=minf(delta,.10)
	if spotlight_clock>=0.:
		spotlight_clock+=maxf(0.,delta)
		if spotlight_clock>=spotlight_duration:
			spotlight_clock=-1.;spotlight_attacker=-1;spotlight_defender=-1;combo_opener=-1
	while acc>=STEP:
		acc-=STEP;_step(STEP)
	_draw_pose(delta)

func story_entry_active()->bool:
	return story_join_slot>=0 and not story_entry_done and not ended and story_entry_clock>=STORY_JOIN_SECONDS

func story_entry_fraction()->float:
	return clampf((story_entry_clock-STORY_JOIN_SECONDS)/STORY_CUTIN_SECONDS,0.0,1.0)

func _story_position_clear(spot:Vector2)->bool:
	for unit in units:
		if unit.hp>0 and spot.distance_squared_to(unit.feet)<36.0*36.0:return false
	return true

func _story_assigned_join_spot(preferred:Vector2)->Vector2:
	if _story_position_clear(preferred):return preferred
	# Preserve the assigned lane unless a moving active unit has occupied it.
	# Search successively wider local rings, retaining preset placement otherwise.
	for radius:float in [38.,52.,68.,88.]:
		for i in 16:
			var spot:=preferred+Vector2.from_angle(TAU*float(i)/16.+PI)*radius
			if Rect2(40.,105.,880.,298.).has_point(spot) and _story_position_clear(spot):return spot
	return _story_entry_spot()

func _story_entry_spot()->Vector2:
	var han:Vector2=units[0].feet
	var offsets: Array = [Vector2(-26,31),Vector2(-39,-15),Vector2(-49,20),Vector2(-65,-16)] if story_join_slot==1 else [Vector2(-51,-19),Vector2(-52,28),Vector2(-75,-18),Vector2(-89,14)]
	var best:Vector2=han+offsets[0]
	var best_clearance:=-1.0
	for offset:Vector2 in offsets:
		var spot:=han+offset
		spot.x=clampf(spot.x,40.,920.)
		spot.y=clampf(spot.y,105.,403.)
		var clearance:=INF
		for u in units:
			if u.hp>0: clearance=minf(clearance,spot.distance_to(u.feet))
		if clearance>=36.0:return spot
		if clearance>best_clearance:
			best_clearance=clearance
			best=spot
	return best

func _tick_story_entry(real_delta:float)->bool:
	if story_join_slot<0 or story_entry_done or ended or not story_outcome.is_empty():return false
	story_entry_clock=minf(story_entry_clock+maxf(0.0,real_delta),STORY_JOIN_SECONDS+STORY_CUTIN_SECONDS)
	return story_entry_active()

func dismiss_story_entry()->bool:
	if not story_entry_active() or not story_outcome.is_empty():return false
	var u:=units[story_join_slot]
	u.feet=_story_assigned_join_spot(u.home) if story_allied_placement.size()==3 else _story_entry_spot()
	story_entry_done=true
	u.story_dormant=false
	u.hp=u.max_hp
	u.sp=_story_opening_charge(story_join_slot)
	u.next=elapsed+.10
	_play(u,"idle")
	for i in story_encounter.party.size():
		huds[i].place_local_combat_hud(480.+128.*(float(i)-float(story_encounter.party.size()-1)*.5))
	huds[story_join_slot].show()
	u.actor.preview.show()
	_draw_pose(0.0)
	return true

func _step(dt:float)->void:
	if not story_outcome.is_empty():return
	elapsed+=dt
	_update_saebom_range()
	if _story_teaching_first_charge() and int(story_encounter.number) == 6 and not story_auto_parry_used and _squad_guard_candidate() == 3:
		var before: float = units[1].sp
		_request("chain", 1)
		story_auto_parry_used = units[1].sp < before
	for i in units.size():
		var u:=units[i];u.age+=dt
		if ended or u.hp<=0:continue
		if float(u.get("uram_splash_stun_until",0.))>elapsed:continue
		if i<3:u.sp=minf(3.0,u.sp+dt/3.1)
		var target:=_target(i)
		if target<0:continue
		var ours:Vector2=u.feet
		var theirs:Vector2=units[target].feet
		if u.move in ["attack","skill","chain","counter"]:
			if i==2 and u.move=="skill" and float(u.get("bom_hop",0.))>0.:
				var hop:=float(u.bom_hop)*SaebomMelee.saebom_hop_envelope(float(u.age)/maxf(.01,float(u.actor.duration)))
				var candidate:Vector2=u.bom_origin+u.bom_dir*hop
				var open:=true
				for k in units.size():
					if k!=i and units[k].hp>0 and candidate.distance_to(units[k].feet)<30.0 and candidate.distance_to(units[k].feet)<u.feet.distance_to(units[k].feet):open=false
				if open:u.feet=candidate
			if launch_dust_draw.is_valid() and i>=3 and u.id=="forest" and u.move=="skill" and u.contact>=0.0:
				var launch:float=u.actor.preview.length("req046_skill_anticipation")
				if launch>0 and float(u.age)-dt<launch and float(u.age)>=launch:
					launch_dust_events.append({"at":elapsed,"origin":u.feet,"unit":i})
			if u.contact>=0 and u.age>=u.contact:
				u.contact=-1.0
				_resolve(i)
			var extra:=SaebomMelee.URAM_FLOOR_HOLD if i==1 and u.move=="skill" and float(u.get("floor_cast_at",-1.))>=0. else 0.
			if u.age>=(Knife.DURATION if i==2 and u.move=="skill" and bool(u.get("bom_near_skill",false)) else float(u.actor.duration))+extra and not (i==1 and u.move=="counter" and not uram_ordinary_wave.is_empty()):_play(u,"idle")
			continue
		if u.move=="hit":
			if u.age>=u.actor.duration:_play(u,"idle")
			continue
		var ordinary_enemy:=i>=3 and saebom_distance_drill.is_empty()
		var formation_aggro:=ordinary_enemy and target==1 and _within_uram_aggro(i)
		if (not _enemy_slot_ready(i,target) if formation_aggro else ours.distance_to(theirs)>_gap(i)+2.0):
			if u.move!="run":_play(u,"run")
			if formation_aggro:_approach_enemy_slot(i,target,dt)
			else:_approach(i,theirs,dt)
		elif elapsed>=u.next:
			var teaching := _story_teaching_first_charge()
			if teaching and i < 3:
				if u.move != "idle": _play(u, "idle")
				continue
			var first_charge := teaching and i == 3
			_begin(i,"skill" if first_charge or (i>=3 and _story_enemy_can_use_skill(u) and int(elapsed*1.45+i)%4==0) else "attack",target)
		elif u.move!="idle":_play(u,"idle")
	_update_projectiles(dt)
	while not knife_events.is_empty() and elapsed-float(knife_events[0].at)>Knife.ECHO_SECONDS:knife_events.pop_front()
	_advance_uram_ordinary_wave()
	_advance_uram_short_fans()
	for index in squad_stuns.keys():
		if elapsed-float(squad_stuns[index])>=1.15:squad_stuns.erase(index)
	for k in range(launch_dust_events.size()-1,-1,-1):
		if elapsed-float(launch_dust_events[k].at)>=2.5:launch_dust_events.remove_at(k)
	for k in range(group_bom_ally_events.size()-1,-1,-1):
		if elapsed-float(group_bom_ally_events[k].at)>=2.24:group_bom_ally_events.remove_at(k)
	for k in range(group_bom_hits.size()-1,-1,-1):
		if elapsed-float(group_bom_hits[k].at)>=1.24:group_bom_hits.remove_at(k)
	for k in range(silver_hits.size()-1,-1,-1):
		if elapsed-float(silver_hits[k].at)>=.67:silver_hits.remove_at(k)
	for k in range(han_ground_events.size()-1,-1,-1):
		if elapsed - float(han_ground_events[k].at) >= HanGround.DURATION:
			han_ground_events.remove_at(k)
	for k in range(authored_events.size()-1,-1,-1):
		if elapsed-float(authored_events[k].at)>=1.20:authored_events.remove_at(k)
	for k in range(uram_ground_events.size()-1,-1,-1):
		if elapsed-float(uram_ground_events[k].at)>=1.04:uram_ground_events.remove_at(k)
	for k in range(heavy_events.size()-1,-1,-1):
		if elapsed-float(heavy_events[k].at)>=heavy_visual_length:heavy_events.remove_at(k)
	for k in range(gong_events.size()-1,-1,-1):
		if elapsed-float(gong_events[k].at)>=1.6:gong_events.remove_at(k)
	for j in range(glints.size()-1,-1,-1):
		if elapsed-float(glints[j].at)>.45:glints.remove_at(j)
	var left:=_target(3)
	var right:=_target(0)
	ended=left<0 or right<0
	if not story_encounter.is_empty():
		if left < 0 or elapsed >= float(story_encounter.seconds):
			story_outcome = "loss"
			ended = true
		elif right < 0:
			story_outcome = "win"

func _resolve(i:int)->void:
	var u:=units[i];var j:int=u.victim
	if i == 3 and u.move == "skill" and _story_teaching_first_charge():
		story_first_charge_resolved = true
	if i==2 and u.move=="chain":
		if int(u.hp)<=0 or _target(i)<0:return
		for k in 3:
			if units[k].hp>0 and (not local_melee_polish or units[k].feet.distance_to(u.feet)<=190.0):
				units[k].rally=elapsed+(5.0 if local_melee_polish else 4.0)
				if not local_melee_polish and k!=i and bom_ally_draw.is_valid() and units[k].feet.distance_to(u.feet)<=190.0:
					group_bom_ally_events.append({"at":elapsed,"unit":k})
		if not authored_draw.is_valid():glints.append({"at":elapsed,"point":u.feet-Vector2(0,20),"tint":Color("ffc971")})
		hits.append({"from":i,"target":-1,"type":"rally","result":"support"})
		bom_cloud_origin=u.feet;bom_cloud_at=elapsed
		for target_index in range(3,units.size()):
			var target:=units[target_index]
			if int(target.hp)<=0:continue
			var wind:=RallyCloud.accrue(int(target.get("bom_cloud_fifths",0)),RallyCloud.SQUAD_BASE)
			target.bom_cloud_fifths=wind.y
			_subtract_hp_and_show(target_index,wind.x)
			hits.append({"from":i,"target":target_index,"type":"rally_cloud","result":"hit","hp":target.hp})
			if int(target.hp)==0:_play(target,"death")
		return
	# The ground strike reaches all living enemies on the existing contact beat.
	if i == 0 and u.move == "chain":
		var amount := 38
		if u.rally > elapsed:
			amount = roundi(amount * (1.20 if local_melee_polish else 1.25))
		var primary_alive := j >= 3 and j < units.size() and int(units[j].hp) > 0
		if primary_alive:
			_damage(0, j, amount, "chain")
		else:
			# A defeated target cannot redirect the full hit to another lane.
			var floor_point: Vector2 = units[j].feet if j >= 3 and j < units.size() else u.feet
			han_ground_events.append({"at":elapsed, "floor":floor_point})
		var splash := roundi(amount * HAN_3SP_SPLASH_FRACTION)
		for enemy in range(3, units.size()):
			if enemy != j and int(units[enemy].hp) > 0:
				_damage(0, enemy, splash, "han_chain_splash")
		return
	if j<0:return
	if units[j].hp<=0 and not (local_melee_polish and i==1 and u.move=="counter"):return
	if i==1 and u.move=="chain":
		if local_melee_polish and not bool(u.get("guarded",false)):
			_begin(i,"counter",j)
		return
	if local_melee_polish and i==1 and u.move=="counter":
		if u.feet.distance_to(units[j].feet)<=76.0:
			_start_uram_short_fan(j,_uram_shield_origin())
			_finish_uram_ordinary_counter(j)
		else:
			var view:HybridCharacter=u.actor.preview
			var shield:Node3D=view.shield
			var origin:=view.position+(view.display.position+view.camera.unproject_position(shield.global_position)*view.display.scale)*view.scale
			var destination:=_deer_tip(units[j])
			_start_uram_short_fan(j,origin)
			uram_ordinary_wave={"to":j,"locked":units[j].actor,"from":origin,"at":elapsed,"span":UramCounterWave.duration(origin,destination)}
		return
	if i==2 and u.move=="skill" and bool(u.get("bom_near_skill",false)):
		var beat:int=u.bom_strike
		if beat>=Knife.contacts.size():return
		u.bom_strike=beat+1
		if beat+1<Knife.contacts.size():u.contact=Knife.contacts[beat+1]
		var amount:=Knife.damage_at(beat,u.rally>elapsed)
		_resolve_saebom_near(i,j,amount,beat)
		return
	var damage:=RallyCloud.SQUAD_BASE if u.move=="attack" else 27 if u.move=="skill" else 38
	if i>=3:
		damage=11 if u.move=="attack" else 23
		# Keep the old production early counter damage. The lab numbers
		# otherwise end 1-2 before its first genuine skill opportunity.
		if not story_encounter.is_empty() and u.move == "attack" and int(story_encounter.number) <= 6:
			damage = Hunt.RULES.COUNTER_DAMAGE
	if u.rally>elapsed:damage=roundi(damage*(1.20 if local_melee_polish else 1.25))
	var start:Vector2=u.feet-Vector2(0,30)
	var finish:Vector2=units[j].feet-Vector2(0,25)
	if i==2 and not (u.move=="attack" and bool(u.get("bom_shove",false))):
		if start.distance_to(finish)>149.0:_miss(i,j,"projectile");return
		var basic_rope:bool=u.move=="attack"
		var paired_presentation:=saebom_distance_drill=="far" or basic_rope
		if paired_presentation:_pose_ranged_release(u)
		var jewel:=_sling_stone(u)
		if basic_rope:
			u.basic_rope_empty=true
			var view:HybridCharacter=u.actor.preview
			var center:=BasicRope.stone_world(view)
			if center.is_finite():jewel=view.position+(view.display.position+view.camera.unproject_position(center)*view.display.scale)*view.scale
			BasicRope.set_loaded(view,false)
		var release:=jewel if paired_presentation or (bom_trail_draw.is_valid() and jewel.distance_to(start)<65.0) else start
		# Original simulation uses start/destination; only drawn trail begins at the rig stone.
		missiles.append({"from":i,"target":j,"point":start,"destination":finish,"damage":damage,"kind":u.move,"trace":PackedVector2Array([release]),"origin":start,"paired_presentation":paired_presentation,"release":release,"rendered":release,"basic_rope":basic_rope,"launched_at":elapsed})
		return
	var range_px:=80.0 if i==2 and u.move=="attack" and bool(u.get("bom_shove",false)) else _gap(i)+8.0+(14.0 if u.move!="attack" else 0.0)
	if u.feet.distance_to(units[j].feet)>range_px:_miss(i,j,u.move);return
	if i==2 and _uses_close_basic_pose(u,j):
		# Capture the receiver pose before damage initializes the native hit clip.
		var target:Dictionary=units[j]
		Knife.show_basic(u,target,.48)
		target["close_basic_impulse"]=Vector2(signf((target.feet as Vector2).x-(u.feet as Vector2).x),0.)
		var receiver:Skeleton3D=target.actor.preview.skeleton
		target["close_basic_neck_pose"]=receiver.get_bone_pose_rotation(receiver.find_bone("neck"))
		target["close_basic_head_pose"]=receiver.get_bone_pose_rotation(receiver.find_bone("head"))
	_damage(i,j,damage,u.move)

func _finish_uram_ordinary_counter(j:int)->void:
	uram_ordinary_impact.emit()
	if j<3 or j>=units.size() or units[j].hp<=0:
		_apply_uram_field_hit(-1)
		return
	_damage(1,j,18,"counter")
	if int(units[j].hp)>0:
		_play(units[j],"hit")
		units[j].next=maxf(float(units[j].next),elapsed+1.15)
		squad_stuns[j]=elapsed
		units[j].uram_splash_stun_until=elapsed+URAM_STUN_SECONDS
	_apply_uram_field_hit(j)

func _advance_uram_ordinary_wave()->void:
	if uram_ordinary_wave.is_empty():return
	var to:int=uram_ordinary_wave.to
	if units[1].hp<=0:
		uram_ordinary_wave.clear()
		return
	if elapsed-float(uram_ordinary_wave.at)+1e-6<float(uram_ordinary_wave.span):return
	var primary_valid:bool=to>=3 and to<units.size() and units[to].hp>0 and units[to].actor==uram_ordinary_wave.locked
	if primary_valid:uram_wave_pop={"at":elapsed,"point":_deer_tip(units[to])}
	uram_ordinary_wave.clear()
	_finish_uram_ordinary_counter(to if primary_valid else -1)

func _uram_shield_origin()->Vector2:
	var u:=units[1]
	var view:HybridCharacter=u.actor.preview
	if not is_instance_valid(view.shield):return (u.feet as Vector2)-Vector2(0.,25.)
	return view.position+(view.display.position+view.camera.unproject_position(view.shield.global_position)*view.display.scale)*view.scale

func _start_uram_short_fan(primary:int,shield:Vector2,parried:=false)->void:
	var origin:Vector2=units[1].feet
	var destination:Vector2=units[primary].feet
	var forward:=origin.direction_to(destination)
	if forward.is_zero_approx():forward=Vector2.RIGHT
	var reach:=UramCounterWave.fan_range(origin,destination,true)
	var combined := not parried and uram_combined.frames.size() == UramCombined.FRAME_COUNT
	uram_short_fans.append({"ground":origin,"from":shield,"axis":forward,"reach":reach,"at":elapsed,"span":UramCombined.SECONDS if combined else UramCounterWave.FIELD_SECONDS,"combined":combined})

func _apply_uram_field_hit(exclude_primary:int)->void:
	# The shield wave is battlefield-wide. Neither the visual axis nor the
	# distance to Uram/primary filters or delays any secondary damage/stun.
	for j in range(3,units.size()):
		var recipient:=units[j]
		if j==exclude_primary or recipient.hp<=0:continue
		_damage(1,j,URAM_SPLASH_DAMAGE,"counter_splash")
		if int(recipient.hp)>0:
			_play(recipient,"hit")
			recipient.next=maxf(float(recipient.next),elapsed+URAM_STUN_SECONDS)
			recipient.uram_splash_stun_until=elapsed+URAM_STUN_SECONDS
			squad_stuns[j]=elapsed

func _advance_uram_short_fans()->void:
	for i in range(uram_short_fans.size()-1,-1,-1):
		var fan := uram_short_fans[i]
		if elapsed-float(fan.at)>=float(fan.span):
			uram_short_fans.remove_at(i)

func _resolve_saebom_near(i:int,j:int,amount:int,beat:int)->void:
	var u:=units[i]
	var v:=units[j]
	var final:=beat==Knife.contacts.size()-1
	if v.hp<=0 or u.feet.distance_to(v.feet)>72.:
		if final:_miss(i,j,"saebom_melee_2sp_4")
		return
	var edge:=Knife.shoulder(v,u.feet)+Vector2(0.,[-2.,3.,-1.,0.][beat])
	knife_events.append({"at":elapsed,"point":edge,"feet":v.feet,"beat":beat})
	if final:
		_damage(i,j,amount,"saebom_melee_2sp_4",edge)
		return
	# Preserve the early arc-only motion response, while committing actual HP.
	_subtract_hp_and_show(j,amount)
	hits.append({"from":i,"target":j,"type":"saebom_melee_2sp_%d"%(beat+1),"result":"hit","hp":v.hp})
	if v.hp<=0:_play(v,"death")

func _miss(i:int,j:int,key:String)->void:
	hits.append({"from":i,"target":j,"type":key,"result":"miss"})

func _subtract_hp_and_show(j:int,amount:int)->void:
	var target:=units[j]
	var hp_before := int(target.hp)
	target.hp=maxi(0,hp_before-amount)
	var anchor := aim.bone_point(target.actor,"head")
	anchor.y = minf(anchor.y,float(target.feet.y)-76.0)
	anchor.x = float(target.feet.x)
	damage_numbers.show_loss(j,hp_before,int(target.hp),anchor-Vector2(0,9),j<3)

const OrdinaryHitAccent = preload("res://scripts/hunt_ordinary_hit_accent.gd")

func _damage(i:int,j:int,amount:int,key:String,stone_impact:=Vector2.INF)->void:
	var target:=units[j]
	if target.hp<=0:return
	if saebom_distance_drill=="far" and i==1:
		# The tank still performs its genuine attack/contact, but this drill
		# isolates Saebom's damage and lets the enemy defeat Uram normally.
		hits.append({"from":i,"target":j,"type":key,"result":"drill_visual_only","hp":target.hp})
		glints.append({"at":elapsed,"point":target.feet-Vector2(0,23) if stone_impact==Vector2.INF else stone_impact,"tint":Color("ffc971")})
		return
	if j==1 and target.move=="chain" and target.age>URAM_GUARD_LATEST and target.age<minf(URAM_GUARD_EARLIEST,target.actor.duration) and (not local_melee_polish or (not bool(target.get("guarded",false)) and int(target.get("guard_source",-1))==i)):
		if local_melee_polish:target.guarded=true
		hits.append({"from":i,"target":j,"type":key,"result":"parried"})
		if not story_encounter.is_empty() and i == 3 and int(story_encounter.number) in [5, 6]:
			story_taught_parry = true
		var cast_at:=elapsed-float(target.age)
		var new_guard:=absf(cast_at-last_gong_cast)>.03
		if new_guard:
			last_gong_cast=cast_at
			var shield:Node3D=target.actor.preview.shield
			var point:Vector2=target.feet-Vector2(0,25)
			if is_instance_valid(shield):
				var view:HybridCharacter=target.actor.preview
				point=view.position+(view.display.position+view.camera.unproject_position(shield.global_position)*view.display.scale)*view.scale
			if local_melee_polish and i>=3:_start_uram_short_fan(i,point,true)
			if parry_dust.is_valid():_spotlight_parry(i,j,point)
			elif gong_draw.is_valid():
				var base:Vector2=target.feet
				var incoming:Vector2=units[i].feet
				gong_events.append({"at":elapsed,"point":point,"forward":base.direction_to(incoming)})
		if not parry_dust.is_valid() and not gong_draw.is_valid():
			glints.append({"at":elapsed,"point":target.feet-Vector2(0,25),"tint":Color("65e4cf")})
		var counter_primary:bool=units[i].hp>0 and target.feet.distance_to(units[i].feet)<76.0
		if counter_primary:
			_damage(j,i,18,"counter")
			if local_melee_polish and int(units[i].hp)>0:
				_play(units[i],"hit")
				units[i].next=maxf(float(units[i].next),elapsed+URAM_STUN_SECONDS)
				units[i].uram_splash_stun_until=elapsed+URAM_STUN_SECONDS
				squad_stuns[i]=elapsed
		if local_melee_polish and new_guard and i>=3:_apply_uram_field_hit(i if counter_primary else -1)
		return
	var hp_before:=int(target.hp)
	_subtract_hp_and_show(j,amount)
	var saebom_switch_hit:=false
	if j==2 and target.hp<hp_before and local_melee_polish and not bool(target.get("bom_close",false)):
		_remember_saebom_proximity(target,_target(2))
		target.saebom_switch_hit_until=elapsed+OrdinaryHitAccent.END
		saebom_switch_hit=bool(target.get("saebom_melee_pending",false))
	hits.append({"from":i,"target":j,"type":key,"result":"hit","hp":target.hp})
	if i == 0 and key == "chain":
		han_ground_events.append({"at":elapsed,"floor":target.feet})
	if bom_hit_draw.is_valid() and i==2 and key=="skill":
		var feet:Vector2=target.feet
		var from:Vector2=units[i].feet
		group_bom_hits.append({"at":elapsed,"point":feet-Vector2(0,25) if stone_impact==Vector2.INF else stone_impact,"forward":from.direction_to(feet)})
	elif silver_impact.is_valid() and i>=3 and key=="skill":
		var ground:Vector2=target.feet
		silver_hits.append({"at":elapsed,"center":ground-Vector2(0,23),"floor_point":ground,"unit":i})
	elif authored_draw.is_valid() and ((i==0 and key in ["skill","chain"]) or (i==2 and key=="skill")):
		var base:Vector2=units[i].feet
		var ground:Vector2=target.feet
		var tag:="saebom_hit" if i==2 else "han_skill" if key=="skill" else "han_chain"
		authored_events.append({"tag":tag,"at":elapsed,"point":ground-Vector2(0,23),"forward":base.direction_to(ground)})
	elif uram_ground_draw.is_valid() and i==1 and key=="skill":pass
	elif heavy_draw.is_valid() and i==1 and key=="skill":
		var from:Vector2=units[i].feet
		var ground:Vector2=target.feet
		heavy_events.append({"at":elapsed,"point":ground-Vector2(0,23),"ground":ground,"forward":from.direction_to(ground)})
	elif key!="han_chain_splash" and not (i==2 and (key=="saebom_melee_2sp_4" or (key=="attack" and _uses_close_basic_pose(units[i],j)))):
		glints.append({"at":elapsed,"point":target.feet-Vector2(0,23) if stone_impact==Vector2.INF else stone_impact,"tint":Color("ffc971") if i<3 else Color("f0ffe8")})
	if target.hp<=0:_play(target,"death")
	else:
		var resting:bool=target.move in ["idle","run","walk"]
		target.ordinary_resting_hit=resting and (key=="attack" or saebom_switch_hit)
		if key=="attack" or saebom_switch_hit:OrdinaryHitAccent.on_hit(target.actor.preview.skeleton,elapsed,resting)
		else:OrdinaryHitAccent.clear(target.actor.preview.skeleton)
		if resting:_play(target,"hit")

func _update_projectiles(dt:float)->void:
	for index in range(missiles.size()-1,-1,-1):
		var m:=missiles[index]
		m.point=m.point.move_toward(m.destination,340.0*dt)
		var paired:bool=m.paired_presentation
		if paired:
			var destination:Vector2=m.destination
			var origin:Vector2=m.origin
			var now:Vector2=m.point
			var ratio:=1.-now.distance_to(destination)/maxf(.001,origin.distance_to(destination))
			var target_now:Dictionary=units[m.target]
			var visible_aim:=_ranged_impact_anchor(target_now,destination) if target_now.hp>0 and destination.distance_to(target_now.feet-Vector2(0,25))<=19.0 else destination
			m.rendered=Vector2(m.release).lerp(visible_aim,clampf(ratio,0.,1.))
		var drawn:Vector2=m.rendered if paired else m.point
		if bom_trail_draw.is_valid() and m.kind=="skill":
			var trace:PackedVector2Array=m.trace
			if trace[-1].distance_squared_to(drawn)>.28:trace.append(drawn)
			while trace.size()>16:trace.remove_at(0)
			m.trace=trace
		if m.point.distance_squared_to(m.destination)>.01:continue
		var u:=units[m.target]
		if u.hp>0 and m.destination.distance_to(u.feet-Vector2(0,25))<=19.0:
			_damage(m.from,m.target,m.damage,m.kind,drawn if paired else Vector2.INF)
			if bool(m.get("basic_rope",false)):
				basic_rope_hit=drawn;basic_rope_hit_at=elapsed
			if paired and ranged_alignment_contact.is_valid():ranged_alignment_contact.call(String(u.id))
		else:_miss(m.from,m.target,m.kind)
		missiles.remove_at(index)

func _ground_heading(cam:Camera3D,d:Vector2)->float:
	var p:=cam.unproject_position(Vector3.ZERO)
	var x:=cam.unproject_position(Vector3.RIGHT)-p
	var z:=cam.unproject_position(Vector3.BACK)-p
	var det:=x.cross(z)
	if absf(det)<.0001:return atan2(d.x,d.y)
	var world:=Vector2(d.cross(z),x.cross(d))/det
	return atan2(world.x,world.y)

func _calibrate_han()->void:
	var actor=units[0].actor
	aim.cache_spear(actor)
	aim.grounded_spear=true
	var p:Node3D=actor.preview.pivot
	p.rotation.y=0
	for key in ["attack","skill","chain"]:
		actor.play(key);actor.sample(actor.duration*.51,false)
		var sk:=aim.spear_skeleton
		var hand_pose:=sk.get_bone_global_pose(aim.hand)
		var tip:=sk.to_global(hand_pose*aim.tip_in_hand)
		var hand_pt:=sk.to_global(hand_pose.origin)
		var direction:=tip-hand_pt
		if Vector2(direction.x,direction.z).length_squared()>.01:
			spear_forward_bias[key]=atan2(direction.x,direction.z)
	_play(units[0],"idle")

func _draw_pose(dt:float)->void:
	_update_saebom_range()
	var ambient:=Color.WHITE.lerp(Color.BLACK,spotlight_dim())
	for i in units.size():
		var u:=units[i];var actor=u.actor
		if bool(u.get("story_dormant", false)):
			u.ring.hide()
			actor.preview.hide()
			continue
		var isolated:=spotlight_attacker==i or spotlight_defender==i
		var tint:=Color.WHITE if isolated else ambient
		actor.preview.modulate=tint
		u.ring.modulate=tint
		actor.preview.position=u.feet
		actor.preview.z_index=int(u.feet.y)
		u.ring.position=u.feet;u.ring.visible=u.hp>0
		if ring_project.is_valid() and u.hp>0 and i!=1:
			u.ring.position=Vector2.ZERO
			u.ring.points=ring_project.call(actor.preview,u.feet)
		if u.move!="death":
			var j:int=u.victim if u.move in ["skill","chain","attack","counter"] else _target(i)
			if j>=0:
				var d:Vector2=units[j].feet-u.feet
				var heading:=_ground_heading(actor.preview.camera,d)
				actor.preview.pivot.rotation.y=heading-float(spear_forward_bias.get(u.move,0.0)) if i==0 else heading
		var show_basic:=i==2 and _uses_close_basic_pose(u,int(u.victim))
		if not show_basic:actor.sample(_ranged_visible_age(u) if i==2 else float(u.age),false)
		if i>=3 and u.move=="hit" and u.has("close_basic_impulse"):
			var away:Vector2=u.close_basic_impulse
			var ride:=smoothstep(0.,.07,u.age)*(1.0-smoothstep(.10,.39,u.age))
			actor.preview.position+=away*6.1*ride
			# During the brief separation the head stays in its pre-impact
			# alignment. Stock hit timing, reactions and damage do not change.
			var receiver:Skeleton3D=actor.preview.skeleton
			var keep:=1.-smoothstep(.085,.235,u.age)
			var neck:=receiver.find_bone("neck")
			var head:=receiver.find_bone("head")
			receiver.set_bone_pose_rotation(neck,receiver.get_bone_pose_rotation(neck).slerp(u.close_basic_neck_pose,keep))
			receiver.set_bone_pose_rotation(head,receiver.get_bone_pose_rotation(head).slerp(u.close_basic_head_pose,keep))
			receiver.force_update_all_bone_transforms()
		if i>=3 and u.move!="hit":u.erase("close_basic_impulse")
		if i==1 and u.move=="skill" and uram_ground_draw.is_valid():_pose_uram_ground(u,actor)
		if i==1 and ring_project.is_valid() and u.hp>0:
			# Sample the visual boots after this frame's final stance/skill pose.
			var view:HybridCharacter=actor.preview
			var sk:Skeleton3D=view.skeleton
			var l:=sk.find_bone("foot.L")
			var r:=sk.find_bone("foot.R")
			var ground:=sk.to_global((sk.get_bone_global_pose(l).origin+sk.get_bone_global_pose(r).origin)*.5)
			ground.y=0.
			var canvas_center:=view.position+(view.display.position+view.camera.unproject_position(ground)*view.display.scale)*view.scale
			u.ring.position=Vector2.ZERO
			u.ring.points=ring_project.call(view,canvas_center)
		if i==2 and u.move=="skill" and float(u.get("bom_hop",0.))>0.:SaebomMelee.saebom_hop_pose(actor,float(u.age)/maxf(.01,float(actor.duration)),float(u.bom_hop)/24.)
		if i==2 and u.hp>0 and u.move=="skill" and bool(u.get("bom_near_skill",false)) and int(u.victim)>=0:
			Knife.sample_skill(u,units[int(u.victim)],float(u.age))
		elif i==2 and u.move=="attack" and bool(u.get("bom_shove",false)):
			if show_basic:
				var target:Dictionary=units[int(u.victim)]
				var p:=clampf(float(u.age)/maxf(.01,float(actor.duration)),0.,1.)
				if p<.43 or not is_finite((u.get("close_basic_edge",Vector2.INF) as Vector2).x):
					u.close_basic_edge=Knife.shoulder(target,u.feet)
				Knife.show_basic(u,target,p)
				actor.preview.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			else:
				SaebomMelee.saebom_shove_pose(actor,float(u.age)/maxf(.01,float(actor.duration)))
				Knife.blade(actor.preview,Vector2.ZERO,0.,0.)
		if i==2 and not (u.move=="attack" and bool(u.get("bom_shove",false))) and not (u.move=="skill" and bool(u.get("bom_near_skill",false))):
			if u.hp>0 and bool(u.get("bom_close",false)) and u.move in ["idle","walk","run","hit"]:
				Knife.blade(actor.preview,Vector2.ZERO,0.,0.)
			elif actor.preview.has_meta("saebom_melee_blade"):actor.preview.remove_meta("saebom_melee_blade")
		if i==2 and bom_pose.is_valid():bom_pose.call(actor,float(u.age) if u.move=="chain" and u.hp>0 else -1.0)
		if i==0:aim.anchor_spear_root(actor)
		OrdinaryHitAccent.display(actor.preview.skeleton,elapsed,u.hp>0,bool(u.get("ordinary_resting_hit",false)) and u.move=="hit",elapsed-float(u.age))
		if silver_draw.is_valid() and i>=3:
			var wake:Array=deer_wakes[i-3]
			while not wake.is_empty() and elapsed-float(wake[0].at)>.53:wake.pop_front()
			if dt>0.0 and u.hp>0 and u.move=="skill" and float(u.age)>=float(actor.preview.length("req046_skill_anticipation")) and u.age<float(actor.preview.length("req046_skill_anticipation"))+.52:
				var tip:=_deer_tip(u)
				if wake.is_empty() or tip.distance_squared_to(wake[-1].tip)>2.0:
					wake.append({"at":elapsed,"foot":u.feet,"tip":tip})
				if wake.size()>20:wake.pop_front()

	_sync_ranged_held_stone(units[2])
	for i in huds.size():
		var u:=units[i]
		huds[i].chain_border_speed=URAM_BORDER_RATE if i==1 and local_melee_polish and not input_paused and not ended and _squad_guard_candidate(URAM_BORDER_LEAD)>=0 else 1.0
		if story_encounter.is_empty():
			huds[i].sync(u.sp,u.hp,MAX_HP,u.hp>0,_free_to_cast(i),dt)
		else:
			huds[i].chain_allowed = int(story_encounter.number) >= 6 or (int(story_encounter.number) == 5 and i == 1)
			var skill_allowed := story_allows(i, "skill")
			huds[i].sync(u.sp, u.hp, u.max_hp, u.hp > 0, _free_to_cast(i) and skill_allowed, dt, _free_to_cast(i) and story_allows(i, "chain"))
			if not skill_allowed:
				huds[i].badge.hide()
				huds[i].warm_glow.hide()
	if is_instance_valid(uram_ground_layer):
		uram_ground_layer.self_modulate=ambient
		uram_ground_layer.queue_redraw()
	paint.self_modulate=ambient
	han_ground_layer.queue_redraw()
	rally_silver_back.z_index=int(units[2].feet.y)-1
	rally_silver_back.queue_redraw()
	paint.queue_redraw()
	bars_paint.queue_redraw()
	if is_instance_valid(cast_notice_paint) and not cast_notices.is_empty():
		for caster in cast_notices.keys():
			if units[caster].hp<=0 or elapsed-float(cast_notices[caster].at)>=CastHud.CAST_SECONDS:
				cast_notices.erase(caster)
		cast_notice_paint.queue_redraw()
	if is_instance_valid(launch_dust_layer):
		launch_dust_layer.self_modulate=ambient
		launch_dust_layer.queue_redraw()
	if is_instance_valid(parry_front):
		parry_ground.queue_redraw()
		parry_front.queue_redraw()

func _draw_launch_dust()->void:
	for event in launch_dust_events:
		launch_dust_draw.call(event.origin,elapsed-float(event.at),launch_dust_layer)

func _paint_cast_notices()->void:
	for i in cast_notices:
		var u:=units[i]
		if u.hp<=0:continue
		var notice:Dictionary=cast_notices[i]
		var point:=aim.bone_point(u.actor,"head")
		# Squad health bars are painted; keep the notice above both the projected head and the bar.
		point.y=minf(point.y,float(u.feet.y)-76.0)
		cast_notice_style.draw_cast_notice(cast_notice_paint,point,null,notice.icon,notice.linked,elapsed-float(notice.at))

func _paint_bars()->void:
	for i in units.size():
		var u := units[i]
		if u.hp<=0:continue
		var at:Vector2=u.feet-Vector2(23,76)
		var back:=Rect2(at,Vector2(46,5))
		bars_paint.draw_rect(back,Color("211f23"))
		var color := Color("68c8ff") if (u.id != "forest" if story_encounter.is_empty() else i < 3) else Color("ff8176")
		bars_paint.draw_rect(Rect2(at+Vector2.ONE,Vector2(44.0*float(u.hp)/float(u.get("max_hp", MAX_HP)),3)),color)

func _paint_rally_silver_wings()->void:
	if local_melee_polish and units.size()>2 and units[2].hp>0:
		RallySilver.wings(rally_silver_back,units[2].feet,elapsed-rally_silver_cast_at)

func _paint()->void:
	if local_melee_polish:
		for i in mini(3,units.size()):
			var u:=units[i]
			if u.hp>0 and float(u.rally)>elapsed:
				RallySilver.aura(paint,u.feet,float(u.rally)-elapsed,5.0)
	if units.size()>2 and units[2].hp>0:Knife.draw_blade(paint,units[2].actor.preview)
	for ev in knife_events:Knife.draw_event(paint,int(ev.beat),ev.point,ev.feet,elapsed-float(ev.at))
	for fan in uram_short_fans:
		if not bool(fan.get("combined", false)):UramCounterWave.draw_fan(paint,fan.from,fan.ground,fan.axis,fan.reach,(elapsed-float(fan.at))/float(fan.span),true,false)
	if not uram_wave_pop.is_empty():
		UramCounterWave.draw_pop(paint,uram_wave_pop.point,elapsed-float(uram_wave_pop.at))
	BasicRope.draw_impact(paint,basic_rope_glow,basic_rope_hit,elapsed-basic_rope_hit_at)
	RallyCloud.draw(paint,bom_cloud_origin,elapsed-bom_cloud_at)
	var bom_active:=false
	for m in missiles:
		var drawn:Vector2=m.rendered if m.paired_presentation else m.point
		if bool(m.get("basic_rope",false)):
			bom_active=true
			BasicRope.draw_stone(paint,basic_rope_glow,drawn,elapsed-float(m.launched_at),true)
			continue
		if weapon_draw.is_valid() and m.from==2:
			bom_active=true
			if bom_trail_draw.is_valid() and m.kind=="skill":
				bom_trail_draw.call(m.trace,1.0,paint)
				continue
			weapon_draw.call(units[2].actor,drawn,false,paint)
		paint.draw_circle(drawn,3.0,Color("ffdf9c"))
	if weapon_draw.is_valid():
		if units[1].hp>0:weapon_draw.call(units[1].actor,Vector2.INF,false,paint)
		if units[2].hp>0 and not bom_active:
			var u:=units[2]
			var after_release:bool=u.move in ["attack","skill"] and u.contact<0.0
			var hands_empty:bool=bom_pose.is_valid() and u.move=="chain" and u.age>=.10 and u.age<2.24
			if not hands_empty and not u.actor.preview.has_meta("saebom_melee_blade") and not (u.move=="attack" and bool(u.get("bom_shove",false))) and not (u.move=="skill" and bool(u.get("bom_near_skill",false))):
				if u.move in ["skill","chain"]:weapon_draw.call(u.actor,Vector2.INF,after_release,paint)
				elif not bool(u.get("basic_rope_empty",false)):
					var view:HybridCharacter=u.actor.preview
					var point:=BasicRope.stone_world(view)
					if point.is_finite():BasicRope.draw_stone(paint,basic_rope_glow,view.position+(view.display.position+view.camera.unproject_position(point)*view.display.scale)*view.scale,0.)
	if heavy_windup.is_valid() and units.size()>1 and units[1].move=="skill" and float(units[1].contact)>0:
		var view:HybridCharacter=units[1].actor.preview
		var club:MeshInstance3D=view.club
		if is_instance_valid(club):
			var tip:=club.to_global(Vector3(club.get_aabb().end.x*.89,0,0))
			var mark:=view.position+(view.display.position+view.camera.unproject_position(tip)*view.display.scale)*view.scale
			heavy_windup.call(mark,clampf(float(units[1].age)/float(units[1].contact),0,1),paint)
	if authored_draw.is_valid():
		for event in authored_events:
			authored_draw.call(event.tag,event.point,event.forward,elapsed-float(event.at),paint)
	if not local_melee_polish:
		if authored_draw.is_valid() and units.size()>2 and units[2].move=="chain" and units[2].hp>0:
			var bom:=units[2]
			if bom_wings_draw.is_valid():bom_wings_draw.call(bom.feet,float(bom.age),paint)
			else:authored_draw.call("saebom_chain",bom.feet,Vector2.ZERO,float(bom.age)*3.5/maxf(.01,float(bom.actor.duration)),paint)
		if bom_ally_draw.is_valid():
			for ev in group_bom_ally_events:
				var ally:=units[int(ev.unit)]
				if ally.hp>0:bom_ally_draw.call(ally.feet,.96+elapsed-float(ev.at),paint)
	if bom_hit_draw.is_valid():
		for hit in group_bom_hits:bom_hit_draw.call(hit.point,hit.forward,elapsed-float(hit.at),paint)
	if silver_draw.is_valid():
		for i in range(3,units.size()):
			var u:=units[i]
			var wind:=maxf(.01,float(u.actor.preview.length("req046_skill_anticipation")))
			var progress:=clampf(float(u.age)/wind,0.0,1.0) if u.hp>0 and u.move=="skill" else -1.0
			silver_draw.call(u.feet,_deer_tip(u),progress,float(u.contact)>=0.0,deer_wakes[i-3],elapsed,paint)
		for event in silver_hits:silver_impact.call(event,clampf((elapsed-float(event.at))/.67,0,1),paint)
	for event in heavy_events:
		heavy_draw.call(event.point,event.ground,event.forward,elapsed-float(event.at),paint)
	for gong in gong_events:
		gong_draw.call(gong.point,gong.forward,elapsed-float(gong.at),paint)


func _uses_close_basic_pose(u:Dictionary,j:int)->bool:
	if not local_melee_polish or j<3 or j>=units.size() or u.move!="attack" or not bool(u.get("bom_shove",false)):
		return false
	var sk:Skeleton3D=units[j].actor.preview.skeleton
	if not is_instance_valid(sk):return false
	for joint in ["front_upper.R","trunk","head","neck"]:
		if sk.find_bone(joint)<0:return false
	return true

func _deer_tip(u:Dictionary)->Vector2:
	var view:HybridCharacter=u.actor.preview
	var sk:Skeleton3D=view.skeleton
	var idx:=sk.find_bone("head")
	if idx<0:return u.feet-Vector2(0,25)
	var point:=sk.to_global(sk.get_bone_global_pose(idx)*Vector3(0,.05,.23))
	return view.position+(view.display.position+view.camera.unproject_position(point)*view.display.scale)*view.scale




func _ranged_visible_age(u:Dictionary)->float:
	var age:float=u.age
	if saebom_distance_drill!="far" or u.move not in ["attack","skill"] or bool(u.get("bom_shove",false)) or bool(u.get("bom_near_skill",false)):
		return age
	var duration:float=u.actor.duration
	var launch:=duration*.61
	var authored:=SaebomMelee.sling_release_seconds(String(u.move))
	if launch<=.001 or authored<=.001 or authored>=duration-.001:return age
	# Keep combat timing. Reach the already-authored throw pose at the original squad launch tick.
	if age<=launch:return age/launch*authored
	return lerpf(authored,duration,clampf((age-launch)/(duration-launch),0.,1.))

func _pose_ranged_release(u:Dictionary)->void:
	var actor=u.actor
	var view:HybridCharacter=actor.preview
	# Only correct native launch presentation; original timed release event remains.
	actor.sample(_ranged_visible_age(u),false)
	var skeleton:Skeleton3D=view.skeleton
	skeleton.force_update_all_bone_transforms()

func _sync_ranged_held_stone(u:Dictionary)->void:
	if u.move not in ["skill","chain"] and not bool(u.get("bom_shove",false)):
		if bool(u.get("basic_rope_empty",false)) and bool(u.get("basic_rope_windup",false)) and u.move=="attack" and float(u.contact)>0. and float(u.age)>.125:
			u.basic_rope_empty=false
		BasicRope.set_loaded(u.actor.preview,not bool(u.get("basic_rope_empty",false)))
		return
	if saebom_distance_drill!="far":return
	var view:HybridCharacter=u.actor.preview
	var stone:MeshInstance3D=u.get("ranged_held_mesh",null)
	if not is_instance_valid(stone):
		for model in view.pivot.find_children("*","MeshInstance3D",true,false):
			var label:=String(model.name).to_lower()
			if "large stone" in label or "large_stone" in label:
				stone=model
				u.ranged_held_mesh=stone
				u.ranged_held_visible=stone.visible
				break
	if is_instance_valid(stone):
		var after_shot:bool=u.move in ["attack","skill"] and u.contact<0. and not u.get("bom_shove",false) and not u.get("bom_near_skill",false)
		stone.visible=bool(u.ranged_held_visible) and not after_shot

func _ranged_impact_anchor(u:Dictionary,fallback:Vector2)->Vector2:
	var view:HybridCharacter=u.actor.preview
	var sk:Skeleton3D=view.skeleton
	var joint:=sk.find_bone("trunk")
	if joint<0:return fallback
	var p:=sk.to_global(sk.get_bone_global_pose(joint).origin)
	return view.position+(view.display.position+view.camera.unproject_position(p)*view.display.scale)*view.scale

func _sling_stone(u:Dictionary)->Vector2:
	var v:HybridCharacter=u.actor.preview
	var sk:Skeleton3D=v.skeleton
	var idx:=sk.find_bone("sling_stone")
	if idx<0:return u.feet-Vector2(0,30)
	var p:=sk.to_global(sk.get_bone_global_pose(idx).origin)
	return v.position+(v.display.position+v.camera.unproject_position(p)*v.display.scale)*v.scale

func _draw_han_ground() -> void:
	for event in han_ground_events:
		han_ground.draw(han_ground_layer, event.floor, elapsed - float(event.at))
