extends SceneTree
var app:Node
var failed:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func finger(id:int,pressed:bool,p:Vector2)->void:
	var e:=InputEventScreenTouch.new();e.index=id;e.position=p;e.pressed=pressed;app.gestures._input(e)
func drag(id:int,p:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.index=id;e.position=p;app.gestures._input(e)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3);app.start_region();app.close_modal();await frames(5)
	check(is_equal_approx(float(DemoConfig.get_data().move_speed),181.5),"Speed is an additional twenty percent over v0.1.26")
	check(HeroMotion.step(PI*1.5,1).y>.16 and HeroMotion.step(PI*1.5,-1).y==0,"Swing foot lifts while opposite foot supports")
	var destination:=Vector2(1320,910)
	var screen:Vector2=app.world.get_global_transform_with_canvas()*destination
	finger(1,true,screen);check(app.navigation.action=="","Press alone never starts movement")
	finger(1,false,screen);check(app.navigation.action=="move","Blank ground release starts route")
	await frames(15)
	var replacement:=Vector2(1220,970);app.world_tap(app.world.get_global_transform_with_canvas()*replacement)
	check(app.navigation.path[-1].distance_to(replacement)<1,"New ground target replaces previous endpoint")
	await frames(180)
	check(app.world.player.position.distance_to(replacement)<5 and app.task=="","Ground arrival does not gather or build")
	check(app.navigation.action=="" and app.navigation.trail.crumbs.is_empty(),"Arrival clears old dots")
	app.world_tap(app.world.get_global_transform_with_canvas()*Vector2(1250,500))
	check(app.navigation.action=="" and app.toast_label.text.contains("이동"),"River destination is rejected with feedback")
	app.world_tap(app.world.get_global_transform_with_canvas()*Vector2(865,650))
	check(app.navigation.action=="","Existing building is not blank ground")
	app.world_tap(app.world.get_global_transform_with_canvas()*Vector2(1620,960))
	check(app.navigation.action=="gather","Resource still starts automatic gather")
	app.cancel_task();check(app.navigation.trail.crumbs.is_empty(),"Cancel clears previous trail")
	app.world.player.position=Vector2(1150,900)
	app.navigation.start("move","",Vector2(1320,910))
	var obstacle:=StaticBody2D.new();var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=9
	shape.shape=circle;obstacle.add_child(shape);obstacle.position=app.navigation.path[2];app.world.add_child(obstacle)
	await frames(450)
	check(app.world.player.position.distance_to(Vector2(1320,910))<5,"A newly blocked waypoint is replanned and the destination is reached")
	check(app.navigation.action=="" and app.navigation.trail.crumbs.is_empty(),"Replanned arrival leaves no stale action or route")
	obstacle.queue_free();await frames(2)
	app.context_panel.show()
	check(not app.gestures.ui_hit(app.context_panel.get_global_rect().get_center()),"Noninteractive gathering hint does not block resource taps")
	for size in [Vector2i(370,896),Vector2i(896,370),Vector2i(816,616)]:
		root.size=size;await frames(10)
		app.world.player.zoom_at(app.world.player.get_viewport_rect().size*.5,1)
		check(app.world.player.can_pan(),"Cropped world permits minimum-zoom pan: "+str(size))
		var p:=Vector2(app.w*.52,app.h*.60)
		# Locate an actual blank, non-UI area in this viewport.
		for y in range(140,int(app.h)-100,25):
			var candidate:=Vector2(app.w*.53,y)
			if not app.gestures.ui_hit(candidate) and not app.world.interaction_at(candidate):p=candidate;break
		finger(2,true,p);drag(2,p+Vector2(35,0));finger(2,false,p+Vector2(35,0));await frames(2)
		check(app.world.player.manual_camera and app.navigation.action=="","Drag release never becomes destination: "+str(size))
		var center:Vector2=app.world.player.camera.get_screen_center_position();await frames(10)
		check(center.distance_to(app.world.player.camera.get_screen_center_position())<1,"Pan remains latched: "+str(size))
		var toggle:Control=app.action_toggle;var expand:Control=app.stage.get_node("ExpandActions")
		check(not toggle.get_global_rect().intersects(expand.get_global_rect()),"Menu and arrow touch areas do not overlap: "+str(size))
		check(toggle.size.x>=64 and toggle.size.y>=64 and toggle.has_node("ActionVisual"),"Menu retains minimum touch size and caption")
		app.apply_action_skin("메뉴")
		var skin:StyleBoxTexture=toggle.get_theme_stylebox("normal")
		check(skin.texture is AtlasTexture and skin.texture.atlas==DemoArt.play_icon("menu"),"Menu uses the approved source image")
		check(toggle.get_node("ActionVisual").find_children("*","TextureRect",true,false).is_empty(),"Menu has no duplicated symbol overlay")
		app.world.player.resume_camera()
	check(app.world.animals.size()==6,"Two existing-model animals added")
	for a in app.world.animals:
		check(not Geometry2D.is_point_in_polygon(a.position,PackedVector2Array(DemoWorld.RIVER_POLYGON)),"Animal remains outside water: "+a.name)
	app.set_process(false);app.world.player.position=Vector2(1150,900);app.world.player.direction=Vector2.RIGHT;await frames(3)
	check(is_equal_approx(app.world.player.velocity.length(),181.5),"Direct movement uses new actual velocity")
	app.world.player.direction=Vector2.ZERO;app.set_process(true)
	var report:Dictionary={"checks":checks,"failed":failed,"runtime":"Native Godot actual physics and synthetic input; no physical device claim"}
	FileAccess.open("res://reports/village-controls-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
