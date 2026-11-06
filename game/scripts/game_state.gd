class_name GameState
extends RefCounted

signal changed
signal failed(message: String)

var state: Dictionary = {}
var store: SaveStore
var busy := false
const RESPAWN_MIN_SECONDS := 300.0
const RESPAWN_MAX_SECONDS := 600.0
# Runtime-only test-period default: builder count is shown, concurrency is unlimited.
# Turning this off enforces the planned single-builder rule; never persisted.
var debug_unlimited_builders := true
var construction_busy := false
const OUTPOST_WOOD_COST := 15
const OUTPOST_STONE_COST := 10
const OUTPOST_UNLOCK_LEVEL := 4

# The chief's existing hut is not part of the resident-home save array.
func completed_hut_count() -> int:
	return 0 if state.is_empty() else 1+built_count()

func outpost_unlocked() -> bool:
	return building_unlocked("outpost")

func can_build_outpost() -> bool:
	return not state.is_empty() and outpost_unlocked() and builder_available() and state.wood >= OUTPOST_WOOD_COST and state.stone >= OUTPOST_STONE_COST

func outpost_requirement() -> String:
	if not outpost_unlocked():
		return building_requirement("outpost")
	if not builder_available():return "건설자 1명이 작업 중이에요"
	return "나무 15개와 돌 10개가 필요해요"

func outposts() -> Array:
	return state.get("outposts",[]).duplicate(true)

func outpost_position(index:int) -> Vector2:
	var list:=outposts()
	return DemoConfig.BUILD_SITES[int(list[index].site)] if index>=0 and index<list.size() else Vector2.INF

func chief_level() -> int:
	return int(state.get("chief_level",1))

func chief_upgrade_cost() -> Dictionary:
	var c:=DemoConfig.get_data()
	return {"wood":int(c.wood_cost),"stone":int(c.stone_cost)}

func can_upgrade_chief() -> bool:
	if state.is_empty() or chief_level()>=4 or state.has("chief_upgrade") or not builder_available():return false
	var cost:=chief_upgrade_cost()
	return state.wood>=cost.wood and state.stone>=cost.stone

func chief_upgrade_duration(target_level:int) -> float:
	return float(DemoConfig.get_data().build_seconds)*pow(2.0,target_level-1)

func upgrade_chief(now:float=-1.0) -> bool:
	if busy or not can_upgrade_chief():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	busy=true
	var next:=state.duplicate(true)
	var cost:=chief_upgrade_cost()
	next.wood-=cost.wood;next.stone-=cost.stone
	var target:=chief_level()+1
	next.chief_upgrade={"from":chief_level(),"to":target,"started_at":now,"finishes_at":now+chief_upgrade_duration(target),"cost":cost}
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
	return ok

# Same atomic payment/save transaction as huts. Outposts do not count toward
# housing, family arrival or seed rewards. Existing towers survive relocking.
func build_outpost(pos:Vector2=Vector2.ZERO, site_id:int=-1) -> bool:
	if busy or not can_build_outpost() or not site_free(site_id):return false
	busy=true
	var next:=state.duplicate(true)
	next.wood-=OUTPOST_WOOD_COST;next.stone-=OUTPOST_STONE_COST
	next.outposts=outposts()
	next.outpost_serial=int(next.get("outpost_serial",0))+1
	next.outposts.append({"uid":"outpost-"+str(next.outpost_serial),"level":1,"site":site_id,"cost":{"wood":OUTPOST_WOOD_COST,"stone":OUTPOST_STONE_COST}})
	if pos!=Vector2.ZERO:next.position=[pos.x,pos.y]
	var ok:=commit(next)
	busy=false
	return ok

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
	var positions:=ResourcePlacement.generate(int(next.resource_seed),chief_level(),missing.size(),occupied)
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
	ensure_respawn_timers()
	finish_chief_upgrade()
	OwnedBuildingUpgrades.finish(self)

func commit(next: Dictionary, reset: bool = false) -> bool:
	if not store.save_game(next,reset):
		failed.emit(store.message)
		return false
	state = next
	changed.emit()
	return true

