class_name ViewportLayout
extends RefCounted

static func content_rect(viewport_size: Vector2) -> Rect2:
	if not OS.has_feature("android"):
		return Rect2(Vector2.ZERO, viewport_size)
	return android_content_rect(viewport_size, DisplayServer.screen_get_size(), DisplayServer.get_display_safe_area())

static func android_content_rect(viewport_size: Vector2, display_size: Vector2, safe_area: Rect2i) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	# A side camera in landscape must not inset the entire screen.
	if viewport_size.x >= viewport_size.y or display_size.x <= 0.0 or display_size.y <= 0.0 or not safe_area.has_area():
		return full
	var ratio := viewport_size / display_size
	var bounds := Rect2(Vector2(safe_area.position) * ratio, Vector2(safe_area.size) * ratio).intersection(full)
	return bounds if bounds.has_area() else full
