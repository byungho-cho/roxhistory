class_name GameState
extends RefCounted

signal notification_requested(event:String,payload:Dictionary)
signal changed
signal failed(message: String)

var state: Dictionary = {}
var store: SaveStore
var busy := false
# Runtime-only target ownership. Never consume a charge until harvest commits.
# Hero's queued and active work share an actor but have separate lifetime tokens.
var gather_claims:Dictionary={}
const RESPAWN_MIN_SECONDS := 300.0
const RESPAWN_MAX_SECONDS := 600.0
# Test-period default remains unlimited; a chosen single-builder mode survives reload.
var debug_unlimited_builders:bool:
	get:return bool(state.get("debug_unlimited_builders",true))
	set(value):set_debug_unlimited_builders(value)
var construction_busy := false
var debug_unlimited_buildings:bool:
	get:return bool(state.get("debug_unlimited_buildings",false))
	set(value):set_debug_unlimited_buildings(value)
var debug_fast_build:bool:
	get:return bool(state.get("debug_fast_build",false))
var debug_show_boundary:bool:
	get:return bool(state.get("debug_show_boundary",false))
	set(value):set_debug_show_boundary(value)
const OUTPOST_WOOD_COST := 10
const OUTPOST_STONE_COST := 10
const OUTPOST_UNLOCK_LEVEL := 3

# The chief's existing hut is not part of the resident-home save array.
func completed_hut_count() -> int:
	return 0 if state.is_empty() else (1 if chief_level()>0 else 0)+built_count()

func outpost_unlocked() -> bool:
	return building_unlocked("outpost")

func can_build_outpost() -> bool:
	return can_construct("outpost")

func outpost_requirement() -> String:
	return building_requirement("outpost")

func outposts() -> Array:
	return state.get("outposts",[]).duplicate(true)

func outpost_position(index:int) -> Vector2:
	var list:=outposts()
	if index<0 or index>=list.size():return Vector2.INF
	return entry_position(list[index])

func chief_level() -> int:
	return int(state.get("chief_level",0 if state.get("hq_can_be_absent",false) else 1))

func chief_upgrade_cost() -> Dictionary:
	return building_cost("chief",chief_level()+1)

func can_upgrade_chief() -> bool:
	if state.is_empty() or chief_level()<1 or chief_level()>=4 or state.has("chief_upgrade") or not builder_available():return false
	var cost:=chief_upgrade_cost()
	return state.wood>=cost.wood and state.stone>=cost.stone

func chief_upgrade_duration(target_level:int) -> float:
	return BuildingRules.duration(target_level)

func upgrade_chief(now:float=-1.0) -> bool:
	if busy or not can_upgrade_chief():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	busy=true
	var next:=state.duplicate(true)
	var job:=BuildingRules.new_job("chief",chief_level(),now,debug_fast_build)
	next.wood-=job.cost.wood;next.stone-=job.cost.stone
	next.chief_upgrade=job
	var ok:=commit(next)
	busy=false
	return ok

func chief_upgrade_remaining(now:float=-1.0) -> float:
	if not state.has("chief_upgrade"):return 0.0
	if now<0:now=Time.get_unix_time_from_system()
	return maxf(0.0,float(state.chief_upgrade.finishes_at)-now)

func finish_chief_upgrade(now:float=-1.0) -> bool:
	if busy or not state.has("chief_upgrade"):return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now) or now<float(state.chief_upgrade.finishes_at):return false
	busy=true
	var next:=state.duplicate(true)
	next.chief_level=int(next.chief_upgrade.to)
	next.erase("chief_upgrade")
	prepare_resource_positions(next)
	var ok:=commit(next)
	busy=false
	if ok:VillageNotifications.dispatch(self,"upgrade",{"kind":"chief"})
	return ok

