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
	"v3-01": preload("res://assets/village-outer-d0035/tree-02-wind-pine.png"),
	"v3-02": preload("res://assets/village-outer-d0035/rock-03-twin-tors.png"),
	"v3-03": preload("res://assets/village-outer-d0035/tree-02-wind-pine.png"),
	"v3-04": preload("res://assets/village-outer-d0037/rock-01-granite-spire.png"),
	"v3-05": preload("res://assets/village-outer-d0037/tree-03-forked-zelkova.png"),
	"v3-06": preload("res://assets/village-outer-d0035/tree-02-wind-pine.png"),
	"v3-07": preload("res://assets/village-outer-d0037/rock-02-rounded-granite.png"),
	"v3-08": preload("res://assets/village-outer-d0035/tree-02-wind-pine.png"),
	"v3-09": preload("res://assets/village-outer-d0037/tree-01-long-trunk.png"),
}

var world_bounds: Rect2
var regions: Array
var props: Array

func _init() -> void:
	name = "Terrain"
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/d0033-village-outer.json"))
	world_bounds = rect_from(spec.ground.world_rect)
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
	var footprints: Dictionary = {}
	for asset in DECORATIONS:
		footprints[asset] = Rect2(DECORATIONS[asset].get_image().get_used_rect())
	var replacement_areas: Dictionary = {}
	for placement in props:
		var rect := rect_from(placement.rect_world)
		var old_scale := rect.size / (DECORATIONS[placement.asset] as Texture2D).get_size()
		var old_area: Rect2 = footprints[placement.asset]
		var contact := rect.position + Vector2(old_area.get_center().x,old_area.end.y)*old_scale
		var old_size := old_area.size*old_scale
		var replacement: Texture2D = REPLACEMENTS[placement.id]
		if not replacement_areas.has(replacement):
			replacement_areas[replacement] = Rect2(replacement.get_image().get_used_rect())
		var area: Rect2 = replacement_areas[replacement]
		var factor := minf(old_size.x/area.size.x,old_size.y/area.size.y)
		var anchor := Vector2(area.get_center().x,area.end.y)
		var decoration := Sprite2D.new()
		decoration.name = "FogProp"+String(placement.id).replace("-","_")
		decoration.texture = replacement
		decoration.scale = Vector2.ONE*factor
		decoration.position = contact+(replacement.get_size()*.5-anchor)*factor
		decoration.visibility_layer = 2
		var mist := ShaderMaterial.new()
		mist.shader = MIST
		mist.set_shader_parameter("height_span",Vector2(area.position.y,area.end.y)/replacement.get_height())
		mist.set_shader_parameter("crown_opacity",0.83)
		decoration.material = mist
		layer.add_child(decoration)
		fog_sprites.append(decoration)
	add_edge_decorations(layer,replacement_areas)

const EDGE_ART := {
	"pine": preload("res://assets/village-outer-d0035/tree-02-wind-pine.png"),
	"tors": preload("res://assets/village-outer-d0035/rock-03-twin-tors.png"),
	"zelkova": preload("res://assets/village-outer-d0037/tree-03-forked-zelkova.png"),
}
const EDGE_PROPS := [
	["EdgePine",2,Vector2(-155,770),125,"pine"],
	["EdgeRock",2,Vector2(2510,920),95,"tors"],
	["EdgeZelkova",2,Vector2(1520,-115),120,"zelkova"],
	["EastPine",2,Vector2(2555,680),160,"pine"],
	["EastStone",2,Vector2(2575,1120),94,"tors"],
	["SouthPine",2,Vector2(1650,1470),125,"pine"],
	["WestZelkova",3,Vector2(-360,1030),138,"zelkova"],
	["EastTors",3,Vector2(2770,985),110,"tors"],
	["EastZelkova",4,Vector2(2985,685),155,"zelkova"],
	["SouthStone",4,Vector2(1860,1660),100,"tors"],
]
var edge_sprites: Array[Sprite2D] = []
var fog_sprites: Array[Sprite2D] = []

func add_edge_decorations(layer: Node2D, areas: Dictionary) -> void:
	for entry in EDGE_PROPS:
		var texture: Texture2D = EDGE_ART[entry[4]]
		if not areas.has(texture):
			areas[texture] = Rect2(texture.get_image().get_used_rect())
		var area: Rect2 = areas[texture]
		var scale_factor := float(entry[3])/area.size.x
		var anchor := Vector2(area.get_center().x,area.end.y)
		var sprite := Sprite2D.new()
		sprite.name = entry[0]
		sprite.texture = texture
		sprite.scale = Vector2.ONE*scale_factor
		sprite.position = entry[2]+(texture.get_size()*.5-anchor)*scale_factor
		sprite.visibility_layer = 2
		var mist := ShaderMaterial.new()
		mist.shader = MIST
		mist.set_shader_parameter("height_span",Vector2(area.position.y,area.end.y)/texture.get_height())
		mist.set_shader_parameter("crown_opacity",.56)
		sprite.material = mist
		layer.add_child(sprite)
		edge_sprites.append(sprite)
		fog_sprites.append(sprite)

func update_edge_decorations(level: int, visual_bounds: Rect2, from_level: int) -> void:
	var clip := Vector4(visual_bounds.position.x,visual_bounds.position.y,visual_bounds.end.x,visual_bounds.end.y)
	for sprite in fog_sprites:
		(sprite.material as ShaderMaterial).set_shader_parameter("open_boundary",clip)
	for i in edge_sprites.size():
		var entry: Array = EDGE_PROPS[i]
		var unlock := int(entry[1])
		var sprite := edge_sprites[i]
		if unlock > level:
			sprite.show()
			sprite.modulate.a = 1.0
		elif from_level >= 1 and unlock > from_level:
			var at: Vector2 = entry[2]
			var distance_inside := minf(minf(at.x-visual_bounds.position.x,visual_bounds.end.x-at.x),
				minf(at.y-visual_bounds.position.y,visual_bounds.end.y-at.y))
			sprite.modulate.a = 1.0-smoothstep(-35.0,30.0,distance_inside)
			sprite.visible = sprite.modulate.a > .001
		else:
			sprite.hide()

static func rect_from(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])
