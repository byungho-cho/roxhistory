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
var walk_weight := 0.0
var hand_uv := Vector2.ZERO
var idle_time := 0.0
var action_time := 0.0
var external_work_clock := false
var activity := ""
var facing := 0
var presentation_paused := false
var motion_state := "idle"
var sprite: Polygon2D
var hybrid: HybridCharacter
var use_3d := false
var perf_frames: Array[float] = []
var perf_start := 0
var perf_done := false
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
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	get_viewport().size_changed.connect(fit_camera)
	fit_camera()
	update_rig()
	hybrid = HybridCharacter.new()
	add_child(hybrid)

func set_character_3d(value: bool) -> void:
	perf_frames.clear()
	perf_start = Time.get_ticks_usec()
	perf_done = false
	use_3d = value
	sprite.visible = not value
	hybrid.set_enabled(value)
	if value: tool.visible = false

func _process(_delta: float) -> void:
	if not OS.has_feature("android") or not OS.is_debug_build() or perf_done or presentation_paused: return
	var now := Time.get_ticks_usec()
	if perf_start > 0: perf_frames.append(float(now-perf_start)/1000.0)
	perf_start = now
	if perf_frames.size() == 660:
		var samples: Array[float] = perf_frames.slice(60)
		samples.sort()
		var total := 0.0
		for value in samples: total += value
		print("HYBRID_PERF "+JSON.stringify({"mode":"3D" if use_3d else "2D","frames":600,"mean_ms":total/600.0,"p95_ms":samples[570],"viewport":str(get_viewport_rect().size),"gpu":RenderingServer.get_video_adapter_name()}))
		perf_done = true

func fit_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := maxf(0.5,maxf(viewport_size.x/2400.0,viewport_size.y/1350.0))
	camera.zoom = Vector2(fit,fit)
	camera.reset_smoothing()

func face_target(target: Vector2) -> void:
	var d := target-position
	if d.length_squared() > 0.01:
		if is_instance_valid(hybrid): hybrid.target_heading = atan2(d.x,d.y)
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
		var stride := hybrid.stride_world_length() if use_3d else STRIDE
		phase = fposmod(phase+travelled/stride*TAU,TAU)
	walk_weight = move_toward(walk_weight,1.0 if motion_state == "walk" else 0.0,delta*9.0)
	if not presentation_paused:
		idle_time += delta
		if activity != "" and not external_work_clock: action_time += delta
	update_rig()
	if use_3d:
		tool.visible = false
		hybrid.animate(delta,direction,phase,motion_state == "walk",activity,action_time,presentation_paused)

func update_rig() -> void:
	var region: Rect2 = PORTRAITS[facing]
	var width := HEIGHT*region.size.x/region.size.y
	var acting := motion_state == "gather" or motion_state == "build"
	var points := PackedVector2Array()
	var coords := PackedVector2Array()
	for rest in rest_points:
		var uv := rest+Vector2(0.5,1.0)
		coords.append(region.position+uv*region.size)
		points.append(deform_point(uv))
	sprite.polygon = points
	sprite.uv = coords
	tool.visible = acting
	if acting:
		hand_uv = Vector2(0.57,0.72) if facing == 2 else (Vector2(0.44,0.72) if facing == 3 else Vector2(0.84,0.72))
		# Share the exact deformation with the painted hand, including breathing.
		tool.position = deform_point(hand_uv)
		var beat := sin(action_time*TAU*1.8)
		# Swing outside the silhouette rather than through the face/chest.
		tool.rotation = (-1.7 if facing == 2 else 1.7)+beat*0.25 if facing >= 2 else 1.2+beat*0.3
		tool.z_index = -1 if facing == 1 else 1
	queue_redraw()

func deform_point(uv: Vector2) -> Vector2:
	var region: Rect2 = PORTRAITS[facing]
	var width := HEIGHT*region.size.x/region.size.y
	var u := uv.x
	var v := uv.y
	var p := Vector2((u-0.5)*width,(v-1.0)*HEIGHT)
	var acting := motion_state == "gather" or motion_state == "build"
	var stride := sin(phase)*walk_weight if not acting and not presentation_paused else 0.0
	var beat := sin(action_time*TAU*1.8) if acting else 0.0
	var breath := sin(idle_time*2.4)*0.6 if not presentation_paused else 0.0
	var leg := smoothstep(0.78,0.93,v)
	# Continuous weights avoid a hard split through the middle mesh column.
	var split := 0.5 if facing < 2 else 0.52
	var step := stride*(smoothstep(split-0.06,split+0.06,u)*2.0-1.0)
	p.x += step*(2.2 if facing < 2 else 7.0)*leg
	p.y -= maxf(0.0,step)*(7.0 if facing < 2 else 4.0)*leg
	var side := -1.0 if u < 0.5 else 1.0
	var arm := smoothstep(0.52,0.69,v)*(1.0-smoothstep(0.75,0.83,v))
	var outer := smoothstep(0.13,0.28,absf(u-0.5))
	if facing >= 2:
		var arm_center := 0.57 if facing == 2 else 0.44
		outer = 1.0-smoothstep(0.08,0.2,absf(u-arm_center))
		side = 1.0 if facing == 2 else -1.0
	var arm_motion := -stride*side*0.23+breath*0.012
	if acting: arm_motion = side*(-0.25+beat*0.35)
	var shoulder := Vector2(side*width*(0.08 if facing >= 2 else 0.23),-HEIGHT*0.47)
	p = p.lerp(shoulder+(p-shoulder).rotated(arm_motion),arm*outer)
	var upper := 1.0-smoothstep(0.67,0.86,v)
	p.y += (breath-absf(stride)*1.5+beat*1.0)*upper
	if acting: p.x += beat*0.8*upper
	return p

func _draw() -> void:
	draw_set_transform(Vector2(0,-2),0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,25,Color(0.12,0.09,0.04,0.045))
	draw_circle(Vector2.ZERO,21,Color(0.12,0.09,0.04,0.075))
	draw_circle(Vector2.ZERO,16,Color(0.12,0.09,0.04,0.13))
	draw_set_transform(Vector2.ZERO)
