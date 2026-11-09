extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	seed(61106)
	var folder:="user://tests/jobs_%s"%Time.get_ticks_usec()
	var model:=GameState.new(SaveStore.new(folder));model.start_new()
	var jobs:=ResidentJobs.new(model)
	check(not jobs.assign("resident-0","wood"),"No job before family arrival")
	# Explicit modern fixture: the legacy family flag no longer admits residents.
	var next:=model.state.duplicate(true);next.family_joined=true
	next.resident_count=2;next.resident_roster=["resident-0","resident-1"];next.chief_level=1
	check(model.commit(next),"Admitted residents and completed chief fixture")
	check(not jobs.assign("resident-2","wood"),"No invented residents")
	check(not jobs.assign("resident-0","hunter"),"Unknown job rejected")
	check(jobs.assign("resident-0","wood"),"Persistent assignment")
	var node:Dictionary={}
	for n in model.nodes():
		if n.kind=="wood":node=n;break
	var before:=int(model.state.wood)
	check(jobs.harvest("resident-0",node.id,1000),"Single harvest")
	check(model.state.wood==before and model.state.depleted.get(node.id,0)==1,"Harvest consumes node but does not remotely credit")
	check(not jobs.harvest("resident-0",node.id),"Cannot harvest another load while hauling")
	model=GameState.new(SaveStore.new(folder));jobs=ResidentJobs.new(model)
	check(jobs.entry("resident-0").cargo.get("amount",0)==int(DemoConfig.get_data().gather_yield),"Reload retains cargo")
	check(jobs.assign("resident-0","stone") and jobs.entry("resident-0").cargo.get("kind","")=="wood","Reassignment preserves old load")
	check(jobs.assign("resident-0","idle") and not jobs.entry("resident-0").cargo.is_empty(),"Stopping preserves old load")
	model.store.blocked=true
	check(not jobs.deposit("resident-0") and model.state.wood==before and not jobs.entry("resident-0").cargo.is_empty(),"Failed deposit preserves resources and cargo")
	model.store.blocked=false
	next=model.state.duplicate(true);next.wood=10000;model.commit(next)
	check(jobs.deposit("resident-0") and jobs.entry("resident-0").cargo.is_empty() and model.state.wood==10000,"Full storage preserves existing balance and discards arriving overflow")
	next=model.state.duplicate(true);next.wood=before;model.commit(next)
	check(jobs.assign("resident-0","wood") and jobs.harvest("resident-0",node.id,1100),"Fresh load after overflow disposal")
	check(jobs.deposit("resident-0") and model.state.wood==before+int(DemoConfig.get_data().gather_yield),"HQ deposit credits once")
	check(not jobs.deposit("resident-0"),"No duplicate deposit")
	model=GameState.new(SaveStore.new(folder));jobs=ResidentJobs.new(model)
	check(jobs.entry("resident-0").cargo.is_empty() and not jobs.deposit("resident-0"),"Reload after delivery cannot duplicate")
	jobs.assign("resident-0","wood");model.store.blocked=true
	var depleted:Dictionary=model.state.depleted.duplicate(true)
	check(not jobs.harvest("resident-0",node.id) and model.state.depleted==depleted and jobs.entry("resident-0").cargo.is_empty(),"Failed harvest changes neither cargo nor node")
	check(not jobs.assign("resident-0","stone") and jobs.entry("resident-0").job=="wood","Failed assignment rolls back")
	model.store.blocked=false
	next=model.state.duplicate(true);next.depleted[node.id]=int(node.charges)-1;model.commit(next)
	check(jobs.harvest("resident-0",node.id,2000),"Last charge harvest")
	check(model.state.depleted.get(node.id,0)==int(node.charges) and float(model.state.respawn_due[node.id])>=2300 and float(model.state.respawn_due[node.id])<=2600,"Last charge sets normal respawn window")
	jobs.deposit("resident-0")
	check(not jobs.harvest("resident-0",node.id),"Depleted node cannot yield twice")
	check(not jobs.harvest("resident-0","missing"),"Unavailable target is safe")
	check(ResidentJobs.valid_saved_jobs(model.state),"Job save passes strict validator")
	var bad:=model.state.duplicate(true);bad.resident_jobs["resident-2"]={"job":"wood","cargo":{}}
	check(not ResidentJobs.valid_saved_jobs(bad),"Invalid resident save rejected")
	var report:={"checks":checks,"failed":failures}
	DirAccess.make_dir_recursive_absolute("res://reports")
	var output:=FileAccess.open("res://reports/resident-jobs-tests.json",FileAccess.WRITE)
	if output==null:
		push_error("Cannot write resident jobs report");quit(1);return
	output.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
