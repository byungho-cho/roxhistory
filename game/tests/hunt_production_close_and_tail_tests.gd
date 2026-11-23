extends "res://tests/hunt_production_frontline_main_input_tests.gd"

func prepare_close(stage:int):
	var hunt=await prepare(stage,Rules.SAEBOM)
	if hunt==null: return null
	hunt.rules.hunter_turn=false
	hunt.rules.next_target=Rules.SAEBOM
	hunt.rules.exchange_clock=Rules.AUTO_INTERVAL
	hunt._process(1.0/60.)
	for i in range(40):hunt._process(1.0/60.)
	hunt.rules.exchange_clock=-100.
	check("Legal front-slot actual prey counter leaves compact safe gap ("+str(stage)+")",hunt.bom_prey_pocket.is_finite() and hunt.hunters[2].position.distance_to(hunt.deer.position)<=30.3)
	return hunt

func try_close(stage:int) -> void:
	var hunt=await prepare_close(stage)
	if hunt==null:return
	hunt.rules.hunter_turn=true
	hunt.rules.next_attacker=Rules.SAEBOM
	hunt.rules.exchange_clock=Rules.AUTO_INTERVAL
	hunt._process(1.0/60.)
	check("Actual next close 1HP attack is a planted shove, no projectile",hunt.pose=="auto_thrust" and hunt.bom_shoving and not hunt.stone.active)
	var before:int=hunt.rules.deer_hp
	var projectile:=false
	for i in range(54):
		hunt._process(1.0/60.)
		projectile=projectile or hunt.stone.active
	check("Physical palm hit exactly one at close range",hunt.rules.deer_hp==before-1 and not projectile and hunt.bom_last_shove=="hit")
	hunt.rules.exchange_clock=-100.
	hunt.rules.charges[Rules.SAEBOM]=3.
	hunt.update_combat_ui()
	var hud:Control=hunt.party_cards[Rules.SAEBOM].hud
	before=hunt.rules.deer_hp
	var feet:Vector2=hunt.hunters[Rules.SAEBOM].position
	var gap:=0.
	check("Actual close Saebom 2SP click and backward planted start",await click_button(hud.portrait_button) and hunt.pose=="team" and hunt.bom_hop_offset.length()>1.)
	for i in range(56):
		hunt._process(1.0/60.)
		gap=maxf(gap,feet.distance_to(hunt.hunters[Rules.SAEBOM].position))
	check("Close 2SP one authentic hit, room then return",hunt.stone_last_result=="hit" and hunt.rules.deer_hp==before-58 and gap>5. and feet.distance_to(hunt.hunters[Rules.SAEBOM].position)<.5)

func test_winning_tail() -> void:
	var hunt=await prepare(4,0)
	if hunt==null:return
	hunt.rules.party_hp[1]=0
	hunt.rules.charges[0]=3.
	hunt.rules.deer_hp=8
	hunt.update_combat_ui()
	var hud:Control=hunt.party_cards[0].hud
	check("Actual standalone 3SP win setup accepts button",await click_button(hud.chain_button))
	var held:=false
	for i in range(160):
		hunt._process(1.0/60.)
		if hunt.rules.outcome=="win" and hunt.hit_age<.60 and not hunt.result_shown: held=true
		if hunt.result_shown:break
	check("Native finish retained full tail, then once ordinary result",held and hunt.result_shown and hunt.hit_age>=1.19 and app.model.state.hunt_cleared==app.hunt_stage+1)

func run()->void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.application_active=true
	check("Fresh ordinary start",app.model.start_new({},true))
	for stage in [4,5]:await try_close(stage)
	await test_winning_tail()
	app.queue_free()
	await process_frame
	print("Ordinary close+finisher gate: ",checks," checks; ",failures," failures")
	quit(int(failures!=0))

