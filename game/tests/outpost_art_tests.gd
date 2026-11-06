extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(n:int)->void:
	for i in n:await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	var store:=SaveStore.new("user://outpost_art_%s"%Time.get_ticks_usec())
	app.model=GameState.new(store);app.model.start_new()
	for i in 3:app.model.build(Vector2.ZERO,i);app.model.claim_reward(i)
	check(app.model.build_outpost(Vector2.ZERO,3),"Build existing L1")
	app.enter_game();await frames(15);app.set_process(false)
	var key:="outpost:"+str(app.model.outposts()[0].uid)
	var body:StaticBody2D=app.world.get_node("Outpost_"+str(app.model.outposts()[0].uid))
	var original_shape:PackedVector2Array=body.get_child(1).shape.points.duplicate()
	var original_position:=body.position
	for level in [2,3,4]:
		var before:Dictionary=app.model.state.duplicate(true)
		check(app.building_workflow.owned_upgrade_reason(key).is_empty(),"Approved outpost stage available")
		app.building_workflow.request_owned_upgrade(key)
		check(app.modal and app.building_workflow.confirm_owned_upgrade(key,level),"UI starts selected outpost stage")
		check(app.model.state.wood==before.wood-20 and app.model.state.stone==before.stone-20,"Exact 20/20 deduction")
		app.building_workflow.update_owned_upgrades();await frames(3)
		var progress:ConstructionProgress=app.building_workflow.owned_progress[key]
		progress._process(.25)
		check(progress.visible and progress.upgrade_sprite()==body.get_child(0),"Outpost bar/hammer anchored")
		var job:Dictionary=app.model.outposts()[0].upgrade
		check(OwnedBuildingUpgrades.finish(app.model,float(job.finishes_at)),"Finish stage")
		await frames(3)
		var image:Sprite2D=body.get_child(0)
		var entry:=AssetCatalog.entry("BLD-OUTPOST-L%d"%level)
		check(image.texture==AssetCatalog.texture("BLD-OUTPOST-L%d"%level),"Exact stage texture")
		var contact:Vector2=image.position+Vector2(entry.ground_pivot[0],entry.ground_pivot[1])*image.scale
		check(contact.is_equal_approx(Vector2(0,3)),"Shared ground contact")
		check(is_equal_approx(image.scale.x*entry.ground_span,180),"Shared ground width")
		check(body.position==original_position and body.get_child(1).shape.points==original_shape,"Collision and saved site unchanged")
		check(GameState.new(store).outposts()[0].level==level,"Level survives reload")
		if "--capture-outposts" in OS.get_cmdline_user_args():
			app.world.player.zoom_at(Vector2(app.w,app.h)*.5,DemoPlayer.MAX_ZOOM)
			await frames(5);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/outpost-level-%d.png"%level)
	check(not app.building_workflow.owned_upgrade_reason(key).is_empty(),"Maximum stage locked")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