func start_new() -> bool:
	var next:=DemoConfig.fresh()
	prepare_resource_positions(next)
	var ok:=commit(next,true)
	if ok:
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
	if busy or state.is_empty():
		return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	busy = true
	for n in nodes():
		if n.id != node_id:
			continue
		var next := state.duplicate(true)
		var count := int(next.depleted.get(node_id,0))
		if count >= n.charges:
			busy = false
			return false
		next.depleted[node_id] = count+1
		if count+1>=int(n.charges):
			if not next.has("respawn_due"):next.respawn_due={}
			next.respawn_due[node_id]=now+randf_range(RESPAWN_MIN_SECONDS,RESPAWN_MAX_SECONDS)
		next[n.kind] += int(DemoConfig.get_data().gather_yield)
		if pos != Vector2.ZERO:
			next.position = [pos.x,pos.y]
		var ok := commit(next)
		busy = false
		return ok
	busy = false
	return false

func can_build() -> bool:
	var c := DemoConfig.get_data()
	return not state.is_empty() and built_count() < home_limit() and builder_available() and state.wood >= c.wood_cost and state.stone >= c.stone_cost

func homes() -> Array:
	if state.has("homes"): return state.homes.duplicate(true)
	# Migrate the existing one-home save without rerolling or granting again.
	return [{"style":int(state.get("hut_style",0)),"claimed":bool(state.get("reward_claimed",false))}] if state.get("built",false) else []

func built_count() -> int: return homes().size()

func reward_pending(index: int) -> bool:
	var list := homes()
	return index >= 0 and index < list.size() and not list[index].claimed

func home_position(index:int)->Vector2:
	var list:=homes()
	if index<0 or index>=list.size():return Vector2.INF
	return DemoConfig.BUILD_SITES[int(list[index].site)] if list[index].has("site") else DemoConfig.HOME_SITES[int(list[index].get("legacy_slot",index))]

func home_key(index:int)->String:
	var list:=homes()
	if index<0 or index>=list.size():return ""
	return str(list[index].get("uid","legacy-"+str(list[index].get("legacy_slot",index))))

func stable_homes()->Array:
	var list:=homes()
	for i in list.size():
		if not list[i].has("site"):list[i].legacy_slot=int(list[i].get("legacy_slot",i))
		list[i].uid=home_key(i)
	return list

func demolition_quote(key:String)->Dictionary:
	var list:=homes()
	for i in list.size():
		if home_key(i)!=key:continue
		var cost:Dictionary=list[i].get("cost",{"wood":1,"stone":1}) # Historical demo cost.
		var result:Dictionary={"index":i,"wood":0,"stone":0,"supported":true}
		for kind in ["wood","stone"]:
			var paid:=int(cost[kind])
			var tenths:=paid*10 if paid<=10 else paid*9
			# Approved policy: integer division floors each resource independently.
			result[kind]=tenths/10
		return result
	return {}

func demolish(key:String)->bool:
	if busy:return false
	var owned:=OwnedBuildingUpgrades.lookup(self,key)
	if not owned.is_empty() and owned.data.has("upgrade"):return false
	var quote:=demolition_quote(key)
	if quote.is_empty() or not quote.supported or reward_pending(int(quote.index)):return false
	busy=true
	var next:=state.duplicate(true)
	next.homes=stable_homes()
	next.homes.remove_at(int(quote.index))
	next.wood+=int(quote.wood);next.stone+=int(quote.stone)
	next.built=not next.homes.is_empty()
	next.reward_claimed=next.homes[0].claimed if next.built else false
	next.hut_style=next.homes[0].style if next.built else 0
	var ok:=commit(next)
	busy=false
	return ok

func site_free(id:int)->bool:
	if id<0 or id>=DemoConfig.BUILD_SITES.size():return false
	var candidate:=EnvironmentProp.hut_footprint(230)
	for k in candidate.size():candidate[k]+=DemoConfig.BUILD_SITES[id]
	for i in built_count():
		var occupied:=EnvironmentProp.hut_footprint(340)
		for k in occupied.size():occupied[k]+=home_position(i)
		if not Geometry2D.intersect_polygons(candidate,occupied).is_empty():return false
	for i in outposts().size():
		var occupied:=EnvironmentProp.hut_footprint(340)
		for k in occupied.size():occupied[k]+=outpost_position(i)
		if not Geometry2D.intersect_polygons(candidate,occupied).is_empty():return false
	return true

