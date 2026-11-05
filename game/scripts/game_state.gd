class_name GameState
extends RefCounted

signal changed
signal failed(message: String)

var state: Dictionary = {}
var store: SaveStore
var busy := false
const RESPAWN_SECONDS := 30.0

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
