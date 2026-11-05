class_name GameState
extends RefCounted

signal changed
signal failed(message: String)

var state: Dictionary = {}
var store: SaveStore
var busy := false
const RESPAWN_SECONDS := 30.0
const OUTPOST_WOOD_COST := 15
const OUTPOST_STONE_COST := 10
const OUTPOST_UNLOCK_HOMES := 4

# The chief's existing hut is not part of the resident-home save array.
func completed_hut_count() -> int:
	return 0 if state.is_empty() else 1+built_count()

func outpost_unlocked() -> bool:
	return completed_hut_count() >= OUTPOST_UNLOCK_HOMES

func can_build_outpost() -> bool:
	return outpost_unlocked() and state.wood >= OUTPOST_WOOD_COST and state.stone >= OUTPOST_STONE_COST

func outpost_requirement() -> String:
	if not outpost_unlocked():
		return "주인공 움집 포함 완성된 움집 4채 필요 (%d/4)" % completed_hut_count()
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
	if state.is_empty() or outposts().is_empty() or chief_level()>=4 or state.has("chief_upgrade"):return false
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

func nodes() -> Array:
	var result:Array=DemoConfig.get_data().nodes.duplicate(true)
	for n in result:
		if state.get("node_positions",{}).has(n.id):n.position=state.node_positions[n.id].duplicate()
	return result

func respawn(id:String, at:Vector2, now:float) -> bool:
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
	finish_chief_upgrade()

func commit(next: Dictionary, reset: bool = false) -> bool:
	if not store.save_game(next,reset):
		failed.emit(store.message)
		return false
	state = next
	changed.emit()
	return true

func start_new() -> bool:
	return commit(DemoConfig.fresh(),true)

func save_position(pos: Vector2) -> bool:
	if state.is_empty():
		return false
	var next := state.duplicate(true)
	next.position = [pos.x,pos.y]
	return commit(next)

func gather(node_id: String, pos: Vector2 = Vector2.ZERO) -> bool:
	if busy or state.is_empty():
		return false
	busy = true
	for n in DemoConfig.get_data().nodes:
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
			next.respawn_due[node_id]=Time.get_unix_time_from_system()+RESPAWN_SECONDS
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
	return not state.is_empty() and built_count() < DemoConfig.MAX_RESIDENT_HOMES and state.wood >= c.wood_cost and state.stone >= c.stone_cost

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
