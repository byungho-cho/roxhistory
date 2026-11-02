extends SceneTree
func _initialize(): call_deferred("run")
func run():
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var app=load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.model.start_new();app.start_region();app.close_modal()
 app.world.player.position=Vector2(1750,1140)
 app.world.player.camera.position=Vector2(0,-80)
 app.world.player.zoom_factor=1.7;app.world.player.fit_camera()
 for i in 120: await process_frame
 var samples:Array[float]=[]
 var last=Time.get_ticks_usec()
 for i in 2000:
  await process_frame
  var now=Time.get_ticks_usec()
  samples.append((now-last)/1000.0);last=now
 samples.sort()
 var total=0.0
 for value in samples: total+=value
 print("BASELINE_COMPARISON "+JSON.stringify({"frames":2000,"mean_ms":total/2000,"p95_ms":samples[1900],"resolution":str(root.size),"gpu":RenderingServer.get_video_adapter_name()}))
 quit()
