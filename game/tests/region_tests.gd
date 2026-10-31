extends SceneTree
var checks:=0
var failed:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region")
	var map:RegionSelection=app.region_selection
	check(is_equal_approx(map.zoom,1),"Initial region screen uses full overview")
	check(map.selected=="amsa" and not map.start_button.disabled,"Playable Amsa is initial detail")
	var fixed_panel:=map.details.get_global_rect()
	for key in RegionSelection.REGIONS:
		var icon:=map.marker_rect(key).position+Vector2(25,25)*map.factor
		map.begin_pointer(0,icon);map.end_pointer(0,icon);await create_timer(.65).timeout
		check(map.selected==key and map.title_label.text==RegionSelection.REGIONS[key].name,"Icon selects and updates "+key)
		check(is_equal_approx(map.zoom,2),"Selection smoothly reaches maximum zoom")
		check(not map.details.get_global_rect().has_point(map.map_point(key)),"Selected region is not hidden by panel")
		check(map.start_button.disabled==(key!="amsa"),"Start reflects real playable support")
		check(map.food.texture.region.position.x==RegionSelection.REGIONS[key].food*map.food.texture.region.size.x,"Fourth food matches selected region")
		var before:=map.selected;map.restore();await create_timer(.55).timeout
		check(map.selected==before and is_equal_approx(map.zoom,1),"Restore keeps selection and returns overview")
		var label:=map.marker_rect(key).position+Vector2(150,35)*map.factor
		map.begin_pointer(1,label);map.end_pointer(1,label)
		check(map.selected==key,"Name is selectable")
		map.restore();await create_timer(.55).timeout
	map.select_region("jeongok");map.select_region("dongsam");map.select_region("amsa");await create_timer(.65).timeout
	check(map.selected=="amsa" and map.title_label.text=="암사동","Rapid selection leaves only final region")
	check(map.details.get_global_rect()==fixed_panel,"Fixed UI is unchanged by map animation")
	map.pose(1.3,map.origin-Vector2(100,50)*map.factor)
	var center:=map.size*Vector2(.40,.52)
	var anchor:Vector2=(center-map.pan)/(map.factor*map.zoom)
	map.begin_pointer(0,center-Vector2(50,0));map.begin_pointer(1,center+Vector2(50,0))
	map.move_pointer(0,center-Vector2(70,0));map.move_pointer(1,center+Vector2(70,0))
	check(absf(map.zoom-1.82)<.001,"Pinch scales continuously rather than discrete steps")
	check(((center-map.pan)/(map.factor*map.zoom)).distance_to(anchor)<.01,"Pinch keeps midpoint map coordinate stable")
	var count:=map.selection_count;map.end_pointer(1,center+Vector2(70,0));map.end_pointer(0,center-Vector2(70,0))
	check(map.selection_count==count,"Pinch release never selects a region")
	var old_pan:=map.pan;map.begin_pointer(0,center);map.move_pointer(0,center+Vector2(30,25));map.end_pointer(0,center+Vector2(30,25))
	check(map.pan.distance_to(old_pan)>5 and map.selection_count==count,"Single finger drags without selecting")
	for target_zoom in [.1,1,1.5,2,5]:
		for extreme in [Vector2(-10000,-10000),Vector2(10000,10000)]:
			map.pose(target_zoom,extreme)
			check(map.zoom>=1 and map.zoom<=2,"Zoom limits hold")
			check(map.pan==map.bounded(extreme,map.zoom),"Pan never passes map boundary")
	var ui_center:=map.details.get_global_rect().get_center();old_pan=map.pan
	map.begin_pointer(0,ui_center);map.move_pointer(0,ui_center-Vector2(150,100));map.end_pointer(0,ui_center-Vector2(150,100))
	check(map.pan==old_pan,"Panel-origin drag cannot pan map")
	map.begin_pointer(0,center);map.begin_pointer(1,ui_center);map.move_pointer(0,center+Vector2(50,50));map.end_pointer(1,ui_center);map.end_pointer(0,center+Vector2(50,50))
	check(map.pan==old_pan and map.selection_count==count,"UI-owned second finger cannot become pinch or tap")
	map.begin_pointer(0,center);map.cancel_input();map.move_pointer(0,center+Vector2(100,0))
	check(map.fingers.is_empty() and map.pan==old_pan,"Lifecycle cancellation drops stale touches")
	map.select_region("dongsam");await create_timer(.65).timeout;var snap:=map.snapshot();app.relayout();map=app.region_selection
	check(map.selected==snap.selected and is_equal_approx(map.zoom,snap.zoom),"Relayout preserves region and zoom")
	var prior_state=app.model.state.duplicate(true);app.start_region()
	check(app.screen=="region" and app.model.state==prior_state,"Unsupported start cannot silently enter Amsa or overwrite save")
	# Regression: an Android cutout must move a control and its adjacent text together.
	var original_size:=Vector2(app.w,app.h);var original_safe:Vector2=app.safe
	for dimensions in [Vector2(960,540),Vector2(960,396),Vector2(960,724)]:
		app.w=dimensions.x;app.h=dimensions.y;app.safe=Vector2(70,24)
		var layout:=RegionSelection.new(app);root.add_child(layout);await process_frame
		var back:Rect2=layout.ui_root.get_node("RegionBack").get_global_rect()
		var heading:Rect2=layout.ui_root.get_node("RegionHeading").get_global_rect()
		var reset_button:Rect2=layout.ui_root.get_node("MapReset").get_global_rect()
		var hint:Rect2=layout.ui_root.get_node("GestureHint").get_global_rect()
		var bag:Rect2=layout.ui_root.get_node("RegionBag").get_global_rect()
		var panel:Rect2=layout.details.get_global_rect()
		var safe_rect:=Rect2(app.safe,dimensions-app.safe*2).grow(.01)
		check(not back.intersects(heading),"Safe-inset back button never overlaps heading "+str(dimensions))
		check(not reset_button.intersects(hint),"Safe-inset reset never overlaps its hint "+str(dimensions))
		check(not panel.intersects(bag),"Short viewport keeps panel below bag "+str(dimensions))
		check(safe_rect.encloses(back) and safe_rect.encloses(bag) and safe_rect.encloses(reset_button),"Fixed controls respect cutout margins "+str(dimensions))
		check(safe_rect.encloses(panel),"Panel remains inside safe viewport "+str(dimensions))
		check(not layout.ui_hit(Vector2(app.safe.x+150,app.safe.y+132*layout.factor+4)),"Header hit area follows fixed header rather than centered map "+str(dimensions))
		layout.queue_free();await process_frame
	app.w=original_size.x;app.h=original_size.y;app.safe=original_safe
	map.select_region("amsa");app.start_region();app.close_modal()
	check(app.screen=="play" and app.world.player.use_3d,"Amsa enters existing 3D gameplay")
	await process_frame;await RenderingServer.frame_post_draw
	app.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true)}
	FileAccess.open("res://reports/region-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
