extends SceneTree
var checks:=0
var failures:Array[String]=[]
var deliveries:={"resident-0":0,"resident-1":0}
var previous_cargo:={"resident-0":false,"resident-1":false}
var remote_credit:=false
var model:GameState
var world:DemoWorld
var max_frame_ms:=0.0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func record_transaction()->void:
	var jobs:=ResidentJobs.new(model)
	for worker in world.residents:
		var id:=worker.resident_id
		var cargo:bool=not jobs.entry(id).cargo.is_empty()
		if previous_cargo[id] and not cargo:
			deliveries[id]+=1
			var depot:=DemoConfig.CHIEF_POSITION+Vector2(-35 if id=="resident-0" else 35,110)
			remote_credit=remote_credit or worker.position.distance_to(depot)>5
		previous_cargo[id]=cargo
func run()->void:
	var test_seed:=61106
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):test_seed=int(arg.trim_prefix("--seed="))
	seed(test_seed)
	model=GameState.new(SaveStore.new("user://tests/job_concurrency_%s"%Time.get_ticks_usec()));model.start_new()
	var next:=model.state.duplicate(true);next.family_joined=true;model.commit(next)
	var jobs:=ResidentJobs.new(model)
	jobs.assign("resident-0","wood");jobs.assign("resident-1","wood")
	var target:Dictionary={}
	for node in model.nodes():
		if node.kind=="wood":target=node;break
	next=model.state.duplicate(true);next.depleted[target.id]=int(target.charges)-1;model.commit(next)
	var balance:=int(model.state.wood)
	check(jobs.harvest("resident-0",target.id,1000),"First worker atomically owns last charge")
	check(not jobs.harvest("resident-1",target.id,1000),"Second worker cannot consume same last charge")
	check(model.state.wood==balance and jobs.entry("resident-1").cargo.is_empty(),"Last-charge contest grants no remote/duplicate credit")
	check(jobs.deposit("resident-0") and not jobs.deposit("resident-0") and not jobs.deposit("resident-1"),"Contested last charge can be deposited exactly once")
	# Reset to an ordinary joined village and let BOTH actors work from spawn.
	model.start_new();next=model.state.duplicate(true);next.family_joined=true;model.commit(next)
	world=DemoWorld.new(model);root.add_child(world)
	await physics_frame;await process_frame
	model.changed.connect(record_transaction)
	jobs.assign("resident-0","wood");jobs.assign("resident-1","wood")
	check(world.player.collision_layer!=0 and world.residents[0].collision_layer!=0 and world.residents[1].collision_layer!=0,"Player and both worker collisions remain enabled")
	var wildlife_active:=not world.animals.is_empty()
	for animal in world.animals:wildlife_active=wildlife_active and animal.is_physics_processing() and is_instance_valid(animal.footprint_body) and animal.footprint_body.collision_layer!=0
	check(wildlife_active,"Wildlife movement and footprint collisions remain enabled")
	var started:=Time.get_ticks_usec();var last_frame:=started;var ticks:=0
	for tick in 3600:
		await physics_frame
		var now:=Time.get_ticks_usec();max_frame_ms=maxf(max_frame_ms,float(now-last_frame)/1000);last_frame=now;ticks=tick+1
		if deliveries["resident-0"]>0 and deliveries["resident-1"]>0:break
	check(deliveries["resident-0"]>0 and deliveries["resident-1"]>0,"Both simultaneous woodcutters deliver at least once within 60 simulated seconds")
	check(not remote_credit,"Every observed cargo deposit occurs at its HQ slot")
	var diagnostics:=[]
	for worker in world.residents:diagnostics.append({"id":worker.resident_id,"phase":worker.job_phase,"position":[worker.position.x,worker.position.y],"cargo":jobs.entry(worker.resident_id).cargo,"route_points":worker.job_route.size()})
	var report:={"seed":test_seed,"checks":checks,"failed":failures,"deliveries":deliveries,"physics_ticks":ticks,"elapsed_wall_ms":float(Time.get_ticks_usec()-started)/1000,"max_frame_interval_ms":max_frame_ms,"workers":diagnostics,"scope":"Native headless Godot PC; original player/wildlife/resident physics left enabled. No Android performance claim."}
	print(JSON.stringify(report));FileAccess.open("res://reports/resident-jobs-concurrency-%s-tests.json"%test_seed,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
