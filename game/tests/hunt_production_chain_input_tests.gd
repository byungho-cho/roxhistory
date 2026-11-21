extends SceneTree

const Hud = preload("res://scripts/duel_skill_hud.gd")
const RallyBadge = preload("res://scripts/hunt_duel_bom_buff_badge.gd")
var taps: Array[String] = []
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func ck(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(why)


func click(screen_point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = screen_point
		event.global_position = screen_point
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func run() -> void:
	for dimensions:Vector2i in [Vector2i(370,465), Vector2i(725,396)]:
		root.size=dimensions
		var h := Hud.new()
		h.position = Vector2(float(dimensions.x)/2.-33.,float(dimensions.y)-125.)
		root.add_child(h)
		h.reset("saebom")
		h.requested.connect(func(action: String): taps.append(action))
		await process_frame
		h.sync(3.,33,33,true,false,.01,true)
		RallyBadge.sync(h,4.1)
		var portrait_area: Rect2 = h.portrait_button.get_global_rect()
		var upper: Rect2 = h.chain_button.get_global_rect()
		var overlap: Rect2 = portrait_area.intersection(h.badge.get_global_rect())
		ck(overlap.has_area() and not upper.intersects(portrait_area), "ordinary badge overlaps its portrait; chain above is a separate contiguous tap target")
		ck(h.portrait_button.disabled and not h.chain_button.disabled, "independent acceptance leaves upper 3SP viable")
		var before := taps.size()
		await click(portrait_area.get_center())
		ck(taps.size()==before,"pending combat still disables ordinary portrait")
		await click(upper.get_center())
		ck(taps.size()==before+1 and taps[-1]=="chain","actual upper click received during ordinary lock")
		h.sync(3.,33,33,true,true,.01,false)
		before=taps.size()
		await click(upper.get_center())
		ck(taps.size()==before,"chain stage can reject independently while normal still available")
		await click(overlap.get_center())
		ck(taps.size()==before+1 and taps[-1]=="skill","actual overlap click delivers exactly one normal portrait request")
		h.sync(3.,33,33,true,false,.01)
		ck(h.portrait_button.disabled and h.chain_button.disabled,"legacy callers retain original six-argument gating")
		h.queue_free()
		await process_frame
	print("Chain/portrait real input: ",checks," checks, ",failures," failures")
	quit(int(failures>0))
