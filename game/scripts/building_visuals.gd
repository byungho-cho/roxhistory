class_name BuildingVisuals
extends RefCounted
## One presentation transform for completed structures and placement previews.
## Does not change collision, saved positions, plot geometry or occupation.
const REFERENCE_WIDTH := 320.0
const TRAINING_HEIGHTS := [180.0, 202.5, 211.5, 229.5]
const SHRINE_HEIGHTS := [166.0, 184.0, 202.0, 222.0]
const HEARTH_HEIGHTS := [114.57, 139.37, 182.4, 184.3]
const OUTPOST_GROUND_SPANS := [800.0, 780.0, 790.0, 830.0]

static func asset_id(kind: String, level: int = 1) -> String:
	var category := "HUT" if kind in ["chief", "hut", "home"] else kind.to_upper()
	return "BLD-%s-L%d" % [category, clampi(level, 1, 4)]

static func texture(kind: String, level: int = 1) -> Texture2D:
	if kind=="farm":return load("res://assets/farm/v002/farm-l%d.png"%clampi(level,1,4))
	var id := asset_id(kind, level)
	if not AssetCatalog.entry(id).get("approved", false): return null
	return AssetCatalog.texture(id)

static func display_size(kind: String, level: int = 1, ground_width: float = 230.0) -> Vector2:
	var source := texture(kind, level)
	if source == null: return Vector2.ZERO
	var stage := clampi(level, 1, 4) - 1
	var scale_factor: float
	match kind:
		"training":
			# Approved broad silhouette, progressive stages, and requested 10% display reduction.
			scale_factor = float(TRAINING_HEIGHTS[stage]) * ground_width / REFERENCE_WIDTH / source.get_height()
		"shrine":
			scale_factor = float(SHRINE_HEIGHTS[stage]) * ground_width / REFERENCE_WIDTH / source.get_height()
		"hearth":
			scale_factor = float(HEARTH_HEIGHTS[stage]) * ground_width / REFERENCE_WIDTH / source.get_height()
		"outpost":
			# Source ground spans retain the modest size growth across tower stages.
			scale_factor = 180.0 * ground_width / 230.0 / float(OUTPOST_GROUND_SPANS[stage])
		_:
			scale_factor = ground_width * 0.8 / source.get_width()
	return source.get_size() * scale_factor

static func display_rect(kind: String, level: int = 1, ground_width: float = 230.0) -> Rect2:
	var dimensions := display_size(kind, level, ground_width)
	var center := Vector2(0.0, -ground_width * 0.2 + 3.0)
	match kind:
		"training", "shrine":
			# All stages sit on the same ground contact line rather than drifting with height.
			center.y = ground_width * 0.12 - dimensions.y * 0.5
		"hearth":
			# A low firepit stays centered over its separate common square foundation.
			center.y = -ground_width * 0.03
		"outpost":
			center.y = -ground_width * 0.3 + 3.0
	return Rect2(center - dimensions * 0.5, dimensions)

static func apply(sprite: Sprite2D, kind: String, level: int = 1, ground_width: float = 230.0) -> void:
	var source := texture(kind, level)
	if source == null: return
	var rect := display_rect(kind, level, ground_width)
	sprite.texture = source
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.scale = Vector2.ONE * rect.size.x / source.get_width()
	sprite.position = rect.get_center()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.set_meta("building_visual_kind", kind)
	sprite.set_meta("building_visual_level", clampi(level, 1, 4))
	sprite.set_meta("building_visual_alignment", "bottom" if kind in ["training", "shrine"] else "center")