# Same atomic payment/save transaction as huts. Outposts do not count toward
# housing, family arrival or seed rewards. Existing towers survive relocking.
func build_outpost(_pos:Vector2=Vector2.ZERO, site_id:int=-1) -> bool:
	if site_id<0:
		for i in DemoConfig.BUILD_SITES.size():
			if site_free(i):site_id=i;break
	if site_id<0 or not site_free(site_id):return false
	return begin_construction("outpost",DemoConfig.BUILD_SITES[site_id],-1,site_id)

func all_nodes() -> Array:
	var result:Array=DemoConfig.get_data().nodes.duplicate(true)
	for n in result:
		if state.get("node_positions",{}).has(n.id):n.position=state.node_positions[n.id].duplicate()
	return result

func nodes()->Array:
	var catalog:=all_nodes()
	# Interleave kinds so each HQ tier has both wood and stone sources.
	var wood:Array=[];var stone:Array=[]
	for n in catalog:
		if n.kind=="wood":wood.append(n)
		else:stone.append(n)
	var active:Array=[]
	while active.size()<resource_node_limit() and (not wood.is_empty() or not stone.is_empty()):
		if not wood.is_empty():active.append(wood.pop_front())
		if active.size()<resource_node_limit() and not stone.is_empty():active.append(stone.pop_front())
	return active

func resource_node_limit()->int:
	return [5,10,10,20][clampi(chief_level(),1,4)-1]

func prepare_resource_positions(next:Dictionary)->void:
	if not next.has("resource_seed"):next.resource_seed=randi_range(1,2147483646)
	if not next.has("node_positions"):next.node_positions={}
	var previous:Dictionary=state
	state=next
	var active:=nodes()
	var bounds:=VillageBounds.rect_for_level(chief_level()).grow(-100)
	var occupied:Array=[];var missing:Array=[]
	for n in active:
		if next.node_positions.has(n.id) and bounds.has_point(DemoConfig.point(next.node_positions[n.id])):
			occupied.append(DemoConfig.point(next.node_positions[n.id]))
		else:missing.append(n.id)
	var reserved:Array=[]
	if chief_level()>0:reserved.append(building_position("chief"))
	for key in OwnedBuildingUpgrades.keys(self):reserved.append(building_position(key))
	var positions:=ResourcePlacement.generate(int(next.resource_seed),chief_level(),missing.size(),occupied,reserved)
	for i in mini(missing.size(),positions.size()):next.node_positions[missing[i]]=[positions[i].x,positions[i].y]
	next.resource_placement_revision=36
	state=previous

func migrate_resource_positions()->bool:
	if state.is_empty():return true
	var next:=state.duplicate(true)
	prepare_resource_positions(next)
	return true if next==state else commit(next)

func ensure_respawn_timers(now:float=-1.0)->bool:
	if busy or state.is_empty():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=state.duplicate(true)
	if not next.has("respawn_due"):next.respawn_due={}
	var changed_timer:=false
	for n in all_nodes():
		if int(next.depleted.get(n.id,0))>=int(n.charges) and not next.respawn_due.has(n.id):
			next.respawn_due[n.id]=now+randf_range(RESPAWN_MIN_SECONDS,RESPAWN_MAX_SECONDS)
			changed_timer=true
	return commit(next) if changed_timer else false

func respawn(id:String, at:Vector2, now:float=-1.0) -> bool:
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now) or not at.is_finite():return false
	if busy or float(state.get("respawn_due",{}).get(id,INF))>now:return false
	for n in nodes():
		if n.id!=id or int(state.depleted.get(id,0))<int(n.charges):continue
		var next:=state.duplicate(true)
		next.depleted[id]=0;next.respawn_due.erase(id)
		if not next.has("node_positions"):next.node_positions={}
		next.node_positions[id]=[at.x,at.y]
		return commit(next)
	return false

func _init(save_store: SaveStore) -> void:
	store = save_store
	state = store.load_game()
	migrate_village()
	migrate_resources()
	migrate_resource_positions()
	migrate_economy()
	ensure_respawn_timers()
	finish_constructions()
	finish_chief_upgrade()
	OwnedBuildingUpgrades.finish(self)
	if debug_fast_build and state.get("fast_build_mode","")!="fixed5":set_debug_fast_build(true)

