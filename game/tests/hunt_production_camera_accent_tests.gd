extends "res://tests/hunt_production_frontline_main_input_tests.gd"

func run()->void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.application_active=true
	check("Fresh ordinary camera fixture",app.model.start_new({},true))
	var hunt=await prepare(4,0)
	hunt.rules.charges[0]=3.0
	hunt.update_combat_ui()
	var han:Control=hunt.party_cards[0].hud
	check("Actual 2SP click reached",await click_button(han.portrait_button))
	for i in range(49):hunt._process(1.0/60.)
	check("2SP does not trigger camera accent",hunt.camera_accent_source.is_empty())
	hunt.rules.party_hp[1]=0
	hunt.rules.charges[0]=3.0
	hunt.update_combat_ui()
	check("Actual standalone Han 3SP click reached",await click_button(han.chain_button))
	for i in range(37):hunt._process(1.0/60.)
	check("3SP subtly zooms at native apex, does not slow simulation",hunt.camera_accent_source=="han_chain" and hunt.battlefield.scale.x>hunt.zoom+.015 and is_equal_approx(Engine.time_scale,1.0))
	check("Active accent never stacks",not hunt._start_camera_accent("overlap",Vector2(510,305)) and hunt.camera_accent_source=="han_chain")
	for i in range(49):hunt._process(1.0/60.)
	check("Camera eases back",absf(hunt.battlefield.scale.x-hunt.zoom)<.01)
	hunt=await prepare(5,1)
	hunt.rules.hunter_turn=false
	hunt.rules.next_target=1
	hunt.rules.charges.assign([3.,3.,3.])
	hunt.rules.exchange_clock=Rules.AUTO_INTERVAL
	hunt._process(1.0/60.)
	check("Enemy charge preparation does not zoom",hunt.camera_accent_source.is_empty())
	var guard:Control=hunt.party_cards[1].hud
	check("Actual guard click reached",await click_button(guard.chain_button))
	check("Guard tap by itself does not trigger camera",hunt.camera_accent_source.is_empty())
	for i in range(26):hunt._process(1.0/60.)
	check("Only real shield contact triggers parry accent",not hunt.last_guard_contact.is_empty() and hunt.camera_accent_source=="parry" and hunt.battlefield.scale.x>hunt.zoom+.015)
	hunt=await prepare(5,1)
	hunt.rules.hunter_turn=false
	hunt.rules.next_target=1
	hunt.rules.exchange_clock=Rules.AUTO_INTERVAL
	for i in range(32):hunt._process(1.0/60.)
	check("Failure and ordinary incoming contact do not zoom",hunt.rules.party_hp[1]==31 and hunt.camera_accent_source.is_empty())
	app.queue_free()
	await process_frame
	print("Ordinary camera accent: ",checks," checks; ",failures," failures")
	quit(int(failures!=0))
