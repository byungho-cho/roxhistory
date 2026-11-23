extends SceneTree

const Art := preload("res://scripts/hunt_uram_3sp_combined.gd")
const Squad := preload("res://scripts/hunt_duel_local_squad.gd")
const Wave := preload("res://scripts/duel_uram_counter_wave.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("URAM COMBINED ",ok," ",label)
	if not ok:
		failures += 1

func run() -> void:
	var fx := Art.new()
	check(fx.prepare() and fx.frames.size() == 59 and fx.frames[0].get_size() == Vector2(192,192), "exact PNG dimensions and count")
	check(fx.index_at(0.0) == 0 and fx.index_at(58.0/30.0) == 58 and fx.index_at(59.0/30.0) == -1, "first, final and expired frames")
	var squad := Squad.new()
	root.add_child(squad)
	squad.setup()
	check(squad.uram_combined.frames.size() == 59, "squad opened with all frames already loaded")
	squad._start_uram_short_fan(3,Vector2(601,252))
	squad._start_uram_short_fan(3,Vector2(602,253),true)
	check(squad.uram_short_fans[0].combined and squad.uram_short_fans[0].span == Art.SECONDS, "squad ordinary renders one new effect")
	check(not squad.uram_short_fans[1].combined and squad.uram_short_fans[1].span == Wave.FIELD_SECONDS, "squad parry still uses stock")
	squad.elapsed = Wave.FIELD_SECONDS + .02
	squad._advance_uram_short_fans()
	check(squad.uram_short_fans.size() == 1 and squad.uram_short_fans[0].combined, "overlapping events expire independently")
	squad.elapsed = Art.SECONDS + .02
	squad._advance_uram_short_fans()
	check(squad.uram_short_fans.is_empty(), "no stuck effects")
	squad.free()
	var lab = load("res://scenes/hunt_duel_lab.tscn").instantiate()
	lab.show_final_test35 = true
	root.add_child(lab)
	lab.set_process(false)
	await process_frame
	lab._select("uram",false)
	lab._select("forest",true)
	check(lab.uram_combined.frames.size() == 59, "solo Uram selection has all frames before combat")
	lab._start_uram_short_counter_fan(Vector2(601,252))
	check(lab.uram_short_counter_fan.get("combined",false), "solo ordinary uses approved texture")
	lab._start_uram_short_counter_fan(Vector2(602,253),true)
	check(not lab.uram_short_counter_fan.get("combined",true) and lab.uram_short_counter_fan.get("span",0) == Wave.FIELD_SECONDS, "solo parry retains stock fan and duration")
	lab.queue_free()
	await process_frame
	print("URAM COMBINED ", "PASS" if failures == 0 else "FAIL", " failures=",failures)
	quit(failures)
