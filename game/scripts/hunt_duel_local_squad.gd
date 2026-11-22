extends Node2D

const Actor = preload("res://scripts/model_test_actor.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const Presenter = preload("res://scripts/duel_motion_presenter.gd")
const HUD = preload("res://scripts/duel_skill_hud.gd")
const Head = preload("res://scripts/battle_head_hud.gd")
const HEROES := ["hangyeol","uram","saebom"]
const HERO_SLOTS := [0,5,3]
const DEER_SLOTS := [4,2,3]
const MAX_HP := 100
const STEP := 1.0/120.0
const SaebomMelee=preload("res://scripts/duel_shared_world.gd")
var local_melee_polish:=false
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
var input_paused:=false
var hud_parent:Control
var paint:Node2D

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
		hud.requested.connect(_request.bind(i))
		huds.append(hud)
	_draw_pose(0.0)

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
	_begin(i,key,target)
	_draw_pose(0.0)

func _target(i:int)->int:
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
	_play(u,key)
	u.victim=target
	var dur:float=u.actor.duration
	u.contact=dur*.54
	if i>=3 and key=="skill":
		u.contact=float(u.actor.preview.length("req046_skill_anticipation"))+.14
	if i==2 and key!="chain":u.contact=dur*.61
	if i==2 and local_melee_polish and target>=0:
		var gap:float=u.feet.distance_to(units[target].feet)
		u.bom_close=SaebomMelee.saebom_close_at(gap,bool(u.get("bom_close",false)),65.,80.)
		u.bom_shove=key=="attack" and u.bom_close
		u.bom_hop=clampf(82.-gap,0.,24.) if key=="skill" and u.bom_close else 0.
		u.bom_origin=u.feet
		var away:Vector2=u.feet-units[target].feet
		u.bom_dir=away.normalized()
		if u.bom_shove:u.contact=dur*.48
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
	while acc>=STEP:
		acc-=STEP;_step(STEP)
	_draw_pose(delta)

func _step(dt:float)->void:
	elapsed+=dt
	for i in units.size():
		var u:=units[i];u.age+=dt
		if ended or u.hp<=0:continue
		if i<3:u.sp=minf(3.0,u.sp+dt/3.1)
		var target:=_target(i)
		if target<0:continue
		var ours:Vector2=u.feet
		var theirs:Vector2=units[target].feet
		if u.move in ["attack","skill","chain"]:
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
			if u.age>=u.actor.duration:_play(u,"idle")
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
	if i==1 and u.move=="chain":return # shield activates during the actual guard window
	var damage:=14 if u.move=="attack" else 27 if u.move=="skill" else 38
	if i>=3:damage=11 if u.move=="attack" else 23
	if u.rally>elapsed:damage=roundi(damage*(1.20 if local_melee_polish else 1.25))
	var start:Vector2=u.feet-Vector2(0,30)
	var finish:Vector2=units[j].feet-Vector2(0,25)
	if i==2 and not (u.move=="attack" and bool(u.get("bom_shove",false))):
		if start.distance_to(finish)>149.0:_miss(i,j,"projectile");return
		var jewel:=_sling_stone(u)
		var release:=jewel if bom_trail_draw.is_valid() and jewel.distance_to(start)<65.0 else start
		# Original simulation uses start/destination; only drawn trail begins at the rig stone.
		missiles.append({"from":i,"target":j,"point":start,"destination":finish,"damage":damage,"kind":u.move,"trace":PackedVector2Array([release]),"origin":start})
		return
	var range_px:=80.0 if i==2 and u.move=="attack" and bool(u.get("bom_shove",false)) else _gap(i)+8.0+(14.0 if u.move!="attack" else 0.0)
	if u.feet.distance_to(units[j].feet)>range_px:_miss(i,j,u.move);return
	_damage(i,j,damage,u.move)

func _miss(i:int,j:int,key:String)->void:
	hits.append({"from":i,"target":j,"type":key,"result":"miss"})

func _damage(i:int,j:int,amount:int,key:String)->void:
	var target:=units[j]
	if target.hp<=0:return
	if j==1 and target.move=="chain" and target.age>.07 and target.age<minf(.62,target.actor.duration):
		hits.append({"from":i,"target":j,"type":key,"result":"parried"})
		if gong_draw.is_valid():
			var cast_at:=elapsed-float(target.age)
			if absf(cast_at-last_gong_cast)>.03:
				last_gong_cast=cast_at
				var shield:Node3D=target.actor.preview.shield
				var point:Vector2=target.feet-Vector2(0,25)
				if is_instance_valid(shield):
					var view:HybridCharacter=target.actor.preview
					point=view.position+(view.display.position+view.camera.unproject_position(shield.global_position)*view.display.scale)*view.scale
				var base:Vector2=target.feet
				var incoming:Vector2=units[i].feet
				gong_events.append({"at":elapsed,"point":point,"forward":base.direction_to(incoming)})
		else:
			glints.append({"at":elapsed,"point":target.feet-Vector2(0,25),"tint":Color("65e4cf")})
		if units[i].hp>0 and target.feet.distance_to(units[i].feet)<76.0:_damage(j,i,18,"counter")
		return
	target.hp=maxi(0,int(target.hp)-amount)
	hits.append({"from":i,"target":j,"type":key,"result":"hit","hp":target.hp})
	if bom_hit_draw.is_valid() and i==2 and key=="skill":
		var feet:Vector2=target.feet
		var from:Vector2=units[i].feet
		group_bom_hits.append({"at":elapsed,"point":feet-Vector2(0,25),"forward":from.direction_to(feet)})
	elif silver_impact.is_valid() and i>=3 and key=="skill":
		var ground:Vector2=target.feet
		silver_hits.append({"at":elapsed,"center":ground-Vector2(0,23),"floor_point":ground,"unit":i})
	elif authored_draw.is_valid() and ((i==0 and key in ["skill","chain"]) or (i==2 and key=="skill")):
		var base:Vector2=units[i].feet
		var ground:Vector2=target.feet
		var tag:="saebom_hit" if i==2 else "han_skill" if key=="skill" else "han_chain"
		authored_events.append({"tag":tag,"at":elapsed,"point":ground-Vector2(0,23),"forward":base.direction_to(ground)})
	elif heavy_draw.is_valid() and i==1 and key=="skill":
		var from:Vector2=units[i].feet
		var ground:Vector2=target.feet
		heavy_events.append({"at":elapsed,"point":ground-Vector2(0,23),"ground":ground,"forward":from.direction_to(ground)})
	else:
		glints.append({"at":elapsed,"point":target.feet-Vector2(0,23),"tint":Color("ffc971") if i<3 else Color("f0ffe8")})
	if target.hp<=0:_play(target,"death")
	elif target.move in ["idle","run","walk"]:_play(target,"hit")

func _update_projectiles(dt:float)->void:
	for index in range(missiles.size()-1,-1,-1):
		var m:=missiles[index]
		m.point=m.point.move_toward(m.destination,340.0*dt)
		if bom_trail_draw.is_valid() and m.kind=="skill":
			var trace:PackedVector2Array=m.trace
			if trace[-1].distance_squared_to(m.point)>.28:trace.append(m.point)
			while trace.size()>16:trace.remove_at(0)
			m.trace=trace
		if m.point.distance_squared_to(m.destination)>.01:continue
		var u:=units[m.target]
		if u.hp>0 and m.destination.distance_to(u.feet-Vector2(0,25))<=19.0:_damage(m.from,m.target,m.damage,m.kind)
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
	for i in units.size():
		var u:=units[i];var actor=u.actor
		actor.preview.position=u.feet
		actor.preview.z_index=int(u.feet.y)
		u.ring.position=u.feet;u.ring.visible=u.hp>0
		if ring_project.is_valid() and u.hp>0:
			u.ring.position=Vector2.ZERO
			u.ring.points=ring_project.call(actor.preview,u.feet)
		if u.move!="death":
			var j:int=u.victim if u.move in ["skill","chain","attack"] else _target(i)
			if j>=0:
				var d:Vector2=units[j].feet-u.feet
				var heading:=_ground_heading(actor.preview.camera,d)
				actor.preview.pivot.rotation.y=heading-float(spear_forward_bias.get(u.move,0.0)) if i==0 else heading
		actor.sample(u.age,false)
		if i==2 and u.move=="skill" and float(u.get("bom_hop",0.))>0.:SaebomMelee.saebom_hop_pose(actor,float(u.age)/maxf(.01,float(actor.duration)),float(u.bom_hop)/24.)
		if i==2 and u.move=="attack" and bool(u.get("bom_shove",false)):SaebomMelee.saebom_shove_pose(actor,float(u.age)/maxf(.01,float(actor.duration)))
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
	for i in huds.size():
		var u:=units[i]
		huds[i].sync(u.sp,u.hp,MAX_HP,u.hp>0,_free_to_cast(i),dt)
	paint.queue_redraw()
	if is_instance_valid(launch_dust_layer):launch_dust_layer.queue_redraw()

func _draw_launch_dust()->void:
	for event in launch_dust_events:
		launch_dust_draw.call(event.origin,elapsed-float(event.at),launch_dust_layer)

func _paint()->void:
	for u in units:
		if u.hp<=0:continue
		var at:Vector2=u.feet-Vector2(23,76)
		var back:=Rect2(at,Vector2(46,5))
		paint.draw_rect(back,Color("211f23"))
		paint.draw_rect(Rect2(at+Vector2.ONE,Vector2(44.0*float(u.hp)/MAX_HP,3)),Color("68c8ff") if u.id!="forest" else Color("ff8176"))
	var bom_active:=false
	for m in missiles:
		if weapon_draw.is_valid() and m.from==2:
			bom_active=true
			if bom_trail_draw.is_valid() and m.kind=="skill":
				bom_trail_draw.call(m.trace,1.0,paint)
				continue
			weapon_draw.call(units[2].actor,m.point,false,paint)
		paint.draw_circle(m.point,3.0,Color("ffdf9c"))
	if weapon_draw.is_valid():
		if units[1].hp>0:weapon_draw.call(units[1].actor,Vector2.INF,false,paint)
		if units[2].hp>0 and not bom_active:
			var u:=units[2]
			var after_release:bool=u.move in ["attack","skill"] and u.contact<0.0
			var hands_empty:bool=bom_pose.is_valid() and u.move=="chain" and u.age>=.10 and u.age<2.24
			if not hands_empty and not (u.move=="attack" and bool(u.get("bom_shove",false))):weapon_draw.call(u.actor,Vector2.INF,after_release,paint)
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
	for spark in glints:
		var t:=clampf((elapsed-float(spark.at))/.45,0,1)
		var tint:Color=spark.tint
		paint.draw_arc(spark.point,lerpf(4,20,t),0,TAU,20,Color(tint,(1.0-t)*.88),2.0,true)






func _deer_tip(u:Dictionary)->Vector2:
	var view:HybridCharacter=u.actor.preview
	var sk:Skeleton3D=view.skeleton
	var idx:=sk.find_bone("head")
	if idx<0:return u.feet-Vector2(0,25)
	var point:=sk.to_global(sk.get_bone_global_pose(idx)*Vector3(0,.05,.23))
	return view.position+(view.display.position+view.camera.unproject_position(point)*view.display.scale)*view.scale




func _sling_stone(u:Dictionary)->Vector2:
	var v:HybridCharacter=u.actor.preview
	var sk:Skeleton3D=v.skeleton
	var idx:=sk.find_bone("sling_stone")
	if idx<0:return u.feet-Vector2(0,30)
	var p:=sk.to_global(sk.get_bone_global_pose(idx).origin)
	return v.position+(v.display.position+v.camera.unproject_position(p)*v.display.scale)*v.scale
