class_name PerformanceDiagnostics
extends RefCounted

const PATH := "user://performance-diagnostics.jsonl"
const MAX_BYTES := 128 * 1024
const INTERVAL := 5.0
var elapsed := 0.0

func tick(app: Node, delta: float) -> void:
	if not app.application_active or not app.settings.get_value("development","performance_diagnostics",true):
		elapsed=0
		return
	elapsed+=delta
	if elapsed<INTERVAL:return
	elapsed=0
	var playing:bool=app.screen=="play" and is_instance_valid(app.world)
	var working:=0
	if playing:
		for resident in app.world.residents:
			if resident.job_kind!="idle":working+=1
	var sample:Dictionary={
		"time":Time.get_datetime_string_from_system(true),
		"version":ProjectSettings.get_setting("application/config/version"),
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
	var engine_memory:=OS.get_static_memory_usage()
	if engine_memory>0:sample.engine_memory_bytes=engine_memory
	if app.village_alerts:sample.merge(app.village_alerts.diagnostic_sample())
	var line:=JSON.stringify(sample)
	var file:=FileAccess.open(PATH,FileAccess.READ_WRITE) if FileAccess.file_exists(PATH) else FileAccess.open(PATH,FileAccess.WRITE)
	if file==null:return
	if file.get_length()+line.to_utf8_buffer().size()+1>MAX_BYTES:
		file.close()
		file=FileAccess.open(PATH,FileAccess.WRITE)
		if file==null:return
	file.seek_end()
	file.store_line(line)
