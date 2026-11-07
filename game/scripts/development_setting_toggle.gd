class_name DevelopmentSettingToggle
extends CheckBox

# Mouse-to-touch emulation is disabled in this game. Keep native mouse/keyboard
# support and toggle once on a touch release, never after a scrolling gesture.
var finger:=-1
var touch_start:=Vector2.ZERO
var touch_cancelled:=false

func _gui_input(event:InputEvent)->void:
	if event is InputEventScreenTouch:
		if event.pressed and finger==-1:
			finger=event.index
			touch_start=event.position
			touch_cancelled=false
		elif not event.pressed and event.index==finger:
			finger=-1
			if not disabled and not touch_cancelled and Rect2(Vector2.ZERO,size).has_point(event.position):
				button_pressed=not button_pressed
			accept_event()
	elif event is InputEventScreenDrag and event.index==finger:
		if event.position.distance_to(touch_start)>12:touch_cancelled=true
		# Let ScrollContainer receive drags, including ones started on the checkbox.

func _notification(what:int)->void:
	if what==NOTIFICATION_SCROLL_BEGIN:
		touch_cancelled=true
	elif what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		finger=-1
