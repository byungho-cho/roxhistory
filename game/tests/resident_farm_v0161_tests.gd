extends SceneTree
var checks:=0
var failures:Array[String]=[]
var events:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func fixture()->GameState:
	var model:=GameState.new(SaveStore.new("user://farm0161_%d"%Time.get_ticks_usec()));model.start_new()
	var s:=model.state.duplicate(true);s.chief_level=4;s.debug_unlimited_buildings=false;s.resident_count=5;s.family_joined=true
	s.homes=[{"uid":"h1","style":1,"claimed":false,"level":4,"position":[900,900],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=false
	s.facilities=[{"uid":"f1","kind":"farm","level":1,"position":[1300,950],"cost":{"wood":10,"stone":5}}]
	s.outposts=[{"uid":"p1","level":1,"position":[1500,800],"cost":{"wood":10,"stone":10}}]
	check(model.commit(s),"Fixture accepted")
	return model
func _initialize()->void:call_deferred("run")
func run()->void:
	var model:=fixture();var jobs:=ResidentJobs.new(model)
	check(model.resident_count()==5 and model.resident_capacity()==5,"Only resident homes supply capacity")
	for level in range(1,5):
		var s:=model.state.duplicate(true);s.chief_level=level;model.commit(s)
		check(model.home_limit()==[1,2,3,3][level-1],"HQ home cap %d"%level)
		check(BuildingRules.cost("farm",level)==[{"wood":10,"stone":5},{"wood":20,"stone":10},{"wood":30,"stone":20},{"wood":50,"stone":30}][level-1],"Farm price %d"%level)
		check(BuildingRules.new_job("farm",level-1,100,true).finishes_at==105,"Farm fast clock %d"%level)
	check(jobs.assign("resident-0","farmer","farm:f1"),"Assign farmer")
	check(not jobs.assign("resident-1","farmer","farm:f1"),"One farmer per farm")
	check(jobs.assign("resident-1","guard","outpost:p1"),"Assign guard")
	check(not jobs.assign("resident-2","guard","outpost:p1"),"One guard per post")
	check(not jobs.assign("resident-2","farmer","outpost:p1"),"Correct building type required")
	check(jobs.assign("resident-2","wood") and jobs.assign("resident-3","wood") and jobs.assign("resident-4","wood"),"No arbitrary wood worker quota")
	check(jobs.assigned_to("farm:f1")=="resident-0","Shared building assignment lookup")
	var invalid:=model.state.duplicate(true);invalid.resident_jobs["resident-2"]={"job":"farmer","cargo":{},"building":"farm:f1"}
	check(not model.store.valid(invalid),"Duplicate saved station assignment rejected")
	invalid=model.state.duplicate(true);invalid.farm_cycles={"farm:missing":FarmProduction.fresh()};check(not model.store.valid(invalid),"Orphan farm state rejected")
	invalid=model.state.duplicate(true);invalid.grain=-1;check(not model.store.valid(invalid),"Negative grain rejected")
	model.store.blocked=true
	check(not jobs.assign("resident-0","idle") and jobs.assigned_to("farm:f1")=="resident-0","Failed assignment rolls back")
	check(not FarmProduction.tick(model,60) and FarmProduction.entry(model,"farm:f1").phase=="prepare","Failed production save rolls back")
	model.store.blocked=false
	for level in range(1,5):
		var s:=model.state.duplicate(true);s.facilities[0].level=level;s.farm_cycles={};model.commit(s)
		check(FarmProduction.tick(model,59) and FarmProduction.entry(model,"farm:f1").phase=="prepare","Separate preparation minute %d"%level)
		FarmProduction.tick(model,1)
		check(FarmProduction.entry(model,"farm:f1").phase=="grow" and FarmProduction.entry(model,"farm:f1").elapsed==0,"Growth starts after preparation %d"%level)
		FarmProduction.tick(model,599)
		check(FarmProduction.entry(model,"farm:f1").phase=="grow","Growth lasts ten minutes %d"%level)
		FarmProduction.tick(model,1)
		check(FarmProduction.entry(model,"farm:f1").phase=="ready","Ready at 100 percent %d"%level)
		for i in FarmProduction.CUTS[level-1]:check(FarmProduction.harvest(model,"resident-0","farm:f1"),"Harvest cut %d-%d"%[level,i])
		var cycle:=FarmProduction.entry(model,"farm:f1")
		check(cycle.stock==FarmProduction.YIELDS[level-1] and cycle.phase=="prepare" and cycle.elapsed==0,"Exact yield and next cycle %d"%level)
		check(not FarmProduction.harvest(model,"resident-0","farm:f1"),"No duplicate final cut %d"%level)
	var grain:int=model.state.grain
	check(not FarmProduction.collect_stock(model,"resident-0","farm:f1",0),"Unspecified transport amount stays pending")
	check(FarmProduction.collect_stock(model,"resident-0","farm:f1",10),"Explicit transport load atomically leaves farm stock")
	check(not FarmProduction.collect_stock(model,"resident-0","farm:f1",10),"One cargo at a time")
	check(jobs.deposit("resident-0") and model.state.grain==grain+10 and not jobs.deposit("resident-0"),"Grain shares exact-once home deposit")
	var before:Dictionary=FarmProduction.entry(model,"farm:f1");var folder:=model.store.directory
	var reloaded:=GameState.new(SaveStore.new(folder))
	check(FarmProduction.entry(reloaded,"farm:f1")==before,"Reload retains active production without offline catch-up")
	var old:=model.state.duplicate(true);old.erase("grain");old.erase("copper");old.tokens=123
	model.commit(old);reloaded=GameState.new(SaveStore.new(folder))
	check(reloaded.state.grain==123 and reloaded.state.tokens==123 and reloaded.state.copper==0,"Seed balance migrated without erasing old value or inventing copper income")
	check(not reloaded.claim_reward(0) and not reloaded.state.homes[0].claimed,"Unspecified copper income not invented; legacy claim flags retained")
	var node:Dictionary=model.nodes()[0]
	while node.kind!="wood":node=model.nodes()[1]
	var s:=model.state.duplicate(true);s.depleted[node.id]=int(node.charges)-1;model.commit(s)
	check(jobs.harvest("resident-2",node.id,1000),"Worker consumes last charge")
	check(not model.gather(node.id) and not jobs.harvest("resident-3",node.id),"Hero and second worker cannot duplicate exhausted charge")
	check(jobs.entry("resident-2").cargo.amount==10,"Worker cargo ten")
	var wood:int=model.state.wood
	check(jobs.deposit("resident-2") and model.state.wood==wood+10 and not jobs.deposit("resident-2"),"Deposit exactly once")
	model.notification_requested.connect(func(event,payload):events.append({"event":event,"payload":payload}))
	check(VillageNotifications.setting(model.state,"construction")==null,"Notification default remains unspecified")
	VillageNotifications.dispatch(model,"construction",{});check(events.is_empty(),"Unconfigured transport does not emit")
	check(VillageNotifications.set_enabled(model,"construction",true),"Notification ON saved")
	VillageNotifications.dispatch(model,"construction",{"kind":"farm"});check(events.size()==1,"Enabled event dispatched")
	VillageNotifications.set_enabled(model,"construction",false);VillageNotifications.dispatch(model,"construction",{});check(events.size()==1,"OFF suppresses event")
	check(not VillageNotifications.set_enabled(model,"harvest",true),"Automatic harvest excluded")
	var quote:=model.demolition_quote("h1");check(quote.departures==5,"Preflight warns all five departures")
	s=model.state.duplicate(true);s.resident_jobs["resident-3"].cargo={"kind":"wood","amount":10};model.commit(s)
	model.store.blocked=true;check(not model.demolish("h1") and model.resident_count()==5,"Failed demolition preserves homes and residents");model.store.blocked=false
	check(model.demolish("h1") and model.resident_count()==0 and model.chief_level()==4,"Last home removal leaves chief and removes all residents")
	check(model.state.resident_jobs.is_empty() and model.state.held_cargo.size()==1 and model.state.held_cargo[0].amount==10,"Departures clear assignments and hold carried goods without automatic credit or loss")
	check(ResidentJobs.new(model).assigned_to("farm:f1").is_empty(),"Farm assignment synchronized after departure")
	check(model.store.valid(model.state),"Departed state valid")
	model=fixture();jobs=ResidentJobs.new(model)
	s=model.state.duplicate(true);s.homes.append({"uid":"h2","style":1,"claimed":true,"level":2,"position":[700,900],"cost":{"wood":30,"stone":20}});s.resident_count=7;model.commit(s)
	for i in 7:jobs.assign("resident-%d"%i,"wood")
	seed(161);check(model.demolish("h1") and model.resident_count()==2,"Partial capacity reduction")
	var ids:=ResidentAdmission.ids(model.state)
	check(ids.size()==2 and model.state.last_departed.size()==5,"Random excess count exact")
	for id in ids:check(jobs.entry(id).job=="wood","Survivor assignment retained by stable identity")
	check(model.store.valid(model.state),"Sparse resident IDs accepted after random departure")
	check(model.nearest_home(Vector2(680,900))==Vector2(700,900),"Nearest home is resident dwelling, not chief")
	check(ActorMovement.direction_to(Vector2.ZERO,Vector2(1000,0),1).x==1.0 and ActorMovement.speed()==DemoConfig.get_data().move_speed,"Shared hero/resident speed")

	var limited:=fixture()
	for level in range(1,5):
		var cap_state:=limited.state.duplicate(true);cap_state.chief_level=level;cap_state.facilities=[]
		for i in mini(level,3):cap_state.facilities.append({"uid":"cap-%d"%i,"kind":"farm","level":1,"position":[1300+i*100,950],"cost":{"wood":10,"stone":5}})
		limited.commit(cap_state)
		check(not limited.can_construct("farm"),"Farm cap counts completed facilities at HQ %d"%level)
	var cap_state:=limited.state.duplicate(true);cap_state.outposts=[]
	for i in 3:cap_state.outposts.append({"uid":"post-%d"%i,"level":1,"position":[1300+i*100,700],"cost":{"wood":10,"stone":10}})
	limited.commit(cap_state);check(not limited.can_construct("outpost"),"Three outpost cap")
	cap_state=limited.state.duplicate(true);cap_state.homes=[];cap_state.built=false;cap_state.reward_claimed=false;limited.commit(cap_state)
	check(not limited.building_unlocked("farm"),"Farm needs completed resident home")
	var txn:=fixture();var txn_jobs:=ResidentJobs.new(txn);txn_jobs.assign("resident-0","farmer","farm:f1")
	var txn_state:=txn.state.duplicate(true);txn_state.farm_cycles={"farm:f1":{"phase":"ready","elapsed":600.0,"cuts":0,"stock":0,"cycle_level":1}};txn.commit(txn_state);txn.store.blocked=true
	check(not FarmProduction.harvest(txn,"resident-0","farm:f1") and FarmProduction.entry(txn,"farm:f1").stock==0,"Failed harvest save cannot consume crop or issue stock")
	txn.store.blocked=false;FarmProduction.harvest(txn,"resident-0","farm:f1");txn.store.blocked=true
	check(not FarmProduction.collect_stock(txn,"resident-0","farm:f1",5) and FarmProduction.entry(txn,"farm:f1").stock==5 and txn_jobs.entry("resident-0").cargo.is_empty(),"Failed load transfer retains exact farm stock")
	txn.store.blocked=false
	check(txn.demolish("farm:f1") and txn_jobs.entry("resident-0").job=="idle" and txn.state.held_cargo[0].amount==5,"Farm removal clears station and preserves gathered stock")

	var notified:=fixture();var emitted:Array=[]
	notified.notification_requested.connect(func(event,payload):emitted.append({"event":event,"payload":payload}))
	VillageNotifications.set_enabled(notified,"construction",true)
	var event_state:=notified.state.duplicate(true);var now:=Time.get_unix_time_from_system()
	var pending:=BuildingRules.new_job("farm",0,now,true);pending.uid="event-farm";pending.position=[1700,1100];event_state.construction_jobs=[pending];notified.commit(event_state)
	notified.store.blocked=true;check(not notified.finish_constructions(now+6) and emitted.is_empty(),"Failed completion save does not emit notification")
	notified.store.blocked=false;check(notified.finish_constructions(now+6) and emitted.size()==1 and emitted[0].event=="construction","Successful completed building emits enabled event")
	check(not notified.finish_constructions(now+7) and emitted.size()==1,"Completed job cannot repeat notification")
	VillageNotifications.set_enabled(notified,"upgrade",true)
	event_state=notified.state.duplicate(true);event_state.facilities[0].upgrade=BuildingRules.new_job("farm",1,now,true);notified.commit(event_state)
	check(OwnedBuildingUpgrades.finish(notified,now+6) and emitted.size()==2 and emitted[-1].event=="upgrade","Owned farm upgrade emits upgrade event")
	VillageNotifications.set_enabled(notified,"arrival",true)
	event_state=notified.state.duplicate(true);event_state.resident_count=0;event_state.pending_family_count=1;notified.commit(event_state)
	check(ResidentAdmission.join(notified,now) and emitted.size()==3 and emitted[-1].event=="arrival","Newly admitted resident emits arrival event")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
