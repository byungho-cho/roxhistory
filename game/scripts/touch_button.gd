class_name DemoButton
extends Button

var finger := -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not disabled and finger == -1:
			finger = event.index
			set_pressed_no_signal(true)
		elif not event.pressed and event.index == finger:
			finger = -1
			set_pressed_no_signal(false)
			if not disabled and Rect2(Vector2.ZERO,size).has_point(event.position):
				pressed.emit()
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		accept_event()

func clear() -> void:
	finger = -1
	set_pressed_no_signal(false)
