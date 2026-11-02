class_name ConstructionProgress
extends Control

# Figma 582:83: retain the approved geometry, scaled as one fixed-size HUD unit.
var app: Node
var fill: TextureRect
var timer: Label
var hammer: TextureRect
var clock := 0.0

func _init(owner_app: Node) -> void: app = owner_app

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(410,72)
	scale = Vector2.ONE*0.65
	var track := Panel.new()
	track.position = Vector2(70,8)
	track.size = Vector2(330,54)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.122,0.161,0.102,0.72)
	style.border_color = Color(0.769,0.639,0.38,0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	track.add_theme_stylebox_override("panel",style)
	add_child(track)
	fill = TextureRect.new()
	fill.position = Vector2(75,13)
	fill.size = Vector2(160,44)
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color(0.698,0.91,0.329,0.92),Color(0.231,0.569,0.129,0.92)])
	gradient.fill_from = Vector2(0,0)
	gradient.fill_to = Vector2(0,1)
	fill.texture = gradient
	var rounded := ShaderMaterial.new()
	rounded.shader = preload("res://shaders/progress_round.gdshader")
	fill.material = rounded
	add_child(fill)
	timer = Label.new()
	timer.position = Vector2(170,13)
	timer.theme = DemoArt.theme()
	timer.add_theme_font_size_override("font_size",30)
	timer.add_theme_color_override("font_color",Color("fffae0"))
	timer.add_theme_color_override("font_outline_color",Color("30251b"))
	timer.add_theme_constant_override("outline_size",3)
	add_child(timer)
	hammer = TextureRect.new()
	hammer.texture = preload("res://assets/effects/construction-hammer.png")
	hammer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hammer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hammer.position = Vector2(17,-5.4)
	hammer.size = Vector2(72,76.8)
	hammer.pivot_offset = Vector2(25,65)
	add_child(hammer)
	for child in get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(delta: float) -> void:
	visible = app.task == "build" and is_instance_valid(app.world) and not app.modal
	if not visible: clock = 0; return
	clock += delta
	var ratio := clampf(1.0-app.task_remaining/maxf(0.001,app.task_total),0,1)
	fill.size.x = maxf(0.01,320*ratio)
	fill.material.set_shader_parameter("dimensions",fill.size)
	var seconds := maxi(0,int(ceil(app.task_remaining)))
	timer.text = "%02d:%02d:%02d" % [seconds/3600,(seconds/60)%60,seconds%60]
	hammer.rotation = deg_to_rad(8+sin(clock*TAU/0.6)*12)
	var point: Vector2 = app.world.get_global_transform_with_canvas()*app.world.site.position
	position = point-Vector2(133,130)
	position.x = clampf(position.x,app.safe.x,app.w-app.safe.x-size.x*scale.x)
	position.y = clampf(position.y,app.safe.y+90,app.h-app.safe.y-100)
