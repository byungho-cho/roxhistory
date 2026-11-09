class_name PerformanceDiagnostics
extends RefCounted

const PATH := "user://performance-diagnostics.jsonl"
const DEFAULT_ENABLED := true
const MAX_BYTES := 128 * 1024
const INTERVAL := 5.0
var elapsed := 0.0
var scene := ""
var last_tick := 0
var frame_times := PackedFloat32Array()
var entry_sampled := false
var path := PATH

static func enabled(settings:ConfigFile)->bool:
	return settings.get_value("development","performance_diagnostics",DEFAULT_ENABLED)

func tick(app: Node, _delta: float) -> void:
	if not app.application_active or not enabled(app.settings):
		reset_window("")
		entry_sampled=false
		return
	var playing:bool=app.screen=="play" and is_instance_valid(app.world)
	var next_scene:String=app.screen
	if playing:
		next_scene="village_entry" if app.village_entry_active() else ("construction_menu" if app.build_side.visible else ("village_popup" if app.modal else "village"))
	if next_scene!=scene:
		reset_window(next_scene)
		entry_sampled=false
	if scene=="village_entry" and entry_sampled:return
	var now:=Time.get_ticks_usec()
	if last_tick>0:
		var ms:float=(now-last_tick)/1000.0
		frame_times.append(ms)
		elapsed+=ms/1000.0
	last_tick=now
	if elapsed<(1.5 if scene=="village_entry" else INTERVAL):return
	var working:=0
	if playing:
		for resident in app.world.residents:
			if resident.job_kind!="idle":working+=1
	var sample:Dictionary={
		"time":Time.get_datetime_string_from_system(true),
		"version":ProjectSettings.get_setting("application/config/version"),
		"platform":OS.get_name(),
		"device":OS.get_model_name() if OS.has_feature("android") else OS.get_processor_name(),
		"scene":scene,
		"sample_seconds":elapsed,
		"screen":app.screen,
		"popup":app.modal,
		"construction_menu":playing and app.build_side.visible,
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
	entry_sampled=scene=="village_entry"
	reset_window(scene)
	var engine_memory:=OS.get_static_memory_usage()
	if engine_memory>0:sample.engine_memory_bytes=engine_memory
	if app.village_alerts:sample.merge(app.village_alerts.diagnostic_sample())
	var line:=JSON.stringify(sample)
	var file:=FileAccess.open(path,FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path,FileAccess.WRITE)
	if file==null:return
	if file.get_length()+line.to_utf8_buffer().size()+1>MAX_BYTES:
		file.close()
		file=FileAccess.open(path,FileAccess.WRITE)
		if file==null:return
	file.seek_end()
	file.store_line(line)

func reset_window(next_scene:String)->void:
	scene=next_scene
	elapsed=0.0
	last_tick=0
	frame_times.clear()
