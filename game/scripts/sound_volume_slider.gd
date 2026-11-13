extends HSlider

var finger := -1
var initial_value := 0.0

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():return
	if finger == -1:
		if event is InputEventScreenTouch and event.pressed and editable:
			var local := make_input_local(event) as InputEventScreenTouch
			if not Rect2(Vector2.ZERO, size).has_point(local.position):return
			var scroll := find_parent("SoundSettingsScroll") as ScrollContainer
			if scroll and not scroll.get_global_rect().has_point(event.position):return
			finger = event.index
			initial_value = value
			drag_started.emit()
			update_touch(local.position.x)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and event.index == finger:
		update_touch(make_input_local(event).position.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == finger and not event.pressed:
		if not event.canceled:update_touch(make_input_local(event).position.x)
		finger = -1
		drag_ended.emit(value != initial_value)
		get_viewport().set_input_as_handled()

func update_touch(x: float) -> void:
	var inset := get_theme_icon("grabber").get_width() * .5
	ratio = clampf((x - inset) / maxf(size.x - inset * 2, 1.0), 0, 1)
