extends SceneTree
var checks:=0
var failed:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failed.append(message);push_error(message)
func capture(name:String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/aurora-"+name+".png")
func run() -> void:
 var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region");await create_timer(.6).timeout
 var map:RegionSelection=app.region_selection
 var saved:String=JSON.stringify(app.model.state)
 for key in ["jeongok","amsa","dongsam"]:
  map.select_region(key);await create_timer(.4).timeout
  var veil:ColorRect=map.markers.auroras[key]
  check(veil.visible and is_equal_approx(veil.modulate.a,1),"Selected aurora persists: "+key)
  check(veil.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Aura cannot intercept map input: "+key)
  check(veil.get_index()<map.markers.images[key].get_index(),"Aura draws behind artifact and label: "+key)
  check(veil.position.is_equal_approx(map.map_point(key)-Vector2(68,126)*map.ui_factor),"Aura tracks geographic ground point: "+key)
  for other in RegionCatalog.REGIONS:
   if other!=key:check(not map.markers.auroras[other].visible,"Old selection aura disappears: "+other)
  await capture(key)
 var phase:float=map.markers.aurora_time;await create_timer(.2).timeout
 check(map.markers.aurora_time>phase,"Selected curtain continues to flow")
 app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED);phase=map.markers.aurora_time;await create_timer(.2).timeout
 check(map.markers.aurora_time==phase,"Background freezes curtain motion")
 app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED);await create_timer(.2).timeout
 check(map.markers.aurora_time>phase,"Resume continues curtain motion")
 map.select_region("amsa");map.pose(1.6,Vector2(-230,-100));await create_timer(.4).timeout
 check(map.markers.auroras.amsa.position.is_equal_approx(map.map_point("amsa")-Vector2(68,126)*map.ui_factor),"Manual camera keeps aura on selected marker")
 await capture("zoom")
 check(JSON.stringify(app.model.state)==saved,"Selection decoration preserves game progress")
 app.queue_free();await process_frame
 var report:={"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true)}
 FileAccess.open("res://reports/aurora-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
