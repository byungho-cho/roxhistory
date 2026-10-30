class_name DemoPlayer
extends CharacterBody2D

# The original four-direction artwork is a subdivided mesh. Arms and legs
# bend independently around their joints; the feet stay on the ground plane.
const PORTRAITS = [Rect2(326,17,299,536),Rect2(801,19,290,533),Rect2(329,566,299,540),Rect2(803,567,294,539)]
const COLS := 16
const ROWS := 32
const HEIGHT := 142.0
const STRIDE := 104.0
var direction := Vector2.ZERO
var phase := 0.0
var idle_time := 0.0
var action_time := 0.0
var activity := ""
var facing := 0
var presentation_paused := false
var motion_state := "idle"
var sprite: Polygon2D
var camera: Camera2D
var rest_points := PackedVector2Array()
var tool: Node2D

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	add_child(shape)
	sprite = Polygon2D.new()
	sprite.name = "CharacterRig"
	sprite.texture = preload("res://assets/characters/villager.png")
	var cells: Array[PackedInt32Array] = []
	for row in ROWS+1:
		for col in COLS+1:
			rest_points.append(Vector2(float(col)/COLS-0.5,float(row)/ROWS-1.0))
	for row in ROWS:
		for col in COLS:
			var i := row*(COLS+1)+col
			cells.append(PackedInt32Array([i,i+1,i+COLS+2,i+COLS+1]))
	sprite.polygons = cells
	add_child(sprite)
	tool = Node2D.new()
	tool.name = "GatherTool"
	var handle := Line2D.new()
	handle.points = PackedVector2Array([Vector2.ZERO,Vector2(0,-30)])
	handle.width = 4
	handle.default_color = Color("765039")
	handle.antialiased = true
	tool.add_child(handle)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-8,-29),Vector2(-3,-36),Vector2(9,-32),Vector2(7,-24)])
	head.color = Color("bab4a1")
	tool.add_child(head)
	tool.visible = false
	add_child(tool)
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
	update_rig()

func fit_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := maxf(0.5,maxf(viewport_size.x/2400.0,viewport_size.y/1350.0))
	camera.zoom = Vector2(fit,fit)

func face_target(target: Vector2) -> void:
	var d := target-position
	if d.length_squared() > 0.01:
		facing = (2 if d.x < 0 else 3) if absf(d.x) > absf(d.y) else (1 if d.y < 0 else 0)

func set_activity(value: String) -> void:
	if activity != value: action_time = 0.0
	activity = value

func _physics_process(delta: float) -> void:
	var movement := Vector2.ZERO if presentation_paused or activity != "" else direction.limit_length()
	velocity = movement*float(DemoConfig.get_data().move_speed)
	var before := position
	move_and_slide()
	position.x = clampf(position.x,40,2360)
	position.y = clampf(position.y,40,1310)
	var travelled := position.distance_to(before)
	if movement.length() > 0.1: face_target(position+movement)
	motion_state = "paused" if presentation_paused else (activity if activity != "" else ("walk" if travelled > 0.05 else "idle"))
	if motion_state == "walk":
		phase = fposmod(phase+travelled/STRIDE*TAU,TAU)
	elif motion_state == "idle":
		phase = lerp_angle(phase,0.0,minf(1.0,delta*18.0))
	if not presentation_paused:
		idle_time += delta
		if activity != "": action_time += delta
	update_rig()

func update_rig() -> void:
	var region: Rect2 = PORTRAITS[facing]
	var width := HEIGHT*region.size.x/region.size.y
	var walking := motion_state == "walk"
	var acting := motion_state == "gather" or motion_state == "build"
	var stride := sin(phase) if walking else 0.0
	var beat := sin(action_time*TAU*1.8) if acting else 0.0
	var breath := sin(idle_time*2.4)*0.6 if not presentation_paused else 0.0
	var points := PackedVector2Array()
	var coords := PackedVector2Array()
	for rest in rest_points:
		var u := rest.x+0.5
		var v := rest.y+1.0
		var p := Vector2(rest.x*width,rest.y*HEIGHT)
		coords.append(region.position+Vector2(u,v)*region.size)
		var leg := smoothstep(0.78,0.93,v)
		var side := -1.0 if u < 0.5 else 1.0
		var step := stride*side
		if facing < 2:
			p.x += step*2.2*leg
			p.y -= maxf(0.0,step)*8.0*leg
		else:
			step = stride*(-1.0 if u < 0.52 else 1.0)
			p.x += step*9.0*leg
			p.y -= maxf(0.0,step)*5.0*leg
		var arm := smoothstep(0.52,0.69,v)*(1.0-smoothstep(0.75,0.83,v))
		var outer := smoothstep(0.13,0.28,absf(u-0.5))
		if facing >= 2:
			var arm_center := 0.57 if facing == 2 else 0.44
			outer = 1.0-smoothstep(0.08,0.2,absf(u-arm_center))
			side = 1.0 if facing == 2 else -1.0
		var arm_motion := -stride*side*0.23 if walking else breath*0.012
		if acting: arm_motion = side*(-0.45+beat*0.65)
		var shoulder := Vector2(side*width*0.23,-HEIGHT*0.47)
		if facing >= 2: shoulder.x = side*width*0.08
		p = p.lerp(shoulder+(p-shoulder).rotated(arm_motion),arm*outer)
		var upper := 1.0-smoothstep(0.67,0.86,v)
		p.y += (breath-(absf(stride)*1.5 if walking else 0.0)+(beat*1.6 if acting else 0.0))*upper
		if acting: p.x += beat*1.3*upper
		points.append(p)
	sprite.polygon = points
	sprite.uv = coords
	tool.visible = acting
	if acting:
		var hand_side := -1.0 if facing == 3 else 1.0
		var shoulder := Vector2(hand_side*width*(0.08 if facing >= 2 else 0.23),-HEIGHT*0.47)
		var hand := Vector2(hand_side*width*(0.09 if facing >= 2 else 0.34),-HEIGHT*0.29)
		var arm_angle := hand_side*(-0.45+beat*0.65)
		tool.position = shoulder+(hand-shoulder).rotated(arm_angle)
		tool.rotation = hand_side*(0.8+beat*0.45) if facing < 2 else (-1.15+beat*0.45)*(1.0 if facing == 2 else -1.0)
		tool.z_index = -1 if facing == 1 else 1
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0,-2),0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,23,Color(0.1,0.08,0.02,0.25))
	draw_set_transform(Vector2.ZERO)
