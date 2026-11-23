extends RefCounted

signal hp_lost(side: int, before: int, after: int)
## Isolated encounter state, never writes campaign rewards, save data, or experience.
const MAX_SP := 3.0
const REVIVE_SECONDS := 1.0
const CampaignRules = preload("res://scripts/deer_hunt_rules.gd")
const TIME_PER_SP := 3.0
const BASIC_EVERY := CampaignRules.AUTO_INTERVAL
const ALLY_HP := 100
const ENEMY_HP := {"forest":100,"adult":180}
var elapsed := 0.0
var ally_id := "hangyeol"
var enemy_id := "forest"
var sp := 1.0
var hp: Array[int] = [100,100]
var revive_at: Array[float] = [-1.0,-1.0]

func reset(ally: String, enemy: String) -> void:
	ally_id = ally
	enemy_id = enemy
	elapsed = 0.0
	sp = 1.0
	hp = [ALLY_HP, int(ENEMY_HP[enemy])]
	revive_at = [-1.0,-1.0]

func full_hp(side: int) -> int:
	return ALLY_HP if side == 0 else int(ENEMY_HP[enemy_id])

func living() -> bool:
	return hp[0] > 0 and hp[1] > 0

func advance(delta: float) -> Array[int]:
	var revived: Array[int] = []
	if hp[0] > 0:
		sp = minf(MAX_SP, sp + delta / TIME_PER_SP)
	else:
		sp = minf(MAX_SP, sp + maxf(0.0, elapsed + delta - revive_at[0]) / TIME_PER_SP)
	elapsed += delta
	for side in 2:
		if revive_at[side] >= 0.0 and elapsed + 0.000001 >= revive_at[side]:
			hp[side] = full_hp(side)
			revive_at[side] = -1.0
			revived.append(side)
	return revived

func afford(cost: int) -> bool:
	return living() and sp + 0.000001 >= float(cost)

func spend(cost: int) -> bool:
	if not afford(cost):
		return false
	sp = maxf(0.0, sp - float(cost))
	return true

func damage(side: int, amount: int) -> bool:
	if not living() or amount <= 0:
		return false
	var before := hp[side]
	hp[side] = maxi(0, before - amount)
	if hp[side] < before:hp_lost.emit(side,before,hp[side])
	if hp[side] > 0:
		return false
	revive_at[side] = elapsed + REVIVE_SECONDS
	return true

func elapsed_label() -> String:
	var seconds := floori(elapsed + 0.000001)
	return "%02d:%02d" % [seconds / 60, seconds % 60]
