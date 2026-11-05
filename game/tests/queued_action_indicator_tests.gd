extends SceneTree
var app:Node
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame
func capture(label:String)->void:
	if not "--capture-queue" in OS.get_cmdline_user_args():return
	await frames(12);await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://reports/queued-action")
	root.get_texture().get_image().save_png("res://reports/queued-action/"+label+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	app.model=GameState.new(SaveStore.new("user://queued_%s"%Time.get_ticks_usec()));app.model.start_new();app.enter_game();await frames(20)
	var indicator:QueuedActionIndicator=app.queued_action_indicator
	check(not indicator.visible,"Empty reservation hidden")
	var wood:="";var stone:=""
	for node in app.model.nodes():
		if node.kind=="wood":wood=str(node.id)
		if node.kind=="stone":stone=str(node.id)
	var before:Dictionary=app.model.state.duplicate(true)
	app.reserve_action({"kind":"gather","id":wood})
	check(indicator.visible and indicator.icon_key=="wood","Wood reservation visible immediately")
	check(indicator.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Icon never intercepts gameplay input")
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.6);await capture("wood")
	app.reserve_action({"kind":"gather","id":stone})
	check(indicator.icon_key=="stone" and app.pending_action.id==stone,"Last reservation replaces earlier icon and action")
	app.reserve_action({"kind":"build","id":0,"building":"outpost"})
	check(indicator.icon_key=="hut" and app.pending_action.building=="outpost","Building kind retained; existing construction symbol")
	await capture("build")
	app.reserve_action({"kind":"move","at":Vector2(800,800)})
	check(indicator.icon_key=="move" and indicator.texture!=null,"Existing movement asset reused")
	app.reserve_action({"kind":"gather","id":""})
	check(indicator.icon_key=="berries","Untargeted gathering uses current gather-button icon")
	app.reserve_action({"kind":"family","id":"first"})
	check(not indicator.visible and app.pending_action.kind=="family","Missing family icon does not mutate reservation")
	app.reserve_action({"kind":"gather","id":wood})
	app.family.set_process(false);app.family.bubble.show();app.family.bubble.position=indicator.position;indicator.refresh()
	check(not indicator.get_global_rect().intersects(app.family.bubble.get_global_rect()),"Reservation avoids existing conversation bubble")
	app.family.bubble.hide();app.world_map_open=true;indicator.refresh();check(not indicator.visible and not app.pending_action.is_empty(),"Map hides icon without consuming reservation")
	app.world_map_open=false;indicator.refresh();check(indicator.visible,"Return restores pending icon")
	app.cancel_task();check(not indicator.visible and app.pending_action.is_empty(),"Cancel removes icon immediately")
	app.reserve_action({"kind":"gather","id":"missing"});app.run_reserved_action()
	check(app.pending_action.is_empty() and not indicator.visible,"Invalid reserved target consumed and icon cleared")
	app.reserve_action({"kind":"build","id":0});app.pending_action.clear();indicator.refresh()
	check(not indicator.visible,"External invalidation cannot leave stale icon")
	check(app.model.state==before,"Presentation never mutates saved state or resources")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
