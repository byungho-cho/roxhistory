extends SceneTree
var app:Node
var checks:=0
var failed:Array[String]=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func frames(n:int=3)->void:
	for i in n:await physics_frame;await process_frame
func blocked(at:Vector2)->bool:
	var pose:Transform2D=app.world.player.transform;pose.origin=at
	return app.world.player.test_move(pose,Vector2.ZERO,null,.08,true)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames();app.start_region();await frames()
	var trees:Array=app.world.environment_props.filter(func(p):return p.kind=="tree")
	var rocks:Array=app.world.environment_props.filter(func(p):return p.kind=="rock")
	check(trees.size()==4 and rocks.size()==2,"Four independent trees and two decorative rocks")
	check(app.world.find_children("LandscapeCanopy*","",true,false).is_empty(),"No old baked canopy masks")
	check(app.world.find_children("LandscapeRock*","",true,false).is_empty(),"No stale painted rock collision or occluder")
	check(app.model.nodes().size()==DemoConfig.get_data().nodes.size(),"Gatherable resource count unchanged")
	for p in trees+rocks:
		check(blocked(p.position+Vector2(0,-10)),"Real footprint blocks "+p.name)
		check(p.sprite.texture!=null and p.has_node("Footprint"),"Visible object owns footprint "+p.name)
	for at in [Vector2(95,750),Vector2(1390,1170),Vector2(110,575)]:check(not blocked(at),"Removed obstacle no longer blocks "+str(at))
	for i in 5:
		var south:Vector2=app.world.SHORE[i]
		var north:Vector2=app.world.RIVER_POLYGON[i]
		var x:=clampf(south.x,50,2350)
		check(blocked(Vector2(x,(south.y+north.y)*.5)),"River centre blocks "+str(i))
	for i in DemoConfig.BUILD_SITES.size():check(app.world.site_available(i),"Candidate free after scenery replacement "+str(i))
	for side in ["behind","front"]:
		app.world.player.position=Vector2(1780,850)+Vector2(40,-70 if side=="behind" else 45);app.world.player.resume_camera();await frames(20)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/clean-tree-"+side+".png")
		app.world.player.position=SceneStyle.PAINTED_ROCKS[0]+Vector2(0,-60 if side=="behind" else 45);app.world.player.resume_camera();await frames(20)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/clean-rock-"+side+".png")
	app.world.player.position=Vector2(1660,900)
	check(app.navigation.start("move","",Vector2(1870,900)),"Path around scenic tree exists")
	var limit:=600
	while app.navigation.action!="" and limit>0:await frames(1);limit-=1
	check(limit>0 and app.world.player.position.distance_to(Vector2(1870,900))<30,"Automatic travel reaches destination around scenery")
	FileAccess.open("res://reports/clean-terrain-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"trees":4,"decorative_rocks":2},"  "))
	print("CLEAN_TERRAIN ",checks," ",failed);quit(0 if failed.is_empty() else 1)

