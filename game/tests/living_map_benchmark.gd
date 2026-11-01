extends SceneTree
# Run without --fixed-fps. Paired off/on/on/off samples isolate decoration cost
# in the same rendered map; this is not a claim about physical Android devices.
func _initialize() -> void:call_deferred("run")
func summarize(values:Array[float]) -> Dictionary:
	var sorted:=values.duplicate();sorted.sort();var total:=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"median":sorted[values.size()/2],"p95":sorted[int(values.size()*.95)],"samples":values.size()}
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region")
	Engine.max_fps=60
	var samples:Array=[]
	for enabled in [false,true,true,false]:
		app.region_selection.ambience.enabled=enabled;app.region_selection.ambience.clock=2;app.region_selection.ambience.queue_redraw()
		for i in 60:await process_frame
		var frame_ms:Array[float]=[];var process_ms:Array[float]=[];var draws:Array[float]=[]
		var before:=Time.get_ticks_usec()
		for i in 180:
			await process_frame
			var now:=Time.get_ticks_usec();frame_ms.append((now-before)/1000.0);before=now
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.append({"environment_enabled":enabled,"frame_ms":summarize(frame_ms),"main_process_ms":summarize(process_ms),"draw_calls":summarize(draws)})
	var report:={"utc":Time.get_datetime_string_from_system(true),"os":OS.get_name(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"fps_limit":60,"fixed_fps":false,"scope":"Paired native environment-decoration comparison, not Android hardware benchmark","runs":samples}
	FileAccess.open("res://reports/living-map-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await process_frame;quit()