func commit(next: Dictionary, reset: bool = false) -> bool:
	if not store.save_game(next,reset):
		failed.emit(store.message)
		return false
	state = next
	prune_gather_claims()
	changed.emit()
	return true

func start_new() -> bool:
	var next:=DemoConfig.fresh()
	prepare_resource_positions(next)
	var ok:=commit(next,true)
	if ok:
		gather_claims.clear()
		debug_unlimited_builders=true
		construction_busy=false
		busy=false
	return ok

func save_position(pos: Vector2) -> bool:
	if state.is_empty():
		return false
	var next := state.duplicate(true)
	next.position = [pos.x,pos.y]
	return commit(next)

func gather(node_id: String, pos: Vector2 = Vector2.ZERO, now:float=-1.0) -> bool:
	if busy or state.is_empty() or not gather_available(node_id,"hero"):
		return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	busy = true
	for n in nodes():
		if n.id != node_id:
			continue
		var next := state.duplicate(true)
		var count := int(next.depleted.get(node_id,0))
		if ResourceStorage.room(self,n.kind)<=0:
			busy=false;return false
		if count >= n.charges:
			busy = false
			return false
		next.depleted[node_id] = count+1
		if count+1>=int(n.charges):
			if not next.has("respawn_due"):next.respawn_due={}
			next.respawn_due[node_id]=now+randf_range(RESPAWN_MIN_SECONDS,RESPAWN_MAX_SECONDS)
		ResourceStorage.receive(self,next,n.kind,int(DemoConfig.get_data().gather_yield))
		if pos != Vector2.ZERO:
			next.position = [pos.x,pos.y]
		var ok := commit(next)
		busy = false
		return ok
	busy = false
	return false

func can_build() -> bool:
	return can_construct("hut")

func homes() -> Array:
	if state.has("homes"): return state.homes.duplicate(true)
	# Migrate the existing one-home save without rerolling or granting again.
	return [{"style":int(state.get("hut_style",0)),"claimed":bool(state.get("reward_claimed",false))}] if state.get("built",false) else []

func built_count() -> int: return homes().size()

func reward_pending(index: int) -> bool:
	return false # Copper income rules pending; legacy claimed flags remain preserved.

func home_position(index:int)->Vector2:
	var list:=homes()
	if index<0 or index>=list.size():return Vector2.INF
	return entry_position(list[index],int(list[index].get("legacy_slot",index)))

func home_key(index:int)->String:
	var list:=homes()
	if index<0 or index>=list.size():return ""
	return str(list[index].get("uid","legacy-"+str(list[index].get("legacy_slot",index))))

func stable_homes()->Array:
	var list:=homes()
	for i in list.size():
		if not list[i].has("site") and not list[i].has("position"):list[i].legacy_slot=int(list[i].get("legacy_slot",i))
		list[i].uid=home_key(i)
	return list

func demolition_quote(key:String)->Dictionary:
	if key=="chief":return {}
	var found:=lookup_building(key)
	if found.is_empty() or found.data.has("upgrade"):return {}
	var departures:=0
	if found.collection=="homes":
		var remaining:=homes();remaining.remove_at(int(found.index))
		departures=maxi(0,resident_count()-housing_capacity(remaining))
	var cost:Dictionary=found.data.get("cost",{"wood":1,"stone":1})
	var result:Dictionary={"index":int(found.index),"collection":found.collection,"kind":found.kind,"wood":0,"stone":0,"supported":true,"departures":departures}
	for resource in ["wood","stone"]:
		var paid:=int(cost[resource])
		var tenths:=paid*10 if paid<=10 else paid*9
		# Preserve the approved demolition rule; cancelling a job is always100%.
		result[resource]=tenths/10
	return result

