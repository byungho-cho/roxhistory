class_name DemoButton
extends Button

signal unavailable(reason: String)
var hint_text := "지금은 사용할 수 없어요"
var finger := -1
var working:=false
var art_feedback:Control

func _get_tooltip(_at_position: Vector2) -> String:
	return ""


func enable_art_feedback() -> void:
	if art_feedback:return
	art_feedback=Control.new();art_feedback.name="PressVisuals";art_feedback.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var visuals:=get_children();add_child(art_feedback)
	for child in visuals:child.reparent(art_feedback)


func set_working(value: bool) -> void:
	if working==value: return
	working=value
	if has_node("FigmaSkin") or get_meta("permanent_action",false):return
	if value:
		set_meta("resting_disabled_style",get_theme_stylebox("disabled"))
		var style:=DemoArt.button_style(true)
		style.bg_color=Color("70592f")
		add_theme_stylebox_override("disabled",style)
	elif has_meta("resting_disabled_style"): add_theme_stylebox_override("disabled",get_meta("resting_disabled_style"))

func _process(delta: float) -> void:
	var down:=is_pressed() or (finger>=0 and not disabled)
	if art_feedback:
		pivot_offset=Vector2.ZERO;scale=Vector2.ONE
		art_feedback.pivot_offset=size*.5
		art_feedback.scale=art_feedback.scale.lerp(Vector2.ONE*(.945 if down else 1.0),1-exp(-delta*28))
		art_feedback.position.y=lerpf(art_feedback.position.y,3 if down else 0,1-exp(-delta*28))
		art_feedback.modulate=Color.WHITE if get_meta("integrated_art",false) else (Color(.72,.70,.66,.86) if disabled else (Color(.91,.86,.75) if down else Color.WHITE))
		return
	pivot_offset=size*0.5
	scale=scale.lerp(Vector2.ONE*(0.965 if down else 1.0),1-exp(-delta*28))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			set_pressed_no_signal(not disabled)
		elif not event.pressed and event.index == finger:
			finger = -1
			set_pressed_no_signal(false)
			if Rect2(Vector2.ZERO,size).has_point(event.position):
				if disabled: unavailable.emit(hint_text)
				else: pressed.emit()
		accept_event()
	elif event is InputEventMouseButton and disabled and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		unavailable.emit(hint_text);accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		accept_event()

func clear() -> void:
	finger = -1
	set_pressed_no_signal(false)
	if art_feedback:art_feedback.scale=Vector2.ONE;art_feedback.position=Vector2.ZERO
