class_name DemoWorld
extends Node2D

var model: GameState
var player: DemoPlayer
var selected := ""
var art_nodes := {}
var resource_labels := {}
var site: Node2D
var home: EnvironmentProp
var homes: Array[EnvironmentProp] = []
var water: Polygon2D
var environment_props: Array[EnvironmentProp] = []
var effects_enabled := true
var feedback: WorldFeedback
var objectives: WorldObjectives
var animals: Array[WorldAnimal] = []
# Water visuals and physics share the shoreline traced on terrain.png.
const SHORE = [Vector2(0,320),Vector2(600,430),Vector2(1200,575),Vector2(1800,750),Vector2(2400,835)]
const RIVER_POLYGON = [Vector2(0,175),Vector2(600,270),Vector2(1200,410),Vector2(1800,550),Vector2(2400,680),Vector2(2400,835),Vector2(1800,750),Vector2(1200,575),Vector2(600,430),Vector2(0,320)]

func _init(game: GameState) -> void:
	model = game

func _ready() -> void:
	y_sort_enabled = true
	var terrain: Texture2D = preload(SceneStyle.TERRAIN)
	var background := Sprite2D.new()
	background.name = "Terrain"
	background.texture = terrain
	background.centered = false
	background.scale = Vector2(2400.0/terrain.get_width(),1350.0/terrain.get_height())
	background.z_index = -20
	add_child(background)
	water = Polygon2D.new()
	water.name = "LivingWater"
	water.polygon = PackedVector2Array(RIVER_POLYGON)
	water.texture = terrain
	var coordinates := PackedVector2Array()
	for p in water.polygon: coordinates.append(p/background.scale)
	water.uv = coordinates
	water.z_index = -19
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	water.material = water_material
	add_child(water)
	polygon_body(PackedVector2Array(RIVER_POLYGON))
	prop("hut",Vector2(865,720),300,Vector2(220,80),"ExistingHut")
	get_node("ExistingHut").set_hut_style(0)
	prop("props",Vector2(1020,795),65,Vector2(40,20),"PotteryAndGrindingStone")
	# Approved landscape already contains vegetation. Match its trunks with physics;
	# do not paste a second, unrelated set of trees over the artwork.
	for p in [Vector2(95,750),Vector2(330,800),Vector2(710,930),Vector2(1780,850),Vector2(2090,930),Vector2(1450,645)]:
		rect_body(Rect2(p-Vector2(25,20),Vector2(50,30)))
		if p.x==1780:get_child(get_child_count()-1).name="SettlementTree"
		# Reuse the exact landscape pixels for depth occlusion, not another tree style.
		var canopy:=Polygon2D.new();canopy.name="LandscapeCanopy";canopy.position=p
		canopy.polygon=PackedVector2Array([Vector2(-78,-110),Vector2(-62,-160),Vector2(0,-180),Vector2(70,-145),Vector2(90,-95),Vector2(45,-55),Vector2(-35,-65)])
		canopy.texture=terrain
		var canopy_uv:=PackedVector2Array()
		for point in canopy.polygon:canopy_uv.append((p+point)/background.scale)
		canopy.uv=canopy_uv;add_child(canopy)
	for n in DemoConfig.get_data().nodes:
		var root := Node2D.new()
		root.name = "Resource_"+str(n.id)
		root.position = DemoConfig.point(n.position)
		add_child(root)
		var icon := Sprite2D.new()
		icon.texture = EnvironmentProp.asset("wood") if n.kind == "wood" else EnvironmentProp.asset("rock")
		var width := SceneStyle.WOOD_WIDTH if n.kind == "wood" else SceneStyle.STONE_WIDTH
		icon.scale = Vector2.ONE*width/icon.texture.get_width()
		icon.position.y = -icon.texture.get_height()*icon.scale.y*0.5
		if n.kind=="stone":icon.material=EnvironmentProp.stone_surface()
		root.add_child(icon)
		var contact_shadow:=Polygon2D.new()
		var outline:=PackedVector2Array()
		for k in 32: outline.append(Vector2(cos(k*TAU/32)*width*.48,sin(k*TAU/32)*9))
		contact_shadow.polygon=outline;contact_shadow.color=SceneStyle.SHADOW
		contact_shadow.position=Vector2(5,-5);contact_shadow.z_index=-1;root.add_child(contact_shadow)
		var text := Label.new()
		text.theme = DemoArt.theme()
		text.add_theme_font_size_override("font_size",16)
		text.add_theme_color_override("font_color",Color("fff2cf"))
		text.add_theme_color_override("font_outline_color",Color("34251b"))
		text.add_theme_constant_override("outline_size",6)
		text.position = Vector2(-44,8)
		root.add_child(text)
		art_nodes[n.id] = root
		resource_labels[n.id] = text
		rect_body(Rect2(root.position-Vector2(28,24),Vector2(56,24)))
	site = Node2D.new()
	site.position = DemoConfig.point(DemoConfig.get_data().build_site)
	add_child(site)
	for i in DemoConfig.HOME_GOAL:
		var hut := prop("hut",DemoConfig.HOME_SITES[i],340,Vector2.ZERO,"QuestHome"+str(i))
		homes.append(hut)
	home=homes[0]
	player = DemoPlayer.new()
	player.position = DemoConfig.point(model.state.position)
	add_child(player)
	# Wildlife stays outside the settlement and clear of the demo resource/build routes.
	for entry in [["deer",520,1030,92,-0.8],["rabbit",1660,1040,34,0.6],["rabbit",1730,1090,32,-0.4],["bear",1510,320,70,-0.7]]:
		var animal := WorldAnimal.new()
		animal.name = "Wildlife_"+str(entry[0])+str(animals.size())
		animal.species = entry[0]
		animal.position = Vector2(entry[1],entry[2])
		animal.world_height = entry[3]
		animal.heading = entry[4]
		add_child(animal)
		animals.append(animal)
	objectives=WorldObjectives.new(self);add_child(objectives)
	feedback = WorldFeedback.new(self)
	add_child(feedback)
	add_child(WorldAmbient.new(self))
	model.changed.connect(refresh)
	refresh()
	call_deferred("restore_clear_position")

