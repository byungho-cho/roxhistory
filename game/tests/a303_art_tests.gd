extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region")
	var map:RegionSelection=app.region_selection
	for key in RegionCatalog.REGIONS:
		map.selected=key;map.refresh();map.pose(1,Vector2.ZERO)
		var initial:=map.markers.artifact_rect(key)
		var contact:=map.markers.bottom(key)
		for i in 20:
			map.selected="dongsam" if key!="dongsam" else "jeongok";map.refresh()
			var small:=map.markers.artifact_rect(key)
			check(is_equal_approx(small.end.y,initial.end.y),"Selection keeps artifact ground contact")
			check(is_equal_approx(small.size.y/initial.size.y,1.0/1.2),"Unselected/selected ratio remains 100/120")
			map.selected=key;map.refresh()
		check(map.markers.artifact_rect(key).is_equal_approx(initial),"Repeated selection never accumulates scale: "+key)
		check(map.markers.bottom(key).is_equal_approx(contact),"Anchor remains stable: "+key)
		check(map.details.resources.get_children().filter(func(n):return n.has_meta("resource_kind")).size()==4,"Exactly three common resources and one regional food")
		check(map.title_label.text==RegionCatalog.REGIONS[key].name,"Semantic title remains available")
		check(map.markers.labels[key].get_index()>map.markers.images[key].get_index(),"Place name draws in front of artifact")
	for key in ["region","jeongok","amsa","dongsam"]:
		var image:=FigmaArt.texture("title-"+key+".png").get_image()
		check(image.get_pixel(0,0).a<.01,"Stone title export has transparent background: "+key)
	for key in FigmaArt.CROPS:
		var tex:AtlasTexture=FigmaArt.texture(key)
		check(Rect2(Vector2.ZERO,tex.atlas.get_size()).encloses(tex.region),"Sprite crop stays inside original: "+key)
	map.selected="amsa";map.refresh();map.pose(1.3,Vector2(-80,-30))
	var point:=map.size*Vector2(.42,.5);var anchor:Vector2=(point-map.pan)/(map.factor*map.zoom)
	var wheel:=InputEventMouseButton.new();wheel.position=point;wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	var before:=map.zoom;map._input(wheel);check(map.zoom==before,"Plain wheel does not accidentally zoom")
	wheel.ctrl_pressed=true;map._input(wheel)
	check(map.zoom>before,"Ctrl + wheel zooms on PC")
	check(((point-map.pan)/(map.factor*map.zoom)).distance_to(anchor)<.01,"PC zoom keeps cursor map coordinate stable")
	map.select_region("jeongok");app.show_about();var stopped:=map.pan
	await create_timer(.7).timeout
	check(map.pan.is_equal_approx(stopped) and map.fingers.is_empty(),"Popup cancels map motion and active input")
	app.close_modal();map.restore();await create_timer(.55).timeout
	check(map.selected=="jeongok" and is_equal_approx(map.zoom,1),"Reset preserves region after popup")
	app.queue_free();await process_frame
	var result:={"checks":checks,"failed":failures,"utc":Time.get_datetime_string_from_system(true)}
	FileAccess.open("res://reports/a303-art-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
