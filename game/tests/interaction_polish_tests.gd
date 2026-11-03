extends SceneTree
var app:Node
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func touch(id:int,pressed:bool,at:Vector2)->void:
	var e:=InputEventScreenTouch.new();e.index=id;e.pressed=pressed;e.position=at;app.gestures._input(e)
func drag(id:int,at:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.index=id;e.position=at;app.gestures._input(e)
func snap(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/interaction-"+name+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3)
	app.start_region();app.close_modal();await frames(5)
	check(is_equal_approx(float(DemoConfig.get_data().move_speed),181.5),"Direct and automatic movement share configured movement speed")
	var n:Dictionary=app.model.nodes()[0];var id:String=n.id
	var old:=DemoConfig.point(n.position)
	for i in int(n.charges):check(app.model.gather(id),"Gather transaction accepted before depletion")
	await frames(3)
	check(not app.world.art_nodes[id].visible,"Fully depleted sprite and child labels disappear")
	check(app.world.art_nodes[id].get_node("ResourceCollision").get_child(0).disabled,"Depleted collision disabled")
	check(not app.model.gather(id),"Duplicate depleted gather cannot award")
	var amount:int=app.model.state[n.kind]
	check(not app.model.respawn(id,Vector2(1800,1100),Time.get_unix_time_from_system()),"Respawn cannot bypass cooldown")
	await snap("depleted")
	var next:Dictionary=app.model.state.duplicate(true);next.respawn_due[id]=Time.get_unix_time_from_system()-1;app.model.commit(next)
	await frames(80)
	var changed:Dictionary={}
	for node in app.model.nodes():
		if node.id==id:changed=node
	var at:=DemoConfig.point(changed.position)
	check(at.distance_to(old)>=180,"Respawn relocates instead of reusing old place")
	check(app.world.art_nodes[id].visible and not app.world.exhausted(changed),"One resource becomes live again")
	check(not app.world.art_nodes[id].get_node("ResourceCollision").get_child(0).disabled,"Respawn collision restored")
	check(app.model.state[n.kind]==amount,"Respawn never grants inventory")
	var restored:=GameState.new(app.model.store)
	check(restored.state.node_positions==app.model.state.node_positions and restored.state.depleted[id]==0,"Reload preserves one respawn and its position")
	check(not restored.respawn(id,old,Time.get_unix_time_from_system()+1000),"Reload cannot respawn active node twice")
	await snap("respawn")
	app.world.player.zoom_at(Vector2(480,270),2)
	var blank:=Vector2.ZERO
	for y in range(180,440,30):
		for x in range(280,700,30):
			var p:=Vector2(x,y)
			if not app.gestures.ui_hit(p) and not app.world.interaction_at(p):blank=p;break
		if blank!=Vector2.ZERO:break
	check(blank!=Vector2.ZERO,"Blank world drag test target exists")
	touch(10,true,blank);drag(10,blank+Vector2(70,20));touch(10,false,blank+Vector2(70,20));await frames(3)
	check(app.world.player.manual_camera and not app.gestures.blocked,"One finger drag latches camera and releases input")
	check(app.navigation.action=="" and app.task=="","Drag cannot trigger auto gather/build")
	var camera_at:Vector2=app.world.player.camera.get_screen_center_position();await frames(30)
	check(camera_at.distance_to(app.world.player.camera.get_screen_center_position())<1,"Camera does not snap back after drag")
	await snap("pan")
	touch(20,true,blank);drag(20,blank+Vector2(20,0));touch(21,true,blank+Vector2(100,0))
	check(app.gestures.pinching,"A second world finger takes ownership from pan")
	drag(21,blank+Vector2(130,0));touch(21,false,blank+Vector2(130,0));drag(20,blank+Vector2(40,0))
	check(app.gestures.blocked and not app.gestures.panning,"Remaining pinch finger cannot accidentally pan or interact")
	touch(20,false,blank+Vector2(40,0))
	check(not app.gestures.blocked and app.navigation.action=="","Last pinch release clears ownership without an action")
	var panel:Control=app.objective.get_parent();var before:Vector2=app.world.player.camera.position
	touch(11,true,panel.position+Vector2(10,10));drag(11,panel.position+Vector2(80,10));touch(11,false,panel.position+Vector2(80,10))
	check(app.world.player.camera.position==before,"Quest-origin drag cannot pan camera")
	app.toggle_quest();check(not app.quest_expanded and not app.objective.text.contains("나무") and app.objective.text.contains("/3채"),"Collapsed quest retains meaningful progress")
	await snap("quest-folded")
	app.toggle_quest();check(app.objective.text.contains("나무") and app.quest_arrow.text=="⌃","Expanded quest and arrow agree")
	app.world.player.resume_camera();check(not app.world.player.manual_camera,"Recenter restores follow camera")
	app.set_process(false);app.world.player.direction=Vector2.ZERO;app.world.player.work_destination=Vector2.INF;app.world.player.idle_elapsed=0
	await frames(180)
	check(app.world.player.hybrid.idle_looking,"Idle look begins after 2.5 seconds")
	await snap("idle")
	app.world.player.direction=Vector2.RIGHT;await frames(2)
	check(not app.world.player.hybrid.idle_looking and app.world.player.idle_elapsed==0,"Input immediately interrupts idle pose")
	app.world.player.direction=Vector2.ZERO;app.set_process(true)
	app.gestures.clear();check(app.gestures.touches.is_empty() and not app.gestures.blocked,"Lifecycle clears all gesture ownership")
	var report:Dictionary={"checks":checks,"failed":failures,"runtime":"Native Godot synthetic input and actual save transactions; cooldown accelerated only in this test"}
	FileAccess.open("res://reports/interaction-polish-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
