extends RefCounted
## Provisional encounter timing. The shared lock applies only to orb skills.
const MAX_HP := 100
const COUNTER_DAMAGE := 2
const MAX_ORBS := 3
const PARTY_HP := [34, 33, 33]
const CHARGE_SECONDS := [1.5, 1.8, 2.0]
const PARTY_SKILLS := ["thrust", "strike", "team"]
const BASIC_INTERVAL := 10.0 / 14.0
const POSE_SECONDS := 0.52
const AUTO_INTERVAL := 2.6
const SKILLS := {
	"thrust": {"label": "찌르기", "cost": 1, "damage": 8},
	"strike": {"label": "강타", "cost": 1, "damage": 31},
	"team": {"label": "협동", "cost": 2, "damage": 58},
}

var charges: Array[float] = [0.0, 0.0, 0.0]
var party_hp: Array[int] = [34, 33, 33]
var hunter_hp: int:
	get: return party_hp[0]+party_hp[1]+party_hp[2]
var next_target := 0
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
var auto_enabled := false
var reserved_skill := ""
var rng := RandomNumberGenerator.new()

func enable_motion_trial() -> void:
	deer_max_hp = MAX_HP * 10
	deer_hp = deer_max_hp

func living_from(start: int) -> int:
	for offset in party_hp.size():
		var index := (start+offset)%party_hp.size()
		if party_hp[index]>0:return index
	return -1

func queue_attack(damage: int, index: int) -> void:
	attacker = index
	pending_damage = damage

func resolve_attack() -> void:
	var damage := pending_damage
	pending_damage = 0
	if damage > 0:
		damage_deer(damage)
	if pending_counter:
		pending_counter = false
		party_hp[attacker] = maxi(0, party_hp[attacker] - COUNTER_DAMAGE)
		if party_hp[attacker]==0:
			charges[attacker]=0.0
			if auto_enabled:reserved_skill=next_auto_skill()
		if hunter_hp == 0:
			outcome = "loss"
			set_auto(false)

func orbs(index: int) -> int:
	return mini(MAX_ORBS,floori(charges[index]+0.000001))

func set_auto(enabled: bool) -> void:
	auto_enabled = enabled and outcome.is_empty()
	reserved_skill = next_auto_skill() if auto_enabled else ""

func next_auto_skill() -> String:
	var options: Array[String] = []
	if party_hp[1]>0:options.append("strike")
	if party_hp[2]>0 and (party_hp[0]>0 or party_hp[1]>0):options.append("team")
	if options.is_empty() and party_hp[0]>0:return "thrust"
	return "" if options.is_empty() else options[rng.randi_range(0,options.size()-1)]

func can_use(skill: String) -> bool:
	if not SKILLS.has(skill) or not outcome.is_empty() or action_lock > 0 or pending_damage > 0 or pending_counter:
		return false
	var index := PARTY_SKILLS.find(skill)
	if party_hp[index]<=0 or orbs(index)<SKILLS[skill].cost:return false
	if skill=="team" and party_hp[0]<=0 and party_hp[1]<=0:return false
	return basic_lock<=0 if skill=="thrust" else orb_lock<=0

func use_skill(skill: String) -> bool:
	if not can_use(skill):
		return false
	var index := PARTY_SKILLS.find(skill)
	action_lock = POSE_SECONDS
	charges[index] = maxf(0.0,charges[index]-SKILLS[skill].cost)
	if skill == "thrust":
		basic_lock = BASIC_INTERVAL
	else:
		orb_lock = 1.0
	queue_attack(SKILLS[skill].damage,index)
	return true

func damage_deer(amount: int) -> void:
	deer_hp = maxi(0, deer_hp - amount)
	if deer_hp == 0:
		outcome = "win"
		set_auto(false)

func advance(delta: float) -> String:
	if not outcome.is_empty():
		return ""
	for index in party_hp.size():
		if party_hp[index]>0:charges[index]=minf(MAX_ORBS,charges[index]+delta/CHARGE_SECONDS[index])
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
		var index := living_from(next_attacker)
		queue_attack(1,index)
		next_attacker = (index+1)%party_hp.size()
		return "auto_thrust"
	attacker = living_from(next_target)
	next_target = (attacker+1)%party_hp.size()
	pending_counter = true
	return "counter"
