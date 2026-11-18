extends HSlider

enum Axis { UNDECIDED, HORIZONTAL, VERTICAL }
const DRAG_THRESHOLD := 8.0
var finger := -1
var initial_value := 0.0
var origin := Vector2.ZERO
var origin_scroll := 0
var axis := Axis.UNDECIDED
var list: ScrollContainer

func _ready() -> void:
	list = find_parent("SoundSettingsScroll") as ScrollContainer
	visibility_changed.connect(func():
		if not is_visible_in_tree() and finger>=0: finish_touch(true))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if finger == -1:
		if event is InputEventScreenTouch and event.pressed and editable:
			var local := make_input_local(event) as InputEventScreenTouch
			if not Rect2(Vector2.ZERO, size).has_point(local.position):return
			if list and not list.get_global_rect().has_point(event.position):return
			finger = event.index
			initial_value = value
			origin = event.position
			origin_scroll = list.scroll_vertical if list else 0
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and event.index == finger:
		var offset: Vector2 = event.position-origin
		if axis==Axis.UNDECIDED and maxf(absf(offset.x),absf(offset.y))>=DRAG_THRESHOLD:
			axis = Axis.VERTICAL if absf(offset.y)>absf(offset.x) else Axis.HORIZONTAL
			if axis==Axis.HORIZONTAL: drag_started.emit()
		if axis==Axis.HORIZONTAL:
			update_touch(make_input_local(event).position.x)
		elif axis==Axis.VERTICAL and list:
			var inverse := list.get_global_transform_with_canvas().affine_inverse()
			var local_delta := (inverse*(origin+offset))-(inverse*origin)
			list.scroll_vertical = origin_scroll-roundi(local_delta.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == finger and not event.pressed:
		if not event.canceled and axis!=Axis.VERTICAL:
			if axis==Axis.UNDECIDED:
				axis=Axis.HORIZONTAL
				drag_started.emit()
			update_touch(make_input_local(event).position.x)
		finish_touch(event.canceled)
		get_viewport().set_input_as_handled()

func finish_touch(canceled: bool) -> void:
	if axis==Axis.HORIZONTAL:
		if canceled: value=initial_value
		drag_ended.emit(not canceled and value!=initial_value)
	finger=-1
	axis=Axis.UNDECIDED

func update_touch(x: float) -> void:
	var inset := get_theme_icon("grabber").get_width() * .5
	ratio = clampf((x - inset) / maxf(size.x - inset * 2, 1.0), 0, 1)
