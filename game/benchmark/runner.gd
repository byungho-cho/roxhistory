extends Node
## Identical seeded village, camera and phase schedule in a new process per mode.
const PHASES := ["idle", "working_village"]
var app: Node
var request: Dictionary
var output := ""
var phases: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var rows: Array[String] = ["phase,frame,elapsed_seconds,frame_ms,process_ms,physics_ms,draw_calls"]
var failure := ""
var real_frames := PackedFloat64Array()
var active := false
var observed_work := {}
var active_time := 0.0

func _notification(what: int) -> void:
	if active and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		failure = "Application paused or lost focus"

func _input(event: InputEvent) -> void:
	if active and OS.has_feature("android") and event is InputEventScreenTouch and event.pressed:
		failure = "Touch interrupted the benchmark"
		get_viewport().set_input_as_handled()

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	request = BenchmarkSession.request
	output = "user://benchmark/" + str(request.run_id)
	DirAccess.make_dir_recursive_absolute(output)
	if FileAccess.file_exists(output.path_join("result.json")):
		get_tree().quit(2)
		return
	active = true
	DisplayServer.screen_set_keep_on(true)
	Engine.max_fps = 60
	app.settings.set_value("development", "performance_diagnostics", true)
	app.settings.set_value("development", "performance_hud", false)
	app.performance_diagnostics.path = output.path_join("diagnostics.jsonl")
	if not prepare_workplaces():
		failure = "Could not prepare seeded farm and resource depots"
		finish("failed")
		return
	app.enter_game(false)
	app.finish_village_entry()
	app.close_modal()
	await get_tree().process_frame
	if not validate_visuals():
		finish("failed")
		return
	for phase in PHASES:
		if phase=="working_village" and not start_work():
			failure = "Could not assign seeded residents"
			break
		await run_phase(phase)
		if not failure.is_empty(): break
	if failure.is_empty() and phases.size()!=PHASES.size():
		failure = "A measurement phase did not finish"
	if failure.is_empty() and float(request.sample_seconds)>=90:
		for activity in ["farmer", "harvest", "carry"]:
			if not observed_work.has(activity):
				failure = "Required work was not observed: " + activity
	finish("complete" if failure.is_empty() else "failed")

func prepare_workplaces() -> bool:
	var state: Dictionary = app.model.state.duplicate(true)
	state.wood = 0
	state.stone = 0
	state.grain = 0
	state.facilities = [
		{"uid":"farm1","kind":"farm","level":4,"position":[1420,650],"cost":{"wood":10,"stone":5}},
		{"uid":"wood1","kind":"wood_store","level":4,"position":[780,570],"cost":{"wood":20,"stone":20}},
		{"uid":"stone1","kind":"stone_store","level":4,"position":[1100,450],"cost":{"wood":20,"stone":20}},
	]
	state.farm_cycles = {"farm:farm1":{"phase":"ready","elapsed":600.0,"cycle_level":4,"cuts":0,"stock":0}}
	app.model.prepare_resource_positions(state)
	return app.model.commit(state)

func start_work() -> bool:
	var jobs := ResidentJobs.new(app.model)
	var assignments := ["farmer","wood","wood","wood","stone","stone","stone"]
	for i in assignments.size():
		var job: String = assignments[i]
		var building: String = {"farmer":"farm:farm1","wood":"wood_store:wood1","stone":"stone_store:stone1"}[job]
		if not jobs.assign("resident-%d"%i,job,building):return false
	return true

func native_sample() -> Dictionary:
	var sample: Dictionary = app.village_alerts.diagnostic_sample() if app.village_alerts else {}
	for key in ["process_pss_kib","process_cpu_total_ms","battery_temperature_c","battery_plugged","thermal_status","system_brightness_setting","screen_interactive"]:
		if not sample.has(key):sample[key] = "unsupported"
	if sample.screen_interactive is bool and not sample.screen_interactive:
		failure = "Screen turned off"
	return sample

func validate_visuals() -> bool:
	var expected_mode := str(request.mode)
	if app.performance_trial != expected_mode:
		failure = "Effective trial differs from requested mode"
	if app.world.residents.size() != 12:
		failure = "Expected twelve residents, got %d" % app.world.residents.size()
	for resident in app.world.residents:
		var sprite_expected: bool = expected_mode == "T2" or (expected_mode == "T1" and resident.variant == "sturdy_male")
		if sprite_expected != is_instance_valid(resident.sprite_trial) or sprite_expected == is_instance_valid(resident.visual):
			failure = "Resident representation does not match " + expected_mode
		if is_instance_valid(resident.visual) and not is_equal_approx(resident.visual.render_size_factor, 0.375 if expected_mode=="T3" else 0.5):
			failure = "3D render size factor mismatch"
	return failure.is_empty()

func set_camera(phase: String, seconds: float) -> void:
	var player = app.world.player
	player.manual_camera = true
	player.zoom_factor = 0.8
	var center: Vector2 = DemoConfig.CHIEF_POSITION + Vector2(0, 150)
	if phase == "working_village":
		center += Vector2(sin(seconds * TAU / 12.0) * 180.0, cos(seconds * TAU / 12.0) * 90.0)
	player.camera_center = center
	player.camera.position = center - player.global_position
	player.camera.zoom = Vector2.ONE * 0.8
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()

