class_name DemoButton
extends Button

signal unavailable(reason: String)
var hint_text := "지금은 사용할 수 없어요"
var finger := -1
var working:=false

func set_working(value: bool) -> void:
	if working==value: return
	working=value
	if value:
		var style:=DemoArt.button_style(true)
		style.bg_color=Color("70592f")
		add_theme_stylebox_override("disabled",style)
	else: remove_theme_stylebox_override("disabled")

func _process(delta: float) -> void:
	pivot_offset=size*0.5
	scale=scale.lerp(Vector2.ONE*(0.965 if is_pressed() else 1.0),1-exp(-delta*28))

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
