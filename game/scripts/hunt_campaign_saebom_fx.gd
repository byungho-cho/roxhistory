extends RefCounted
## Drawing for the campaign short-hide rig. Contact and damage stay in the squad.

static func blade(layer: CanvasItem, palm: Vector2, direction: Vector2, size := 1.3) -> void:
	if not palm.is_finite() or direction.is_zero_approx():
		return
	var along := direction.normalized() * size
	var side := along.orthogonal()
	var handle := palm - along * 5.0
	var base := palm + along * 4.0
	var middle := palm + along * 10.0
	var tip := palm + along * 20.0
	var edge := PackedVector2Array([base + side * 3.0, middle + side * 3.5, tip, middle - side * 2.6, base - side * 3.0, base + side * 3.0])
	layer.draw_polyline(edge, Color(1.0, .85, .57, .16), 10.0, true)
	layer.draw_polyline(edge, Color(1.0, .93, .76, .44), 4.0, true)
	layer.draw_colored_polygon(PackedVector2Array([handle + side * 2.0, base + side * 2.7, base - side * 2.7, handle - side * 2.0]), Color("#503724"))
	layer.draw_colored_polygon(edge.slice(0, -1), Color("#4e5b67"))
	layer.draw_colored_polygon(PackedVector2Array([base, middle + side * 2.5, tip, middle - side * .7]), Color("#e2d8ba"))
	layer.draw_line(base.lerp(middle, .22) + side * .45, tip, Color(1.0, .98, .83, .85), 1.35, true)
	layer.draw_line(middle + side * 2.5, tip, Color(1.0, .99, .93, .76), .75, true)

static func projectile_progress(progress: float, accelerated: bool) -> float:
	return .30 * progress + .70 * pow(progress, 1.85) if accelerated else progress

static func flight(layer: CanvasItem, start: Vector2, finish: Vector2, progress: float, accelerated: bool, strong: bool, fade := 1.0) -> void:
	var axis := start.direction_to(finish)
	if axis.is_zero_approx():
		return
	var back := maxf(0.0, progress - (.58 if strong else .51))
	var span := progress - back
	if span < .009:
		return
	for i in 19:
		var j := float(i) / 19.0
		var k := float(i + 1) / 19.0
		var a := start.lerp(finish, projectile_progress(lerpf(back, progress, j), accelerated))
		var b := start.lerp(finish, projectile_progress(lerpf(back, progress, k), accelerated))
		var opacity := fade * (.60 if strong else .47) * pow((j + k) * .5, 1.3)
		var width := lerpf(.38, 5.8 if strong else 4.2, (j + k) * .5)
		layer.draw_line(a, b, Color(1.0, .73, .34, opacity * .26), width * 2.6, true)
		layer.draw_line(a, b, Color(1.0, .86, .60, opacity * .68), width, true)
		layer.draw_line(a, b, Color(1.0, .98, .84, opacity), width * .32, true)

static func rising_slash(layer: CanvasItem, palm: Vector2, forward: Vector2, age: float) -> void:
	if age < 0.0 or age >= .195:
		return
	var progress := age / .195
	var axis := Vector2(forward.x, absf(forward.y)).normalized()
	var rise := axis.rotated(-signf(axis.x) * deg_to_rad(55.0))
	var start := palm - rise * 24.0 - axis * 5.0
	var bend := palm + axis * (16.0 + 3.0 * progress)
	var tip := palm + rise * (30.0 + 5.0 * progress)
	var fade := pow(1.0 - progress, 1.2)
	var last := start
	for i in range(1, 17):
		var t := float(i) / 16.0
		var point := start.lerp(bend, t).lerp(bend.lerp(tip, t), t)
		var edge := pow(sin(PI * (float(i) - .5) / 16.0), .57)
		layer.draw_line(last, point, Color(.62, .30, .045, .61 * fade * edge), .8 + 6.0 * edge, true)
		layer.draw_line(last, point, Color(1.0, .65, .14, .97 * fade * edge), .7 + 3.9 * edge, true)
		layer.draw_line(last, point, Color(1.0, .94, .66, .98 * fade * edge), .5 + 1.9 * edge, true)
		last = point
