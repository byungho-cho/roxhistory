extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	seed(621)
	var folder:="user://village_rules_%s"%Time.get_ticks_usec()
	var store:=SaveStore.new(folder)
	var model:=GameState.new(store)
	check(model.start_new(),"Start isolated new save")
	check(model.debug_unlimited_builders and model.builder_available(),"Test-period unlimited builders default on")
	model.construction_busy=true
	check(model.can_upgrade_chief(),"Default unlimited allows upgrade during construction")
	model.debug_unlimited_builders=false
	check(not model.can_upgrade_chief(),"Turning unlimited off enforces one builder")
	model.construction_busy=false
	check(model.home_limit()==1 and model.nodes().size()==5,"HQ1 limits")
	check(model.build(Vector2.ZERO,0),"First home")
	check(not model.can_build(),"HQ1 second home locked")
	check(model.resident_capacity()==1 and model.resident_count()==0,"Home capacity excludes chief and hero")
	check(not OwnedBuildingUpgrades.start(model,model.home_key(0),1000),"Home cannot exceed HQ")
	var now:=floorf(Time.get_unix_time_from_system())+10000
	for target in [2,3,4]:
		check(model.can_upgrade_chief(),"HQ upgrade without outpost")
		check(model.upgrade_chief(now),"Start HQ upgrade")
		check(model.state.chief_upgrade.finishes_at-now==pow(2,target),"HQ4/8/16 seconds")
		check(model.active_builder_jobs()==1 and not model.can_build(),"HQ job occupies builder")
		check(not OwnedBuildingUpgrades.start(model,model.home_key(0),now),"No simultaneous owned upgrade")
		check(model.finish_chief_upgrade(now+pow(2,target)),"Finish HQ")
		check(model.home_limit()==mini(target,3),"HQ home count limit")
		check(model.nodes().size()==[5,10,10,20][target-1],"Active resource tier")
		now+=100
	check(model.building_unlocked("hearth") and model.building_unlocked("shrine") and model.outpost_unlocked(),"HQ unlocks")
	check(model.build(Vector2.ZERO,1) and model.build(Vector2.ZERO,2),"Three homes")
	check(not model.can_build(),"Absolute new cap3")
	check(model.join_family() and model.resident_count()==2,"Only actual joined residents counted")
	var key:=model.home_key(0)
	for target in [2,3,4]:
		check(OwnedBuildingUpgrades.start(model,key,now),"Owned upgrade")
		check(not model.can_build_outpost(),"Owned upgrade blocks outpost construction")
		check(OwnedBuildingUpgrades.finish(model,now+pow(2,target)),"Owned finish")
		check(model.resident_capacity()==[1,2,3,5][target-1]+2,"Per-level resident capacity")
		now+=100
	# Preserve all legacy homes, identities, resources and in-flight jobs.
	var legacy:=model.state.duplicate(true)
	legacy.homes.append({"uid":"legacy-extra4","style":0,"claimed":true,"site":3,"level":1})
	legacy.homes.append({"uid":"legacy-extra5","style":2,"claimed":true,"site":4,"level":1})
	legacy.chief_level=1
	legacy.homes[3].upgrade={"from":1,"to":2,"started_at":now,"finishes_at":now+4,"cost":{"wood":20,"stone":20}}
	check(store.valid(legacy) and model.commit(legacy),"Legacy5 plus above-HQ in-flight allowed")
	var reload:=GameState.new(store)
	check(reload.built_count()==5 and reload.home_key(4)=="legacy-extra5","Reload preserves fifth identity")
	check(reload.state.wood==legacy.wood and reload.state.stone==legacy.stone,"Reload preserves earned resources")
	check(not reload.can_build(),"Over-cap legacy cannot create new home")
	check(OwnedBuildingUpgrades.finish(reload,now+4),"Legacy in-flight completion grandfathered")
	check(reload.homes()[3].level==2,"Grandfathered target retained")
	check(reload.start_new(),"Fresh resource fixture")
	var node:Dictionary=reload.nodes()[0]
	for i in int(node.charges):check(reload.gather(node.id,Vector2.ZERO,1000),"Active harvest")
	var due:float=reload.state.respawn_due[node.id]
	check(due>=1300 and due<=1600,"Randomized5–10m respawn")
	check(not reload.respawn(node.id,DemoConfig.point(node.position),due-1),"No early respawn")
	check(reload.respawn(node.id,DemoConfig.point(node.position),due),"Due respawn")
	check(not reload.gather(reload.all_nodes()[-1].id,Vector2.ZERO,1000),"Inactive catalog cannot harvest")
	var saved_positions:Dictionary=reload.state.node_positions.duplicate(true)
	var again:=GameState.new(store)
	for id in saved_positions:check(DemoConfig.point(again.state.node_positions[id]).is_equal_approx(DemoConfig.point(saved_positions[id])),"Seeded positions stable across load")
	for n in again.nodes():check(VillageBounds.rect_for_level(1).has_point(DemoConfig.point(n.position)),"Active position inside HQ area")
	again.construction_busy=true
	again.debug_unlimited_builders=false
	check(not again.can_upgrade_chief(),"Runtime construction occupies builder")
	again.debug_unlimited_builders=true
	check(again.can_upgrade_chief(),"Explicit debug unlimited bypass")
	again.debug_unlimited_builders=false
	check(GameState.new(store).debug_unlimited_builders,"Reload restores test-period unlimited default")
	check(again.start_new() and again.debug_unlimited_builders and not again.construction_busy and not again.busy,"New campaign resets runtime builder options")
	# Clean only the unique test folder we created, not any user's save.
	for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
