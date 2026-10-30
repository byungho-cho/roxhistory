class_name DemoWorld
extends Node2D

var model: GameState
var player: DemoPlayer
var selected := ""
var art_nodes := {}
var site: Node2D
var home: Sprite2D
const RIVER_POLYGON = [Vector2(860,0),Vector2(2400,0),Vector2(2400,820),Vector2(2160,700),Vector2(1890,630),Vector2(1650,540),Vector2(1410,500),Vector2(1190,360),Vector2(900,280)]

func _init(game: GameState) -> void:
	model = game

func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = preload("res://assets/figma/98398.png")
	background.centered = false
	background.scale = Vector2(2400.0/1672.0,1350.0/941.0)
	background.z_index = -10
	add_child(background)
	polygon_body(PackedVector2Array(RIVER_POLYGON))
	for rect in [Rect2(15,350,370,290),Rect2(420,230,420,280),Rect2(870,470,350,210),
		Rect2(1740,630,140,110),Rect2(1450,1160,590,150),Rect2(0,0,2400,100)]:
		rect_body(rect)
	for n in DemoConfig.get_data().nodes:
		var root := Node2D.new()
		root.position = DemoConfig.point(n.position)
		add_child(root)
		var icon := Sprite2D.new()
		icon.texture = DemoArt.icon(n.kind)
		icon.scale = Vector2(0.22,0.22)
		icon.position.y = -30
		root.add_child(icon)
		var text := Label.new()
		text.theme = DemoArt.theme()
		text.text = "나무" if n.kind == "wood" else "돌"
		text.add_theme_color_override("font_color",Color("fff2cf"))
		text.add_theme_color_override("font_outline_color",Color("34251b"))
		text.add_theme_constant_override("outline_size",6)
		text.position = Vector2(-30,10)
		root.add_child(text)
		art_nodes[n.id] = root
		rect_body(Rect2(root.position-Vector2(19,17),Vector2(38,34)))
	site = Node2D.new()
	site.position = DemoConfig.point(DemoConfig.get_data().build_site)
	add_child(site)
	home = Sprite2D.new()
	home.texture = DemoArt.icon("hut")
	home.scale = Vector2(0.8,0.8)
	home.position.y = -95
	site.add_child(home)
	player = DemoPlayer.new()
	player.position = DemoConfig.point(model.state.position)
	add_child(player)
	model.changed.connect(refresh)
	refresh()

func rect_body(rect: Rect2) -> void:
	var b := StaticBody2D.new()
	b.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	b.add_child(shape)
	add_child(b)

func polygon_body(points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.name = "RiverBank"
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	add_child(body)

func refresh() -> void:
	for n in DemoConfig.get_data().nodes:
		art_nodes[n.id].modulate = Color(0.5,0.5,0.5,0.45) if exhausted(n) else Color.WHITE
		var text: Label = art_nodes[n.id].get_child(1)
		text.text = ("%s %d/%d" % ["나무" if n.kind == "wood" else "돌",int(n.charges)-int(model.state.depleted.get(n.id,0)),int(n.charges)])
	home.visible = model.state.built
	if model.state.built and not has_node("HomeCollision"):
		var body := StaticBody2D.new()
		body.name = "HomeCollision"
		body.position = site.position+Vector2(0,-72)
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
	if not is_instance_valid(player):
		return
	var n := nearest()
	var id := str(n.get("id",""))
	if id != selected:
		selected = id
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	for n in DemoConfig.get_data().nodes:
		if n.id == selected:
			draw_arc(DemoConfig.point(n.position),60,0,TAU,48,Color("ffe39b"),4,true)
	if not model.state.built:
		var p := DemoConfig.point(DemoConfig.get_data().build_site)
		draw_arc(p,110,0,TAU,64,Color("ffe2a5"),4,true)
		draw_line(p-Vector2(30,0),p+Vector2(30,0),Color("ffe2a5"),3,true)
		draw_line(p-Vector2(0,30),p+Vector2(0,30),Color("ffe2a5"),3,true)
