class_name DemoJoystick
extends Control

var finger := -1
var value := Vector2.ZERO
var knob := Vector2.ZERO
var center := Vector2(70,70)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(140,140)

func clear() -> void:
	finger = -1
	value = Vector2.ZERO
	knob = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			update_value(event.position)
		elif not event.pressed and finger == event.index:
			clear()
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		update_value(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			finger = -2
			update_value(event.position)
		else:
			clear()
		accept_event()
	elif event is InputEventMouseMotion and finger == -2:
		update_value(event.position)
		accept_event()

func update_value(pos: Vector2) -> void:
	knob = (pos-center).limit_length(48)
	value = knob/48.0
	if value.length() < 0.12:
		value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	draw_circle(center,64,Color("27251f80"))
	draw_arc(center,64,0,TAU,64,Color("ebd6a58c"),2,true)
	draw_circle(center+knob,27,Color("dbc69cb3"))
	draw_arc(center+knob,27,0,TAU,40,Color("fff4d6cc"),2,true)