func demolish(key:String)->bool:
	if busy:return false
	var quote:=demolition_quote(key)
	if quote.is_empty() or not quote.supported:return false

	var next:=state.duplicate(true)
	if quote.collection=="homes":next.homes=stable_homes()
	next[quote.collection].remove_at(int(quote.index))
	next.wood+=int(quote.wood);next.stone+=int(quote.stone)
	if quote.collection=="homes":
		next.built=not next.homes.is_empty()
		next.reward_claimed=next.homes[0].claimed if next.built else false
		next.hut_style=next.homes[0].style if next.built else 0
		ResidentJobs.remove_excess(next,int(quote.departures))
	ResidentJobs.clear_building(next,key)
	if next.get("farm_cycles",{}).has(key):
		var stock:=int(next.farm_cycles[key].stock)
		if stock>0:
			if not next.has("held_cargo"):next.held_cargo=[]
			next.held_cargo.append({"kind":"grain","amount":stock,"reason":"farm_demolition"})
		next.farm_cycles.erase(key)
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func site_free(id:int)->bool:
	return id>=0 and id<DemoConfig.BUILD_SITES.size() and placement_requirement("hut",DemoConfig.BUILD_SITES[id]).is_empty()

func build(_pos: Vector2 = Vector2.ZERO, site_id:int=-1) -> bool:
	if site_id<0:
		for i in DemoConfig.BUILD_SITES.size():
			if site_free(i):site_id=i;break
	if site_id<0 or not site_free(site_id):return false
	return begin_construction("hut",DemoConfig.BUILD_SITES[site_id],-1,site_id)

func claim_reward(_index: int = 0) -> bool:
	# Copper collection amount and interval remain unspecified. Retain legacy
	# claimed flags and balances; do not issue the former seed reward again.
	return false

func migrate_village()->bool:
	if state.is_empty() or int(state.get("terrain_revision",0))>=34:return true
	var next:=state.duplicate(true)
	next.homes=stable_homes()
	# Preserve stable identity, style, costs and claimed flags; remap plots only once.
	for i in next.homes.size():next.homes[i].site=i;next.homes[i].erase("legacy_slot")
	next.position=DemoConfig.get_data().spawn.duplicate()
	next.node_positions={}
	next.terrain_revision=34
	next.family_joined=false
	next.family_unlocked=next.homes.size()>=DemoConfig.HOME_GOAL
	return commit(next)

func family_available()->bool:
	return ResidentAdmission.available(self)

func join_family()->bool:
	return ResidentAdmission.join(self)

func family_visitor_count()->int:
	return ResidentAdmission.visitor_count(state)

func ensure_family_visit(now:float=-1)->bool:
	return ResidentAdmission.prepare_visit(self,now)

func migrate_resources()->bool:
	if state.is_empty() or int(state.get("resource_revision",0))>=35:return true
	var next:=state.duplicate(true)
	for n in DemoConfig.get_data().nodes:
		var used:=int(next.depleted.get(n.id,0))
		var old_max:=5 if n.kind=="wood" else 4
		# Keep fully exhausted sources exhausted. Preserve earned balances and timers.
		next.depleted[n.id]=int(n.charges) if used>=old_max else mini(used,int(n.charges)-1)
	next.resource_revision=35
	return commit(next)

# New-action rules intentionally do not invalidate legacy ownership or jobs.
func home_limit()->int:
	return BuildingRules.MAX_ENTRIES if debug_unlimited_buildings else mini(DemoConfig.MAX_RESIDENT_HOMES,chief_level())

func resident_capacity()->int:
	return housing_capacity(homes())

func housing_capacity(list:Array)->int:
	var capacity:=0
	for home in list:capacity += [1,2,3,5][clampi(int(home.get("level",1)),1,4)-1]
	return mini(ResidentAdmission.MAX_RESIDENTS,capacity)

func resident_count()->int:
	return ResidentAdmission.count(state)

func active_builder_jobs()->int:
	var count:=(1 if state.has("chief_upgrade") else 0)+construction_jobs().size()
	if construction_busy:count+=1
	for collection in [homes(),outposts(),facilities()]:
		for entry in collection:
			if entry.has("upgrade"):count+=1
	return count

