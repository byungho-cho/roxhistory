class_name WorldFeedback
extends Node2D

# Presentation only: inventory/build/reward mutations stay in GameState.
var world: DemoWorld
var activity := ""
var target := ""
var elapsed := 0.0
var next_hit := 0.278
var particles: Array[Dictionary] = []
var notices: Array[Dictionary] = []
var events: Array[String] = []
var pulse := 0.0
var impact_strength := 0.0
var impact_point := Vector2.ZERO
var preview: Node2D
var roof: Sprite2D
var preview_progress := 0.0
var celebration := 0.0

func _init(owner_world: DemoWorld) -> void: world = owner_world
func _ready() -> void:
	z_index = 4
	preview = Node2D.new()
	preview.name = "ConstructionPreview"
	preview.position = world.site.position
	world.add_child.call_deferred(preview)
	roof = Sprite2D.new()
	roof.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	roof.texture = world.home.sprite.texture
	roof.scale = world.home.sprite.scale
	roof.position = world.home.sprite.position
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/construction.gdshader")
	roof.material = mat
	preview.add_child(roof)
	preview.visible = false

func remember(event: String) -> void:
	events.append(event)
	if events.size() > 64: events.pop_front()

func begin(kind: String, id := "") -> void:
	cancel()
	activity = kind; target = id; elapsed = 0; next_hit = 0.278
	preview_progress = 0
	preview.visible = kind == "build"
	roof.material.set_shader_parameter("progress",0.0)
	remember("begin:"+kind)

func update_work(seconds: float, total: float) -> void:
	elapsed = seconds
	if activity == "": return
	if activity == "build":
		preview_progress = clampf(seconds/total,0,1)
		roof.material.set_shader_parameter("progress",smoothstep(0.15,1.0,preview_progress))
	while elapsed >= next_hit:
		var point := world.site.position+Vector2(0,-35)
		var color := Color("d9ad6b")
		if activity == "gather" and world.art_nodes.has(target):
			point = world.art_nodes[target].position+Vector2(0,-35)
			color = Color("d4bd92") if target.begins_with("wood") else Color("b6b7a4")
		impact_point = point; impact_strength = 1.0
		burst(point,color,7,0.42)
		remember("impact:"+activity)
		next_hit += 1.0/1.8
	queue_redraw()

func cancel() -> void:
	if target != "" and world.art_nodes.has(target): world.art_nodes[target].get_child(0).rotation = 0
	activity = ""; target = ""; impact_strength = 0
	if is_instance_valid(preview): preview.visible = false
	preview_progress = 0
	queue_redraw()

func clear_transients() -> void:
	cancel(); particles.clear(); notices.clear(); celebration = 0; queue_redraw()

func burst(at: Vector2, color: Color, count: int, lifetime: float) -> void:
	for i in count:
		var a := TAU*i/count
		particles.append({"p":at,"v":Vector2(cos(a)*65,-48-absf(sin(a))*65),"age":0.0,"life":lifetime,"color":color,"size":3.0+i%3})
	if particles.size() > 120: particles = particles.slice(particles.size()-120)

func gathered(id: String) -> void:
	var kind := "wood" if id.begins_with("wood") else "stone"
	var at: Vector2 = world.art_nodes[id].position+Vector2(0,-125)
	burst(at,Color("f4d58b"),12,0.65)
	notices.append({"p":at,"age":0.0,"text":("나무" if kind == "wood" else "돌")+" +1","icon":kind})
	remember("credit:"+kind)

func built() -> void:
	celebration = 1.5
	burst(world.site.position+Vector2(0,-90),Color("ffe2a0"),24,1.1)
	remember("built")

func rewarded() -> void:
	notices.append({"p":world.player.position+Vector2(0,-170),"age":0.0,"text":"씨앗 +10 · 보금자리 완성","icon":""})
	burst(world.player.position+Vector2(0,-95),Color("f6d88f"),18,0.9)
	remember("reward")

func _process(delta: float) -> void:
	pulse += delta
	impact_strength = maxf(0,impact_strength-delta*7)
	celebration = maxf(0,celebration-delta)
	if activity == "gather" and world.art_nodes.has(target):
		world.art_nodes[target].get_child(0).rotation = sin(impact_strength*PI*4)*impact_strength*0.055
	for p in particles:
		p.age += delta; p.p += p.v*delta; p.v.y += 160*delta
	particles = particles.filter(func(p): return p.age < p.life)
	for n in notices: n.age += delta
	notices = notices.filter(func(n): return n.age < 1.45)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world.player): return
	if world.selected != "" and world.art_nodes.has(world.selected):
		var at: Vector2 = world.art_nodes[world.selected].position
		draw_set_transform(at,0,Vector2(1,0.42))
		draw_arc(Vector2.ZERO,65+sin(pulse*3)*2,0,TAU,48,Color(1,0.88,0.53,0.85),4,true)
		draw_set_transform(Vector2.ZERO)
		var tip := at+Vector2(0,-110+sin(pulse*3)*3)
		draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-8,-10),tip+Vector2(8,-10)]),Color("ffe5aa"))
	if activity == "build":
		var p: Vector2 = world.site.position
		var alpha := 1.0-smoothstep(0.5,1.0,preview_progress)
		for x in [-86.0,-43.0,0.0,43.0,86.0]:
			var base := p+Vector2(x,-12)
			var top := p+Vector2(x*0.25,-145)
			draw_line(base,base.lerp(top,minf(1,preview_progress*4)),Color(0.49,0.32,0.16,alpha),7,true)
		if preview_progress > 0.15: draw_line(p+Vector2(-70,-60),p+Vector2(70,-60),Color(0.78,0.61,0.36,alpha),5,true)
	for p in particles:
		var color: Color = p.color
		color.a *= 1.0-p.age/p.life
		draw_circle(p.p,p.size*(1-p.age/p.life*0.4),color)
	for n in notices:
		var alpha := minf(1,(1.45-n.age)*3)
		var at: Vector2 = n.p+Vector2(-48,-n.age*40)
		var font := DemoArt.theme().default_font
		var width := font.get_string_size(n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
		draw_rect(Rect2(at+Vector2(-8,-29),Vector2(width+16,38)),Color(0.20,0.14,0.08,alpha*0.78))
		draw_string_outline(font,at,n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28,3,Color(0.18,0.12,0.06,alpha))
		draw_string(font,at,n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color(1,0.94,0.75,alpha))
	if celebration > 0:
		draw_set_transform(world.site.position,0,Vector2(1,0.45))
		draw_arc(Vector2.ZERO,115+(1.5-celebration)*35,0,TAU,64,Color(1,0.9,0.61,celebration/1.5),5,true)
		draw_set_transform(Vector2.ZERO)
