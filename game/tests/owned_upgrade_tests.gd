extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var store:=SaveStore.new("user://owned_%s"%Time.get_ticks_usec())
	var model:=GameState.new(store);model.start_new()
	for i in 3:check(model.build(Vector2.ZERO,i),"Create resident hut");model.claim_reward(i)
	check(model.build_outpost(Vector2.ZERO,3),"Outpost still costs 15/10")
	check(model.state.wood==425 and model.state.stone==430,"Initial construction prices unchanged")
	var key:=model.home_key(0)
	var outpost_key:="outpost:"+str(model.outposts()[0].uid)
	var now:=Time.get_unix_time_from_system()+100
	for target in [2,3,4]:
		var before:int=model.state.wood
		check(OwnedBuildingUpgrades.start(model,key,now),"Resident upgrade starts")
		check(OwnedBuildingUpgrades.start(model,outpost_key,now),"Outpost domain upgrade starts")
		check(model.state.wood==before-40,"Each building deducts exactly 20")
		check(not OwnedBuildingUpgrades.start(model,key,now),"Duplicate start denied")
		check(not model.demolish(key),"Cannot demolish active upgrade")
		var job:Dictionary=OwnedBuildingUpgrades.lookup(model,key).data.upgrade
		check(job.finishes_at-job.started_at==pow(2,target),"4/8/16 seconds")
		var reload:=GameState.new(store)
		check(OwnedBuildingUpgrades.lookup(reload,key).data.has("upgrade"),"Unfinished work restores")
		check(not OwnedBuildingUpgrades.finish(model,now-1000),"Clock rollback never finishes early")
		check(OwnedBuildingUpgrades.finish(model,job.finishes_at),"Finish both atomically")
		check(not OwnedBuildingUpgrades.finish(model,job.finishes_at),"Completion idempotent")
		check(OwnedBuildingUpgrades.lookup(model,key).data.level==target,"Resident level applied")
		check(OwnedBuildingUpgrades.lookup(model,outpost_key).data.level==target,"Outpost level applied")
		now+=100
	check(not OwnedBuildingUpgrades.start(model,key,now),"Maximum level enforced")
	var offline_key:=model.home_key(1)
	check(OwnedBuildingUpgrades.start(model,offline_key,Time.get_unix_time_from_system()-20),"Offline fixture")
	model=GameState.new(store)
	check(OwnedBuildingUpgrades.lookup(model,offline_key).data.level==2,"Offline completion restored")
	var invalid:=model.state.duplicate(true);invalid.homes[0].level=5
	check(not store.valid(invalid),"Reject invalid level")
	invalid=model.state.duplicate(true);invalid.homes[1].upgrade={"from":2,"to":4,"started_at":1,"finishes_at":2,"cost":{"wood":20,"stone":20}}
	check(not store.valid(invalid),"Reject skipped stage")
	var fixture:=model.state.duplicate(true);fixture.outposts[0].level=1;model.commit(fixture)
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	for i in 5:await process_frame
	app.model=model;app.enter_game()
	for i in 15:await process_frame
	app.set_process(false)
	check(app.building_workflow.owned_upgrade_reason(outpost_key).is_empty(),"Approved outpost stage ready")
	AssetCatalog.entry("BLD-OUTPOST-L2").approved=false
	var before_block:Dictionary=model.state.duplicate(true)
	app.building_workflow.request_owned_upgrade(outpost_key)
	check(not app.modal and model.state==before_block,"Missing outpost art never charges or starts")
	AssetCatalog.entry("BLD-OUTPOST-L2").approved=true
	var ui_key:=model.home_key(2)
	check(app.building_workflow.owned_upgrade_reason(ui_key).is_empty(),"Resident approved stage ready")
	app.building_workflow.request_owned_upgrade(ui_key)
	check(app.modal and app.building_workflow.confirm_owned_upgrade(ui_key,2),"Actual confirmation starts resident job")
	app.building_workflow.update_owned_upgrades()
	var progress:ConstructionProgress=app.building_workflow.owned_progress[ui_key]
	progress._process(.2)
	check(progress.visible and progress.hammer.texture!=null,"Shared progress and hammer visible")
	check(progress.upgrade_sprite()==app.world.homes[2].sprite,"Progress follows selected house")
	check(BuildingWorkflow.approved_texture("BLD-OUTPOST-L2")!=null,"Approved outpost artwork restored")
	if "--capture-owned" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/owned-upgrade-working.png")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
