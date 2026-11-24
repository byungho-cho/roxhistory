extends SceneTree

const CATALOG := preload("res://scripts/hunt_chapter_one_catalog.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + title)


func run() -> void:
	var expected := [["forest"], ["forest", "forest"], ["stag", "forest"],
		["stag", "forest", "forest"], ["juvenile"], ["juvenile", "forest"],
		["juvenile", "forest", "forest"], ["juvenile", "stag", "forest"],
		["juvenile", "stag", "stag"], ["adult"]]
	var meat := [10, 20, 30, 40, 30, 40, 50, 60, 70, 90]
	var best_meat := 0
	for i in range(10):
		var stage := CATALOG.encounter(i + 1)
		check(stage.prey == expected[i] and stage.prey.size() <= 3, "roster %s" % stage.key)
		check(stage.party == (["han"] if i < 2 else ["han", "uram"] if i == 2 else ["han", "uram", "saebom"]), "party %s" % stage.key)
		check(stage.base_meat == meat[i] and stage.seconds == (60 if i == 4 else 90 if i == 9 else 50), "reward/time %s" % stage.key)
		best_meat += int(stage.base_meat) * 2
	check(CATALOG.encounter(3).opening_party == ["han"] and CATALOG.encounter(3).story_join == ["uram"], "1-3 follows Han with Uram only")
	check(CATALOG.encounter(4).opening_party == ["han", "uram"] and CATALOG.encounter(4).story_join == ["saebom"], "1-4 follows Han and Uram with Saebom")
	check(best_meat == 880, "Figma base three-star total")
	check(CATALOG.encounter(0).is_empty() and CATALOG.encounter(11).is_empty(), "invalid numbers aren't stages")
	check(CATALOG.victory_stars(20.0,60.0)==3 and CATALOG.victory_stars(20.001,60.0)==2, "three-star threshold is inclusive")
	check(CATALOG.victory_stars(25.0,50.0)==2 and CATALOG.victory_stars(25.001,50.0)==1, "two-star threshold is inclusive")
	check(CATALOG.victory_stars(89.999,90.0)==1 and CATALOG.victory_stars(90.0,90.0)==0, "timeout has no victory stars")
	check(CATALOG.encounter(1).lesson == "han_manual_2sp" and CATALOG.encounter(1).first_clear_stars == 3, "shipped 1-1 override")
	var demo := CATALOG.encounter(6)
	check(demo.lesson == "first_parry_demo_then_chain" and CATALOG.encounter(5).lesson == "uram_parry_only", "parry then chain")
	demo.prey.clear()
	check(CATALOG.encounter(6).prey.size() == 2, "caller cannot mutate catalog")
	var fresh := CATALOG.completion_view(0)
	check(CATALOG.next_number(fresh) == 1 and CATALOG.is_unlocked(1, fresh) and not CATALOG.is_unlocked(2, fresh), "fresh")
	var old_four := CATALOG.completion_view(4)
	check(CATALOG.next_number(old_four) == 5 and CATALOG.is_unlocked(5, old_four) and not CATALOG.is_unlocked(10, old_four), "old 1–4 only")
	var old_boss_open := CATALOG.completion_view(5)
	check(not old_boss_open.has("ch1-10") and CATALOG.is_unlocked(6, old_boss_open), "old midboss clear does not fake boss clear")
	var old_ch2 := CATALOG.completion_view(12)
	check(old_ch2.size() == 6 and old_ch2.get("ch1-10") and not old_ch2.has("ch1-06") and CATALOG.next_number(old_ch2) == 6, "chapter 2 never fakes 6–9 clears")
	check(CATALOG.is_unlocked(10, old_ch2) and CATALOG.is_unlocked(6, old_ch2) and not CATALOG.is_unlocked(7, old_ch2), "boss replay preserved while later new stages gate")
	check(CATALOG.legacy_display_number(5) == 10 and CATALOG.legacy_display_number(6) == 0, "legacy IDs never relabel chapter 2")
	var merged := CATALOG.completion_view(12, {"ch1-06": true, "ch1-07": true, "garbage": true, "ch1-09": false})
	check(CATALOG.next_number(merged) == 8 and CATALOG.is_unlocked(8, merged) and not merged.has("garbage"), "new flags merge independent of legacy")
	var finished := CATALOG.completion_view(12, {"ch1-06": true, "ch1-07": true, "ch1-08": true, "ch1-09": true})
	check(CATALOG.next_number(finished) == 0, "all ten clears recognized")
	print("CATALOG ", checks, " checks, ", failures, " failures")
	quit(failures)
