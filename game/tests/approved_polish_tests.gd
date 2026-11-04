extends SceneTree
var app:Node
var failed:Array[String]=[]
var checks:=0
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failed.append(label);push_error(label)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(2)
	app.start_region();app.close_modal();await frames(3)
	for r in app.world.residents:r.set_physics_process(false);r.collision_layer=0
	for a in app.world.animals:a.set_physics_process(false)
	var p:DemoPlayer=app.world.player
	check(p.hybrid.model_path=="res://assets/characters/meshy01/hero.glb","Hero original GLB retained")
	check(app.chrome.portrait.resource_path=="res://assets/ui/s40000/portrait.png","Hero original portrait retained")
	check(is_equal_approx(DemoConfig.get_data().move_speed,181.5),"v27 movement speed preserved")
	# Arm and ipsilateral leg must counter-swing, including the full imported bone basis.
	for phase in [0.0,PI]:
		p.hybrid.animate(.5,Vector2.DOWN,phase,true,"",0,false)
		for side in ["L","R"]:
			var arm:=p.hybrid.rig.get_bone_pose_rotation(p.hybrid.bones["arm"+side]).get_euler().x
			var thigh:=p.hybrid.rig.get_bone_pose_rotation(p.hybrid.bones["thigh"+side]).get_euler().x
			check(arm*thigh<0,"Contralateral arm/leg swing "+side+str(phase))
	var hut:EnvironmentProp=app.world.get_node("ExistingHut")
	var old_position:=hut.position
	for style in 3:
		hut.set_hut_style(style)
		check(hut.sprite.get_parent()==hut.depth_visual and hut.y_sort_enabled,"Roof participates in footprint-centred Y sorting")
		check(is_equal_approx(hut.depth_visual.global_position.y,hut.position.y-36),"Sort plane is ground centre, style "+str(style))
		check(hut.position==old_position,"Style never moves physics/save origin")
		var bottom:=hut.sprite.global_position.y+hut.sprite.texture.get_height()*hut.sprite.scale.y*.5
		check(is_equal_approx(bottom,hut.position.y),"Visible ground anchor remains fixed, style "+str(style))
		for side in [-1,1]:
			var pose:=p.transform;pose.origin=hut.position+Vector2(side*140,-25)
			check(p.test_move(pose,Vector2.ZERO,null,.08,true),"Physical flank still blocked, style/side "+str(style)+str(side))
	hut.set_hut_style(0)
	for size in [Vector2i(1280,720),Vector2i(896,370),Vector2i(816,616)]:
		root.size=size;await frames(4);app.actions_expanded=true;await frames(4)
		var toggle:Rect2=app.action_toggle.get_global_rect()
		var arrow:Rect2=app.stage.get_node("ExpandActions").get_global_rect()
		check(not toggle.intersects(arrow),"Toggle/arrow touch areas separate "+str(size))
		for b in app.action_row.get_children():
			check(not b.get_global_rect().intersects(toggle),"Menu action touch does not overlap fold "+b.text+str(size))
		check(toggle.size.x>=64 and arrow.size.x>=44,"Usable action targets "+str(size))
		check(app.objective.get_parent().size.y==58,"Compact expanded quest "+str(size))
		app.toggle_quest();check(app.objective.text.contains("/3채"),"Collapsed quest retains meaningful count");app.toggle_quest()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/polish-layout-%dx%d.png"%[size.x,size.y])
	var measured:Array[Dictionary]=[]
	for size in [Vector2i(1280,720),Vector2i(896,370),Vector2i(816,616),Vector2i(370,896)]:
		root.size=size;await frames(4);p.position=Vector2(1150,810)
		p.zoom_at(root.get_visible_rect().size*.5,1);await frames(4)
		var previous:=root.get_visible_rect().size/p.camera.zoom
		var joystick_size:Vector2=app.joystick.size
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/overview-before-%dx%d.png"%[size.x,size.y])
		p.zoom_at(root.get_visible_rect().size*.5,DemoPlayer.MIN_ZOOM);await frames(4)
		var current:=root.get_visible_rect().size/p.camera.zoom
		check(current.distance_to(previous*1.2)<.1,"Actual visible width/height grow 20% "+str(size))
		check(app.joystick.size==joystick_size,"Overview never scales joystick "+str(size))
		measured.append({"viewport":str(size),"old_world_span":str(previous),"new_world_span":str(current),"width_ratio":current.x/previous.x,"height_ratio":current.y/previous.y})
		for delta in [Vector2(10000,10000),Vector2(-10000,-10000)]:
			p.pan_camera(delta);await frames(2)
			var inv:=root.get_canvas_transform().affine_inverse()
			var first:Vector2=inv*Vector2.ZERO;var last:Vector2=inv*root.get_visible_rect().size
			var bounds:=p.camera_bounds().grow(1)
			check(bounds.has_point(first) and bounds.has_point(last),"Pan remains inside rendered overview "+str(size)+str(delta))
		p.zoom_at(root.get_visible_rect().size*.5,DemoPlayer.MIN_ZOOM,Vector2(1200,675));await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/overview-after-%dx%d.png"%[size.x,size.y])
	root.size=Vector2i(1280,720);await frames(4)
	p.zoom_at(root.get_visible_rect().size*.5,DemoPlayer.MIN_ZOOM)
	var target:Vector2=app.world.art_nodes.wood_3.position
	app.world_tap(app.world.get_global_transform_with_canvas()*target)
	check(app.navigation.action=="gather","Resource tap at new overview targets actual resource")
	app.cancel_task()
	check(app.navigation.action=="" and app.model.state.wood==0,"Overview route cancellation grants no resource")
	var report:Dictionary={"checks":checks,"failed":failed,"overview_measurements":measured,"runtime":"Windows native Godot; synthetic layout/rig/physics checks, not physical Android"}
	FileAccess.open("res://reports/approved-polish-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
