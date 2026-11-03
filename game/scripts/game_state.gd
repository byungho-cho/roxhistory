class_name GameState
extends RefCounted

signal changed
signal failed(message: String)

var state: Dictionary = {}
var store: SaveStore
var busy := false

func _init(save_store: SaveStore) -> void:
	store = save_store
	state = store.load_game()

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
	return not state.is_empty() and built_count() < DemoConfig.HOME_GOAL and state.wood >= c.wood_cost and state.stone >= c.stone_cost

func homes() -> Array:
	if state.has("homes"): return state.homes.duplicate(true)
	# Migrate the existing one-home save without rerolling or granting again.
	return [{"style":int(state.get("hut_style",0)),"claimed":bool(state.get("reward_claimed",false))}] if state.get("built",false) else []

func built_count() -> int: return homes().size()

func reward_pending(index: int) -> bool:
	var list := homes()
	return index >= 0 and index < list.size() and not list[index].claimed

func build(pos: Vector2 = Vector2.ZERO) -> bool:
	if busy or not can_build():
		return false
	busy = true
	var c := DemoConfig.get_data()
	var next := state.duplicate(true)
	next.wood -= int(c.wood_cost)
	next.stone -= int(c.stone_cost)
	next.built = true
	# Choose once at the successful transaction; reload/visual effects never reroll.
	next.hut_style = randi_range(0,2)
	next.homes = homes()
	next.homes.append({"style":next.hut_style,"claimed":false})
	next.hut_style = next.homes[0].style
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
