extends SceneTree

const Rules := preload("res://scripts/deer_hunt_rules.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)


func _close(actual: float, expected: float) -> bool:
	return absf(actual - expected) < .0001


func _rules_suite() -> void:
	var rules := Rules.new()
	var positions: Array[Vector2] = [Vector2(70, 0), Vector2(191, 0), Vector2.ZERO]
	rules.charges[Rules.SAEBOM] = 2.99
	_check(not rules.start_rally(),"Saebom cannot cast before all three orbs")
	rules.charges[Rules.SAEBOM] = 3.0
	_check(rules.start_rally() and rules.charges[Rules.SAEBOM] == 0.0,"Rally spends exactly three orbs")
	_check(rules.deer_hp == 100 and rules.pending_damage == 0 and rules.rally_remaining[Rules.SAEBOM] == 0.0,"No damage or buff before release")
	_check(not rules.start_rally(),"Re-entrance cannot spend or stack while pending")
	_check(rules.apply_rally(positions),"Rally releases once")
	_check(not rules.apply_rally(positions),"Rally does not trigger twice")
	_check(rules.rally_remaining == [5.0, 0.0, 5.0],"Only caster and close living friendly receive five seconds")
	for slot in [0,1,2]:
		var before := rules.deer_hp
		for i in 5:
			rules.queue_attack(1,slot)
			rules.resolve_attack()
		_check(before - rules.deer_hp == (5 if slot == 1 else 6),"Five basic hits include per-friendly fifth accumulation: slot "+str(slot))
	rules.advance(.6)
	var first_before := rules.rally_remaining[0]
	rules.orb_lock = 0.0
	rules.charges[Rules.SAEBOM] = 3.0
	_check(rules.start_rally(),"Rally may refresh after action/cooldown")
	positions[0] = Vector2(300, 0)
	positions[1] = Vector2(80, 0)
	_check(rules.apply_rally(positions),"Refresh reaches the new in-range friendly")
	_check(rules.rally_remaining == [first_before,5.,5.],"Refresh does not stack or shorten out-of-range existing buff")
	rules.exchange_clock = -100.0
	rules.advance(4.99)
	_check(rules.rally_remaining[Rules.SAEBOM] > 0.0,"Boost stays active before five seconds")
	rules.advance(.01)
	_check(rules.rally_remaining == [0.0,0.0,0.0],"Each active status expires precisely")
	var baseline := rules.deer_hp
	rules.queue_attack(10,Rules.SAEBOM)
	rules.resolve_attack()
	_check(baseline - rules.deer_hp == 10,"Damage returns to unchanged baseline on expiry")
	rules.party_hp[0]=0
	rules.party_hp[1]=0
	rules.charges[Rules.SAEBOM]=3.
	_check(not rules.can_use("team") and rules.start_rally(),"Rally still works when only Saebom is alive; legacy team skill remains blocked")
	_check(rules.apply_rally(positions) and rules.rally_remaining == [0.,0.,5.],"Dead friendlies cannot receive the aura")
	var legacy := Rules.new()
	legacy.charges[Rules.SAEBOM]=2.
	_check(legacy.use_skill("team") and legacy.pending_damage == 58 and legacy.charges[Rules.SAEBOM] == 0.0,"Legacy 2SP team damage and cost preserved")
	_check(legacy.next_auto_skill() in ["strike","team"],"Legacy auto selector does not auto-cast Rally")
	var repeated := Rules.new()
	repeated.exchange_clock = -100.0
	var total := 0
	for cast in 5:
		repeated.charges[Rules.SAEBOM] = 3.0
		if not repeated.start_rally() or not repeated.apply_rally(positions):
			_check(false,"Each later boosted window starts from an ordinary 3SP cast")
			break
		var before := repeated.deer_hp
		repeated.queue_attack(1,Rules.SAEBOM)
		repeated.resolve_attack()
		total += before - repeated.deer_hp
		repeated.advance(5.0)
		before = repeated.deer_hp
		repeated.queue_attack(1,Rules.SAEBOM)
		repeated.resolve_attack()
		_check(before - repeated.deer_hp == 1,"Stored fractions never boost an unbuffed strike")
	_check(total == 6,"Five separate single-hit buff windows still award exactly 20% total")


func _screen_suite() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.has_method("prepare_selected_hunt"), "Main production script loaded")
	if not app.has_method("prepare_selected_hunt"):
		return
	app.application_active = true
	_check(app.model.start_new({},true), "Isolated save uses real new game initialization")
	print("Production Rally fixture: entering scenario selector")
	app.show_screen("hunt_select")
	await process_frame
	app.modal = false
	print("Production Rally fixture: confirming stage and loading hunt")
	await app.prepare_selected_hunt()
	print("Production Rally fixture: hunt initialized")
	var hunt: Control = app.hunt
	_check(is_instance_valid(hunt) and app.screen == "hunt","Normal selection opens real hunting screen")
	if not is_instance_valid(hunt):
		return
	hunt.set_process(false)
	hunt.arrival_finished = true
	hunt.transition_elapsed = -1.0
	hunt.running = true
	var saebom = hunt.hunters[Rules.SAEBOM]
	_check(saebom.get_script().resource_path == "res://scripts/hunt_production_saebom_rig.gd" and saebom.character == "saebom","Normal hunt instantiates Saebom's authored 3D rig")
	_check(saebom.has_anchor("sling_stone") and saebom.tool_3d.get_child_count() == 0,"Native sling stone is available; no generated training spear")
	hunt.transition_elapsed = .3
	hunt.approach = .35
	hunt.update_actors(.05)
	var approach_start: Vector2 = saebom.position
	hunt.approach = .65
	hunt.update_actors(.05)
	_check(saebom.position.distance_to(approach_start) > 2.0 and saebom.animation.current_animation == "run","Saebom follows the existing movement path using authored run")
	hunt.transition_elapsed = -1.0
	hunt.approach = 1.0
	hunt.update_actors(.05)
	var saebom_settled: Vector2 = saebom.position
	var caster_hud: Control = hunt.party_cards[Rules.SAEBOM].hud
	var raw_rules = hunt.rules
	raw_rules.party_hp[0] = 0
	raw_rules.party_hp[1] = 0
	raw_rules.charges[Rules.SAEBOM] = 3.0
	hunt.update_combat_ui()
	_check(not caster_hud.chain_button.disabled and caster_hud.portrait_button.disabled,"Portrait 3SP action stays available with only Saebom alive; 2SP remains blocked")
	raw_rules.party_hp[0] = 34
	raw_rules.party_hp[1] = 33
	hunt.hunters[0].position = Vector2(60,0)
	hunt.hunters[1].position = Vector2(250,0)
	hunt.hunters[2].position = Vector2.ZERO
	caster_hud.chain_button.pressed.emit()
	_check(hunt.pose == "rally" and raw_rules.rally_cast_pending and raw_rules.orbs(Rules.SAEBOM) == 0,"Real chain button routes to Saebom Rally")
	hunt._process(.27)
	var badge: Panel = caster_hud.portrait_button.get_node_or_null("SaebomBuffPortraitTimer")
	_check(raw_rules.rally_remaining == [5.0,0.0,5.0] and raw_rules.deer_hp == 100,"Screen resolves radius recipients, no enemy hit")
	_check(is_instance_valid(badge) and badge.visible and badge.get_node("Seconds").text == "5" and badge.get_node("Icon").texture == caster_hud.chain_art.texture,"Bottom portrait shows five seconds and actual chain icon")
	app.modal = true
	hunt._process(1.0)
	_check(raw_rules.rally_remaining[Rules.SAEBOM] == 5.0,"Pause freezes the timer")
	app.modal = false
	hunt.speed = 2.0
	raw_rules.exchange_clock = -100.0
	for frame in 51:
		hunt._process(.01)
	_check(_close(raw_rules.rally_remaining[Rules.SAEBOM], 3.98) and badge.get_node("Seconds").text == "4","2x maintains battle-time semantics and ticks portrait")
	for frame in 199:
		hunt._process(.01)
	_check(raw_rules.rally_remaining[Rules.SAEBOM] == 0.0 and not badge.visible,"Portrait indicator hides on expiry")
	raw_rules.charges[Rules.SAEBOM]=3.0
	caster_hud.portrait_button.pressed.emit()
	_check(raw_rules.pending_damage == 58 and raw_rules.charges[Rules.SAEBOM] == 1.0, "Real portrait light skill keeps the legacy 2SP attack")
	hunt.speed = 1.0
	hunt._process(.27)
	_check(saebom.position.is_equal_approx(saebom_settled) and saebom.animation.current_animation == "sling_heavy","Legacy 2SP shows real sling motion without the old spear lunge")
	var cleared := int(app.model.state.get("hunt_cleared", 0))
	raw_rules.damage_deer(raw_rules.deer_hp)
	hunt._process(.01)
	_check(hunt.result_shown and int(app.model.state.get("hunt_cleared", 0)) == cleared + 1,"Ordinary victory still records stage progression")
	app.retry_hunt()
	await process_frame
	_check(app.hunt.rules.rally_remaining == [0.0,0.0,0.0],"Retry cannot leak an old buff")
	app.queue_free()
	await process_frame


func _run() -> void:
	_rules_suite()
	if "--production-hunt-screen" in OS.get_cmdline_user_args():
		create_timer(18.0).timeout.connect(func():
			push_error("Production hunt fixture timed out")
			quit(1))
		await _screen_suite()
	print("Production hunt Saebom Rally: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
