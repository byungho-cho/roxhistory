extends SceneTree
var app:Node
var errors:Array[String]=[]
var checks:=0
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func frames(n:int=20)->void:
	for i in n:await physics_frame;await process_frame
func capture(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/review-"+label+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3)
	app.start_region();await frames()
	var saved:=JSON.stringify(app.model.state)
	var toggle_at:Vector2=app.menu_toggle.get_global_transform()*(app.menu_toggle.size*.5)
	app.toggle_menu();await frames(4)
	check(app.gather_button.visible and app.gather_button.modulate.a<1,"Collapse interpolates instead of instantly hiding")
	app.toggle_menu();await frames()
	check(not app.menu_expanded and not app.gather_button.visible,"Repeated toggle during animation is ignored safely")
	app.toggle_menu();await frames()
	check(app.gather_button.visible and is_equal_approx(app.gather_button.modulate.a,1),"Toggle after animation restores all actions")
	app.toggle_menu();await frames()
	check(not app.gather_button.visible and app.build_button.visible,"Collapsed menu retains construction")
	check(not app.gestures.ui_hit(app.gather_button.global_position-Vector2(200,0)),"Collapsed empty menu space does not swallow map taps")
	check((app.menu_toggle.get_global_transform()*(app.menu_toggle.size*.5)).is_equal_approx(toggle_at),"Toggle center remains fixed while collapsing")
	check(not app.menu_toggle.get_node("ToggleVisual").expanded,"Collapsed arrow visual uses collapsed state")
	await capture("collapsed")
	app.toggle_menu();await frames()
	check(app.menu_toggle.get_node("ToggleVisual").expanded,"Expanded arrow visual uses expanded state")
	check(app.action_row.get_child(0).disabled and app.action_row.get_child(2).disabled,"Unreleased actions stay disabled")
	app.task="gather";app.update_hud();check(app.gather_button.text=="채집","Gather label remains stable")
	app.task="build";app.update_hud();check(app.build_button.text=="건설","Build label remains stable")
	app.task="";app.update_hud()
	for key in app.world.resource_labels:
		var indicator:ResourceIndicator=app.world.resource_labels[key]
		check(indicator.total>0 and indicator.remaining<=indicator.total,"Resource indicator has valid remaining capacity: "+key)
	await capture("village-min")
	var mini:LiveMinimap=app.chrome.minimap
	check(mini.village_view.world_2d==app.world.get_world_2d(),"Minimap renders the actual village canvas")
	check(mini.normalized_point(VillageBounds.WORLD_RECT.get_center()).is_zero_approx(),"Map center and marker share projection")
	check(mini.village_view.size==Vector2i(192,192),"Thumbnail render budget is bounded")
	if DisplayServer.get_name()!="headless":
		var thumb:=mini.current_texture().get_image()
		check(thumb.get_pixel(96,96)!=thumb.get_pixel(0,0),"Live thumbnail contains rendered terrain")
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,10);await frames()
	check(is_equal_approx(app.world.player.zoom_factor,DemoPlayer.MAX_ZOOM),"Village maximum matches configured zoom limit")
	await capture("village-max")
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1);await frames()
	app.map_toggle.pressed.emit();await frames(10)
	check(app.map_transition_active and not app.world_map_open,"Clouds cover the old scene before swapping")
	await capture("clouds-covering")
	app.toggle_world_map()
	check(not app.world_map_open,"Repeated toggle is ignored during transition")
	await frames(15);await capture("clouds-covered")
	await frames(35)
	check(app.map_toggle.icon==null and app.map_toggle.get_node("FigmaHomeFace").visible,"Home toggle uses the separate preserved frame and village overlay")
	check(not app.map_toggle.has_node("HomeFace"),"No second background panel on map toggle")
	await capture("world-min")
	app.world_map.zoom_at(Vector2(app.w,app.h)*.5,2.4);await frames()
	await capture("world-max")
	app.world_map.pan(Vector2(200,100));app.recenter_map()
	check(app.world_map.center.is_zero_approx(),"World-map GPS recenters the world map")
	app.world_map.enter_village(Vector2(app.w,app.h)*.5)
	check(app.map_transition_active and is_instance_valid(app.map_transition),"Village tap starts cloud transition")
	await frames(60)
	check(not app.world_map_open,"Covered scene switches back to village")
	check(not is_instance_valid(app.map_transition),"Transition cleans up after completion")
	check(JSON.stringify(app.model.state)==saved,"UI and camera changes do not mutate saved state")
	var empty:Dictionary=app.model.state.duplicate(true);empty.wood=0;empty.stone=0;app.model.commit(empty)
	app.construction_menu();await frames()
	check(app.build_side.hut.disabled,"Insufficient materials still block construction")
	await capture("construction-poor")
	var rich:Dictionary=app.model.state.duplicate(true);rich.wood=100;rich.stone=100;app.model.commit(rich)
	app.construction_menu();await frames();await capture("construction-ready")
	app.cancel_build_preview()
	for animal in app.world.animals:animal.set_physics_process(false)
	app.choosing_plot=true;app.build_preview.select(0);app.confirm_build_preview()
	var ticks:=0
	while app.task!="" and ticks<200:await frames(1);ticks+=1
	check(app.model.built_count()==1,"Construction completes through real confirmation")
	check(app.world.reward_markers.z_index>app.world.home.z_index,"Seed reward is above building sprites")
	await frames();await capture("seed-reward")
	check(app.model.claim_reward(0),"Seed reward is collectible")
	check(not app.model.claim_reward(0),"Duplicate reward cannot pay twice")
	var restored:=GameState.new(app.model.store)
	check(restored.state.tokens==app.model.state.tokens and restored.built_count()==1,"Reload preserves reward and building")
	# Exercise the actual gather button, including its contact-timed reward.
	var resource:Dictionary=app.model.nodes()[0]
	app.world.player.position=app.world.gather_stand(DemoConfig.point(resource.position),resource.kind)
	app.world.player.resume_camera();await frames(3)
	var wood_before:int=app.model.state.wood
	app.gather_action(resource.id);await frames(180)
	check(app.model.state.wood>=wood_before+10,"Actual gathering awards resources")
	check(app.gather_button.text=="채집","Gather label stays stable throughout contact loop")
	app.cancel_task()
	await capture("gathered")
	var expanded:Dictionary=app.model.state.duplicate(true);expanded.chief_level=3;app.model.commit(expanded)
	check(app.model.build(Vector2.ZERO,1) and app.model.build(Vector2.ZERO,2),"Three homes unlock residents")
	app.world.player.position=FamilyArrival.MEETING;app.world.player.resume_camera();await frames()
	check(app.family.bubble.visible,"Resident dialogue is available")
	var head:Vector2=app.world.get_global_transform_with_canvas()*Vector2(1590,740)
	check(app.family.bubble.position.y+app.family.bubble.size.y<head.y+10,"Speech bubble stays above resident heads")
	await capture("residents")
	app.family.bubble.pressed.emit();await frames(180)
	check(app.model.state.family_joined,"Resident conversation still joins the family")
	var family_reload:=GameState.new(app.model.store)
	check(family_reload.state.family_joined,"Resident progress survives reload")
	# Resize during menu animation: no stale tween callbacks or ghost input areas.
	app.toggle_menu();root.size=Vector2i(720,1280);await frames(40)
	check(app.screen=="play" and app.build_button.visible,"Portrait relayout preserves playable HUD")
	await capture("portrait")
	var result:={"checks":checks,"failures":errors,"environment":"Godot 4.5.1 / isolated test profile; headless captures skipped"}
	FileAccess.open("res://reports/ui-review-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
