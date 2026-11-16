extends Node2D

const FLAG_CYCLE := 8.733
const FLAME_START := 0.15
const FLAME_DURATION := 2.9
const SMOKE_START := FLAME_START + FLAME_DURATION + 1.0
const SMOKE_DURATION := 1.2
const CYCLE := SMOKE_START + SMOKE_DURATION + 4.983
const CHIMNEY_PUFFS := 7
const EYE_PUFFS := 3
const ATLAS := preload("res://assets/ui/d0030/chief-vfx-atlas.png")
const RIGS := {
	3: [preload("res://assets/ui/d0030/chief-l3-base.png"), preload("res://assets/ui/d0030/chief-l3-flag-cloth.png"),
		Vector2(748.06,475.88), Vector2(828.25,469.79), Vector2(590.05,254.25), Vector4(1024.49,178.46,958.51,357.45)],
	4: [preload("res://assets/ui/d0030/chief-l4-base.png"), preload("res://assets/ui/d0030/chief-l4-flag-cloth.png"),
		Vector2(744.09,465.49), Vector2(828.19,456.95), Vector2(599,238), Vector4(1034.69,180.69,975.2,357.11)]
}

var level := 0
var clock := 0.0
var flag := Sprite2D.new()
var flag_material := ShaderMaterial.new()
var smoke_material := ShaderMaterial.new()
var chimney_material := ShaderMaterial.new()
var flame_material := ShaderMaterial.new()
var puffs: Array[Sprite2D] = []
var puff_index := 0

func _ready() -> void:
	flag_material.shader = preload("res://shaders/chief_flag.gdshader")
	smoke_material.shader = preload("res://shaders/chief_smoke.gdshader")
	chimney_material.shader = smoke_material.shader
	chimney_material.set_shader_parameter("white_core", 0.78)
	flame_material.shader = preload("res://shaders/chief_eye_flame.gdshader")
	flag.material = flag_material
	z_index = 1
	add_child(flag)
	for index in CHIMNEY_PUFFS + EYE_PUFFS * 2:
		var particle := Sprite2D.new()
		particle.texture = ATLAS
		particle.region_enabled = true
		particle.region_filter_clip_enabled = true
		particle.hide()
		add_child(particle)
		puffs.append(particle)

func apply_level(sprite: Sprite2D, next_level: int) -> void:
	var rig: Array = RIGS[next_level]
	sprite.texture = rig[0]
	if level == next_level:
		return
	level = next_level
	clock = 0.0
	flag.texture = rig[1]
	var size := flag.texture.get_size()
	flag_material.set_shader_parameter("seam", rig[5] / Vector4(size.x,size.y,size.x,size.y))

func _process(delta: float) -> void:
	if level == 0 or not is_visible_in_tree():
		return
	clock += delta
	var beat := fposmod(clock, FLAG_CYCLE)
	var wind := 0.42
	for start in [0.17, 1.60, 4.54, 5.97]:
		var pulse := clampf((beat - float(start)) / 1.31, 0.0, 1.0)
		wind += sin(pulse * PI) * 2.0
	flag_material.set_shader_parameter("clock", clock)
	flag_material.set_shader_parameter("wind", wind)
	update_particles()

func update_particles() -> void:
	puff_index = 0
	var rig: Array = RIGS[level]
	var origin := -flag.texture.get_size() * 0.5
	var outlet: Vector2 = origin + rig[4]
	for index in CHIMNEY_PUFFS:
		var emission := clock / 3.1 + float(index) / CHIMNEY_PUFFS
		var age := fposmod(emission, 1.0)
		var phase := sin(floorf(emission) * 3.14 + float(index) * 2.4)
		var drift := Vector2(230 * age * age + phase * 58 * age, -402 * age)
		var alpha := smoothstep(0.0, 0.14, age) * (1.0 - smoothstep(0.35, 1.0, age))
		var spread := smoothstep(0.0, 1.0, age)
		var extent := Vector2(93,117).lerp(Vector2(440,330), spread) * (1.0 + phase * 0.11)
		draw_puff(0, outlet + drift, extent, alpha * 0.78, phase * 0.52 * age)

	var beat := fposmod(clock, CYCLE)
	flame_material.set_shader_parameter("clock", beat)
	for index in 2:
		var eye: Vector2 = origin + rig[index + 2]
		var lean := -0.09 if index == 0 else 0.09
		if beat >= FLAME_START and beat < FLAME_START + FLAME_DURATION:
			var elapsed := beat - FLAME_START
			var strength := smoothstep(0.0, 0.22, elapsed) * (1.0 - smoothstep(0.9, FLAME_DURATION, elapsed))
			var flicker := 0.5 + 0.5 * sin(elapsed * 15.0 + index * 1.8)
			var angle := lean + 0.12 + sin(elapsed * 5.0) * 0.055
			draw_puff(3, eye, Vector2(124,109), strength * 0.60)
			var height := 310.0 * strength * lerpf(0.79, 1.0, flicker)
			draw_puff(2, eye + Vector2(sin(angle), -cos(angle)) * height * 0.46,
				Vector2(112.0 * strength, height), strength, angle)
		elif beat >= SMOKE_START and beat < SMOKE_START + SMOKE_DURATION:
			for puff in EYE_PUFFS:
				var delay := puff * 0.17 + index * 0.055
				var age := (beat - SMOKE_START - delay) / (SMOKE_DURATION - delay)
				if age <= 0.0:
					continue
				var alpha := smoothstep(0.0, 0.13, age) * (1.0 - smoothstep(0.57, 1.0, age))
				var drift := Vector2((lean + 0.12) * 150, -159) * age
				draw_puff(1, eye + drift, Vector2.ONE * lerpf(56.0, 138.0, age), alpha * 0.85, lean * age)
	for index in range(puff_index, puffs.size()):
		puffs[index].hide()

func draw_puff(tile: int, at: Vector2, size: Vector2, alpha: float, rotation_angle := 0.0) -> void:
	var particle := puffs[puff_index]
	puff_index += 1
	particle.region_rect = Rect2(tile * 128, 0, 128, 128)
	particle.material = chimney_material if tile == 0 else smoke_material if tile == 1 else null
	if tile == 2:
		particle.material = flame_material
	particle.position = at
	particle.rotation = rotation_angle
	particle.scale = size / 128.0
	particle.modulate.a = alpha
	particle.show()
