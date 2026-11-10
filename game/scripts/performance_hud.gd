extends PanelContainer

var value:Label
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=35
	var skin:=StyleBoxFlat.new()
	skin.bg_color=Color("17191b")
	skin.set_corner_radius_all(6)
	skin.set_content_margin_all(8)
	add_theme_stylebox_override("panel",skin)
	value=Label.new()
	value.mouse_filter=Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_size_override("font_size",12)
	value.add_theme_color_override("font_color",Color("fff3d2"))
	add_child(value)
	value.text="성능 측정 중…"

func update_sample(sample:Dictionary)->void:
	if sample.is_empty():return
	var cpu:="미지원"
	if sample.has("process_cpu_one_core_percent"):cpu="%.0f%% (1코어=100%%)"%sample.process_cpu_one_core_percent
	elif sample.has("process_cpu_total_ms"):cpu="측정 중"
	var memory:="미지원"
	if sample.has("process_pss_kib"):memory="%.1f MB PSS"%(sample.process_pss_kib/1024.0)
	elif sample.has("engine_memory_bytes"):memory="%.1f MB 엔진"%(sample.engine_memory_bytes/1048576.0)
	var battery:="미지원"
	if sample.has("battery_temperature_c"):battery="%.1f°C"%sample.battery_temperature_c
	var thermal:=str(sample.get("thermal_status","미지원"))
	value.text="%s · %s\n%.1f FPS · p95 %.1f ms\nCPU %s\n메모리 %s\n배터리 %s · 발열 %s"%[
		sample.get("version",""),sample.get("trial","regular"),sample.measured_fps,sample.frame_p95_ms,cpu,memory,battery,thermal]
