extends RefCounted
## First deer encounter tuning. These values are independent from village progression.
const MAX_GAUGE := 100.0
const MAX_HP := 100
const CHARGE_PER_SECOND := 14.0
const AUTO_INTERVAL := 2.6
const AUTO_DAMAGE := 1
const AUTO_COUNTER_DAMAGE := 2
const SKILLS := {
	"thrust": {"label":"찌르기", "cost":10, "damage":8},
	"strike": {"label":"강타", "cost":50, "damage":31},
	"team": {"label":"협동", "cost":100, "damage":58},
}

var gauge := 0.0
var hunter_hp := MAX_HP
var deer_hp := MAX_HP
var outcome := ""
var auto_clock := 0.0
var hunter_turn := true
var pending_basic_damage := 0

func can_use(skill: String) -> bool:
	return outcome.is_empty() and pending_basic_damage==0 and gauge >= SKILLS[skill].cost

func use_skill(skill: String) -> bool:
	if not can_use(skill):return false
	gauge -= SKILLS[skill].cost
	if skill=="thrust":
		pending_basic_damage = SKILLS[skill].damage
		return true
	deer_hp = maxi(0,deer_hp-int(SKILLS[skill].damage))
	if deer_hp==0:outcome = "win"
	return true

func resolve_basic_impact() -> bool:
	if pending_basic_damage==0:return false
	deer_hp = maxi(0,deer_hp-pending_basic_damage)
	pending_basic_damage = 0
	if deer_hp==0:outcome = "win"
	return true

func advance(delta: float) -> Array[String]:
	var moves: Array[String] = []
	if not outcome.is_empty():return moves
	gauge = minf(MAX_GAUGE,gauge+delta*CHARGE_PER_SECOND)
	auto_clock += delta
	while auto_clock>=AUTO_INTERVAL and outcome.is_empty() and pending_basic_damage==0:
		auto_clock -= AUTO_INTERVAL
		if hunter_turn:
			pending_basic_damage = AUTO_DAMAGE
			moves.append("auto_thrust")
		else:
			hunter_hp = maxi(0,hunter_hp-AUTO_COUNTER_DAMAGE)
			moves.append("counter")
			if hunter_hp==0:outcome = "loss"
		hunter_turn = not hunter_turn
	return moves
