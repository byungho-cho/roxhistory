extends Node2D

signal parry_spotlight_started

const Actor = preload("res://scripts/model_test_actor.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const Presenter = preload("res://scripts/duel_motion_presenter.gd")
const HUD = preload("res://scripts/duel_skill_hud.gd")
const UramCounterWave=preload("res://scripts/duel_uram_counter_wave.gd")
const Head = preload("res://scripts/battle_head_hud.gd")
const HEROES := ["hangyeol","uram","saebom"]
const HERO_SLOTS := [0,5,3]
const DEER_SLOTS := [4,2,3]
const MAX_HP := 100
const STEP := 1.0/120.0
const SaebomMelee=preload("res://scripts/duel_shared_world.gd")
const CLOSE_2SP_HIT_PHASES:=[.225,.40,.645,.855]
const CLOSE_2SP_FINAL_DAMAGE:=27
const CloseBasicPose=preload("res://scripts/duel_saebom_close_basic_pose.gd")
const NEAR_SAE_2SP=preload("res://assets/ui/saebom-melee-test47/near-2sp.png")
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
var uram_wave_pop:Dictionary={}
var uram_ground_layer:Node2D
var input_paused:=false
var hud_parent:Control
var paint:Node2D
var bars_paint:Node2D
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
	paint=Node2D.new();paint.z_index=600;add_child(paint)
	paint.draw.connect(_paint)
	bars_paint=Node2D.new();bars_paint.z_index=601;add_child(bars_paint)
	bars_paint.draw.connect(_paint_bars)
	for i in 6:
		var ally:=i<3
		var id:String=HEROES[i] if ally else "forest"
		var home:Vector2
		if ally:home=Hunt.HUNTER_BATTLE_CENTER+(Hunt.ALLY_CELLS[HERO_SLOTS[i]]-Hunt.FORMATION_CENTER)*.62
		else:home=Hunt.DEER_SLOT+Vector2(111,-9)+(Hunt.ENEMY_CELLS[DEER_SLOTS[i-3]]-Hunt.ENEMY_CELLS[4])*.86
		var actor:=Actor.new();actor.create(self,id);actor.configure(true)
		actor.preview.scale=Vector2.ONE*[.76588,1.08,.90,.82588,.82588,.82588][i]
		var ring:=Line2D.new();ring.width=1.65;ring.antialiased=true;ring.default_color=Head.duel_team_color(ally)
		for j in 41:ring.add_point(Vector2.from_angle(TAU*float(j)/40)*Vector2(22,8))
		add_child(ring)
		var u:Dictionary={"actor":actor,"id":id,"home":home,"feet":home,"hp":MAX_HP,"sp":1.0,"move":"idle","age":0.0,"next":.52+float(i%3)*.17,"contact":-1.0,"victim":-1,"ring":ring,"rally":0.0}
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
		if int(attacker.hp)>0:
			parry_stars.call(_deer_tip(attacker)-Vector2(6.,25.),clampf(spotlight_clock/2.25,0.,1.),parry_front)
	for index in squad_stuns:
		if index!=spotlight_attacker and int(units[index].hp)>0:
			parry_stars.call(_deer_tip(units[index])-Vector2(6.,25.),clampf((elapsed-float(squad_stuns[index]))/1.15,0.,1.),parry_front)

func configure_saebom_distance_drill(mode:String)->void:
	# Preset only: all points, hits, death and target movement still use the squad rules.
	saebom_distance_drill=mode
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
	if saebom_distance_drill.is_empty() or units[2].hp<=0:return
	var target:=_target(2)
	if target<0:return
	var u:=units[2]
	u.bom_close=SaebomMelee.saebom_close_at(u.feet.distance_to(units[target].feet),bool(u.get("bom_close",false)),65.,80.)
	huds[2].set_saebom_distance_icon(u.bom_close,NEAR_SAE_2SP)

func set_input_paused(value:bool)->void:
	input_paused=value
	_draw_pose(0.0)

func grant_sp()->void:
	for i in 3:
		if units[i].hp>0:units[i].sp=3.0
	_draw_pose(0.0)

func _play(u:Dictionary,key:String)->void:
	u.actor.play(key);u.move=key;u.age=0.0;u.contact=-1.0

func _free_to_cast(i:int)->bool:
	return not input_paused and not ended and units[i].hp>0 and units[i].move in ["idle","run","walk","attack","hit"]

func _request(key:String,i:int)->void:
	var cost:=2 if key=="skill" else 3
	if not _free_to_cast(i) or units[i].sp+0.000001<float(cost):return
	var target:=_target(i)
	if target<0:return
	units[i].sp-=float(cost)
	if local_melee_polish and i==1 and key=="chain":
		var guard_index:=_squad_guard_candidate()
		_begin(i,"chain" if guard_index>=0 else "counter",target)
		units[i].guard_source=guard_index
	else:_begin(i,key,target)
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
	# Preserve the opening lane until its target falls, then reacquire the nearest living opponent.
	var initial:=[3,4,5,0,1,2]
	if units[initial[i]].hp>0:return initial[i]
	var best:=-1
	var nearest:=INF
	for j in range(3 if i<3 else 0,6 if i<3 else 3):
		if units[j].hp<=0:continue
		var d:float=units[i].feet.distance_squared_to(units[j].feet)
		if d<nearest:nearest=d;best=j
	return best

func _begin(i:int,key:String,target:int)->void:
	var u:=units[i]
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
		u.bom_close=SaebomMelee.saebom_close_at(gap,bool(u.get("bom_close",false)),65.,80.)
		u.bom_shove=key=="attack" and u.bom_close
		u.bom_hop=clampf(82.-gap,0.,24.) if key=="skill" and u.bom_close else 0.
		u.bom_near_skill=not saebom_distance_drill.is_empty() and key=="skill" and u.bom_close
		u.bom_strike=0
		if u.bom_near_skill:
			u.bom_hop=0.
			u.contact=dur*float(CLOSE_2SP_HIT_PHASES[0])
		u.bom_origin=u.feet
		var away:Vector2=u.feet-units[target].feet
		u.bom_dir=away.normalized()
		if u.bom_shove:
			u.contact=dur*.48
			u["close_basic_edge"]=Vector2.INF
	u.next=elapsed+maxf(dur+.28,1.26)

func _gap(i:int)->float:
	return 124.0 if i==2 else 59.0 if i==0 else 49.0

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

func tick(delta:float,paused:bool)->void:
	if paused:return
	acc+=minf(delta,.10)
	if spotlight_clock>=0.:
		spotlight_clock+=maxf(0.,delta)
		if spotlight_clock>=spotlight_duration:
			spotlight_clock=-1.;spotlight_attacker=-1;spotlight_defender=-1;combo_opener=-1
	while acc>=STEP:
		acc-=STEP;_step(STEP)
	_draw_pose(delta)

func _step(dt:float)->void:
	elapsed+=dt
	_update_saebom_range()
	for i in units.size():
		var u:=units[i];u.age+=dt
		if ended or u.hp<=0:continue
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
			if u.age>=u.actor.duration+extra and not (i==1 and u.move=="counter" and not uram_ordinary_wave.is_empty()):_play(u,"idle")
			continue
		if u.move=="hit":
			if u.age>=u.actor.duration:_play(u,"idle")
			continue
		if ours.distance_to(theirs)>_gap(i)+2.0:
			if u.move!="run":_play(u,"run")
			_approach(i,theirs,dt)
		elif elapsed>=u.next:
			_begin(i,"skill" if i>=3 and int(elapsed*1.45+i)%4==0 else "attack",target)
		elif u.move!="idle":_play(u,"idle")
	_update_projectiles(dt)
	_advance_uram_ordinary_wave()
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

func _resolve(i:int)->void:
	var u:=units[i];var j:int=u.victim
	if j<0 or units[j].hp<=0:return
	if i==2 and u.move=="chain":
		# Existing animation is a cheer: grant temporary team power, not a pretend hit.
		for k in 3:
			if units[k].hp>0 and (not local_melee_polish or units[k].feet.distance_to(u.feet)<=190.0):
				units[k].rally=elapsed+(5.0 if local_melee_polish else 4.0)
				if k!=i and bom_ally_draw.is_valid() and units[k].feet.distance_to(u.feet)<=190.0:
					group_bom_ally_events.append({"at":elapsed,"unit":k})
		if not authored_draw.is_valid():glints.append({"at":elapsed,"point":u.feet-Vector2(0,20),"tint":Color("ffc971")})
		hits.append({"from":i,"target":-1,"type":"rally","result":"support"})
		return
	if i==1 and u.move=="chain":
		if local_melee_polish and not bool(u.get("guarded",false)):
			_begin(i,"counter",j)
		return
	if local_melee_polish and i==1 and u.move=="counter":
		if u.feet.distance_to(units[j].feet)<=76.0:
			_finish_uram_ordinary_counter(j)
		else:
			var view:HybridCharacter=u.actor.preview
			var shield:Node3D=view.shield
			var origin:=view.position+(view.display.position+view.camera.unproject_position(shield.global_position)*view.display.scale)*view.scale
			var destination:=_deer_tip(units[j])
			uram_ordinary_wave={"to":j,"locked":units[j].actor,"from":origin,"at":elapsed,"span":UramCounterWave.duration(origin,destination)}
		return
	if i==2 and not saebom_distance_drill.is_empty():
		if u.move=="skill" and bool(u.get("bom_near_skill",false)):
			var hit_index:int=u.bom_strike
			u.bom_strike+=1
			if hit_index+1<CLOSE_2SP_HIT_PHASES.size():
				u.contact=float(u.actor.duration)*float(CLOSE_2SP_HIT_PHASES[hit_index+1])
			var amount:=roundi(float(CLOSE_2SP_FINAL_DAMAGE)*1.2) if u.rally>elapsed else CLOSE_2SP_FINAL_DAMAGE
			_resolve_saebom_near(i,j,amount,hit_index+1)
			return
	var damage:=14 if u.move=="attack" else 27 if u.move=="skill" else 38
	if i>=3:damage=11 if u.move=="attack" else 23
	if u.rally>elapsed:damage=roundi(damage*(1.20 if local_melee_polish else 1.25))
	var start:Vector2=u.feet-Vector2(0,30)
	var finish:Vector2=units[j].feet-Vector2(0,25)
	if i==2 and not (u.move=="attack" and bool(u.get("bom_shove",false))):
		if start.distance_to(finish)>149.0:_miss(i,j,"projectile");return
		var paired_presentation:=saebom_distance_drill=="far"
		if paired_presentation:_pose_ranged_release(u)
		var jewel:=_sling_stone(u)
		var release:=jewel if paired_presentation or (bom_trail_draw.is_valid() and jewel.distance_to(start)<65.0) else start
		# Original simulation uses start/destination; only drawn trail begins at the rig stone.
		missiles.append({"from":i,"target":j,"point":start,"destination":finish,"damage":damage,"kind":u.move,"trace":PackedVector2Array([release]),"origin":start,"paired_presentation":paired_presentation,"release":release,"rendered":release})
		return
	var range_px:=80.0 if i==2 and u.move=="attack" and bool(u.get("bom_shove",false)) else _gap(i)+8.0+(14.0 if u.move!="attack" else 0.0)
	if u.feet.distance_to(units[j].feet)>range_px:_miss(i,j,u.move);return
	if i==2 and _uses_close_basic_pose(u,j):
		# Capture the receiver pose before damage initializes the native hit clip.
		var target:Dictionary=units[j]
		var ball:=CloseBasicPose.sample(u,target,.48)
		target["close_basic_impulse"]=ball.strike_axis
		var receiver:Skeleton3D=target.actor.preview.skeleton
		target["close_basic_neck_pose"]=receiver.get_bone_pose_rotation(receiver.find_bone("neck"))
		target["close_basic_head_pose"]=receiver.get_bone_pose_rotation(receiver.find_bone("head"))
	_damage(i,j,damage,u.move)

func _finish_uram_ordinary_counter(j:int)->void:
	if j<3 or j>=units.size() or units[j].hp<=0:return
	_damage(1,j,18,"counter")
	if int(units[j].hp)>0:
		_play(units[j],"hit")
		units[j].next=maxf(float(units[j].next),elapsed+1.15)
		squad_stuns[j]=elapsed

func _advance_uram_ordinary_wave()->void:
	if uram_ordinary_wave.is_empty():return
	var to:int=uram_ordinary_wave.to
	if to<3 or to>=units.size() or units[to].hp<=0 or units[to].actor!=uram_ordinary_wave.locked or units[1].hp<=0:
		uram_ordinary_wave.clear()
		return
	if elapsed-float(uram_ordinary_wave.at)+1e-6<float(uram_ordinary_wave.span):return
	uram_wave_pop={"at":elapsed,"point":_deer_tip(units[to])}
	uram_ordinary_wave.clear()
	_finish_uram_ordinary_counter(to)

func _resolve_saebom_near(i:int,j:int,amount:int,variant:int)->void:
	var u:=units[i]
	var v:=units[j]
	var name:="saebom_melee_2sp_%d"%variant
	# First three beats still read visually. Only the existing fourth phase
	# can resolve the one aggregate damage event. An interruption before it
	# clears the action through _play, so no earlier damage can leak through.
	if variant<CLOSE_2SP_HIT_PHASES.size():
		if v.hp>0 and u.feet.distance_to(v.feet)<=72.:
			glints.append({"at":elapsed,"point":v.feet-Vector2(0,23),"tint":Color("ffc971")})
		return
	if v.hp<=0 or u.feet.distance_to(v.feet)>72.:
		_miss(i,j,name)
		return
	_damage(i,j,amount,name)

func _miss(i:int,j:int,key:String)->void:
	hits.append({"from":i,"target":j,"type":key,"result":"miss"})

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
		var cast_at:=elapsed-float(target.age)
		var new_guard:=absf(cast_at-last_gong_cast)>.03
		if new_guard:
			last_gong_cast=cast_at
			var shield:Node3D=target.actor.preview.shield
			var point:Vector2=target.feet-Vector2(0,25)
			if is_instance_valid(shield):
				var view:HybridCharacter=target.actor.preview
				point=view.position+(view.display.position+view.camera.unproject_position(shield.global_position)*view.display.scale)*view.scale
			if parry_dust.is_valid():_spotlight_parry(i,j,point)
			elif gong_draw.is_valid():
				var base:Vector2=target.feet
				var incoming:Vector2=units[i].feet
				gong_events.append({"at":elapsed,"point":point,"forward":base.direction_to(incoming)})
		if not parry_dust.is_valid() and not gong_draw.is_valid():
			glints.append({"at":elapsed,"point":target.feet-Vector2(0,25),"tint":Color("65e4cf")})
		if units[i].hp>0 and target.feet.distance_to(units[i].feet)<76.0:
			_damage(j,i,18,"counter")
			if local_melee_polish and int(units[i].hp)>0:
				_play(units[i],"hit")
				units[i].next=maxf(float(units[i].next),elapsed+1.15)
		return
	target.hp=maxi(0,int(target.hp)-amount)
	hits.append({"from":i,"target":j,"type":key,"result":"hit","hp":target.hp})
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
	elif not (i==2 and key=="attack" and _uses_close_basic_pose(units[i],j)):
		glints.append({"at":elapsed,"point":target.feet-Vector2(0,23) if stone_impact==Vector2.INF else stone_impact,"tint":Color("ffc971") if i<3 else Color("f0ffe8")})
	if target.hp<=0:_play(target,"death")
	elif target.move in ["idle","run","walk"]:_play(target,"hit")

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

func _sample_stock_close_2sp(actor,progress:float)->void:
	# Stable fallback while the new visual choreography is reviewed: reuse the
	# original close shove pose per actual contact and the ordinary hit glint.
	var beat:float=CLOSE_2SP_HIT_PHASES[0]
	for phase in CLOSE_2SP_HIT_PHASES:
		if absf(progress-float(phase))<absf(progress-beat):beat=float(phase)
	var from_beat:=progress-beat
	var phase:=clampf(.48+from_beat/(.20 if from_beat<0. else .18),0.,.99)
	SaebomMelee.saebom_shove_pose(actor,phase)

func _draw_pose(dt:float)->void:
	var ambient:=Color.WHITE.lerp(Color.BLACK,spotlight_dim())
	for i in units.size():
		var u:=units[i];var actor=u.actor
		var isolated:=spotlight_attacker==i or spotlight_defender==i
		var tint:=Color.WHITE if isolated else ambient
		actor.preview.modulate=tint
		u.ring.modulate=tint
		actor.preview.position=u.feet
		actor.preview.z_index=int(u.feet.y)
		u.ring.position=u.feet;u.ring.visible=u.hp>0
		if ring_project.is_valid() and u.hp>0:
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
		if i==2 and u.move=="skill" and float(u.get("bom_hop",0.))>0.:SaebomMelee.saebom_hop_pose(actor,float(u.age)/maxf(.01,float(actor.duration)),float(u.bom_hop)/24.)
		if i==2 and u.move=="skill" and bool(u.get("bom_near_skill",false)):
			_sample_stock_close_2sp(actor,float(u.age)/maxf(.01,float(actor.duration)))
		elif i==2 and u.move=="attack" and bool(u.get("bom_shove",false)):
			if show_basic:
				var target:Dictionary=units[int(u.victim)]
				var p:=clampf(float(u.age)/maxf(.01,float(actor.duration)),0.,1.)
				if p<.43 or not is_finite((u.get("close_basic_edge",Vector2.INF) as Vector2).x):
					u.close_basic_edge=CloseBasicPose.shoulder(target,u.feet)
				CloseBasicPose.sample(u,target,p)
				actor.preview.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			else:SaebomMelee.saebom_shove_pose(actor,float(u.age)/maxf(.01,float(actor.duration)))
		if i==2 and bom_pose.is_valid():bom_pose.call(actor,float(u.age) if u.move=="chain" and u.hp>0 else -1.0)
		if i==0:aim.anchor_spear_root(actor)
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
		huds[i].sync(u.sp,u.hp,MAX_HP,u.hp>0,_free_to_cast(i),dt)
	if is_instance_valid(uram_ground_layer):
		uram_ground_layer.self_modulate=ambient
		uram_ground_layer.queue_redraw()
	paint.self_modulate=ambient
	paint.queue_redraw()
	bars_paint.queue_redraw()
	if is_instance_valid(launch_dust_layer):
		launch_dust_layer.self_modulate=ambient
		launch_dust_layer.queue_redraw()
	if is_instance_valid(parry_front):
		parry_ground.queue_redraw()
		parry_front.queue_redraw()

func _draw_launch_dust()->void:
	for event in launch_dust_events:
		launch_dust_draw.call(event.origin,elapsed-float(event.at),launch_dust_layer)

func _paint_bars()->void:
	for u in units:
		if u.hp<=0:continue
		var at:Vector2=u.feet-Vector2(23,76)
		var back:=Rect2(at,Vector2(46,5))
		bars_paint.draw_rect(back,Color("211f23"))
		bars_paint.draw_rect(Rect2(at+Vector2.ONE,Vector2(44.0*float(u.hp)/MAX_HP,3)),Color("68c8ff") if u.id!="forest" else Color("ff8176"))

func _paint()->void:
	if not uram_ordinary_wave.is_empty():
		var p:float=(elapsed-float(uram_ordinary_wave.at))/float(uram_ordinary_wave.span)
		UramCounterWave.draw(paint,uram_ordinary_wave.from,_deer_tip(units[int(uram_ordinary_wave.to)]),p)
	if not uram_wave_pop.is_empty():
		UramCounterWave.draw_pop(paint,uram_wave_pop.point,elapsed-float(uram_wave_pop.at))
	var bom_active:=false
	for m in missiles:
		var drawn:Vector2=m.rendered if m.paired_presentation else m.point
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
			if not hands_empty and not (u.move=="attack" and bool(u.get("bom_shove",false))) and not (u.move=="skill" and bool(u.get("bom_near_skill",false))):weapon_draw.call(u.actor,Vector2.INF,after_release,paint)
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
		if units.size()>2 and units[2].move=="chain" and units[2].hp>0:
			var bom:=units[2]
			if bom_wings_draw.is_valid():
				bom_wings_draw.call(bom.feet,float(bom.age),paint)

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
	if saebom_distance_drill!="near":return false
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
