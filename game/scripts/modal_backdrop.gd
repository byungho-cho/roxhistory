class_name ModalBackdrop
extends ColorRect
var dismiss:Callable
var pointer:=-2
var origin:=Vector2.ZERO
func _gui_input(event:InputEvent)->void:
	var id:=-2
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:id=-1
	elif event is InputEventScreenTouch:id=event.index
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if pointer!=-2 and event.position.distance_to(origin)>12:pointer=-2
		return
	else:return
	accept_event()
	if event.pressed:
		pointer=id;origin=event.position
	elif pointer==id:
		pointer=-2
		if not (event is InputEventScreenTouch and event.canceled) and dismiss.is_valid():dismiss.call()
