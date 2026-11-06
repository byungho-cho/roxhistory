extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	seed(61106)
	var model:=GameState.new(SaveStore.new("user://tests/job_runtime_%s"%Time.get_ticks_usec()));model.start_new()
	var next:=model.state.duplicate(true);next.family_joined=true;model.commit(next)
	var world:=DemoWorld.new(model);root.add_child(world)
	await physics_frame;await process_frame
	for animal in world.animals:animal.set_physics_process(false)
	for resident in world.residents:resident.set_physics_process(false);resident.collision_layer=0
	world.player.set_physics_process(false);world.player.collision_layer=0
	var worker:TrialResident=world.residents[0];var jobs:=worker.jobs
	check(worker.resident_id=="resident-0","Stable actor ID")
	jobs.assign(worker.resident_id,"wood")
	# Exhaust every active matching node and prove search sleeps between retries.
	next=model.state.duplicate(true)
	for node in model.nodes():
		if node.kind=="wood":next.depleted[node.id]=int(node.charges)
	model.commit(next)
	worker._job_tick(.1)
	check(worker.job_phase=="wait" and worker.job_timer==2.0 and worker.job_route.is_empty(),"No available node enters timed wait")
	worker._job_tick(.5)
	check(worker.job_timer==1.5 and worker.job_route.is_empty(),"Waiting does not rescan every frame")
	# Resume a loaded save away from HQ; balance cannot change remotely.
	next=model.state.duplicate(true);next.resident_jobs[worker.resident_id].cargo={"kind":"wood","amount":10};model.commit(next)
	worker.position=DemoConfig.CHIEF_POSITION+Vector2(-35,210);worker.job_timer=0
	var before:=int(model.state.wood)
	worker._job_tick(.016)
	check(model.state.wood==before and not jobs.entry(worker.resident_id).cargo.is_empty(),"Remote loaded cargo is not credited")
	jobs.assign(worker.resident_id,"idle")
	worker.position=DemoConfig.CHIEF_POSITION+Vector2(-35,110);worker._job_tick(.016)
	check(model.state.wood==before+10 and jobs.entry(worker.resident_id).cargo.is_empty(),"Stopped actor delivers old cargo only at HQ")
	worker._job_tick(.016)
	check(model.state.wood==before+10,"Repeated HQ tick does not double-credit")
	# A selected job remains valid without an active actor and grants no resources.
	jobs.assign("resident-1","stone")
	check(jobs.entry("resident-1").job=="stone" and int(model.state.stone)==500,"Unavailable/disabled actor produces no remote rewards")
	# Actual physics cycle: start beside a tree, harvest, then walk home.
	var target:Dictionary={}
	for node in model.nodes():
		if node.kind=="wood":target=node;break
	next=model.state.duplicate(true);next.depleted[target.id]=0;model.commit(next);world.refresh()
	worker.position=DemoConfig.point(target.position)+Vector2(0,65)
	worker.job_phase="idle";worker.job_timer=0;worker.job_route.clear()
	jobs.assign(worker.resident_id,"wood");worker.set_physics_process(true)
	var balance:=int(model.state.wood);var carried:=false;var remote_credit:=false
	for tick in 1200:
		await physics_frame
		if not jobs.entry(worker.resident_id).cargo.is_empty():carried=true;remote_credit=remote_credit or int(model.state.wood)!=balance
		if int(model.state.wood)>balance:break
	worker.set_physics_process(false)
	check(carried and not remote_credit,"Physics harvest enters visible return trip without remote credit")
	check(int(model.state.wood)==balance+10 and worker.position.distance_to(DemoConfig.CHIEF_POSITION+Vector2(-35,110))<=5,"Physics route delivers one load to HQ")
	var report:={"checks":checks,"failed":failures};print(JSON.stringify(report));FileAccess.open("res://reports/resident-jobs-runtime-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
