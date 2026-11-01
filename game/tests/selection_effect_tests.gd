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
	var source:=map.map_surface.texture
	map.pose(1.4,Vector2(-170,-60)*map.factor)
	var before_pan:=map.pan;var before_zoom:=map.zoom
	for key in RegionCatalog.REGIONS:
		map.select_region(key);await create_timer(.32).timeout
		check(map.pan==before_pan and map.zoom==before_zoom,"Selection never changes manual camera: "+key)
		check(map.map_surface.texture==source,"Selection retains single shared map: "+key)
		check(map.markers.bottom(key)==map.map_point(key),"Icon anchored directly to geographic point: "+key)
		var extent:=map.markers.artifact_rect(key).size/map.ui_factor
		check(is_equal_approx(maxf(extent.x,extent.y),86*1.2),"Selected icon settles at exactly 120 percent: "+key)
		for other in RegionCatalog.REGIONS:
			if other!=key:
				var base:=map.markers.artifact_rect(other).size/map.ui_factor
				check(is_equal_approx(maxf(base.x,base.y),86),"Other icon stays at shared base size: "+other)
	var empty:=map.size*Vector2(.22,.65)
	map.begin_pointer(0,empty);map.end_pointer(0,empty)
	check(not map.panel_visible and not map.details.visible,"Empty map tap hides entire information panel")
	var previous:=map.selected
	check(not map.ui_hit(map.start_button.get_global_rect().get_center()),"Hidden start button cannot capture map touches")
	var snap:=map.snapshot();app.relayout();map=app.region_selection
	check(not map.details.visible and map.selected==previous,"Hidden panel and selection survive relayout")
	map.restore();await create_timer(.55).timeout
	check(not map.details.visible and map.selected==previous and map.zoom==1,"Explicit reset keeps hidden panel and selected region")
	var dimensions_before:=Vector2(app.w,app.h)
	for dimensions in [Vector2(1307,540),Vector2(960,724)]:
		app.w=dimensions.x;app.h=dimensions.y
		var resized:=RegionSelection.new(app,map.snapshot());root.add_child(resized);await process_frame
		check(resized.pan.is_equal_approx(resized.camera.overview_pan()) and not resized.details.visible,"Overview and hidden panel survive aspect-ratio change")
		for key in RegionCatalog.REGIONS:
			check(Rect2(Vector2.ZERO,dimensions).encloses(resized.markers.artifact_rect(key)),"All anchored icons remain visible after resize: "+key)
		resized.queue_free();await process_frame
	app.w=dimensions_before.x;app.h=dimensions_before.y
	var label:=map.markers.name_rect("amsa").get_center()
	map.begin_pointer(0,label);map.end_pointer(0,label)
	check(map.details.visible and map.selected=="amsa","Name tap restores correct information panel")
	map.begin_pointer(0,empty);map.move_pointer(0,empty+Vector2(60,20));map.end_pointer(0,empty+Vector2(60,20))
	check(map.details.visible,"Map drag does not dismiss panel")
	map.begin_pointer(0,empty);map.begin_pointer(1,empty+Vector2(110,0));map.move_pointer(1,empty+Vector2(150,0));map.end_pointer(1,empty+Vector2(150,0));map.end_pointer(0,empty)
	check(map.details.visible and map.selected=="amsa","Pinch release neither hides panel nor selects another region")
	for i in 12:map.select_region("amsa")
	await create_timer(.32).timeout
	check(is_equal_approx(map.markers.artifact_rect("amsa").size.y,86*1.2*map.ui_factor),"Repeated selection cannot accumulate icon scale")
	map.begin_pointer(0,empty);map.cancel_input();map.end_pointer(0,empty)
	check(map.details.visible and map.fingers.is_empty(),"Canceled lifecycle touch never dismisses panel")
	app.queue_free();await process_frame
	var report:={"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true)}
	FileAccess.open("res://reports/selection-effect-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
