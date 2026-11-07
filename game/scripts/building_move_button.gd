class_name BuildingMoveButton
extends DemoButton
signal drag_started
signal drag_moved(at:Vector2)
var holding:=false
var dragging:=false
var hold_age:=0.0
var pointer_id:=-2
var suppressed_until:=0
func _gui_input(event:InputEvent)->void:
	if disabled:super._gui_input(event);return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:holding=true;hold_age=0;pointer_id=-1
		elif not dragging:holding=false
	elif event is InputEventScreenTouch:
		if event.pressed:holding=true;hold_age=0;pointer_id=event.index
		elif not dragging:holding=false
	super._gui_input(event)
func _process(delta:float)->void:
	super._process(delta)
	if holding and not dragging:
		hold_age+=delta
		if hold_age>=.5:
			dragging=true;suppressed_until=Time.get_ticks_msec()+1000;drag_started.emit()
func _input(event:InputEvent)->void:
	if not dragging:return
	var released:=false
	if event is InputEventMouseMotion and pointer_id==-1:drag_moved.emit(event.position)
	elif event is InputEventScreenDrag and event.index==pointer_id:drag_moved.emit(event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and pointer_id==-1:released=true
	elif event is InputEventScreenTouch and not event.pressed and event.index==pointer_id:released=true
	else:return
	if released:
		drag_moved.emit(event.position);dragging=false;holding=false;suppressed_until=Time.get_ticks_msec()+150;super.clear()
	get_viewport().set_input_as_handled()
func suppress_click()->bool:return dragging or Time.get_ticks_msec()<suppressed_until
func clear()->void:
	holding=false;dragging=false;pointer_id=-2;super.clear()
