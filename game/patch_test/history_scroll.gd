extends DevelopmentSettingsScroll

const MAX_SPEED := 2600.0
const STOP_SPEED := 28.0
const DECAY := 5.5
const RELEASE_CUTOFF_MS := 110

var speed := 0.0
var last_drag := 0

func _input(event: InputEvent) -> void:
	var owns_touch := finger>=0
	var owner := finger
	var at := scroll_vertical
	if event is InputEventScreenTouch and event.pressed and is_visible_in_tree() and get_global_rect().has_point(event.position):
		speed = 0.0
		last_drag = 0
	super._input(event)
	if not is_visible_in_tree():
		speed = 0.0
	elif event is InputEventScreenDrag and owns_touch and event.index==owner and dragging:
		last_drag = Time.get_ticks_msec()
		speed = clampf(-event.velocity.y,-MAX_SPEED,MAX_SPEED) if scroll_vertical!=at else 0.0
	elif event is InputEventScreenTouch and not event.pressed and owns_touch and event.index==owner:
		if event.canceled or Time.get_ticks_msec()-last_drag>RELEASE_CUTOFF_MS:
			speed = 0.0
	elif event is InputEventMouseButton and event.pressed and get_global_rect().has_point(event.position):
		speed = 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree() or finger>=0 or absf(speed)<STOP_SPEED: return
	var bar := get_v_scroll_bar()
	var before := bar.value
	bar.value = before+speed*delta
	speed *= exp(-DECAY*delta)
	if bar.value<=bar.min_value or bar.value>=bar.max_value-bar.page: speed = 0.0
