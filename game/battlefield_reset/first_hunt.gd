extends Control
## Clean Chapter 1 slice. The task is a single encounter; no chapter catalogue,
## story timers, formation rules, platform scales, or legacy battle controller.
signal exit_requested
enum Phase { READY, APPROACH, FIGHT, DONE }
const HAN_SCENE := "res://assets/characters/res050/hangyeol-latest.glb"
const DEER_SCENE := "res://assets/animals/res050/forest-deer-latest.glb"
const MEADOW := "res://assets/ui/hunting-formation/clearing-meadow-1.png"
const HAN_BASIC := "res://assets/characters/han-meshy-motion/basic-first-accelerated.res"
const HAN_WALK := "res://assets/characters/han-meshy-motion/walk.res"
const HAN_IDLE := "res://assets/characters/han-meshy-motion/battle-idle10.res"
const REACH := 1.14
var phase := Phase.READY
var han_hp := 20
var deer_hp := 15
var active_attacker := -1
var attack_elapsed := 0.0
var impact_at := 0.0
var release_at := 0.0
var contact_done := false
var elapsed := 0.0
var impact_pulse := 0.0
var attack_gate := 0.0
var last_target := 1
var selection := 0
var stand := Vector3(-2.35, 0, 0.0)
var field: SubViewport
var camera: Camera3D
var han: Node3D
var deer: Node3D
var han_anim: AnimationPlayer
var deer_anim: AnimationPlayer
var paint: Control
var status_line: Label
var body_line: Label
var start_button: Button
var formation_button: Button
var attack_button: Button
var art_failed := false
var played_clips: Array[String] = []
var landed_hits := 0
var previous_touch_emulation := false

func _ready() -> void:
	previous_touch_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	var cjk := Theme.new()
	cjk.default_font = load("res://assets/fonts/NotoSansKR.ttf") as Font
	theme = cjk
	var backdrop := TextureRect.new()
	backdrop.texture = load(MEADOW) as Texture2D
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	var viewport_layer := SubViewportContainer.new()
	viewport_layer.stretch = true
	viewport_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(viewport_layer)
	viewport_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	field = SubViewport.new()
	field.transparent_bg = true
	field.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_layer.add_child(field)
	var world := Node3D.new()
	field.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -20, 0)
	light.light_energy = 0.75
	world.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff0df")
	env.environment.ambient_light_energy = 0.64
	world.add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 9.5
	world.add_child(camera)
	camera.position = Vector3(1.9, 5.6, 7.9)
	camera.look_at(Vector3(0, 0.45, 0))
	camera.current = true
	han = _spawn_actor(world,HAN_SCENE,0.79)
	deer = _spawn_actor(world,DEER_SCENE,0.79)
	han_anim = _player(han)
	deer_anim = _player(deer)
	_add_clip(han_anim,"ready_idle",HAN_IDLE)
	_add_clip(han_anim,"steady_walk",HAN_WALK)
	_add_clip(han_anim,"clear_basic",HAN_BASIC)
	art_failed = han_anim == null or deer_anim == null
	paint = Control.new()
	paint.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(paint)
	paint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	paint.draw.connect(_paint_field)
	_build_ui()
	_reset()

func _spawn_actor(world: Node3D,path: String, factor: float) -> Node3D:
	var pivot := Node3D.new()
	world.add_child(pivot)
	var model := load(path) as PackedScene
	if model:
		var actor := model.instantiate() as Node3D
		if actor:
			pivot.add_child(actor)
			actor.scale = Vector3.ONE * factor
	return pivot

func _player(pivot: Node3D) -> AnimationPlayer:
	var candidates := pivot.find_children("*", "AnimationPlayer", true, false)
	return null if candidates.is_empty() else candidates[0] as AnimationPlayer

func _add_clip(player: AnimationPlayer,key: String,path: String) -> void:
	if not player: return
	var resource := load(path) as Animation
	if not resource: return
	var clip := resource.duplicate(true) as Animation
	var animation_root := player.get_node_or_null(player.root_node)
	if not animation_root: return
	var rigs := animation_root.find_children("*","Skeleton3D",true,false)
	if rigs.is_empty(): return
	var skeleton := rigs[0] as Skeleton3D
	var prefix := String(animation_root.get_path_to(skeleton))
	for i in range(clip.get_track_count()-1,-1,-1):
		var original := clip.track_get_path(i)
		if original.get_subname_count() != 1:
			clip.remove_track(i)
			continue
		var bone := original.get_subname(0)
		if skeleton.find_bone(bone) < 0 or (bone == &"root" and clip.track_get_type(i) == Animation.TYPE_POSITION_3D):
			clip.remove_track(i)
			continue
		clip.track_set_path(i,NodePath(prefix+":"+String(bone)))
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	library.add_animation(key,clip)
	player.remove_animation_library("")
	player.add_animation_library("",library)

