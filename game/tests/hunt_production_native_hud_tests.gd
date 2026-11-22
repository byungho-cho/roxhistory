extends "res://tests/hunt_production_frontline_main_input_tests.gd"

func capture(name:String) -> void:
	if OS.get_environment("ROX_HUD_CAP").is_empty(): return
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(OS.get_environment("ROX_HUD_CAP")+"/"+name+".png")

func run()->void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.application_active=true
	check("Fresh ordinary game starts",app.model.start_new({},true))
	var hunt=await prepare(4,0)
	if hunt==null:
		quit(1)
		return
	for i in range(10):
		hunt._process(1.0/60.)
		await process_frame
	check("All head HP initially invisible while grounded rings already available",is_inf(hunt.first_blood_age) and not hunt.head_headers[0].panel.visible and not hunt.head_headers[3].panel.visible and hunt.ring_sizing.size()==4 and hunt.ring_sizing[3].y>4)
	capture("normal-hunt-before-first-hit")
	hunt.rules.charges[0]=3.
	hunt.update_combat_ui()
	var hud:Control=hunt.party_cards[0].hud
	check("Actual local HUD 2SP click",await click_button(hud.portrait_button))
	check("Cast icon is actual normal texture",hunt.cast_notices[0]!=null and hunt.cast_notices[0].texture==hud.badge_art.texture and not hunt.cast_notices[0].linked)
	var taken:=0
	var before:int=hunt.rules.deer_hp
	for i in range(57):
		hunt._process(1.0/60.)
		await process_frame
		if hunt.rules.deer_hp<before and taken==0:
			capture("normal-hunt-live-2sp-impact")
			taken+=1
	check("Actual first hard hit happened",taken==1)
	check("First actual contact revealed compact ally/prey HP with fade complete",hunt.first_blood_age>.27 and hunt.head_headers[0].panel.visible and hunt.head_headers[3].panel.visible and is_equal_approx(hunt.head_headers[3].panel.modulate.a,1.0))
	check("Overhead cast naturally expired",hunt.cast_notices[0]==null)
	capture("normal-hunt-after-first-hit")
	app.queue_free()
	await process_frame
	print("Ordinary combined HUD: ",checks," checks; ",failures," failures")
	quit(int(failures>0))