func build(pos: Vector2 = Vector2.ZERO, site_id:int=-1) -> bool:
	if site_id==-1:
		for i in DemoConfig.BUILD_SITES.size():
			if site_free(i):site_id=i;break
	if busy or not can_build() or not site_free(site_id):
		return false
	busy = true
	var c := DemoConfig.get_data()
	var next := state.duplicate(true)
	next.wood -= int(c.wood_cost)
	next.stone -= int(c.stone_cost)
	next.built = true
	# Choose once at the successful transaction; reload/visual effects never reroll.
	next.hut_style = 1
	next.homes = stable_homes()
	next.home_serial=int(next.get("home_serial",0))+1
	next.homes.append({"uid":"built-"+str(next.home_serial),"style":next.hut_style,"claimed":false,"site":site_id,"cost":{"wood":int(c.wood_cost),"stone":int(c.stone_cost)}})
	next.hut_style = next.homes[0].style
	if next.homes.size()>=DemoConfig.HOME_GOAL:next.family_unlocked=true
	if pos != Vector2.ZERO:
		next.position = [pos.x,pos.y]
	var ok := commit(next)
	busy = false
	return ok

func claim_reward(index: int = 0) -> bool:
	if busy or state.is_empty() or not reward_pending(index):
		return false
	busy = true
	var next := state.duplicate(true)
	next.homes = homes()
	next.homes[index].claimed = true
	next.reward_claimed = next.homes[0].claimed
	next.tokens += int(DemoConfig.get_data().reward)
	var ok := commit(next)
	busy = false
	return ok

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
	return not state.get("family_joined",false) and (state.get("family_unlocked",false) or built_count()>=DemoConfig.HOME_GOAL)
func join_family()->bool:
	if busy or not family_available():return false
	var next:=state.duplicate(true);next.family_joined=true;next.family_unlocked=true
	return commit(next)

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
	return mini(DemoConfig.MAX_RESIDENT_HOMES,chief_level())

func resident_capacity()->int:
	var capacity:=0
	for home in homes():capacity += [1,2,3,5][clampi(int(home.get("level",1)),1,4)-1]
	return capacity

func resident_count()->int:
	return 2 if state.get("family_joined",false) else 0

func active_builder_jobs()->int:
	var count:=1 if state.has("chief_upgrade") else 0
	if construction_busy:count+=1
	for collection in [homes(),outposts()]:
		for entry in collection:
			if entry.has("upgrade"):count+=1
	return count

func builder_available()->bool:
	return debug_unlimited_builders or active_builder_jobs()==0

func building_unlocked(kind:String)->bool:
	if state.is_empty():return false
	match kind:
		"home", "hut", "chief":return true
		"hearth":return chief_level()>=2
		"shrine":return chief_level()>=3
		"outpost":return chief_level()>=OUTPOST_UNLOCK_LEVEL
	return false

func building_requirement(kind:String)->String:
	var required:int={"home":1,"hut":1,"chief":1,"hearth":2,"shrine":3,"outpost":4}.get(kind,0)
	if required==0:return "아직 지원하지 않는 건물이에요"
	if not building_unlocked(kind):return "본부 Lv.%d 필요" % required
	if kind in ["home","hut"]:
		if built_count()>=DemoConfig.MAX_RESIDENT_HOMES:return "주민 움집은 최대 3채까지 지을 수 있어요"
		if built_count()>=home_limit():return "본부 Lv.%d 필요 · 현재 움집 한도 %d채" % [chief_level()+1,home_limit()]
		if not builder_available():return "건설자 1명이 작업 중이에요"
		var cost:=chief_upgrade_cost()
		if state.wood<cost.wood or state.stone<cost.stone:return "나무 %d개와 돌 %d개가 필요해요" % [cost.wood,cost.stone]
	return ""

func upgrade_requirement(key:String="chief")->String:
	var level:=chief_level()
	if key!="chief":
		var found:=OwnedBuildingUpgrades.lookup(self,key)
		if found.is_empty():return "건물을 찾을 수 없어요"
		level=int(found.data.get("level",1))
		if found.data.has("upgrade"):return "이미 업그레이드 중이에요"
		if level<4 and level>=chief_level():return "본부 Lv.%d 필요" % (level+1)
	elif state.has("chief_upgrade"):return "이미 업그레이드 중이에요"
	if level>=4:return "최고 레벨이에요"
	if not builder_available():return "건설자 1명이 작업 중이에요"
	return ""