func _play(player: AnimationPlayer, options: Array[String], looping := false) -> float:
	if not player: return 0.0
	for key in options:
		if player.has_animation(key):
			var clip := player.get_animation(key)
			if looping: clip.loop_mode = Animation.LOOP_LINEAR
			if player.current_animation != key or not looping:
				player.play(key,0.12)
				played_clips.append(key)
			return clip.length
	return 0.0

func _build_ui() -> void:
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_left",24)
	gutter.add_theme_constant_override("margin_right",24)
	gutter.add_theme_constant_override("margin_top",16)
	gutter.add_theme_constant_override("margin_bottom",18)
	add_child(gutter)
	gutter.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	gutter.mouse_filter = MOUSE_FILTER_IGNORE
	var layout := VBoxContainer.new()
	layout.mouse_filter = MOUSE_FILTER_IGNORE
	gutter.add_child(layout)
	var top := HBoxContainer.new()
	top.mouse_filter = MOUSE_FILTER_IGNORE
	layout.add_child(top)
	var back := Button.new()
	back.text = "마을"
	back.custom_minimum_size = Vector2(84,49)
	top.add_child(back)
	back.pressed.connect(request_exit)
	status_line = Label.new()
	status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_line.size_flags_horizontal = SIZE_EXPAND_FILL
	status_line.add_theme_font_size_override("font_size",28)
	status_line.add_theme_constant_override("outline_size",4)
	status_line.add_theme_color_override("font_color",Color("fff3d6"))
	status_line.add_theme_color_override("font_outline_color",Color("302014"))
	top.add_child(status_line)
	var empty := Control.new()
	empty.custom_minimum_size.x = 84
	top.add_child(empty)
	body_line = Label.new()
	body_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_line.add_theme_font_size_override("font_size",19)
	body_line.add_theme_constant_override("outline_size",3)
	body_line.add_theme_color_override("font_color",Color("fff3d6"))
	body_line.add_theme_color_override("font_outline_color",Color("302014"))
	layout.add_child(body_line)
	var fill := Control.new()
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(fill)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",16)
	layout.add_child(row)
	formation_button = _button(row,"배치 변경",_cycle_slot)
	start_button = _button(row,"전투 시작",_start_or_retry)
	attack_button = _button(row,"공격",_press_attack)

