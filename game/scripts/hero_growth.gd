class_name HeroGrowth
extends RefCounted

const Story := preload("res://scripts/hunt_chapter_one_catalog.gd")
const Duel := preload("res://scripts/deer_hunt_rules.gd")
const Frontline := preload("res://scripts/hunt_production_frontline_actions.gd")
const Rally := preload("res://scripts/saebom_rally_cloud.gd")

const SAVE_KEY := "hero_growth"
const HEROES := [Story.ALLY_HAN, Story.ALLY_URAM, Story.ALLY_SAEBOM, "gahui", "bau"]
const HAN_CHAIN_DAMAGE := 38
const STATS := ["hp", "attack", "skill"]

# S40700 provisional rules for the 0.313.314 review.
const XP_PER_MEAT := 1
const MAX_LEVEL := 5
const XP_TO_NEXT := [10, 20, 35, 55]
const GROWTH_PER_LEVEL := 0.05

static func owns(state: Dictionary, id: String) -> bool:
	var raw: Variant = state.get(Story.CLEARS_KEY, {})
	var clears: Dictionary = raw if raw is Dictionary else {}
	return id in Story.replay_opening_party(clears, state.get(Story.RECRUITS_KEY, []))

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

static func multiplier(level: int) -> float:
	return 1.0 + (clampi(level, 1, MAX_LEVEL) - 1) * GROWTH_PER_LEVEL

static func stats_at(id: String, level: int) -> Dictionary:
	var factor := multiplier(level)
	var stats := {
		"hp": roundi(Duel.PARTY_HP[clampi(HEROES.find(id), 0, 2)] * factor),
		"attack": roundi(Rally.SQUAD_BASE * factor),
		"skill": roundi(Frontline.HAN_STORY_2SP_DAMAGE * factor)
	}
	if id == Story.ALLY_HAN: stats.chain = roundi(HAN_CHAIN_DAMAGE * factor)
	if id == Story.ALLY_URAM: stats.chain = roundi(Duel.URAM_SHIELD_COUNTER_DAMAGE * factor)
	return stats

static func needed_at(level: int) -> int:
	return XP_TO_NEXT[level - 1] if level > 0 and level < MAX_LEVEL else 0

static func can_feed(state: Dictionary, id: String) -> bool:
	return int(state.get("meat", 0)) > 0 and owns(state, id) and int(read(state, id).level) < MAX_LEVEL

static func after_feed(state: Dictionary, id: String) -> Dictionary:
	if not can_feed(state, id): return {}
	var progress := read(state, id)
	progress.xp += XP_PER_MEAT
	while progress.level < MAX_LEVEL:
		var required := needed_at(progress.level)
		if progress.xp < required: break
		progress.xp -= required
		progress.level += 1
	if progress.level == MAX_LEVEL: progress.xp = 0
	return progress