func restore_clear_position() -> void:
	# Existing saves remain valid when new scenery occupies their old position.
	await get_tree().physics_frame
	# The artwork changed the shoreline. Preserve progress, but never strand an old
	# save on the inaccessible northern bank.
	var bank:=shore_point(clampf(player.position.x/2400.0,0,1))
	if player.position.y<bank.y+25:player.position=DemoConfig.point(DemoConfig.get_data().spawn)
	if not player.test_move(player.transform,Vector2.ZERO,null,0.08,true): return
	var original := player.position
	for radius in [48,96,160,240,360]:
		for i in 16:
			var candidate: Vector2 = original+Vector2.from_angle(i*TAU/16)*float(radius)
			if candidate.x < 40 or candidate.x > 2360 or candidate.y < 40 or candidate.y > 1310: continue
			var at := player.transform
			at.origin = candidate
			if not player.test_move(at,Vector2.ZERO,null,0.08,true):
				player.position = candidate
				return

func prop(key: String, at: Vector2, width: float, footprint: Vector2, node_name: String) -> EnvironmentProp:
	var p := EnvironmentProp.new()
	p.name = node_name
	p.position = at
	p.configure(key,width,footprint,at.x*0.017+at.y*0.023)
	add_child(p)
	environment_props.append(p)
	return p

func shore_point(t: float) -> Vector2:
	var index := clampi(int(t*(SHORE.size()-1)),0,SHORE.size()-2)
	return SHORE[index].lerp(SHORE[index+1],clampf(t*(SHORE.size()-1)-index,0,1))

