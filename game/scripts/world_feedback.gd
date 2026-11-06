class_name WorldFeedback
extends Node2D
signal sound_cue(key: String)

# Presentation only: inventory/build/reward mutations stay in GameState.
var world: DemoWorld
var activity := ""
var target := ""
var elapsed := 0.0
var next_hit := HeroMotion.CONTACT
var build_sound_count:=0
var next_build_sound:=0.0
var particles: Array[Dictionary] = []
var notices: Array[Dictionary] = []
var events: Array[String] = []
var pulse := 0.0
var impact_strength := 0.0
var impact_point := Vector2.ZERO
var resource_impact_point := Vector2.ZERO
var preview: Node2D
var roof: Sprite2D
var preview_progress := 0.0
var celebration := 0.0
var celebration_point := Vector2.ZERO

func _init(owner_world: DemoWorld) -> void: world = owner_world
func _ready() -> void:
	z_index = 4
	preview = Node2D.new()
	preview.name = "ConstructionPreview"
	preview.position = world.site.position
	world.add_child.call_deferred(preview)
	roof = Sprite2D.new()
	roof.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	roof.texture = preload("res://assets/effects/construction-scaffold.png")
	roof.scale = Vector2.ONE*220.0/roof.texture.get_width()
	# Scaffold image includes the back and front of an elliptical footprint.
	# Its front posts extend below the site's center, unlike a hut's doorway anchor.
	roof.position.y = -roof.texture.get_height()*roof.scale.y*0.5+55
	preview.add_child(roof)
	preview.visible = false

func remember(event: String) -> void:
	events.append(event)
	if events.size() > 64: events.pop_front()

func begin(kind: String, id := "") -> void:
	cancel()
	activity = kind; target = id; elapsed = 0; next_hit = HeroMotion.CONTACT
	build_sound_count=0;next_build_sound=0
	world.player.hybrid.work_kind = ("wood" if id.begins_with("wood") else "stone") if kind == "gather" else "build"
	world.player.external_work_clock = true
	preview_progress = 0
	preview.visible = kind == "build"
	preview.position = world.site.position
	roof.modulate.a = 0.0
	remember("begin:"+kind)
	world.objectives.redraw()

func update_work(seconds: float, total: float) -> void:
	elapsed = seconds
	if activity == "": return
	if activity=="gather" and world.resource_labels.has(target):world.resource_labels[target].reveal_bar()
	world.player.action_time = seconds
	if activity == "build":
		preview_progress = clampf(seconds/total,0,1)
		roof.modulate.a = smoothstep(0.0,0.12,preview_progress)
	while elapsed >= next_hit:
		var point := world.site.position+Vector2(0,-35)
		var color := Color("d9ad6b")
		if activity == "gather" and world.art_nodes.has(target):
			point = world.art_nodes[target].position+Vector2(0,-35)
			color = Color("d4bd92") if target.begins_with("wood") else Color("b6b7a4")
		# Particles originate at the rendered tool head, not the object's center
		# several pixels away. Object sway and the matching sound share this beat.
		if activity=="gather" and world.player.use_3d:
			var hero := world.player.hybrid
			hero.animate(0,Vector2.ZERO,world.player.phase,false,activity,next_hit,false)
			point = hero.tool_contact_world()
		impact_point = point; impact_strength = 1.0
		burst(point,color,2,0.25)
		# The target's material response has its own anchor. Never overwrite the
		# rendered tool contact (which is also used to diagnose reach mismatch).
		resource_impact_point = point
		if activity=="gather" and world.art_nodes.has(target):
			resource_impact_point=world.art_nodes[target].position+Vector2(0,-18)
		burst(resource_impact_point,color,6,0.40,("wood" if target.begins_with("wood") else "stone") if activity=="gather" else "wood")
		if activity=="gather":burst(resource_impact_point,Color(.62,.53,.38,.22) if target.begins_with("wood") else Color(.65,.66,.64,.20),3,.30,"dust")
		else:
			burst(world.site.position+Vector2(0,-35),Color(.76,.65,.46,.28),12,.65,"dust")
			burst(world.site.position+Vector2(0,-70),Color(1,.8,.34,.7),8,.6)
		remember("impact:"+activity)
		if activity=="gather":sound_cue.emit("wood" if target.begins_with("wood") else "stone")
		elif next_hit>=next_build_sound:
			sound_cue.emit("build");build_sound_count+=1
			# Trial cadence: two early phrases, then one phrase every six seconds.
			next_build_sound=next_hit+(1.0 if build_sound_count==1 else 6.0)
		next_hit += HeroMotion.CYCLE
	queue_redraw()

