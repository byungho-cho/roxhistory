class_name DemoPlayer
extends CharacterBody2D

var direction := Vector2.ZERO
var phase := 0.0
var sprite: Sprite2D
var frames: Array[Texture2D] = []
var camera: Camera2D

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	add_child(shape)
	var texture: Texture2D = preload("res://assets/characters/villager.png")
	var dim := texture.get_size()/2.0
	for xy in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(xy*dim,dim)
		frames.append(frame)
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.scale = Vector2(0.205,0.205)
	sprite.position = Vector2(0,-50)
	add_child(sprite)
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(0.5,0.5)
	camera.position = Vector2(180,-220)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 2400
	camera.limit_bottom = 1350
	add_child(camera)
	get_viewport().size_changed.connect(fit_camera)
	fit_camera()
	queue_redraw()

func fit_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := maxf(0.5,maxf(viewport_size.x/2400.0,viewport_size.y/1350.0))
	camera.zoom = Vector2(fit,fit)

func _physics_process(delta: float) -> void:
	velocity = direction.limit_length()*float(DemoConfig.get_data().move_speed)
	move_and_slide()
	position.x = clampf(position.x,40,2360)
	position.y = clampf(position.y,40,1310)
	if direction.length() > 0.1:
		phase += delta*13.0
		sprite.position.y = -50+sin(phase)*3
		if absf(direction.x) > absf(direction.y):
			sprite.texture = frames[2] if direction.x < 0 else frames[3]
		else:
			sprite.texture = frames[1] if direction.y < 0 else frames[0]
	else:
		sprite.position.y = -50

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4))
	draw_circle(Vector2.ZERO,30,Color(0.1,0.08,0.02,0.4))
	draw_set_transform(Vector2.ZERO)
