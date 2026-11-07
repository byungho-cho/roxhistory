extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,title:String)->void:
	checks+=1
	if not ok:failures.append(title);push_error(title)
func _initialize()->void:call_deferred("run")
func run()->void:
	for kind in BuildingRules.KINDS:
		for level in 4:
			var job:=BuildingRules.new_job(kind,level,100,true)
			check(job.clock_duration==5 and job.finishes_at==105,"Every building/tier uses5 seconds: %s%d"%[kind,level+1])
			var normal:=BuildingRules.new_job(kind,level,100,false)
			check(normal.clock_duration==BuildingRules.duration(level+1),"OFF keeps original duration: %s%d"%[kind,level+1])
	var model:=GameState.new(SaveStore.new("user://fixed5_%d"%Time.get_ticks_usec()));model.start_new()
	var now:=Time.get_unix_time_from_system()
	var state:=model.state.duplicate(true);state.chief_level=1;state.debug_fast_build=true;state.fast_build_mode="speed10"
	var old:=BuildingRules.new_job("chief",1,now-30,false);old.clock_duration=60.0;old.started_at=now-30;old.finishes_at=now+30
	state.chief_upgrade=old;model.commit(state)
	var wood:int=model.state.wood
	var loaded:=GameState.new(model.store)
	var migrated:Dictionary=loaded.state.chief_upgrade
	check(loaded.state.fast_build_mode=="fixed5" and migrated.clock_duration==5,"Old ON save migrates to fixed5")
	check(migrated.finishes_at-Time.get_unix_time_from_system()>2.35 and migrated.finishes_at-Time.get_unix_time_from_system()<2.65,"Legacy half-finished job retains half progress")
	check(loaded.state.wood==wood and loaded.chief_level()==1,"Migration neither charges nor completes early")
	var due:float=migrated.finishes_at
	check(absf(float(GameState.new(model.store).state.chief_upgrade.finishes_at)-due)<.001,"Reload does not restart five-second clock")
	var halfway:float=migrated.started_at+2.5
	loaded.set_debug_fast_build(false,halfway)
	check(loaded.state.chief_upgrade.clock_duration==600 and absf(float(loaded.state.chief_upgrade.finishes_at)-(halfway+300))<.001,"OFF retains50 percent progress on normal clock")
	loaded.set_debug_fast_build(true,halfway+150)
	check(loaded.state.chief_upgrade.clock_duration==5 and absf(float(loaded.state.chief_upgrade.finishes_at)-(halfway+151.25))<.001,"ON retains75 percent progress with1.25 seconds left")
	var done:=BuildingRules.new_job("hut",0,100,false);var snapshot:=done.duplicate(true)
	BuildingRules.set_clock_mode(done,200,true);check(done==snapshot,"Completed job never becomes pending again")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
