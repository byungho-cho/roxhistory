extends "res://tests/building_hold_v056_tests.gd"

func tap(at:Vector2)->void:
	touch(at,0,true)
	touch(at,0,false)

func run()->void:
	var folder:="user://first_quests_%d"%Time.get_ticks_usec()
	var model:=GameState.new(SaveStore.new(folder))
	check(model.start_new(),"Fresh game saved")
	check(model.state.wood==0 and model.state.stone==0 and model.state.grain==0,"Fresh stock is zero")
	check(not model.ensure_family_visit(),"First visit waits for a hut")
	var wood:String=""
	var stone:String=""
	for node in model.nodes():
		if node.kind=="wood" and wood.is_empty():wood=node.id
		if node.kind=="stone" and stone.is_empty():stone=node.id
	check(not wood.is_empty() and not stone.is_empty(),"Gather sources available from actual map fixture")
	check(model.gather(stone) and model.state.stone==110 and FirstQuests.current(model.state)==0,"Early stone gathering pays once and keeps wood as current")
	check(model.gather(wood) and model.state.wood==110 and FirstQuests.current(model.state)==2,"Successful wood gathering pays and advances past completed stone")
	model=GameState.new(SaveStore.new(folder))
	check(model.state.stone==110 and model.state.wood==110 and not model.gather(wood),"Reload does not repeat automatic rewards and normal cap applies")
	var now:=Time.get_unix_time_from_system()
	check(model.begin_construction("chief",DemoConfig.CHIEF_POSITION,now) and model.finish_constructions(now+60),"Chief construction completes")
	check(model.state.grain==100 and model.state.wood==90 and model.state.stone==90,"Chief completion pays grain only")
	check(model.begin_construction("hut",Vector2(900,900),now) and model.finish_constructions(now+60),"First hut completes")
	check(FirstQuests.pending(model.state)==[3] and FirstQuests.current(model.state)==4,"An unclaimed hut reward does not gate the next quest")
	check(model.ensure_family_visit() and model.family_visitor_count()==1,"First visit has exactly one resident after hut completion")
	check(ResidentAdmission.join(model,now) and FirstQuests.current(model.state)==5,"Admission advances the quest")
	check(model.ensure_family_visit(now+61) and model.family_visitor_count() in [1,2],"Later visits contain one or two residents")
	model.store.blocked=true
	check(not model.claim_quest_reward(3) and model.state.grain==100,"Failed save does not award or claim")
	model.store.blocked=false
	check(model.claim_quest_reward(3) and model.state.grain==150 and not model.claim_quest_reward(3),"Repeated reward claim pays exactly once")
	model=GameState.new(SaveStore.new(folder))
	check(model.state.grain==150 and not model.claim_quest_reward(3),"Manual receipt persists across reload")
	var legacy_store:=SaveStore.new(folder+"_legacy")
	var legacy:=DemoConfig.fresh()
	legacy.chief_level=2
	legacy.wood=275
	check(legacy_store.save_game(legacy,true),"Legacy fixture saved")
	var migrated:=GameState.new(legacy_store)
	check(migrated.state.wood==375 and migrated.state.grain==100 and "chief_upgrade" in migrated.state.quests_done,"Legacy milestones credited without truncating existing stock")
	check(GameState.new(legacy_store).state.wood==375,"Legacy credit is idempotent")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames()
	app.model=model
	model.changed.connect(app.update_hud)
	var state:=model.state.duplicate(true)
	state.resident_guide_seen=true
	state.pending_family_count=0
	state.family_next_at=now+10000
	model.commit(state)
	app.enter_game()
	await frames(12)
	var entry:Button=app.stage.get_node("QuestRewardEntry")
	tap(entry.get_global_rect().get_center())
	await frames()
	check(app.modal and app.overlay.has_node("QuestRewardPanel"),"Lower left reward entry opens the popup")
	var panel:Control=app.overlay.get_node("QuestRewardPanel")
	tap(panel.get_global_rect().position+Vector2(45,80))
	await frames()
	check(app.modal and model.state.grain==150,"Panel body consumes input without awarding")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/first-quest-rewards.png")
	var button:Button=panel.find_child("ClaimQuest4",true,false)
	tap(button.get_global_rect().get_center())
	await frames()
	check(app.modal and model.state.grain==200 and FirstQuests.pending(model.state).is_empty(),"Reward button pays individual card and refreshes popup")
	var close:Button=panel.get_node("QuestRewardClose")
	check(close.get_global_rect().size.x>=47.9,"Close touch area is at least 48 logical pixels")
	tap(close.get_global_rect().get_center())
	await frames()
	check(not app.modal and model.state.grain==200,"X closes without another award")
	tap(entry.get_global_rect().get_center())
	await frames()
	tap(Vector2(10,10))
	await frames()
	check(not app.modal and model.state.grain==200,"Backdrop closes without awarding")
	var chief:Sprite2D=app.world.building_sprite("chief")
	check(chief.texture.resource_path.ends_with("chief-retouch/l1.png"),"Actual chief uses approved art")
	if DisplayServer.get_name()!="headless":
		app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.1,model.building_position("chief"))
		await frames(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/first-quest-chief.png")
	check(model.upgrade_chief(now) and model.finish_chief_upgrade(now+61),"Chief upgrade completes")
	check(FirstQuests.current(model.state)==6,"Upgrade advances to farm")
	check(model.begin_construction("farm",Vector2(1300,1000),now) and model.finish_constructions(now+61),"Farm construction completes")
	var farm:Dictionary=model.facilities()[0]
	check(ResidentJobs.new(model).assign("resident-0","farmer","farm:"+str(farm.uid)),"Farmer can be assigned normally")
	check(FirstQuests.current(model.state)==-1 and FirstQuests.pending(model.state)==[5,6,7],"All eight quests complete without requiring reward collection")
	for level in range(1,5):
		var stage_state:=model.state.duplicate(true)
		stage_state.chief_level=level
		model.commit(stage_state)
		check(app.world.building_sprite("chief").texture.resource_path.ends_with("chief-retouch/l%d.png"%level),"Chief %d uses its approved retouch"%level)
	app.close_modal()
	check(model.start_new(),"Isolated fixture resets for guide checks")
	await frames(4)
	check(app.overlay is CharacterGuide and app.overlay.heading==FirstQuests.TITLES[0],"First wood quest presents its guide")
	app.close_modal()
	check(model.gather(wood),"Guide fixture gathers wood")
	await frames(4)
	check(app.overlay is CharacterGuide and app.overlay.heading==FirstQuests.TITLES[1],"Stone quest presents its guide")
	app.close_modal()
	check(model.gather(stone),"Guide fixture gathers stone")
	await frames(4)
	check(app.overlay is CharacterGuide and app.overlay.heading==FirstQuests.TITLES[2],"Chief quest presents its guide")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