func builder_available()->bool:
	return debug_unlimited_builders or active_builder_jobs()==0

func building_unlocked(kind:String)->bool:
	kind=BuildingRules.canonical(kind)
	if kind in ["stone_store","wood_store"]:
		var farms:=0
		for item in facilities():
			if item.kind=="farm":farms+=1
		if built_count()==0 or farms==0:return false
	return not state.is_empty() and BuildingRules.REQUIRED_HQ.has(kind) and chief_level()>=int(BuildingRules.REQUIRED_HQ[kind]) and (kind!="farm" or built_count()>0)

func building_requirement(kind:String)->String:
	kind=BuildingRules.canonical(kind)
	if state.is_empty():return "게임을 먼저 시작해 주세요"
	if not BuildingRules.REQUIRED_HQ.has(kind):return "아직 지원하지 않는 건물이에요"
	if kind in ["stone_store","wood_store"]:
		if built_count()==0:return "주민 움집 1채를 먼저 지어 주세요"
		var farms:=0
		var stores:=pending_construction_count(kind)
		for item in facilities():
			if item.kind=="farm":farms+=1
			if item.kind==kind:stores+=1
		if farms==0:return "농장 1개를 먼저 지어 주세요"
		if stores>=1:return "%s은 1개만 지을 수 있어요"%BuildingWorkflow.building_name(kind)
		if not BuildingRules.STORAGE_TIMING_CONFIRMED:return "저장 건물 공사 시간 확인 대기 중"
	if kind=="farm" and built_count()==0:return "주민 움집 1채를 먼저 지어 주세요"
	if not building_unlocked(kind):return "촌장집 Lv.%d 필요" % int(BuildingRules.REQUIRED_HQ[kind])
	if kind=="chief":
		if chief_level()>0:return "촌장집가 이미 있어요"
		if pending_construction_count(kind)>0:return "촌장집를 건설 중이에요"
	if kind=="hut":
		var reserved:=built_count()+pending_construction_count(kind)
		if not debug_unlimited_buildings and reserved>=DemoConfig.MAX_RESIDENT_HOMES:return "주민 움집은 최대 3채까지 지을 수 있어요"
		if reserved>=home_limit():return "촌장집 Lv.%d 필요 · 현재 움집 한도 %d채" % [chief_level()+1,home_limit()]
	if not debug_unlimited_buildings and kind in ["hearth","shrine"]:
		var count:=pending_construction_count(kind)
		for entry in facilities():
			if str(entry.kind)==kind:count+=1
		if count>=1:return "%s은 1개만 지을 수 있어요" % BuildingWorkflow.building_name(kind)
	if not builder_available():return "건설자 1명이 작업 중이에요"
	if construction_jobs().size()>=BuildingRules.MAX_ENTRIES:return "건설 중인 건물이 너무 많아요"
	if kind=="outpost" and not debug_unlimited_buildings and outposts().size()+pending_construction_count(kind)>=3:return "초소는 최대 3개예요"
	if kind=="farm" and not debug_unlimited_buildings:
		var farms:=pending_construction_count(kind)
		for facility in facilities():
			if facility.kind=="farm":farms+=1
		if farms>=mini(3,chief_level()):return "현재 농장 한도 %d개"%mini(3,chief_level())
	if kind in BuildingRules.FACILITY_KINDS:
		var pending_facilities:=0
		for job in construction_jobs():
			if str(job.kind) in BuildingRules.FACILITY_KINDS:pending_facilities+=1
		if facilities().size()+pending_facilities>=BuildingRules.MAX_ENTRIES:return "시설 한도에 도달했어요"
	var cost:=building_cost(kind,1)
	if state.wood<cost.wood or state.stone<cost.stone:return "나무 %d개와 돌 %d개가 필요해요" % [cost.wood,cost.stone]
	return ""

