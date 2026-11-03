extends SceneTree
var app:Node
var failed:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3)
	app.start_region();app.close_modal();await frames(3)
	var w:DemoWorld=app.world
	check(w.get_node("Terrain").texture.resource_path==SceneStyle.TERRAIN,"Approved diagonal river background loaded")
	var ambient:WorldAmbient
	for c in w.get_children():
		if c is WorldAmbient:ambient=c
	check(ambient!=null and ambient.school.size()==5,"Five individually animated approved fish")
	var smoke_before:Vector2=ambient.smoke[0].sprite.position
	var fish_before:Vector2=ambient.school[0].position
	var poses:Dictionary={}
	for a in w.animals:
		check(a.rig.get_bone_count()==15,"Actual skinned 3D animal: "+a.species)
		poses[a]=a.rig.get_bone_pose_rotation(a.bones.head)
	await frames(600)
	for a in w.animals:
		check(a.walked_distance>15,"Autonomous locomotion: "+a.species)
		check(not Geometry2D.is_point_in_polygon(a.position,PackedVector2Array(DemoWorld.RIVER_POLYGON)),"Wildlife remains on land")
		check(a.rig.get_bone_pose_rotation(a.bones.head)!=poses[a],"Idle/grazing joint changes: "+a.species)
	check(ambient.smoke[0].sprite.position.distance_to(smoke_before)>5,"Smoke rises from completed chimney")
	check(ambient.school[0].position.distance_to(fish_before)>10,"Fish school swims")
	for f in ambient.school:check(Geometry2D.is_point_in_polygon(f.position,PackedVector2Array(DemoWorld.RIVER_POLYGON)),"Fish remains inside water mask")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);await frames(3)
	var clock:float=ambient.clock;var animal_clock:float=w.animals[0].clock;var pos:Vector2=w.animals[0].position
	await frames(20)
	check(ambient.clock==clock and w.animals[0].clock==animal_clock and w.animals[0].position==pos,"Lifecycle freezes all ambient movement")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED);app.close_modal();await frames(3)
	w.player.position=Vector2(1150,810)
	app.world_tap(w.get_global_transform_with_canvas()*Vector2(1620,960));await frames(25)
	check(app.navigation.action=="gather" and app.navigation.path.size()>0,"Clicked resource owns an actual route")
	check(is_instance_valid(app.navigation.trail) and app.navigation.trail.crumbs.size()>0,"Passed route has fading trail samples")
	app.cancel_task();await frames(45)
	check(app.navigation.trail.crumbs.is_empty() and app.navigation.path.is_empty(),"Cancelled route and travelled dots clear")
	var joy:Vector2=app.joystick.size
	w.player.zoom_at(Vector2(480,270),99);check(w.player.zoom_factor==2 and app.joystick.size==joy,"Measured artwork zoom limit, HUD fixed")
	w.player.zoom_at(Vector2(480,270),.1);check(w.player.zoom_factor==1,"Minimum fits the complete landscape")
	w.player.position=Vector2(1500,180);w.restore_clear_position();await frames(3)
	check(w.player.position.y>600,"Old north-bank saves return to accessible ground without erasing progress")
	var report:Dictionary={"checks":checks,"failed":failed,"runtime":"Windows native Godot; actual physics, skeleton transforms and lifecycle"}
	FileAccess.open("res://reports/s40000-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
