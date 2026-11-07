class_name DevelopmentSettingsScroll
extends ScrollContainer
## Own touch scrolling even when the gesture starts on a row or a toggle.
var finger:=-1
var origin:=Vector2.ZERO
var origin_scroll:=0
var dragging:=false
func cancel_row_touches(node:Node)->void:
	if node is DevelopmentSettingToggle:
		node.touch_cancelled=true;node.finger=-1;node.set_pressed_no_signal(node.button_pressed)
	elif node is DemoButton:node.clear()
	for child in node.get_children():cancel_row_touches(child)
func _input(event:InputEvent)->void:
	if not is_visible_in_tree():finger=-1;dragging=false;return
	if event is InputEventScreenTouch:
		if event.pressed and finger==-1 and get_global_rect().has_point(event.position):
			finger=event.index;origin=event.position;origin_scroll=scroll_vertical;dragging=false
		elif not event.pressed and event.index==finger:
			finger=-1
			if dragging:
				cancel_row_touches(self);get_viewport().set_input_as_handled()
			dragging=false
	elif event is InputEventScreenDrag and event.index==finger:
		if not dragging and event.position.distance_to(origin)>12:
			dragging=true;cancel_row_touches(self)
		if dragging:
			scroll_vertical=origin_scroll+roundi(origin.y-event.position.y)
			get_viewport().set_input_as_handled()