func upgrade_requirement(key:String="chief")->String:
	var found:=lookup_building(key)
	if found.is_empty():return "건물을 찾을 수 없어요"
	if found.kind in ["stone_store","wood_store"] and not BuildingRules.STORAGE_TIMING_CONFIRMED:return "저장 건물 공사 시간 확인 대기 중"
	var level:=int(found.data.get("level",1))
	if found.data.has("upgrade"):return "이미 업그레이드 중이에요"
	if level>=4:return "최고 레벨이에요"
	if key!="chief" and level>=chief_level():return "촌장집 Lv.%d 필요" % (level+1)
	if not builder_available():return "건설자 1명이 작업 중이에요"
	var cost:=building_cost(found.kind,level+1)
	if state.wood<cost.wood or state.stone<cost.stone:return "나무 %d개와 돌 %d개가 필요해요" % [cost.wood,cost.stone]
	return ""

func building_cost(kind:String,target:int=1)->Dictionary:
	return BuildingRules.cost(kind,target)

func building_duration(target:int)->float:
	return BuildingRules.DEVELOPMENT_DURATION if debug_fast_build else BuildingRules.duration(target)

func facilities()->Array:
	return state.get("facilities",[]).duplicate(true)

func construction_jobs()->Array:
	return state.get("construction_jobs",[]).duplicate(true)

func pending_construction_count(kind:String)->int:
	kind=BuildingRules.canonical(kind)
	var count:=0
	for job in construction_jobs():
		if job.kind==kind:count+=1
	return count

func can_construct(kind:String)->bool:
	return building_requirement(kind).is_empty()

func entry_position(entry:Dictionary,legacy_slot:int=-1)->Vector2:
	if entry.has("position"):return DemoConfig.point(entry.position)
	if entry.has("site"):return DemoConfig.BUILD_SITES[int(entry.site)]
	return DemoConfig.HOME_SITES[legacy_slot] if legacy_slot>=0 and legacy_slot<DemoConfig.HOME_SITES.size() else Vector2.INF

func lookup_building(key:String)->Dictionary:
	if key!="chief":return OwnedBuildingUpgrades.lookup(self,key)
	if state.is_empty() or chief_level()<1:return {}
	var data:Dictionary={"uid":"chief","kind":"chief","level":chief_level()}
	if state.has("chief_upgrade"):data.upgrade=state.chief_upgrade.duplicate(true)
	return {"collection":"chief","index":-1,"data":data,"position":building_position("chief"),"kind":"chief","key":"chief"}

func building_position(key:String)->Vector2:
	if key=="chief":return DemoConfig.point(state.chief_position) if state.has("chief_position") else DemoConfig.CHIEF_POSITION
	var found:=OwnedBuildingUpgrades.lookup(self,key)
	return found.position if not found.is_empty() else Vector2.INF

func placement_requirement(kind:String,position:Vector2,ignore_key:String="")->String:
	kind=BuildingRules.canonical(kind)
	if not kind in BuildingRules.KINDS:return "지원하지 않는 건물이에요"
	if not ignore_key.is_empty():
		var moving:=lookup_building(ignore_key)
		if not moving.is_empty() and moving.data.has("upgrade"):return "공사를 완료하거나 취소한 후 이동할 수 있어요"
	if not position.is_finite() or not VillageBounds.rect_for_level(chief_level()).grow(-100).has_point(position):return "마을 경계 안에 배치해 주세요"
	var candidate:=EnvironmentProp.hut_footprint(230)
	for k in candidate.size():candidate[k]+=position
	var occupied_positions:Array[Vector2]=[]
	if chief_level()>0 and ignore_key!="chief":occupied_positions.append(building_position("chief"))
	for key in OwnedBuildingUpgrades.keys(self):
		if key!=ignore_key:occupied_positions.append(building_position(key))
	for job in construction_jobs():
		if str(job.uid)!=ignore_key:occupied_positions.append(DemoConfig.point(job.position))
	for occupied_position in occupied_positions:
		var occupied:=EnvironmentProp.hut_footprint(340)
		for k in occupied.size():occupied[k]+=occupied_position
		if not Geometry2D.intersect_polygons(candidate,occupied).is_empty():return "다른 건물과 겹쳐요"
	return ""

