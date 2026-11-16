extends Node2D

const CYCLE := 8.733
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
var puffs: Array[Sprite2D] = []
var puff_index := 0

func _ready() -> void:
	flag_material.shader = preload("res://shaders/chief_flag.gdshader")
	smoke_material.shader = preload("res://shaders/chief_smoke.gdshader")
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
	var beat := fposmod(clock, CYCLE)
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
		var age := fposmod(clock / 2.9 + float(index) / CHIMNEY_PUFFS, 1.0)
		var drift := Vector2(220 * age * age + sin(age * TAU + index) * 35 * age, -330 * age)
		var alpha := smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.56, 1.0, age))
		draw_puff(0, outlet + drift, Vector2(68,60).lerp(Vector2(243,190),age), alpha)

	var beat := fposmod(clock, CYCLE)
	for index in 2:
		var eye: Vector2 = origin + rig[index + 2]
		var lean := 0.32 if index == 0 else -0.28
		if beat >= 0.15 and beat < 1.55:
			var elapsed := beat - 0.15
			var strength := smoothstep(0.0, 0.14, elapsed) * (1.0 - smoothstep(0.42, 1.4, elapsed))
			strength *= 0.90 + 0.10 * sin(clock * 29.0 + index * 2.0)
			draw_puff(3, eye, Vector2(139,108), strength * 0.78)
			var height := 172.0 * strength
			draw_puff(2, eye + Vector2(sin(lean), -cos(lean)) * height * 0.44,
				Vector2(67, height), strength, lean)
		elif beat >= 2.55 and beat < 3.75:
			for puff in EYE_PUFFS:
				var delay := puff * 0.17 + index * 0.055
				var age := (beat - 2.55 - delay) / (1.2 - delay)
				if age <= 0.0:
					continue
				var alpha := smoothstep(0.0, 0.13, age) * (1.0 - smoothstep(0.57, 1.0, age))
				draw_puff(1, eye + Vector2(lean * 110, -159) * age,
					Vector2.ONE * lerpf(56.0, 138.0, age), alpha)
	for index in range(puff_index, puffs.size()):
		puffs[index].hide()

func draw_puff(tile: int, at: Vector2, size: Vector2, alpha: float, rotation_angle := 0.0) -> void:
	var particle := puffs[puff_index]
	puff_index += 1
	particle.region_rect = Rect2(tile * 128, 0, 128, 128)
	particle.material = smoke_material if tile < 2 else null
	particle.position = at
	particle.rotation = rotation_angle
	particle.scale = size / 128.0
	particle.modulate.a = alpha
	particle.show()
