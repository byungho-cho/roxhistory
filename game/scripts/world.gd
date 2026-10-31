class_name DemoWorld
extends Node2D

var model: GameState
var player: DemoPlayer
var selected := ""
var art_nodes := {}
var resource_labels := {}
var site: Node2D
var home: EnvironmentProp
var water: Polygon2D
var environment_props: Array[EnvironmentProp] = []
var effects_enabled := true
var feedback: WorldFeedback
var objectives: WorldObjectives
# Water visuals and physics share the shoreline traced on terrain.png.
const SHORE = [Vector2(690,0),Vector2(790,100),Vector2(1000,201),Vector2(1249,287),Vector2(1478,402),Vector2(1722,488),Vector2(1981,552),Vector2(2167,631),Vector2(2400,689)]
const RIVER_POLYGON = [Vector2(690,0),Vector2(2400,0),Vector2(2400,689),Vector2(2167,631),Vector2(1981,552),Vector2(1722,488),Vector2(1478,402),Vector2(1249,287),Vector2(1000,201),Vector2(790,100)]

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
	prop("hut",Vector2(700,510),380,Vector2(270,100),"ExistingHut")
	prop("hut",Vector2(360,720),390,Vector2(285,110),"VillageHut")
	prop("hut",Vector2(990,740),400,Vector2(260,100),"RiversideHut")
	prop("props",Vector2(1140,790),100,Vector2(60,24),"RiversidePottery")
	prop("props",Vector2(700,610),108,Vector2(65,28),"PotteryAndGrindingStone")
	prop("props",Vector2(570,935),100,Vector2(60,24),"FishingNet")
	for entry in [[180,680,330],[320,400,310],[530,270,285],[1110,620,260],[1700,1060,290],[2120,1150,320],[80,1190,280],[1150,1350,210],[2290,840,260]]:
		prop("tree",Vector2(entry[0],entry[1]),entry[2],Vector2(54,38),"SettlementTree" if entry[0]==1700 else "Tree")
	for entry in [[900,380,108],[1330,410,84],[1570,510,102],[1860,600,90],[2070,700,115],[2300,770,90],[280,1140,95],[1470,1210,80]]:
		prop("rock",Vector2(entry[0],entry[1]),entry[2],Vector2(entry[2]*0.65,30),"BankStone")
	for entry in [[800,340,120],[1440,470,130],[1810,620,140],[2200,810,125],[300,1230,145],[1900,1250,155]]:
		prop("shrub",Vector2(entry[0],entry[1]),entry[2],Vector2(35,24),"WillowShrub")
	# Deterministic varied sizes and wind phases, leaving quest routes open.
	for i in 36:
		var t := float(i)/35.0
		var p := shore_point(t)+Vector2(-30,68+sin(i*2.2)*22)
		prop("grass",p,42+fposmod(i*19.0,38),Vector2.ZERO,"BankReeds")
	for entry in [[290,940,58],[350,1040,50],[610,1170,65],[900,1160,45],[1110,1160,48],[1500,1110,55],[1730,1190,60],[2040,910,50],[400,580,48],[1010,700,42],[1100,1240,58],[2280,1190,65]]:
		prop("grass",Vector2(entry[0],entry[1]),entry[2],Vector2.ZERO,"MeadowGrass")
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
	home = prop("hut",site.position,340,Vector2.ZERO,"QuestHome")
	player = DemoPlayer.new()
	player.position = DemoConfig.point(model.state.position)
	add_child(player)
	objectives=WorldObjectives.new(self);add_child(objectives)
	feedback = WorldFeedback.new(self)
	add_child(feedback)
	model.changed.connect(refresh)
	refresh()
	call_deferred("restore_clear_position")

func restore_clear_position() -> void:
	# Existing saves remain valid when new scenery occupies their old position.
	await get_tree().physics_frame
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
	home.visible = model.state.built
	if model.state.built and not has_node("HomeCollision"):
		var body := StaticBody2D.new()
		body.name = "HomeCollision"
		body.position = site.position+Vector2(0,-60)
		var collision := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(220,120)
		collision.shape = box
		body.add_child(collision)
		add_child(body)
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
	return player.position.distance_to(site.position) < 150 and player.position.y >= site.position.y

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	var id := str(nearest().get("id",""))
	if id != selected:
		selected = id
		queue_redraw()
	for key in resource_labels: resource_labels[key].visible=key==selected

func _draw() -> void:
	if not is_instance_valid(player): return
	for n in DemoConfig.get_data().nodes:
		var p := DemoConfig.point(n.position)
		draw_set_transform(p,0,Vector2(1,0.42))
		draw_arc(Vector2.ZERO,63,0,TAU,48,Color("ffe39b") if n.id == selected else Color(0.95,0.81,0.43,0.45),3,true)
		draw_set_transform(Vector2.ZERO)
	if not model.state.built:
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
		for y in [0,16,32]:
			var candidate:=target+Vector2(x,y)
			var at:=player.transform;at.origin=candidate
			if not player.test_move(at,Vector2.ZERO,null,0.08,true):return candidate
	return Vector2.INF