func move_building(key:String,position:Vector2)->bool:
	if busy:return false
	var found:=lookup_building(key)
	if found.is_empty() or found.data.has("upgrade") or not placement_requirement(found.kind,position,key).is_empty():return false
	var next:=state.duplicate(true)
	if key=="chief":next.chief_position=[position.x,position.y]
	else:
		if found.collection=="homes":next.homes=stable_homes()
		var entry:Dictionary=next[found.collection][found.index]
		entry.position=[position.x,position.y]
		entry.erase("site");entry.erase("legacy_slot")
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func begin_construction(kind:String,position:Vector2,now:float=-1.0,site_id:int=-1)->bool:
	kind=BuildingRules.canonical(kind)
	if busy or not can_construct(kind) or not placement_requirement(kind,position).is_empty():return false
	if site_id>=0 and (site_id>=DemoConfig.BUILD_SITES.size() or position!=DemoConfig.BUILD_SITES[site_id]):return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=state.duplicate(true)
	next.construction_serial=int(next.get("construction_serial",0))+1
	var job:=BuildingRules.new_job(kind,0,now,debug_fast_build)
	job.uid="construction-"+str(next.construction_serial)
	job.position=[position.x,position.y]
	if site_id>=0:job.site=site_id
	if kind=="hut":job.style=1
	next.construction_jobs=construction_jobs()
	next.construction_jobs.append(job)
	next.wood-=int(job.cost.wood);next.stone-=int(job.cost.stone)
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func cancel_construction(uid:String)->bool:
	if busy:return false
	var jobs:=construction_jobs()
	for i in jobs.size():
		if str(jobs[i].uid)!=uid:continue
		if Time.get_unix_time_from_system()>=float(jobs[i].finishes_at):
			finish_constructions();return false
		var next:=state.duplicate(true)
		next.wood+=int(jobs[i].cost.wood);next.stone+=int(jobs[i].cost.stone)
		jobs.remove_at(i);next.construction_jobs=jobs
		busy=true
		var ok:=commit(next)
		busy=false
		return ok
	return false

func finish_constructions(now:float=-1.0)->bool:
	if busy or state.is_empty():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=state.duplicate(true)
	var pending:Array=[]
	next.homes=stable_homes()
	var did_finish:=false
	for job in construction_jobs():
		if now<float(job.finishes_at):pending.append(job);continue
		did_finish=true
		if job.kind=="chief":
			next.chief_level=1;next.chief_position=job.position.duplicate()
			continue
		var entry:Dictionary={"uid":job.uid,"kind":job.kind,"position":job.position.duplicate(),"level":1,"cost":job.cost.duplicate()}
		if job.has("site"):entry.site=job.site
		var collection:String="facilities"
		if job.kind=="hut":
			collection="homes";entry.style=int(job.get("style",1));entry.claimed=false
			if not next.has("homes"):next.homes=stable_homes()
		elif job.kind=="outpost":collection="outposts"
		if not next.has(collection):next[collection]=[]
		next[collection].append(entry)
	if not did_finish:return false
	var completed:Array=[]
	for job in construction_jobs():
		if now>=float(job.finishes_at):completed.append(str(job.kind))
	next.construction_jobs=pending
	next.built=not next.get("homes",[]).is_empty()
	if next.built:
		next.reward_claimed=next.homes[0].claimed;next.hut_style=next.homes[0].style
	prepare_resource_positions(next)
	busy=true
	var ok:=commit(next)
	busy=false
	if ok:
		for kind in completed:VillageNotifications.dispatch(self,"construction",{"kind":kind})
	return ok

