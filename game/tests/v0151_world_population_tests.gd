extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func frames(count:int)->void:
	for i in count:await physics_frame
func home(id:int,level:int)->Dictionary:
	return {"uid":"test-home-%d"%id,"style":1,"claimed":true,"position":[900+id*400,1000],"level":level,"cost":{"wood":20,"stone":10}}
func run()->void:
	seed(61107)
	var folder:="user://tests/v0151_world_%s"%Time.get_ticks_usec()
	var model:=GameState.new(SaveStore.new(folder));check(model.start_new(),"Fresh save")
	check(model.resident_count()==0 and model.resident_capacity()==0,"Fresh population is zero of zero")
	check(not model.family_available(),"No invented visitors on new save")
	check(model.ensure_family_visit(1000),"First visit timer persists")
	check(not model.ensure_family_visit(1059),"Visit waits full configured interval")
	check(model.ensure_family_visit(1060) and model.family_visitor_count() in [1,2,3],"Random party contains one to three visitors")
	var party:=model.family_visitor_count()
	var loaded:=GameState.new(SaveStore.new(folder))
	check(loaded.family_visitor_count()==party,"Pending party survives reload without reroll")
	check(not model.join_family() and model.resident_count()==0 and model.family_visitor_count()==party,"No housing prevents all admission and retains party")
	var world:=DemoWorld.new(model);root.add_child(world);await frames(3)
	world.player.set_physics_process(false)
	for animal in world.animals:animal.set_physics_process(false)
	var chief:=world.get_node("ExistingHut") as EnvironmentProp
	check(not chief.visible and chief.get_node("Footprint").collision_layer==0,"Absent HQ has no visible art or collision")
	check(world.residents.is_empty() and world.visitors.size()==party,"Visitors are excluded from admitted actors")
	check(not world.boundary_root.get_node("UnlockedPerimeter").visible,"Boundary line is off by default")
	check(model.set_debug_show_boundary(true),"Boundary debug setting saves")
	check(world.boundary_root.get_node("UnlockedPerimeter").visible,"Debug boundary red line enabled")
	check(world.boundary_root.get_node("UnlockedPerimeter").default_color==Color("ed514b"),"Debug boundary uses red")
	var sizes:Array=[]
	for level in range(1,5):sizes.append(VillageBounds.rect_for_level(level).size.x/VillageBounds.WORLD_SIZE.x*.9)
	check(is_equal_approx(sizes[0],.6) and is_equal_approx(sizes[1],.7) and is_equal_approx(sizes[2],.8) and is_equal_approx(sizes[3],.9),"Actual boundary sizes are 60/70/80/90 percent")
	var next:=model.state.duplicate(true)
	next.chief_level=1;next.chief_position=[1098,600];next.homes=[home(0,1)];next.built=true;next.reward_claimed=true;next.pending_family_count=3
	check(model.commit(next),"Fixture one home and three visitors")
	check(not model.join_family() and model.resident_count()==0 and model.family_visitor_count()==3,"Two spare visitors are never partially admitted")
	next=model.state.duplicate(true);next.homes[0].level=3;check(model.commit(next),"Housing capacity upgrade")
	check(model.resident_count()==0,"Capacity upgrade never auto-fills residents")
	model.store.blocked=true
	check(not model.join_family() and model.resident_count()==0 and model.family_visitor_count()==3,"Failed admission save keeps whole party")
	model.store.blocked=false
	check(ResidentAdmission.join(model,2000) and model.resident_count()==3 and not model.family_available(),"Whole party joins once when all fit")
	check(not model.join_family(),"Duplicate conversation cannot admit twice")
	next=model.state.duplicate(true);next.chief_level=4;next.homes=[home(0,4),home(1,4),home(2,4)]
	check(model.commit(next),"Three level-four homes")
	check(model.resident_capacity()==15 and model.resident_count()==3,"Fifteen capacity does not imply fifteen admitted")
	check(model.ensure_family_visit(2060),"Recurring party appears after previous admission")
	while model.resident_count()<15:
		next=model.state.duplicate(true);next.pending_family_count=mini(3,15-model.resident_count());model.commit(next)
		check(ResidentAdmission.join(model,3000+model.resident_count()),"Next whole party admitted")
	await frames(3)
	for resident in world.residents:resident.set_physics_process(false);resident.collision_layer=0
	check(world.residents.size()==15 and world.visitors.is_empty(),"Dynamic actors reach fifteen admitted residents")
	check(not model.ensure_family_visit(9000),"No unadmittable visits after absolute population maximum")
	var jobs:=ResidentJobs.new(model)
	check(jobs.assign("resident-14","stone"),"Fifteenth resident can receive work")
	check(not jobs.assign("resident-15","wood") and not jobs.assign("resident-01","wood"),"Unadmitted and noncanonical resident IDs rejected")
	check(ResidentJobs.valid_saved_jobs(model.state),"Dynamic resident jobs validate")
	next=model.state.duplicate(true);next.resident_count=16
	check(not model.store.valid(next),"Population beyond fifteen rejected")
	# Resource disappearance remains cosmetic: no second harvest or collision.
	var target:Dictionary=model.nodes()[0]
	next=model.state.duplicate(true);next.depleted[target.id]=int(target.charges);next.respawn_due={str(target.id):10000.0};model.commit(next)
	var resource:=world.art_nodes[target.id] as Node2D
	check(resource.visible and world.resource_tweens.has(target.id),"Depleted resource blinks before disappearing")
	check(resource.get_node("ResourceCollision").collision_layer==0 and not world.resource_hit(target,resource.position),"Depletion immediately removes collision and hit target")
	check(not jobs.harvest("resident-14",target.id),"Depleted resource cannot be harvested during fade")
	world.player.presentation_paused=true
	await create_timer(.95).timeout
	check(not resource.visible,"Depleted resource finishes fade out")
	next=model.state.duplicate(true);next.depleted[target.id]=0;next.respawn_due.erase(target.id);model.commit(next)
	check(resource.visible and resource.modulate.a<.1 and resource.get_node("ResourceCollision").collision_layer==1,"Regrown resource fades in with active collision")
	await create_timer(.65).timeout
	check(resource.visible and is_equal_approx(resource.modulate.a,1.0),"Regrowth finishes fade in")
	# Completed facilities move with their generic sprites and foundations.
	next=model.state.duplicate(true);next.facilities=[{"uid":"test-shrine","kind":"shrine","level":2,"position":[200,1000],"cost":{"wood":20,"stone":30}}];model.commit(next)
	var sprite:=world.building_sprite("shrine:test-shrine")
	check(sprite!=null and sprite.get_meta("building_visual_alignment")=="bottom","Facility uses approved bottom-aligned sprite")
	check(world.get_node("Facility_test-shrine").position==Vector2(200,1000),"Facility uses saved free position")
	next=model.state.duplicate(true);next.facilities[0].position=[300,1100];model.commit(next)
	check(world.get_node("Facility_test-shrine").position==Vector2(300,1100),"Moving facility updates physical building")
	check(not world.placement_requirement("hut",Vector2(300,1100)).is_empty(),"World placement prevents occupied building overlap")
	var layout:VillageLayout
	for child in world.get_children():
		if child is VillageLayout:layout=child
	var found_pad:=false
	for child in layout.get_children():
		if child.has_meta("foundation_level") and child.position.is_equal_approx(Vector2(300,1100)):found_pad=true
	check(found_pad,"Common foundation follows moved facility")
	# Existing paid cargo remains safe without a depot, and follows a moved depot.
	var worker:=world.residents[0]
	jobs.assign("resident-0","wood")
	next=model.state.duplicate(true);next.chief_level=0;next.resident_jobs["resident-0"].cargo={"kind":"wood","amount":10};model.commit(next)
	var wood_before:=int(model.state.wood)
	worker._job_tick(.1)
	check(worker.job_route.is_empty() and not jobs.entry("resident-0").cargo.is_empty() and model.state.wood==wood_before,"No HQ means safe idle with cargo retained")
	check(not jobs.deposit("resident-0"),"No HQ rejects direct deposit")
	next=model.state.duplicate(true);next.chief_level=4;next.chief_position=[700,700];model.commit(next)
	check(chief.visible and chief.position==Vector2(700,700),"Existing HQ node reappears at saved moved position")
	worker.position=Vector2(665,810);worker.job_timer=0;worker._job_tick(.1)
	check(model.state.wood==wood_before+10 and jobs.entry("resident-0").cargo.is_empty(),"Single load deposits at moved HQ without stock truncation")
	worker._job_tick(.1)
	check(model.state.wood==wood_before+10,"Repeat return tick cannot duplicate cargo")
	loaded=GameState.new(SaveStore.new(folder))
	check(loaded.resident_count()==15 and ResidentJobs.new(loaded).entry("resident-14").job=="stone","Admitted count and fifteenth assignment survive reload")
	# A newly assigned fifteenth actor performs the full physical harvest/return loop.
	world.player.presentation_paused=false;world.player.collision_layer=0
	worker=world.residents[14];worker.position=DemoConfig.point(target.position)+Vector2(0,65)
	worker.job_phase="idle";worker.job_timer=0;worker.job_route.clear()
	jobs.assign("resident-14",str(target.kind))
	var balance:=int(model.state[target.kind]);var carried:=false;var remote_credit:=false
	worker.set_physics_process(true)
	for tick in 1800:
		await physics_frame
		if not jobs.entry("resident-14").cargo.is_empty():carried=true;remote_credit=remote_credit or int(model.state[target.kind])!=balance
		if int(model.state[target.kind])>balance:break
	worker.set_physics_process(false)
	check(carried and not remote_credit,"Fifteenth resident physically harvests without remote credit")
	check(int(model.state[target.kind])==balance+int(DemoConfig.get_data().gather_yield),"Fifteenth resident completes one-load return to moved HQ")
	check(worker.position.distance_to(model.building_position("chief")+Vector2(70,170))<=5,"Fifteenth resident arrives at its own HQ drop-off")
	var report:={"checks":checks,"failed":failures,"visit_interval_seconds":ResidentAdmission.VISIT_INTERVAL_SECONDS}
	print(JSON.stringify(report));FileAccess.open("res://reports/v0151-world-population-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	world.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
