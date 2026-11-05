class_name EnvironmentProp
extends Node2D

var sprite: Sprite2D
var shadow_size := Vector2.ZERO
var ground_size := Vector2.ZERO
var kind := ""
var hut_style := 0
var depth_visual:Node2D
static var textures := {}
static var stone_material: ShaderMaterial
const HUTS := ["res://assets/environment/hut-round.png", "res://assets/environment/hut-oval.png", "res://assets/environment/hut-covered.png"]
# Measured alpha > 0.5 bounds; avoid decoding/scanning three PNGs on mobile startup.
const HUT_BOUNDS := [Rect2(63,50,901,589),Rect2(62,83,899,551),Rect2(15,72,997,546)]

func set_hut_style(value: int) -> void:
	hut_style = clampi(value,0,2)
	var width := sprite.texture.get_width()*sprite.scale.x
	sprite.texture = AssetCatalog.texture("BLD-HUT-L1")
	sprite.scale = Vector2.ONE*width/sprite.texture.get_width()
	sprite.position.y = -sprite.texture.get_height()*sprite.scale.y*0.30
	if depth_visual:sprite.position.y-=depth_visual.position.y
	queue_redraw()

func chimney_socket() -> Vector2:
	var dimensions := sprite.texture.get_size()*sprite.scale
	var sockets := [Vector2(0.0,0.86),Vector2(0.19,0.69),Vector2(0.0,0.86)]
	return Vector2(dimensions.x*sockets[hut_style].x,-dimensions.y*sockets[hut_style].y)
static func hut_footprint(width:float)->PackedVector2Array:
	# Ground ellipse under the eaves, not the roof silhouette above the walker.
	var points:=PackedVector2Array()
	for p in [Vector2(-.49,-.08),Vector2(-.40,-.23),Vector2(-.15,-.33),Vector2(.20,-.31),Vector2(.43,-.21),Vector2(.49,-.08),Vector2(.32,.015),Vector2(-.30,.015)]:points.append(p*width)
	return points

static func stone_surface() -> ShaderMaterial:
	if not stone_material:
		stone_material=ShaderMaterial.new();stone_material.shader=preload("res://shaders/stone_surface.gdshader")
	return stone_material
# Opaque-silhouette bounds (alpha > 0.5), excluding generator's faint padding.
# Atlas crops preserve original pixels; origin is the visible ground contact.
const REGIONS = {
	"tree":Rect2(15,52,1062,1380), "hut":Rect2(10,160,1235,900), "wood":Rect2(128,52,1635,728),
	"grass":Rect2(134,56,1046,1138), "rock":Rect2(90,151,1390,709),
	"props":Rect2(54,94,1435,845), "shrub":Rect2(57,216,1186,860)
}

static func asset(key: String) -> Texture2D:
	if not textures.has(key):
		var texture: Texture2D = load("res://assets/environment/%s.png" % SceneStyle.PROP_FILES.get(key,key))
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = REGIONS[key]
		textures[key] = atlas
	return textures[key]

func configure(key: String, width: float, footprint: Vector2, wind_phase: float = 0.0) -> void:
	kind = key
	ground_size = footprint
	shadow_size = Vector2(width*0.30, width*0.08)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.texture = asset(key)
	var ratio := width/sprite.texture.get_width()
	sprite.scale = Vector2(ratio,ratio)
	sprite.position.y = -sprite.texture.get_height()*ratio*0.5
	add_child(sprite)
	if key=="hut":
		var surface:=ShaderMaterial.new();surface.shader=preload("res://shaders/hut_surface.gdshader");sprite.material=surface
		# Sort at the centre of the ground footprint, not the lowest roof pixel.
		# The physical origin/footprint and all saved building positions stay fixed.
		y_sort_enabled=true;depth_visual=Node2D.new();depth_visual.name="DepthVisual";depth_visual.position.y=-width*.12;add_child(depth_visual)
		sprite.reparent(depth_visual,true)
	if key=="rock":sprite.material=stone_surface()
	if key in ["tree","grass","shrub"]:
		var material_instance := ShaderMaterial.new()
		material_instance.shader = preload("res://shaders/foliage.gdshader")
		material_instance.set_shader_parameter("phase",wind_phase)
		material_instance.set_shader_parameter("speed",0.7+fposmod(wind_phase,0.8))
		material_instance.set_shader_parameter("strength",4.0 if key == "tree" else 10.0)
		sprite.material = material_instance
	if footprint.x > 0:
		var body := StaticBody2D.new()
		body.name = "Footprint"
		body.position.y = 0 if key=="hut" else -footprint.y*0.5
		var collision := CollisionShape2D.new()
		if key=="hut":
			var shape:=ConvexPolygonShape2D.new();shape.points=hut_footprint(width);collision.shape=shape
		else:
			var shape:=RectangleShape2D.new();shape.size=footprint;collision.shape=shape
		body.add_child(collision)
		add_child(body)
	queue_redraw()

func set_effects_enabled(enabled: bool) -> void:
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("animated",enabled)

func _draw() -> void:
	if kind == "grass": return
	if kind=="hut":
		var width:=sprite.texture.get_width()*sprite.scale.x
		# Irregular worn soil beneath the entrance, never a new navigation obstacle.
		var door:=Vector2(width*.20,-6)
		draw_set_transform(door+Vector2(8,9),-.12,Vector2(1,.28))
		for ring in 8:draw_circle(Vector2.ZERO,width*(.15-ring*.008),Color(.50,.36,.20,.018))
		draw_set_transform(Vector2(width*.03,-width*.055),0,Vector2(1,.23))
		for ring in 10:draw_circle(Vector2.ZERO,width*(.45-ring*.016),Color(.20,.15,.08,.018))
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(SceneStyle.CONTACT_OFFSET+Vector2(0,-6),0,Vector2(1,0.22))
	# Feather the contact instead of a hard opaque oval below the threshold.
	for ring in 6:
		draw_circle(Vector2.ZERO,shadow_size.x*(1.0-ring*.09),Color(SceneStyle.SHADOW,.024))
	draw_set_transform(Vector2.ZERO)