func cancel_upgrade(key:String)->bool:
	if key!="chief":return OwnedBuildingUpgrades.cancel(self,key)
	if busy or not state.has("chief_upgrade"):return false
	if chief_upgrade_remaining()<=0:finish_chief_upgrade();return false
	var next:=state.duplicate(true)
	next.wood+=int(next.chief_upgrade.cost.wood);next.stone+=int(next.chief_upgrade.cost.stone)
	next.erase("chief_upgrade")
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func set_debug_fast_build(enabled:bool,now:float=-1.0)->bool:
	if busy or state.is_empty():return false
	if enabled==debug_fast_build and state.get("fast_build_mode","")=="fixed5":return true
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=state.duplicate(true)
	if next.has("chief_upgrade"):BuildingRules.set_clock_mode(next.chief_upgrade,now,enabled)
	for job in next.get("construction_jobs",[]):BuildingRules.set_clock_mode(job,now,enabled)
	for collection in ["homes","outposts","facilities"]:
		for entry in next.get(collection,[]):
			if entry.has("upgrade"):BuildingRules.set_clock_mode(entry.upgrade,now,enabled)
	next.debug_fast_build=enabled
	next.fast_build_mode="fixed5"
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func set_debug_show_boundary(enabled:bool)->bool:
	if busy or state.is_empty():return false
	if enabled==debug_show_boundary:return true
	var next:=state.duplicate(true);next.debug_show_boundary=enabled
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func set_debug_unlimited_buildings(enabled:bool)->bool:
	if busy or state.is_empty():return false
	var next:=state.duplicate(true);next.debug_unlimited_buildings=enabled
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func set_debug_unlimited_builders(enabled:bool)->bool:
	if busy or state.is_empty():return false
	if enabled==debug_unlimited_builders:return true
	var next:=state.duplicate(true);next.debug_unlimited_builders=enabled
	busy=true
	var ok:=commit(next)
	busy=false
	return ok

func migrate_economy()->bool:
	if state.is_empty() or state.has("grain"):return true
	var next:=state.duplicate(true)
	next.grain=int(next.tokens);next.copper=int(next.get("copper",0))
	return commit(next)

func nearest_home(from:Vector2)->Vector2:
	var best:=Vector2.INF;var distance:=INF
	for i in built_count():
		var at:=home_position(i)
		if at.distance_squared_to(from)<distance:best=at;distance=at.distance_squared_to(from)
	return best

func gather_available(target:String,owner:String)->bool:
	var valid_target:=false
	for node in nodes():
		if node.id==target and ResourceStorage.room(self,node.kind)>0 and int(state.depleted.get(target,0))<int(node.charges):valid_target=true;break
	if not valid_target:return false
	for claimant in gather_claims:
		if gather_claims[claimant]==target and gather_actor(claimant)!=gather_actor(owner):return false
	return true

func claim_gather(target:String,owner:String)->bool:
	if owner.is_empty() or not gather_available(target,owner):return false
	for node in nodes():
		if node.id==target and ResourceStorage.room(self,node.kind)>0 and int(state.depleted.get(target,0))<int(node.charges):
			gather_claims[owner]=target;return true
	return false

func release_gather(owner:String)->void:gather_claims.erase(owner)
func owns_gather(target:String,owner:String)->bool:return gather_claims.get(owner,"")==target
func gather_actor(owner:String)->String:return "hero" if owner in ["hero","hero-pending"] else owner

func prune_gather_claims()->void:
	var catalog:Dictionary={}
	for node in nodes():catalog[node.id]=node
	for owner in gather_claims.keys():
		var target:String=gather_claims[owner]
		if not catalog.has(target) or int(state.depleted.get(target,0))>=int(catalog[target].charges):
			gather_claims.erase(owner);continue
		if gather_actor(owner)!="hero":
			var item:Dictionary=state.get("resident_jobs",{}).get(owner,{})
			if owner not in ResidentAdmission.ids(state) or item.get("job","")!=catalog[target].kind or not item.get("cargo",{}).is_empty():gather_claims.erase(owner)

func debug_fill_resources()->bool:
	if busy or state.is_empty():return false
	var next:=state.duplicate(true)
	for kind in ["wood","stone","grain"]:next[kind]=maxi(int(next.get(kind,0)),9999)
	busy=true
	var ok:=commit(next)
	busy=false
	return ok
