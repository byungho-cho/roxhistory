class_name ConstructionProgress
extends Control

# Figma 582:83 geometry follows its building, with a minimum readable size.
var app: Node
var fill: TextureRect
var timer: Label
var hammer: TextureRect
var clock := 0.0
var gathering:=false

func _init(owner_app: Node, for_gathering:bool=false) -> void:
	app = owner_app;gathering=for_gathering

func _ready() -> void:
	name="GatheringTimeProgress" if gathering else "ConstructionTimeProgress"
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
	visible = app.task == ("gather" if gathering else "build") and is_instance_valid(app.world) and not app.modal and not app.world_map_open and app.application_active
	if gathering:visible=visible and not app.gather_approach and app.world.art_nodes.has(app.task_target)
	if gathering and visible:visible=app.world.art_nodes[app.task_target].visible
	if not visible: clock = 0; return
	clock += delta
	var ratio := clampf(1.0-app.task_remaining/maxf(0.001,app.task_total),0,1)
	fill.size.x = maxf(0.01,320*ratio)
	fill.material.set_shader_parameter("dimensions",fill.size)
	var seconds := maxi(0,int(ceil(app.task_remaining)))
	timer.text = "%02d:%02d:%02d" % [seconds/3600,(seconds/60)%60,seconds%60]
	hammer.rotation = 0 if gathering else deg_to_rad(8+sin(clock*TAU/0.6)*12)
	if gathering:
		for node in app.model.nodes():
			if str(node.id)==app.task_target:hammer.texture=DemoArt.icon(str(node.kind));break
	var point: Vector2 = app.world.get_global_transform_with_canvas()*app.world.site.position
	var world_zoom:float=app.world.get_global_transform_with_canvas().get_scale().x
	scale=Vector2.ONE*clampf(world_zoom*.85,.34,.68)
	position = point-Vector2(size.x*scale.x*.5,150*world_zoom+size.y*scale.y)
	if gathering:
		scale*=2.0/3.0
		var image:Sprite2D=app.world.art_nodes[app.task_target].get_child(0)
		var bounds:Rect2=image.get_global_transform_with_canvas()*image.get_rect()
		position=Vector2(bounds.get_center().x-size.x*scale.x*.5,bounds.position.y-size.y*scale.y-5)
	position.x = clampf(position.x,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-size.x*scale.x))
	position.y = clampf(position.y,app.safe.y+90,maxf(app.safe.y+90,app.h-app.safe.y-100-size.y*scale.y))
