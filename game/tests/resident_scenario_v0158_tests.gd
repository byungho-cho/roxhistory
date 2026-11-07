extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	seed(61108)
	var folder:="user://tests/resident_v0158_%s"%Time.get_ticks_usec()
	var model:=GameState.new(SaveStore.new(folder));check(model.start_new(),"Fresh save")
	var next:=model.state.duplicate(true)
	next.chief_level=2;next.chief_position=[1098,600]
	next.homes=[{"uid":"test-home","style":1,"claimed":true,"position":[1390,1000],"level":2,"cost":{"wood":20,"stone":10}}]
	next.built=true;next.reward_claimed=true;next.pending_family_count=2
	check(model.commit(next),"Current housing fixture")
	check(model.join_family() and model.resident_count()==2,"Two visitors admitted through normal capacity gate")
	var jobs:=ResidentJobs.new(model)
	check(jobs.assign("resident-0","wood") and jobs.assign("resident-1","stone"),"Both resource professions assign")
	check(not jobs.assign("resident-2","wood"),"Unadmitted resident rejected")
	var target:Dictionary={}
	for node in model.nodes():
		if node.kind=="wood":target=node;break
	var before:=int(model.state.wood)
	check(jobs.harvest("resident-0",target.id,1000),"One load gathered")
	check(int(model.state.wood)==before and int(jobs.entry("resident-0").cargo.amount)==10,"One gather does not credit before return")
	check(not jobs.harvest("resident-0",target.id,1000),"Loaded worker cannot gather a second load")
	var loaded:=GameState.new(SaveStore.new(folder));var loaded_jobs:=ResidentJobs.new(loaded)
	check(loaded_jobs.entry("resident-0").cargo.get("kind")=="wood" and int(loaded_jobs.entry("resident-0").cargo.get("amount",0))==10,"Cargo survives save and reload")
	check(loaded_jobs.assign("resident-0","stone") and loaded_jobs.entry("resident-0").cargo.kind=="wood","Changing profession keeps existing cargo")
	check(loaded_jobs.assign("resident-0","idle") and loaded_jobs.deposit("resident-0"),"Resting worker may finish prior delivery")
	check(int(loaded.state.wood)==before+10 and not loaded_jobs.deposit("resident-0"),"Delivery credits once")
	model=loaded;jobs=loaded_jobs
	next=model.state.duplicate(true);next.depleted[target.id]=int(target.charges)-1;model.commit(next)
	jobs.assign("resident-0","wood")
	check(jobs.harvest("resident-0",target.id,2000),"Final node charge gathered")
	var due:=float(model.state.respawn_due[target.id])
	check(due>=2300 and due<=2600,"Respawn scheduled five to ten minutes later")
	check(not model.respawn(target.id,Vector2(900,900),due-1),"No early regrowth")
	check(model.respawn(target.id,Vector2(900,900),due),"Stable resource ID respawns at new position")
	check(model.state.depleted[target.id]==0 and model.state.node_positions[target.id]==[900.0,900.0],"Regrowth resets charges and preserves new location")
	jobs.deposit("resident-0")
	# Actual actor loop, with normal navigation and resource collision retained.
	var world:=DemoWorld.new(model);root.add_child(world)
	await physics_frame;await process_frame
	world.player.set_physics_process(false)
	for animal in world.animals:animal.set_physics_process(false)
	for actor in world.residents:actor.set_physics_process(false)
	var worker:TrialResident=world.residents[0]
	worker.position=Vector2(900,965);worker.job_timer=0;worker.job_route.clear()
	check(worker.work_status() in ["작업 준비 중","자원으로 이동 중","채집 중"],"Assigned worker status available")
	var balance:=int(model.state.wood);var carried:=false;var invalid_credit:=false
	worker.set_physics_process(true)
	for tick in 2400:
		await physics_frame
		var cargo:Dictionary=jobs.entry(worker.resident_id).cargo
		if not cargo.is_empty():carried=true;invalid_credit=invalid_credit or int(model.state.wood)!=balance
		if int(model.state.wood)>balance:break
	worker.set_physics_process(false)
	check(carried and not invalid_credit,"Visible harvest enters return phase without remote credit")
	check(int(model.state.wood)==balance+10,"Actor deposits exactly one load after walking")
	check(worker.position.distance_to(model.building_position("chief")+Vector2(-35,110))<=5,"Deposit occurs at chief hut")
	# The second profession also follows a complete return trip in the live world.
	var stone_target:Dictionary={}
	for node in model.nodes():
		if node.kind=="stone":stone_target=node;break
	var stone_worker:TrialResident=world.residents[1]
	stone_worker.position=DemoConfig.point(stone_target.position)+Vector2(0,65)
	stone_worker.job_phase="idle";stone_worker.job_timer=0;stone_worker.job_route.clear()
	var stone_before:=int(model.state.stone);var stone_carried:=false
	stone_worker.set_physics_process(true)
	for tick in 3000:
		await physics_frame
		if not jobs.entry(stone_worker.resident_id).cargo.is_empty():stone_carried=true
		if int(model.state.stone)>stone_before:break
	stone_worker.set_physics_process(false)
	check(stone_carried and int(model.state.stone)==stone_before+10,"Stone worker completes independent gather and return")
	check(stone_worker.position.distance_to(model.building_position("chief")+Vector2(35,110))<=5,"Stone delivery uses its own chief hut arrival point")
	jobs.assign(worker.resident_id,"idle")
	check(worker.work_status()=="쉬는 중","Idle assignment reflected in status")
	print(JSON.stringify({"checks":checks,"failed":failures,"phase":worker.job_phase,"position":[worker.position.x,worker.position.y]}))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
