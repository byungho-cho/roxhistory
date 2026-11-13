extends RefCounted
## Provisional encounter timing. The shared lock applies only to orb skills.
const MAX_HP := 100
const MAX_ORBS := 3
const ORB_SECONDS := 100.0 / 14.0 / MAX_ORBS
const BASIC_INTERVAL := 10.0 / 14.0
const POSE_SECONDS := 0.52
const AUTO_INTERVAL := 2.6
const SKILLS := {
	"thrust": {"label": "타격", "cost": 0, "damage": 8},
	"strike": {"label": "강타", "cost": 1, "damage": 31},
	"team": {"label": "협동", "cost": 2, "damage": 58},
}

var charge := 0.0
var hunter_hp := MAX_HP
var deer_max_hp := MAX_HP
var deer_hp := MAX_HP
var pending_damage := 0
var pending_counter := false
var next_attacker := 0
var attacker := 0
var outcome := ""
var exchange_clock := 0.0
var hunter_turn := true
var basic_lock := 0.0
var orb_lock := 0.0
var action_lock := 0.0
var orb_filled := false
var auto_enabled := false
var reserved_skill := ""
var rng := RandomNumberGenerator.new()

func enable_motion_trial() -> void:
	deer_max_hp = MAX_HP * 10
	deer_hp = deer_max_hp

func queue_attack(damage: int) -> void:
	attacker = next_attacker
	next_attacker = 1 - next_attacker
	pending_damage = damage

func resolve_attack() -> void:
	var damage := pending_damage
	pending_damage = 0
	if damage > 0:
		damage_deer(damage)
	if pending_counter:
		pending_counter = false
		hunter_hp = maxi(0, hunter_hp - 2)
		if hunter_hp == 0:
			outcome = "loss"
			set_auto(false)

func orbs() -> int:
	return mini(MAX_ORBS,floori(charge+0.000001))

func set_auto(enabled: bool) -> void:
	auto_enabled = enabled and outcome.is_empty()
	reserved_skill = next_auto_skill() if auto_enabled else ""

func next_auto_skill() -> String:
	return "strike" if rng.randi_range(0, 1) == 0 else "team"

func can_use(skill: String) -> bool:
	if not SKILLS.has(skill) or not outcome.is_empty() or action_lock > 0 or pending_damage > 0 or pending_counter:
		return false
	if skill == "thrust":
		return basic_lock <= 0
	return orb_lock <= 0 and orbs() >= SKILLS[skill].cost

func use_skill(skill: String) -> bool:
	if not can_use(skill):
		return false
	action_lock = POSE_SECONDS
	if skill == "thrust":
		basic_lock = BASIC_INTERVAL
	else:
		charge = maxf(0.0,charge-SKILLS[skill].cost)
		orb_lock = 1.0
	queue_attack(SKILLS[skill].damage)
	return true

func damage_deer(amount: int) -> void:
	deer_hp = maxi(0, deer_hp - amount)
	if deer_hp == 0:
		outcome = "win"
		set_auto(false)

func advance(delta: float) -> String:
	orb_filled = false
	if not outcome.is_empty():
		return ""
	var previous_orbs := orbs()
	charge = minf(MAX_ORBS, charge + delta / ORB_SECONDS)
	orb_filled = orbs() > previous_orbs
	action_lock = maxf(0.0, action_lock - delta)
	basic_lock = maxf(0.0, basic_lock - delta)
	orb_lock = maxf(0.0, orb_lock - delta)
	exchange_clock = minf(AUTO_INTERVAL, exchange_clock + delta)
	var queued := reserved_skill
	if auto_enabled and use_skill(queued):
		if auto_enabled:
			reserved_skill = next_auto_skill()
		return queued
	if exchange_clock < AUTO_INTERVAL or action_lock > 0 or pending_damage > 0 or pending_counter:
		return ""
	exchange_clock = 0.0
	action_lock = POSE_SECONDS
	hunter_turn = not hunter_turn
	if not hunter_turn:
		queue_attack(1)
		return "auto_thrust"
	pending_counter = true
	return "counter"
