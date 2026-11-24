class_name HeroGrowth
extends RefCounted

const Story := preload("res://scripts/hunt_chapter_one_catalog.gd")
const Duel := preload("res://scripts/deer_hunt_rules.gd")
const Frontline := preload("res://scripts/hunt_production_frontline_actions.gd")
const Rally := preload("res://scripts/saebom_rally_cloud.gd")

const SAVE_KEY := "hero_growth"
const HEROES := [Story.ALLY_HAN, Story.ALLY_URAM, Story.ALLY_SAEBOM, "gahui", "bau"]
const HAN_CHAIN_DAMAGE := 38
const STATS := ["hp", "attack", "skill", "chain"]

# This table holds approved progression only. Empty rows keep growth locked.
const RULES := {}

static func owns(state: Dictionary, id: String) -> bool:
	var clears := _saved_clears(state)
	return id in Story.replay_opening_party(clears, state.get(Story.RECRUITS_KEY, []))

static func _saved_clears(state: Dictionary) -> Dictionary:
	var raw: Variant = state.get(Story.CLEARS_KEY, {})
	return raw if raw is Dictionary else {}

static func read(state: Dictionary, id: String) -> Dictionary:
	var heroes: Dictionary = state.get(SAVE_KEY, {})
	var saved: Dictionary = heroes.get(id, {})
	return {"level": int(saved.get("level", 1)), "xp": int(saved.get("xp", 0))}

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if id not in HEROES or not value[id] is Dictionary: return false
		var hero: Dictionary = value[id]
		if not BuildingRules.valid_number(hero.get("level"), 1, BuildingRules.MAX_RESOURCE, true): return false
		if not BuildingRules.valid_number(hero.get("xp"), 0, BuildingRules.MAX_RESOURCE, true): return false
	return true

static func cap(state: Dictionary, id: String, rules: Dictionary) -> int:
	var rows: Array = rules.get("levels", {}).get(id, [])
	var maximum := 0
	var clears: Dictionary = Story.completion_view(int(state.get("hunt_cleared", 0)), _saved_clears(state))
	for gate: Dictionary in rules.get("caps", []):
		var stage: String = gate.get("after", "")
		if stage.is_empty() or clears.get(stage, false):
			maximum = maxi(maximum, int(gate.level))
	return mini(maximum, rows.size())

static func row_at(id: String, level: int, rules: Dictionary) -> Dictionary:
	var rows: Array = rules.get("levels", {}).get(id, [])
	return rows[level - 1] if level > 0 and level <= rows.size() else {}

static func stats_at(id: String, level: int, rules: Dictionary) -> Dictionary:
	var stats := {
		"hp": Duel.PARTY_HP[clampi(HEROES.find(id), 0, 2)],
		"attack": Rally.SQUAD_BASE,
		"skill": Frontline.HAN_STORY_2SP_DAMAGE,
		"chain": HAN_CHAIN_DAMAGE if id == Story.ALLY_HAN else Duel.URAM_SHIELD_COUNTER_DAMAGE
	}
	stats.merge(row_at(id, level, rules).get("stats", {}), true)
	return stats

static func battle_overrides(state: Dictionary, id: String, rules: Dictionary) -> Dictionary:
	return row_at(id, read(state, id).level, rules).get("stats", {})

static func needed_at(id: String, level: int, rules: Dictionary) -> int:
	return int(row_at(id, level, rules).get("next_xp", 0))

static func can_feed(state: Dictionary, id: String, rules: Dictionary) -> bool:
	if int(state.get("meat", 0)) < 1 or not owns(state, id) or int(rules.get("xp_per_meat", 0)) < 1:
		return false
	var level: int = read(state, id).level
	return level < cap(state, id, rules) and needed_at(id, level, rules) > 0

static func after_feed(state: Dictionary, id: String, rules: Dictionary) -> Dictionary:
	if not can_feed(state, id, rules): return {}
	var progress := read(state, id)
	var maximum := cap(state, id, rules)
	progress.xp = mini(BuildingRules.MAX_RESOURCE, int(progress.xp) + int(rules.xp_per_meat))
	while progress.level < maximum:
		var required := needed_at(id, progress.level, rules)
		if required <= 0 or progress.xp < required: break
		progress.xp -= required
		progress.level += 1
	if progress.level == maximum and not rules.get("carry_at_cap", false):
		progress.xp = 0
	return progress
