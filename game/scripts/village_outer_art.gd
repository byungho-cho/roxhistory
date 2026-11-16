extends Node2D

const GROUND := preload("res://assets/village-outer-d0033/village-outer-ground.png")
const DECORATIONS := {
	"fog-oak-canopy": preload("res://assets/village-outer-d0033/fog-oak-canopy.png"),
	"fog-twin-canopies": preload("res://assets/village-outer-d0033/fog-twin-canopies.png"),
	"fog-granite-tip": preload("res://assets/village-outer-d0033/fog-granite-tip.png"),
	"fog-granite-cluster": preload("res://assets/village-outer-d0033/fog-granite-cluster.png"),
}
const MIST := preload("res://shaders/village_outer_prop.gdshader")
const REPLACEMENTS := {
	"v3-03": preload("res://assets/village-outer-d0035/tree-02-wind-pine.png"),
	"v3-02": preload("res://assets/village-outer-d0035/rock-03-twin-tors.png"),
}

var world_bounds: Rect2
var regions: Array
var props: Array
var original_bounds: Rect2

func _init() -> void:
	name = "Terrain"
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/d0033-village-outer.json"))
	world_bounds = rect_from(spec.ground.world_rect)
	original_bounds = rect_from(spec.ground.native_center.dst_world_rect)
	regions = spec.ground.registration.regions
	props = spec.props.layout

func _draw() -> void:
	for region in regions:
		# Neighboring cells sample the same source pixels at each shared edge.
		draw_texture_rect_region(GROUND, rect_from(region.dst_world_rect),
			rect_from(region.src_px_rect), Color.WHITE, false, false)

func add_decorations(world: Node2D) -> void:
	var layer := Node2D.new()
	layer.name = "OuterFogDecorations"
	layer.z_index = 15
	layer.visibility_layer = 2
	world.add_child(layer)
	var materials: Dictionary = {}
	var footprints: Dictionary = {}
	for asset in DECORATIONS:
		var texture: Texture2D = DECORATIONS[asset]
		var visible_area := texture.get_image().get_used_rect()
		footprints[asset] = Rect2(visible_area)
		var material := ShaderMaterial.new()
		material.shader = MIST
		material.set_shader_parameter("height_span",Vector2(visible_area.position.y,visible_area.end.y)/texture.get_height())
		material.set_shader_parameter("original_bounds",Vector4(original_bounds.position.x,original_bounds.position.y,original_bounds.end.x,original_bounds.end.y))
		materials[asset] = material
	for placement in props:
		var rect := rect_from(placement.rect_world)
		var decoration := Sprite2D.new()
		decoration.name = "FogProp"+String(placement.id).replace("-","_")
		decoration.texture = DECORATIONS[placement.asset]
		decoration.position = rect.get_center()
		decoration.scale = rect.size / decoration.texture.get_size()
		decoration.visibility_layer = 2
		decoration.material = materials[placement.asset]
		if REPLACEMENTS.has(placement.id):
			var old_area: Rect2 = footprints[placement.asset]
			var old_anchor := old_area.get_center()
			old_anchor.y = old_area.end.y
			var contact := rect.position + old_anchor * decoration.scale
			var old_size := old_area.size * decoration.scale
			var replacement: Texture2D = REPLACEMENTS[placement.id]
			var area := Rect2(replacement.get_image().get_used_rect())
			var factor := minf(old_size.x/area.size.x,old_size.y/area.size.y)
			var new_anchor := Vector2(area.get_center().x,area.end.y)
			decoration.texture = replacement
			decoration.scale = Vector2.ONE * factor
			decoration.position = contact + (replacement.get_size()*.5-new_anchor)*factor
			var mist := decoration.material.duplicate() as ShaderMaterial
			mist.set_shader_parameter("height_span",Vector2(area.position.y,area.end.y)/replacement.get_height())
			mist.set_shader_parameter("crown_opacity",0.83)
			decoration.material = mist
		layer.add_child(decoration)

static func rect_from(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])