func run_phase(phase: String) -> void:
	if is_instance_valid(app.build_side): app.build_side.hide()
	app.close_modal()
	var warm_start := Time.get_ticks_usec()
	while failure.is_empty() and (Time.get_ticks_usec() - warm_start) / 1000000.0 < float(request.warmup_seconds):
		set_camera(phase, (Time.get_ticks_usec() - warm_start) / 1000000.0)
		await get_tree().process_frame
	if not failure.is_empty() or not app.application_active:
		if failure.is_empty():failure = "Application lost focus during warmup"
		return
	var native_start: Dictionary = native_sample()
	var frame_times := PackedFloat64Array()
	var phase_start := Time.get_ticks_usec()
	var last := phase_start
	var next_sample := 0.0
	var next_work_sample := 0.0
	while true:
		var elapsed: float = (Time.get_ticks_usec() - phase_start) / 1000000.0
		if elapsed >= float(request.sample_seconds): break
		set_camera(phase, elapsed)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		frame_times.append(ms)
		real_frames.append(ms)
		if phase == "working_village" and elapsed >= next_work_sample:
			next_work_sample = elapsed + 0.25
			for resident in app.world.residents:
				if resident.job_kind=="farmer" and resident.job_phase in ["farm_wait","harvest"]:observed_work.farmer=true
				if resident.job_kind in ["wood","stone"] and resident.job_phase=="harvest":observed_work.harvest=true
				if not resident.jobs.entry(resident.resident_id).cargo.is_empty():observed_work.carry=true
		rows.append("%s,%d,%.6f,%.6f,%.6f,%.6f,%d" % [phase, frame_times.size(), (now-phase_start)/1000000.0, ms, Performance.get_monitor(Performance.TIME_PROCESS)*1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		if not failure.is_empty() or not app.application_active:
			if failure.is_empty():failure = "Application lost focus during " + phase
			return
		if elapsed >= next_sample:
			var sample: Dictionary = native_sample()
			sample.merge({"phase":phase,"elapsed_seconds":elapsed,"mode":request.mode,"run_id":request.run_id,"engine_memory_bytes":OS.get_static_memory_usage()})
			samples.append(sample)
			next_sample = elapsed + 5.0
	var duration := (Time.get_ticks_usec() - phase_start) / 1000000.0
	var native_end: Dictionary = native_sample()
	var summary := statistics(frame_times, duration)
	summary.merge({"phase":phase,"warmup_seconds":request.warmup_seconds,"native_start":native_start,"native_end":native_end})
	summary.process_cpu_one_core_percent = "unsupported"
	if native_start.process_cpu_total_ms is float and native_end.process_cpu_total_ms is float:
		summary.process_cpu_one_core_percent = (float(native_end.process_cpu_total_ms)-float(native_start.process_cpu_total_ms))/duration/10.0
	active_time += duration
	phases.append(summary)
	print("ROX_BENCHMARK_PHASE " + JSON.stringify(summary))

static func statistics(values: PackedFloat64Array, seconds: float) -> Dictionary:
	var result := {"frame_count":values.size(),"duration_seconds":seconds}
	if values.is_empty() or seconds <= 0: return result
	var ordered := values.duplicate()
	ordered.sort()
	result.measured_fps = values.size()/seconds
	result.frame_p50_ms = ordered[ceili(values.size()*0.5)-1]
	result.frame_p95_ms = ordered[ceili(values.size()*0.95)-1]
	result.frame_p99_ms = ordered[ceili(values.size()*0.99)-1]
	result.frame_max_ms = ordered[-1]
	var long_frames := 0
	for value in ordered:
		if value > 33.333:long_frames += 1
	result.long_frame_ratio_over_33_333_ms = float(long_frames)/ordered.size()
	return result

func finish(status: String) -> void:
	active = false
	var sample_text := ""
	for sample in samples: sample_text += JSON.stringify(sample) + "\n"
	write_file("samples.jsonl", sample_text)
	write_file("frames.csv", "\n".join(rows) + "\n")
	if not failure.is_empty():status="failed"
	var report := {
		"schema_version":1,"status":status,"error":failure,"run_id":request.run_id,"mode":request.mode,
		"source_baseline":BenchmarkSession.BASE_COMMIT,"scenario":"seed289-residents12-idle-work-camera080-v2",
		"request":request,"pid":OS.get_process_id(),"platform":OS.get_name(),"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_video_adapter_name(),"rendering_method":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"headless":DisplayServer.get_name()=="headless","viewport_px":[get_window().size.x,get_window().size.y],
		"fps_limit":Engine.max_fps,"physics_ticks_per_second":Engine.physics_ticks_per_second,
		"utc":Time.get_datetime_string_from_system(true),"phases":phases,
		"whole_run":statistics(real_frames,active_time) if status=="complete" else {},"observed_work":observed_work,
		"version":ProjectSettings.get_setting("application/config/version"),
		"resident_count":12,"zoom":0.8,"build_commit":BenchmarkSession.build_commit(),
		"scope":"Seeded live village with scripted camera. Simulation is live and headless results only validate flow."
	}
	write_file("result.json.part", JSON.stringify(report,"  "))
	if DirAccess.rename_absolute(output.path_join("result.json.part"),output.path_join("result.json")) != OK:
		push_error("ROX_BENCHMARK could not atomically finish result")
		get_tree().quit(2)
		return
	print("ROX_BENCHMARK_RESULT " + JSON.stringify(report))
	get_tree().quit(0 if status=="complete" else 1)

func write_file(name: String, contents: String) -> void:
	var file := FileAccess.open(output.path_join(name),FileAccess.WRITE)
	if file == null:
		failure = "Cannot write " + name
		return
	file.store_string(contents)
	file.close()