func cancel() -> void:
	world.player.external_work_clock = false
	if target != "" and world.art_nodes.has(target): world.art_nodes[target].get_child(0).rotation = 0
	activity = ""; target = ""; impact_strength = 0
	if is_instance_valid(preview): preview.visible = false
	preview_progress = 0
	if is_instance_valid(world.objectives): world.objectives.redraw()
	queue_redraw()

func clear_transients() -> void:
	cancel(); particles.clear(); notices.clear(); celebration = 0; queue_redraw()

func burst(at: Vector2, color: Color, count: int, lifetime: float, material_kind: String="spark") -> void:
	for i in count:
		var a := TAU*i/count
		particles.append({"p":at,"v":Vector2(cos(a)*65,-48-absf(sin(a))*65),"age":0.0,"life":lifetime,"color":color,"size":3.0+i%2,"material":material_kind,"spin":i*0.75})
	if particles.size() > 120: particles = particles.slice(particles.size()-120)

func gathered(id: String) -> void:
	var kind := "wood" if id.begins_with("wood") else "stone"
	var at: Vector2 = world.art_nodes[id].position+Vector2(0,-35)
	burst(at,Color("f4d58b"),5,0.45)
	remember("credit:"+kind)
	sound_cue.emit("gain")

func built(at: Vector2 = Vector2.INF) -> void:
	celebration = 1.5
	celebration_point=world.site.position if not at.is_finite() else at
	burst(celebration_point+Vector2(0,-90),Color("ffe2a0"),24,1.1)
	remember("built")
	sound_cue.emit("complete")

func rewarded() -> void:
	burst(world.player.position+Vector2(0,-95),Color("f6d88f"),18,0.9)
	remember("reward")
	sound_cue.emit("reward")

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
	# Proximity does not add a second selection ring or arrow under resources.
	if activity == "build":
		draw_build_activity(self,preview.position,VillageLayout.plot_polygon(world.selected_site),pulse,preview_progress)
	for p in particles:
		var color: Color = p.color
		color.a *= 1.0-p.age/p.life
		var extent: float=p.size*(1-p.age/p.life*0.4)
		if p.material=="dust":draw_circle(p.p,extent*(1+p.age*3),color)
		elif p.material=="spark": draw_circle(p.p,extent,color)
		else:
			draw_set_transform(p.p,p.spin+p.age*7)
			if p.material=="wood": draw_colored_polygon(PackedVector2Array([Vector2(-extent,-2),Vector2(extent,-1),Vector2(extent*0.7,2),Vector2(-extent*0.8,1)]),color)
			else: draw_colored_polygon(PackedVector2Array([Vector2(-extent,0),Vector2(-extent*0.3,-extent),Vector2(extent,extent*0.2),Vector2(0,extent)]),color)
			draw_set_transform(Vector2.ZERO)
	for n in notices:
		var alpha := minf(1,(1.45-n.age)*3)
		var at: Vector2 = n.p+Vector2(-48,-n.age*40)
		var font := DemoArt.theme().default_font
		var width := font.get_string_size(n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
		draw_rect(Rect2(at+Vector2(-8,-29),Vector2(width+16,38)),Color(0.20,0.14,0.08,alpha*0.78))
		draw_string_outline(font,at,n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28,3,Color(0.18,0.12,0.06,alpha))
		draw_string(font,at,n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color(1,0.94,0.75,alpha))
	if celebration > 0:
		draw_set_transform(celebration_point+Vector2(0,-35),0,Vector2(1,0.45))
		draw_arc(Vector2.ZERO,115+(1.5-celebration)*35,0,TAU,64,Color(1,0.9,0.61,celebration/1.5),5,true)
		draw_set_transform(Vector2.ZERO)

static func draw_build_activity(canvas:Node2D,point:Vector2,footprint:PackedVector2Array,elapsed:float,progress:float)->void:
	var outline:=footprint.duplicate();outline.append(outline[0]);canvas.draw_polyline(outline,Color(1,.79,.32,.6),3,true)
	for shaft in 7:
		var x:float=sin(shaft*2.4)*125
		var alpha:float=(.12+.045*sin(elapsed*2+shaft))*smoothstep(0,.12,progress)
		var base:=point+Vector2(x,-25)
		canvas.draw_colored_polygon(PackedVector2Array([base+Vector2(-13,0),base+Vector2(13,0),base+Vector2(5,-160),base+Vector2(-5,-160)]),Color(1,.82,.32,alpha))
	for i in 14:
		var t:=fposmod(elapsed*.65+i/14.0,1.0)
		canvas.draw_circle(point+Vector2(sin(i*2.4)*80,-35-t*65),19+t*25,Color(.93,.77,.50,sin(t*PI)*.32))
	for i in 6:
		var t:=fposmod(elapsed*.6+i/6.0,1.0)
		canvas.draw_circle(point+Vector2(sin(i*2.4)*90,-25-t*110),2.5,Color(1,.83,.35,sin(t*PI)*.65))
