extends "res://tests/building_hold_v056_tests.gd"
func snap(name:String)->void:
	await frames(5);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/v0161-"+name+".png")
func run()->void:
	root.size=Vector2i(1280,800)
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.model=GameState.new(SaveStore.new("user://farm_ui_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
	var s:Dictionary=app.model.state.duplicate(true);s.chief_level=4;s.resident_count=3;s.resident_guide_seen=true;s.family_next_at=Time.get_unix_time_from_system()+10000
	s.homes=[{"uid":"h1","style":1,"claimed":false,"level":4,"position":[900,900],"cost":{"wood":20,"stone":10}},{"uid":"h2","style":1,"claimed":true,"level":1,"position":[1400,800],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=false
	s.facilities=[{"uid":"f1","kind":"farm","level":4,"position":[1300,1000],"cost":{"wood":10,"stone":5}}];s.outposts=[{"uid":"p1","level":1,"position":[1600,800],"cost":{"wood":10,"stone":10}}]
	check(app.model.commit(s),"UI fixture accepted");app.enter_game();await frames(12)
	for actor in app.world.residents:actor.set_physics_process(false)
	app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,.8,Vector2(1250,850));await frames()
	check(is_instance_valid(app.world.building_sprite("farm:f1")),"Farm placeholder participates in ordinary building rendering")
	check(app.world.get_node("Facility_f1").has_node("TemporaryCropVisual"),"Four-stage temporary crops and production HUD attached")
	check(app.resident_panel.bubbles.size()==3,"Chief, farm and post have persistent assignment entry points")
	var bubble:DemoButton=app.resident_panel.bubbles["farm:f1"]
	check(bubble.get_child(0).modulate.a<.5 and app.gestures.ui_hit(bubble.get_global_rect().get_center()),"Empty building bubble is distinct and owns input")
	touch(bubble.get_global_rect().get_center(),0,true);touch(bubble.get_global_rect().get_center(),0,false);await frames();check(app.modal and app.overlay.find_child("AssignmentContent",true,false)!=null,"Touching building bubble opens direct assignment")
	await snap("building-assignment");app.close_modal()
	app.resident_panel.assign(0,"farmer","farm:f1");await frames()
	check(ResidentJobs.new(app.model).assigned_to("farm:f1")==app.resident_panel.id_at(0) and bubble.get_child(0).modulate.a==1.0,"Building assignment and bubble update from shared persisted source")
	app.resident_panel.show_summary();await frames();await snap("residents")
	check(app.overlay.find_child("ResidentAssignmentScroll",true,false)!=null,"Whole resident list is scrollable")
	app.resident_panel.show_assignment(1,"guard","outpost:p1");await frames();await snap("jobs")
	var confirm:Button=app.overlay.find_child("ConfirmResidentAssignment",true,false);check(not confirm.disabled,"Guard assignment requires selected valid post")
	confirm.pressed.emit();await frames();check(ResidentJobs.new(app.model).assigned_to("outpost:p1")==app.resident_panel.id_at(1),"Guard selection commits one station")
	app.resident_panel.show_assignment(2,"farmer","");await frames();check(app.overlay.find_child("ConfirmResidentAssignment",true,false).disabled,"No target farm cannot be assigned")
	app.close_modal();var farmer:TrialResident=app.world.residents[0];farmer.position=Vector2(1300,1000)+TrialResident.FARM_STANDS[0]
	s=app.model.state.duplicate(true);s.farm_cycles={"farm:f1":{"phase":"ready","elapsed":600.0,"cuts":0,"stock":0,"cycle_level":4}};app.model.commit(s)
	var grain_before:int=app.model.state.grain
	farmer._job_tick(.6);check(farmer.job_phase=="harvest" and ResidentJobs.new(app.model).entry(farmer.resident_id).cargo.is_empty(),"Harvest action active before 1.2 second cut")
	farmer._job_tick(.6)
	check(ResidentJobs.new(app.model).entry(farmer.resident_id).cargo.amount==10 and app.model.state.grain==grain_before,"First cut becomes one carried load without remote credit")
	var loads:Array=[10];var carrying:=true;var early_credit:=false
	farmer.set_physics_process(true)
	for tick in 4800:
		await physics_frame
		var cargo:Dictionary=ResidentJobs.new(app.model).entry(farmer.resident_id).cargo
		if not cargo.is_empty() and not carrying:loads.append(int(cargo.amount))
		carrying=not cargo.is_empty()
		if carrying and app.model.state.grain!=grain_before+10*(loads.size()-1):early_credit=true
		if int(app.model.state.grain)>=grain_before+40:break
	farmer.set_physics_process(false)
	check(loads==[10,10,10,10] and not early_credit,"Four separate cuts produce four sequential home trips")
	check(app.model.state.grain==grain_before+40 and FarmProduction.entry(app.model,"farm:f1").stock==0,"Farmer walks each load home and credits exactly forty")
	check(FarmProduction.entry(app.model,"farm:f1").phase=="prepare","All four harvest trips lead to next preparation phase")
	app.world.player.presentation_paused=false;await snap("farm")
	s=app.model.state.duplicate(true);s.farm_cycles["farm:f1"].phase="grow";s.farm_cycles["farm:f1"].elapsed=450.0;app.model.commit(s)
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.2,Vector2(1300,1000));await snap("farm-growth-temporary")
	var jobs:=ResidentJobs.new(app.model);jobs.assign(app.resident_panel.id_at(2),"wood")
	var worker:TrialResident=app.world.residents[2];worker.position=Vector2(1420,930)
	var node:Dictionary={}
	for candidate in app.model.nodes():
		if candidate.kind=="wood":node=candidate;break
	check(jobs.harvest(worker.resident_id,node.id),"Natural worker load retained independently of hero balance")
	worker._job_tick(.016)
	check(worker.depot_home==Vector2(1400,800),"Worker selects closest resident home instead of chief")
	check(worker.job_depot.is_finite(),"Reachable doorway route planned without fixed transport timer")
	var wood:int=app.model.state.wood;worker.position=worker.job_depot;worker._job_tick(.016)
	check(app.model.state.wood==wood+10 and jobs.entry(worker.resident_id).cargo.is_empty(),"Actual home arrival delivers once")
	app.show_notification_settings();await frames();await snap("notifications")
	check(VillageNotifications.setting(app.model.state,"arrival")==null,"General settings show unspecified notification state")
	app.close_modal();app.show_demolition_confirmation("h1");await frames();await snap("demolition-warning")
	check(app.modal and int(app.model.demolition_quote("h1").departures)==2,"Demolition popup preflights exact excess population")
	var warning_scroll:ScrollContainer=app.overlay.find_children("*","ScrollContainer",true,false)[0];check(warning_scroll.get_v_scroll_bar().max_value<=warning_scroll.size.y+1,"Departure warning is visible without scrolling")
	var old_count:int=app.model.resident_count();app.close_modal();check(app.model.resident_count()==old_count,"Closing demolition popup never removes residents")
	app.resident_panel.show_summary();await frames();root.size=Vector2i(1280,720);await frames(15);app.resident_panel.show_summary();await frames()
	var scroll:ScrollContainer=app.overlay.find_child("ResidentAssignmentScroll",true,false);check(scroll.size.y>0,"Assignment remains usable at mobile landscape height")
	app.close_modal();s=app.model.state.duplicate(true);s.resident_count=15;s.homes[1].level=4;s.homes.append({"uid":"h3","style":1,"claimed":true,"level":4,"position":[700,1100],"cost":{"wood":20,"stone":10}});app.model.commit(s)
	for actor in app.world.residents:actor.set_physics_process(false)
	app.resident_panel.show_summary();await frames(8);scroll=app.overlay.find_child("ResidentAssignmentScroll",true,false)
	var row_button:Button
	for button in app.overlay.find_children("*","Button",true,false):
		if button.text=="변경":row_button=button;break
	var start:=row_button.get_global_rect().get_center();touch(start,0,true);drag_touch(start-Vector2(0,320),0);touch(start-Vector2(0,320),0,false);await frames()
	check(scroll.scroll_vertical>0 and app.overlay.find_child("ResidentAssignmentScroll",true,false)==scroll,"Dragging from resident change button scrolls instead of assigning")
	scroll.scroll_vertical=100000;await frames();check(scroll.scroll_vertical>300,"Fifteen residents can scroll to bottom at mobile height")
	await snap("residents-scroll-bottom")
	print(JSON.stringify({"checks":checks,"failures":failures,"touch":"synthetic; Android hardware not tested"}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)

