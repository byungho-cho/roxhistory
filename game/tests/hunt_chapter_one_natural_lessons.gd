extends SceneTree

const Squad = preload("res://scripts/hunt_duel_local_squad.gd")
const Catalog = preload("res://scripts/hunt_chapter_one_catalog.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + msg)


func run() -> void:
	for item in [[2, true], [3, true], [5, true], [6, true], [6, false]]:
		var number: int = item[0]
		var first: bool = item[1]
		var row := Catalog.encounter(number)
		row.first_visit = first
		var fight = Squad.new()
		root.add_child(fight)
		check(fight.configure_story_encounter(row), "real configuration %d" % number)
		fight.setup(Callable(), Callable(), Callable(), Callable(), Callable(), Callable(), Callable(),
			Callable(), Callable(), 1.15, Callable(), Callable(), Callable(), Callable(), Callable(), true)
		var manual_guard := 0
		for frame in range(60 * 91):
			fight.tick(1.0 / 60.0, false)
			if fight.ended:
				break
			for i in 3:
				if fight.huds[i].visible and not fight.huds[i].portrait_button.disabled:
					fight.huds[i].portrait_button.pressed.emit()
			if number == 5 and not fight.huds[1].chain_button.disabled:
				var before: float = fight.units[1].sp
				fight.huds[1].chain_button.pressed.emit()
				if fight.units[1].sp < before:
					manual_guard += 1
		if first:
			check(fight.story_outcome == "win", "natural clear 1-%d" % number)
		if number == 2:
			var taps: int = fight.hits.filter(func(hit: Dictionary) -> bool:
				return hit.get("from", -1) == 0 and hit.get("type", "") == "skill" and hit.get("result", "") == "hit").size()
			check(taps > 0, "actual Han manual 2SP contact")
		if number == 5:
			check(manual_guard > 0 and fight.story_taught_parry and not fight.story_auto_parry_used, "1-5 actual manual parry")
		if number == 6:
			check(fight.story_auto_parry_used == first and (not first or fight.story_taught_parry), "1-6 first real auto-parry; no replay automation")
		print("natural 1-",number," first=",first," outcome=",fight.story_outcome," seconds=",fight.elapsed)
		fight.queue_free()
		await process_frame
	quit(failures)