func set_environment_effects(enabled: bool) -> void:
	effects_enabled = enabled
	water.material.set_shader_parameter("animated",enabled)
	for p in environment_props: p.set_effects_enabled(enabled)
	for animal in animals: animal.effects_enabled = enabled

func rect_body(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func polygon_body(points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.name = "RiverBank"
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	add_child(body)

func refresh() -> void:
	for n in DemoConfig.get_data().nodes:
		art_nodes[n.id].modulate = Color(0.62,0.59,0.48,0.6) if exhausted(n) else Color.WHITE
		resource_labels[n.id].text = "%s %d/%d" % ["나무" if n.kind == "wood" else "돌",int(n.charges)-int(model.state.depleted.get(n.id,0)),int(n.charges)]
	var saved_homes:=model.homes()
	for i in homes.size():
		homes[i].visible=i<saved_homes.size()
		if i>=saved_homes.size():continue
		homes[i].set_hut_style(int(saved_homes[i].style))
		if not has_node("HomeCollision"+str(i)):
			var body := StaticBody2D.new()
			body.name = "HomeCollision"+str(i)
			body.position = homes[i].position+Vector2(0,-60)
			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(220,120)
			collision.shape = shape
			body.add_child(collision)
			add_child(body)
	site.position=DemoConfig.HOME_SITES[mini(model.built_count(),DemoConfig.HOME_GOAL-1)]
	queue_redraw()

func exhausted(n: Dictionary) -> bool:
	return model.state.depleted.get(n.id,0) >= n.charges

func nearest() -> Dictionary:
	var result := {}
	var distance := float(DemoConfig.get_data().interact_radius)
	for n in DemoConfig.get_data().nodes:
		var d := player.position.distance_to(DemoConfig.point(n.position))
		if not exhausted(n) and d < distance:
			distance = d
			result = n
	return result

func near_site() -> bool:
	return model.built_count()<DemoConfig.HOME_GOAL and player.position.distance_to(site.position) < 150 and player.position.y >= site.position.y

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	for animal in animals: animal.presentation_paused = player.presentation_paused
	var id := str(nearest().get("id",""))
	if id != selected:
		selected = id
		queue_redraw()
	for key in resource_labels: resource_labels[key].visible=key==selected

func _draw() -> void:
	if not is_instance_valid(player): return
	for i in model.built_count():
		if model.reward_pending(i):
			var at:Vector2=homes[i].position+Vector2(0,-220)
			draw_circle(at,26,Color(.22,.15,.07,.85))
			draw_arc(at,27,0,TAU,40,Color("ffe6a1"),2,true)
			draw_texture_rect(DemoArt.icon("tokens"),Rect2(at-Vector2(19,19),Vector2(38,38)),false)
	if model.built_count()<DemoConfig.HOME_GOAL:
		draw_set_transform(site.position,0,Vector2(1,0.50))
		draw_circle(Vector2.ZERO,112,Color(0.43,0.30,0.14,0.18))
		draw_arc(Vector2.ZERO,110,0,TAU,64,Color("ffe2a5"),4,true)
		for i in 8:
			var post := Vector2.from_angle(i*TAU/8)*108
			draw_line(post,post-Vector2(0,20),Color("9c703d"),7,true)
		draw_set_transform(Vector2.ZERO)

func gather_stand(target: Vector2, resource_kind: String="wood") -> Vector2:
	# Keep the short contact stance clear of huts and scenery, without teleporting.
	var side: float=-1.0 if player.position.x<=target.x else 1.0
	var reach:=47.0 if resource_kind=="stone" else 53.0
	for x in [side*reach,-side*reach]:
		for y in ([16,24,32] if resource_kind=="stone" else [-8,0,8]):
			var candidate:=target+Vector2(x,y)
			var at:=player.transform;at.origin=candidate
			if not player.test_move(at,Vector2.ZERO,null,0.08,true):return candidate
	return Vector2.INF
