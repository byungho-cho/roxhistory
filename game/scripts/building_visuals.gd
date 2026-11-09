class_name BuildingVisuals
extends RefCounted
## One presentation transform for completed structures and placement previews.
## Does not change collision, saved positions, plot geometry or occupation.
const REFERENCE_WIDTH := 320.0
const FARM_WIDTH := 256.0
const FARM_PREVIOUS_WIDTH := 184.0
const TRAINING_HEIGHTS := [180.0, 202.5, 211.5, 229.5]
const SHRINE_HEIGHTS := [166.0, 184.0, 202.0, 222.0]
const HEARTH_HEIGHTS := [114.57, 139.37, 182.4, 184.3]
const OUTPOST_GROUND_SPANS := [800.0, 780.0, 790.0, 830.0]

static func asset_id(kind: String, level: int = 1) -> String:
	var category := "HUT" if kind in ["chief", "hut", "home"] else kind.to_upper()
	return "BLD-%s-L%d" % [category, clampi(level, 1, 4)]

static func texture(kind: String, level: int = 1) -> Texture2D:
	if kind=="chief":return load("res://assets/chief-retouch/l%d.png"%clampi(level,1,4))
	if kind=="farm":return load("res://assets/farm/v003/farm-empty-l%d.png"%clampi(level,1,4))
	if kind in ["stone_store","wood_store"]:return load("res://assets/buildings/storage-v001/%s-l%d.png"%[kind,clampi(level,1,4)])
	var id := asset_id(kind, level)
	if not AssetCatalog.entry(id).get("approved", false): return null
	return AssetCatalog.texture(id)

static func display_size(kind: String, level: int = 1, ground_width: float = 230.0) -> Vector2:
	var source := texture(kind, level)
	if source == null: return Vector2.ZERO
	if kind=="chief":
		# The approved Figma canvas already includes both increases.
		var frame:=Vector2(783.36,587.52)*(ground_width/680.0)
		var original:=source.get_size()
		return original*minf(frame.x/original.x,frame.y/original.y)
	if kind=="farm":
		var aspect:float=[320.0/420,340.0/440,380.0/480,420.0/520][clampi(level,1,4)-1]
		return Vector2(FARM_WIDTH,FARM_WIDTH*aspect)*ground_width/230.0
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
		"chief":
			center.y=ground_width*.10-dimensions.y*.5
		"training", "shrine":
			# All stages sit on the same ground contact line rather than drifting with height.
			center.y = ground_width * 0.12 - dimensions.y * 0.5
		"hearth":
			# A low firepit stays centered over its separate common square foundation.
			center.y = -ground_width * 0.03
		"outpost":
			center.y = -ground_width * 0.3 + 3.0
	if kind=="farm":
		# Keep the artwork ground anchor at its previous world position.
		var previous_height:=dimensions.y*FARM_PREVIOUS_WIDTH/FARM_WIDTH
		center.y+=previous_height*.7-dimensions.y*.4
	return Rect2(center - dimensions * 0.5, dimensions)

static func apply(sprite: Sprite2D, kind: String, level: int = 1, ground_width: float = 230.0) -> void:
	var source := texture(kind, level)
	if source == null: return
	var rect := display_rect(kind, level, ground_width)
	sprite.texture = source
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.scale = rect.size/source.get_size() if kind=="farm" else Vector2.ONE * rect.size.x / source.get_width()
	sprite.position = rect.get_center()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.set_meta("building_visual_kind", kind)
	sprite.set_meta("building_visual_level", clampi(level, 1, 4))
	sprite.set_meta("building_visual_alignment", "bottom" if kind in ["training", "shrine"] else "center")

static func has_own_ground(kind:String)->bool:
	return kind in ["farm","stone_store","wood_store","hearth","shrine"]
static var visible_regions:Dictionary={}
static func visible_rect(sprite:Sprite2D)->Rect2:
	var texture:=sprite.texture
	var id:=texture.get_instance_id()
	if not visible_regions.has(id):
		var image:=texture.get_image()
		var step:=maxi(1,mini(image.get_width(),image.get_height())/96)
		var first:=Vector2(image.get_size());var last:=Vector2.ZERO
		for y in range(0,image.get_height(),step):
			for x in range(0,image.get_width(),step):
				if image.get_pixel(x,y).a<.12:continue
				first=first.min(Vector2(x,y));last=last.max(Vector2(x+step,y+step))
		visible_regions[id]=Rect2(first,last-first) if last.x>first.x else sprite.get_rect()
	var rect:Rect2=visible_regions[id]
	return Rect2(rect.position+sprite.get_rect().position,rect.size)
