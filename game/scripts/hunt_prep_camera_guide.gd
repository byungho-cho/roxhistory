extends CanvasLayer

class SphereGuide:
	extends Control
	signal orbit_drag(pitch_delta: float, yaw_delta: float)
	var cam_direction := Vector3(.1,.62,.78)
	var center_mark := false
	var drag_carry := Vector2.ZERO
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			drag_carry += Vector2(-event.relative.y, event.relative.x) * .34
			var whole := Vector2(float(int(drag_carry.x)),float(int(drag_carry.y)))
			if not whole.is_zero_approx():
				drag_carry -= whole
				orbit_drag.emit(whole.x,whole.y)
			accept_event()
	func project(v: Vector3) -> Vector2:
		return Vector2(v.x * .87 - v.z * .50, -v.y * .92 + v.x * .20 + v.z * .34)
	func at(v: Vector3) -> Vector2:
		return size * .5 + project(v) * 40.0
	func _draw() -> void:
		if center_mark:
			var c := size * .5
			var col := Color(1.0,.91,.56,.94)
			draw_arc(c, 8.0, 0.0, TAU, 32, Color(.07,.07,.05,.7), 3.5, true)
			draw_arc(c, 8.0, 0.0, TAU, 32, col, 1.4, true)
			draw_line(c-Vector2(15,0),c+Vector2(15,0),col,1.2,true)
			draw_line(c-Vector2(0,15),c+Vector2(0,15),col,1.2,true)
			draw_string(ThemeDB.fallback_font,c+Vector2(13,-11),"전장 중앙 · 회전 기준",HORIZONTAL_ALIGNMENT_LEFT,-1,12,col)
			return
		var c := size * .5
		var ring := Color(.48,.70,.78,.38)
		draw_circle(c,40.0,Color(.13,.21,.24,.85))
		draw_arc(c,40.0,0.0,TAU,64,Color(.48,.70,.78,.66),1.0,true)
		for degree in [-40,0,40]:
			var angle := deg_to_rad(float(degree))
			for direction in [0,1]:
				var line := PackedVector2Array()
				for i in range(65):
					var t := TAU * float(i) / 64.0
					var v := Vector3(cos(t)*cos(angle), sin(angle), sin(t)*cos(angle))
					if direction == 1: v = Vector3(v.y,v.x,v.z)
					line.append(at(v))
				draw_polyline(line,ring,1.0,true)
		axis(Vector3.RIGHT,"X",Color("#ff8981"))
		axis(Vector3.UP,"Y",Color("#95e4a0"))
		axis(Vector3.BACK,"Z",Color("#87bdff"))
		var endpoint := at(cam_direction * 1.15)
		draw_dashed_line(c,endpoint,Color("#ffde8d"),1.5,3.0,true)
		draw_circle(endpoint,4.6,Color("#ffde8d"))
		draw_circle(c,2.7,Color.WHITE)
		draw_string(ThemeDB.fallback_font,endpoint+Vector2(7,-3),"CAM",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#ffde8d"))
	func axis(dir: Vector3, letter: String, color: Color) -> void:
		var end := at(dir * 1.22)
		draw_line(at(-dir * .86),at(Vector3.ZERO),Color(color,.27),1.0,true)
		draw_line(at(Vector3.ZERO),end,color,1.35,true)
		draw_string(ThemeDB.fallback_font,end+Vector2(2,-2),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)

var field: Node
var ui: Control
var panel: PanelContainer
var globe: SphereGuide
var cross: SphereGuide
var pitch: HSlider
var yaw: HSlider
var readout: Label
var default_font: Font
const SETTINGS_PATH := "user://hunt-prep-camera-pc.cfg"
const DEFAULT_PITCH := 36.0
const DEFAULT_YAW := 23.0
var save_timer: Timer
var initialized := false

func setup(hunt: Node) -> void:
	field = hunt
	layer = 90
	default_font = load("res://assets/fonts/NotoSansKR.ttf")
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross = SphereGuide.new()
	cross.center_mark = true
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.resized.connect(cross.queue_redraw)
	panel = PanelContainer.new()
	ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -209
	panel.offset_right = -17
	panel.offset_top = 174
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.043,.075,.089,.94)
	style.border_color = Color(.43,.59,.60,.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel",style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	label(col,"카메라 가이드  /  F7",13)
	globe = SphereGuide.new()
	globe.custom_minimum_size.y = 99.0
	globe.mouse_default_cursor_shape = Control.CURSOR_MOVE
	globe.orbit_drag.connect(_drag)
	col.add_child(globe)
	label(col,"지구본을 드래그하거나 아래 값을 조절",10)
	readout = label(col,"",12)
	label(col,"상하  ·  0° 수평 / 90° 탑뷰",10)
	pitch = slider(col, 15.0, 70.0, 38.0)
	label(col,"좌우  ·  음수 왼쪽 / 양수 오른쪽",10)
	yaw = slider(col, -45.0, 45.0, 8.0)
	var buttons := HBoxContainer.new()
	col.add_child(buttons)
	button(buttons,"기본값",Vector2(DEFAULT_PITCH,DEFAULT_YAW))
	close_button(buttons)
	label(col,"전장 중앙 고정  ·  PC 줌 0.80×",10)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	set_pose(float(config.get_value("camera","pitch",DEFAULT_PITCH)),float(config.get_value("camera","yaw",DEFAULT_YAW)))
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = .28
	save_timer.timeout.connect(save_camera)
	add_child(save_timer)
	initialized = true
	ui.hide()

func label(parent: Node, txt: String, size_px: int) -> Label:
	var l := Label.new()
	l.text = txt
	if default_font != null: l.add_theme_font_override("font",default_font)
	l.add_theme_font_size_override("font_size",size_px)
	parent.add_child(l)
	return l

func slider(parent: Node, lower: float, upper: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lower
	s.max_value = upper
	s.step = 1.0
	s.value = value
	s.custom_minimum_size.y = 16.0
	s.value_changed.connect(_value_changed)
	parent.add_child(s)
	return s

func button(parent: Node, txt: String, pair: Vector2) -> void:
	var b := Button.new()
	b.text = txt
	if default_font != null: b.add_theme_font_override("font",default_font)
	b.add_theme_font_size_override("font_size",11)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: set_pose(pair.x,pair.y))
	parent.add_child(b)

func close_button(parent: Node) -> void:
	var b := Button.new()
	b.text = "닫기"
	if default_font != null: b.add_theme_font_override("font",default_font)
	b.add_theme_font_size_override("font_size",11)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(toggle_guide)
	parent.add_child(b)

func toggle_guide() -> void:
	ui.visible = not ui.visible
	if not ui.visible: flush_save()

func pointer_over(at: Vector2) -> bool:
	return ui.visible and panel.get_global_rect().has_point(at)

func flush_save() -> void:
	if initialized and is_instance_valid(save_timer) and not save_timer.is_stopped():
		save_timer.stop()
		save_camera()

func save_camera() -> void:
	var config := ConfigFile.new()
	config.set_value("camera","pitch",pitch.value)
	config.set_value("camera","yaw",yaw.value)
	var result := config.save(SETTINGS_PATH)
	if result != OK: push_warning("Could not save PC camera preferences: %s" % result)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: flush_save()

func _value_changed(_n: float) -> void:
	if pitch != null and yaw != null:
		set_pose(pitch.value,yaw.value)
func _drag(p: float, y: float) -> void:
	set_pose(pitch.value+p,yaw.value+y)
func _input(event: InputEvent) -> void:
	if ui != null and is_instance_valid(field) and field.arrival_finished and not field.app.modal and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		toggle_guide()
		get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
	if not is_instance_valid(field) or field.prep_camera_transforms.is_empty():
		queue_free()

func set_pose(p: float, y: float) -> void:
	pitch.set_value_no_signal(roundf(clampf(p,15,70)))
	yaw.set_value_no_signal(roundf(clampf(y,-45,45)))
	globe.cam_direction = field.set_prep_center_orbit(pitch.value,yaw.value)
	globe.queue_redraw()
	readout.text = "상하 %.0f°    좌우 %+.0f°" % [pitch.value,yaw.value]
	if initialized: save_timer.start()