func _button(row: HBoxContainer, label: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = label
	control.custom_minimum_size = Vector2(144,52)
	control.add_theme_font_size_override("font_size",22)
	row.add_child(control)
	control.pressed.connect(callback)
	return control

func _refresh() -> void:
	status_line.text = "1-1  ·  숲속 첫 사냥"
	body_line.text = "한결  %d / 20       사슴  %d / 15" % [han_hp,deer_hp]
	if phase == Phase.DONE:
		status_line.text = "승리" if deer_hp == 0 else "패배"
		body_line.text = "새 전장 테스트  ·  보상 및 저장 연동 없음"
	elif art_failed:
		body_line.text = "모델을 불러오지 못했습니다."
	formation_button.visible = phase == Phase.READY
	start_button.visible = phase == Phase.READY or phase == Phase.DONE
	start_button.text = "다시 시작" if phase == Phase.DONE else "전투 시작"
	start_button.disabled = art_failed
	attack_button.visible = phase == Phase.FIGHT
	attack_button.disabled = active_attacker != -1 or attack_gate > 0.0

func _reset() -> void:
	phase = Phase.READY
	han_hp = 20
	deer_hp = 15
	active_attacker = -1
	attack_gate = 0.0
	elapsed = 0.0
	landed_hits = 0
	impact_pulse = 0.0
	_set_slot()
	deer.position = Vector3(2.0,0,0)
	_face()
	_play(han_anim,["ready_idle","idle"],true)
	_play(deer_anim,["req046_idle","idle"],true)
	_refresh()

func _set_slot() -> void:
	stand.z = [0.0,0.62,-0.62][selection]
	han.position = stand

func _cycle_slot() -> void:
	if phase != Phase.READY: return
	selection = (selection + 1) % 3
	_set_slot()
	_face()

func _start_or_retry() -> void:
	if phase == Phase.DONE:
		_reset()
		return
	if phase != Phase.READY or art_failed: return
	phase = Phase.APPROACH
	_play(han_anim,["steady_walk","walk"],true)
	_play(deer_anim,["walk"],true)
	_refresh()

func _face() -> void:
	var v := deer.position - han.position
	if v.length_squared() < 0.0001: return
	han.rotation.y = atan2(v.x,v.z)
	deer.rotation.y = atan2(-v.x,-v.z)

func _process(delta: float) -> void:
	if paint: paint.queue_redraw()
	impact_pulse = maxf(0,impact_pulse-delta)
	if phase == Phase.APPROACH:
		var offset := deer.position - han.position
		var step := minf(maxf(0.0,(offset.length()-REACH)*0.5),delta*1.22)
		han.position += offset.normalized()*step
		deer.position -= offset.normalized()*step
		_face()
		if offset.length() <= REACH + 0.018:
			phase = Phase.FIGHT
			_play(han_anim,["ready_idle","idle"],true)
			_play(deer_anim,["req046_idle","idle"],true)
			_refresh()
		return
	if phase != Phase.FIGHT: return
	if active_attacker == -1:
		attack_gate = maxf(attack_gate-delta,0.0)
		attack_button.disabled = attack_gate > 0.0
		elapsed += delta
		if elapsed >= 2.2 and attack_gate <= 0.0:
			_begin_attack(1)
		return
	attack_elapsed += delta
	if not contact_done and attack_elapsed >= impact_at:
		contact_done = true
		landed_hits += 1
		last_target = 1-active_attacker
		impact_pulse = 0.35
		if active_attacker == 0:
			deer_hp = maxi(0,deer_hp-5)
			_play(deer_anim,["hit_reaction"])
		else:
			han_hp = maxi(0,han_hp-3)
			_play(han_anim,["hit_reaction"])
		_refresh()
	if attack_elapsed >= release_at:
		active_attacker = -1
		if deer_hp == 0 or han_hp == 0: phase = Phase.DONE
		_play(han_anim,["ready_idle","idle"],true)
		_play(deer_anim,["req046_idle","idle"],true)
		attack_gate = 0.16
		_refresh()

func _press_attack() -> void:
	if phase == Phase.FIGHT and active_attacker == -1 and attack_gate <= 0.0:
		_begin_attack(0)

func _begin_attack(which: int) -> void:
	active_attacker = which
	attack_elapsed = 0.0
	contact_done = false
	elapsed = 0.0
	var length := _play(han_anim,["clear_basic","basic_attack"]) if which == 0 else _play(deer_anim,["req046_basic_attack","attack"])
	release_at = maxf(length,0.65)
	impact_at = release_at * (0.44 if which == 0 else 0.67)
	_refresh()

func _paint_field() -> void:
	if not camera or field.size.x < 2: return
	var han_point := camera.unproject_position(han.position)
	var deer_point := camera.unproject_position(deer.position)
	for point: Vector2 in [han_point,deer_point]:
		paint.draw_set_transform(point,0.0,Vector2(1.0,0.3))
		paint.draw_circle(Vector2.ZERO,31.0,Color(0.10,0.12,0.07,0.23))
		if phase == Phase.READY:
			paint.draw_arc(Vector2.ZERO,33.0,0.0,TAU,36,Color(1,0.86,0.53,0.48),2.4,true)
	paint.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	if impact_pulse > 0:
		var hit := (deer if last_target == 1 else han).position + Vector3(0,0.92,0)
		var center := camera.unproject_position(hit)
		var fade := impact_pulse / 0.35
		var radius := lerpf(48.0,6.0,fade)
		for i in range(7):
			var direction := Vector2.from_angle(TAU*i/7.0+0.27)
			paint.draw_line(center+direction*radius*0.52,center+direction*radius,Color(1,0.80,0.38,fade),3.0,true)
		paint.draw_arc(center,radius,0.0,TAU,36,Color(1,0.68,0.23,fade*0.46),3.0,true)

func _exit_tree() -> void:
	Input.emulate_mouse_from_touch = previous_touch_emulation

func request_exit() -> void:
	exit_requested.emit()
