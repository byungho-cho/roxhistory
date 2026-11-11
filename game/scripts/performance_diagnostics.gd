class_name PerformanceDiagnostics
extends RefCounted

const RUNS := "user://diagnostics/runs"
const DEFAULT_ENABLED := true
const INTERVAL := 5.0
var elapsed := 0.0
var scene := ""
var last_tick := 0
var frame_times := PackedFloat32Array()
var entry_sampled := false
var path := ""
var latest:Dictionary={}
var previous_cpu:=0.0
var previous_sample_at:=0

static func enabled(settings:ConfigFile)->bool:
	return settings.get_value("development","performance_diagnostics",DEFAULT_ENABLED)

static func hud_enabled(settings:ConfigFile)->bool:
	return settings.get_value("development","performance_hud",false)

func tick(app: Node, _delta: float) -> void:
	if not app.application_active or (not enabled(app.settings) and not hud_enabled(app.settings)):
		reset_window("")
		previous_sample_at=0
		entry_sampled=false
		return
	var playing:bool=app.screen=="play" and is_instance_valid(app.world)
	var next_scene:String=app.screen
	if is_instance_valid(app.intro_cloud):
		next_scene="first_village_transition" if app.first_village_loading else "intro_transition"
	elif playing:
		if app.village_entry_active():next_scene="village_entry"
		elif app.build_side.visible:next_scene="construction_menu"
		elif app.building_menu.visible:next_scene="building_selection_menu"
		else:next_scene="village_popup" if app.modal else "village"
	var now:=Time.get_ticks_usec()
	if next_scene!=scene:
		if last_tick>0 and scene in ["intro_transition","first_village_transition","intro"]:
			collect_frame(now)
			record_window(app,now,playing)
		reset_window(next_scene)
		previous_sample_at=0
		entry_sampled=false
	if scene=="village_entry" and entry_sampled:return
	if last_tick>0:collect_frame(now)
	last_tick=now
	if elapsed<(1.5 if scene=="village_entry" else INTERVAL):return
	record_window(app,now,playing)

func collect_frame(now: int) -> void:
	var ms := (now-last_tick)/1000.0
	frame_times.append(ms)
	elapsed+=ms/1000.0

func record_window(app: Node, now: int, playing: bool) -> void:
	if frame_times.is_empty() or elapsed<=0.0:return
	var working:=0
	if playing:
		for resident in app.world.residents:
			if resident.job_kind!="idle":working+=1
	var sample:Dictionary={
		"time":Time.get_datetime_string_from_system(true),
		"version":ProjectSettings.get_setting("application/config/version"),
		"platform":OS.get_name(),
		"baseline_commit":ProjectSettings.get_setting("roxhistory/update/source_commit",""),
		"zoom":app.world.player.zoom_factor if playing else null,
		"device":OS.get_model_name() if OS.has_feature("android") else OS.get_processor_name(),
		"scene":scene,
		"sample_seconds":elapsed,
		"screen":app.screen,
		"popup":app.modal,
		"construction_menu":playing and app.build_side.visible,
		"building_selection_menu":playing and app.building_menu.visible,
		"hero_moving":playing and not app.world.player.velocity.is_zero_approx(),
		"hero_task":app.task,
		"residents":app.world.residents.size() if playing else 0,
		"assigned_residents":working,
		"window_px":[app.get_window().size.x,app.get_window().size.y],
		"fps":Engine.get_frames_per_second(),
		"process_frame_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		"physics_frame_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	}
	frame_times.sort()
	var count:=frame_times.size()
	sample.frame_count=count
	sample.measured_fps=count/elapsed
	sample.frame_p50_ms=frame_times[(count-1)/2]
	sample.frame_p95_ms=frame_times[ceili(count*.95)-1]
	sample.frame_max_ms=frame_times[count-1]
	if scene in ["intro_transition","first_village_transition"]:
		sample.transition_prepare_ms=app.transition_prepare_ms
	entry_sampled=scene=="village_entry"
	reset_window(scene)
	var engine_memory:=OS.get_static_memory_usage()
	if engine_memory>0:sample.engine_memory_bytes=engine_memory
	if app.village_alerts:sample.merge(app.village_alerts.diagnostic_sample())
	if sample.has("process_cpu_total_ms"):
		var current_cpu:=float(sample.process_cpu_total_ms)
		if previous_sample_at>0 and current_cpu>=previous_cpu:
			sample.process_cpu_one_core_percent=(current_cpu-previous_cpu)*100000.0/(now-previous_sample_at)
		previous_cpu=current_cpu
		previous_sample_at=now
	latest=sample
	if is_instance_valid(app.performance_hud):app.performance_hud.update_sample(latest)
	if not enabled(app.settings):return
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute(RUNS)
		var stamp:=Time.get_datetime_string_from_system(true).replace(":","-")
		path=RUNS+"/%s-%d.jsonl"%[stamp,OS.get_process_id()]
	var file:=FileAccess.open(path,FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path,FileAccess.WRITE)
	if file==null:return
	file.seek_end()
	file.store_line(JSON.stringify(sample))

static func log_files() -> PackedStringArray:
	var files:=PackedStringArray()
	for name in DirAccess.get_files_at(RUNS):
		if name.ends_with(".jsonl"):files.append(name)
	return files

static func log_summary() -> Dictionary:
	var files:=log_files()
	var bytes:=0
	for name in files:
		var file:=FileAccess.open(RUNS.path_join(name),FileAccess.READ)
		if file!=null:bytes+=file.get_length()
	return {"count":files.size(),"bytes":bytes}

func delete_logs() -> int:
	var failed:=0
	for name in log_files():
		if DirAccess.remove_absolute(RUNS.path_join(name))!=OK:failed+=1
	if path.begins_with(RUNS+"/"):path=""
	reset_window(scene)
	return failed

func export_zip()->String:
	var files:=log_files()
	if files.is_empty():return ""
	var stamp:=Time.get_datetime_string_from_system(true).replace(":","-")
	var destination:="user://diagnostics/Roxhistory-diagnostics-%s.zip"%stamp
	var zip:=ZIPPacker.new()
	if zip.open(destination)!=OK:return ""
	for name in files:
		var data:=FileAccess.get_file_as_bytes(RUNS.path_join(name))
		if data.is_empty():continue
		if zip.start_file(name)!=OK or zip.write_file(data)!=OK or zip.close_file()!=OK:
			zip.close()
			return ""
	return destination if zip.close()==OK else ""

func reset_window(next_scene:String)->void:
	scene=next_scene
	elapsed=0.0
	last_tick=0
	frame_times.clear()
