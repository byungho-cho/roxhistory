extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(count:int)->void:
	for i in count:await process_frame
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	app.model=GameState.new(SaveStore.new("user://workflow_%s"%Time.get_ticks_usec()))
	app.model.start_new()
	app.enter_game();await frames(10)
	var flow:BuildingWorkflow=app.building_workflow
	var state:Dictionary=app.model.state.duplicate(true);state.wood=200;state.stone=200;app.model.commit(state)
	check(not flow.upgrade_block_reason(2).is_empty(),"No completed outpost blocks upgrade")
	for site in [0,1,2]:check(app.model.build(Vector2.ZERO,site),"Fixture hut built")
	check(app.model.build_outpost(Vector2.ZERO,3),"Fixture outpost for controller tests only")
	var shipped_entry:=AssetCatalog.entry("BLD-CHIEF-L2").duplicate(true)
	AssetCatalog.entries.erase("BLD-CHIEF-L2");AssetCatalog.cache.erase("BLD-CHIEF-L2")
	var before:Dictionary=app.model.state.duplicate(true)
	flow.request_upgrade()
	check(not app.modal and app.model.state==before,"Missing approved asset prevents confirmation and charge")
	check(flow.approved_texture("NONEXISTENT")==null,"Never use generic fallback as building art")
	# Test-only entry reuses a real existing texture to exercise the controller.
	# This never modifies the catalog file or the shipped game's approval status.
	var entry:=AssetCatalog.entry("BLD-HUT-L1").duplicate(true)
	AssetCatalog.entries["BLD-CHIEF-L2"]=entry
	check(flow.approved_texture("BLD-CHIEF-L2")==null,"Unapproved catalog entry remains blocked")
	entry.approved=true;AssetCatalog.entries["BLD-CHIEF-L2"]=entry
	var invalid:=entry.duplicate(true);invalid.crop=[0,0,999999,999999];AssetCatalog.entries["BAD-CROP"]=invalid
	check(flow.approved_texture("BAD-CROP")==null,"Invalid crop cannot silently become fallback art")
	AssetCatalog.entries.erase("BAD-CROP")
	flow.request_upgrade();check(app.modal and flow.confirmation_target==2,"Approved test asset opens existing confirmation")
	app.close_modal();check(not flow.confirm_upgrade(2) and app.model.state==before,"Cancel invalidates callback without charge")
	flow.request_upgrade()
	state=app.model.state.duplicate(true);state.wood=0;app.model.commit(state)
	check(not flow.confirm_upgrade(2) and not app.model.state.has("chief_upgrade"),"Confirmation rechecks resources")
	state=app.model.state.duplicate(true);state.wood=100;app.model.commit(state)
	flow.request_upgrade();before=app.model.state.duplicate(true)
	check(flow.confirm_upgrade(2),"Confirmation starts persisted job")
	check(not flow.confirm_upgrade(2) and app.model.state.wood==before.wood-20,"Duplicate callback cannot charge again")
	check(is_instance_valid(flow.scaffold) and flow.scaffold.visibility_layer==2,"Existing construction scaffold excluded from GPS")
	app.cancel_task();check(app.model.state.has("chief_upgrade"),"Ordinary work cancellation preserves durable upgrade")
	app.switch_map_scene();await frames(2)
	check(not flow.scaffold.visible and app.model.state.has("chief_upgrade"),"Map switch hides scaffold without canceling job")
	state=app.model.state.duplicate(true);state.chief_upgrade.started_at=Time.get_unix_time_from_system()-5;state.chief_upgrade.finishes_at=Time.get_unix_time_from_system()-1;app.model.commit(state)
	flow._process(.2)
	check(app.model.chief_level()==2 and not app.model.state.has("chief_upgrade"),"Completion runs while world map is open")
	var paid:int=app.model.state.wood;flow._process(.2)
	check(app.model.chief_level()==2 and app.model.state.wood==paid,"Repeated frame cannot repeat completion/payment")
	app.switch_map_scene();await frames(2)
	flow._process(.4)
	check(not flow.scaffold.visible,"Completed scaffold hidden after brief finish fade")
	AssetCatalog.entries["BLD-CHIEF-L2"]=shipped_entry;AssetCatalog.cache.erase("BLD-CHIEF-L2")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
