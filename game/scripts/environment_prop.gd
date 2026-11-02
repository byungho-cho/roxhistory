class_name EnvironmentProp
extends Node2D

var sprite: Sprite2D
var shadow_size := Vector2.ZERO
var ground_size := Vector2.ZERO
var kind := ""
var hut_style := 0
static var textures := {}
static var stone_material: ShaderMaterial
const HUTS := ["res://assets/environment/hut-round.png", "res://assets/environment/hut-oval.png", "res://assets/environment/hut-covered.png"]
# Measured alpha > 0.5 bounds; avoid decoding/scanning three PNGs on mobile startup.
const HUT_BOUNDS := [Rect2(63,50,901,589),Rect2(62,83,899,551),Rect2(15,72,997,546)]

func set_hut_style(value: int) -> void:
	hut_style = clampi(value,0,2)
	var width := sprite.texture.get_width()*sprite.scale.x
	var key := "hut_style_"+str(hut_style)
	if not textures.has(key):
		var texture: Texture2D = load(HUTS[hut_style])
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = HUT_BOUNDS[hut_style]
		textures[key] = atlas
	sprite.texture = textures[key]
	sprite.scale = Vector2.ONE*width/sprite.texture.get_width()
	sprite.position.y = -sprite.texture.get_height()*sprite.scale.y*0.5

func chimney_socket() -> Vector2:
	var dimensions := sprite.texture.get_size()*sprite.scale
	var sockets := [Vector2(0.0,0.86),Vector2(0.19,0.69),Vector2(0.0,0.86)]
	return Vector2(dimensions.x*sockets[hut_style].x,-dimensions.y*sockets[hut_style].y)
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
		body.position.y = -footprint.y*0.5
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = footprint
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	queue_redraw()

func set_effects_enabled(enabled: bool) -> void:
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("animated",enabled)

func _draw() -> void:
	if kind == "grass": return
	draw_set_transform(Vector2(8,-15),0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,shadow_size.x,SceneStyle.SHADOW)
	draw_circle(Vector2.ZERO,shadow_size.x*0.72,Color(SceneStyle.SHADOW,0.08))
	draw_set_transform(Vector2.ZERO)
