class_name DemoWorld
extends Node2D

var model: GameState
var player: DemoPlayer
var selected := ""
var art_nodes := {}
var resource_labels := {}
var selected_site:=0
var show_candidates:=false
var site: Node2D
var home: EnvironmentProp
var homes: Array[EnvironmentProp] = []
var water: Polygon2D
var environment_props: Array[EnvironmentProp] = []
var effects_enabled := true
var feedback: WorldFeedback
var objectives: WorldObjectives
var animals: Array[WorldAnimal] = []
var residents:Array[TrialResident]=[]
var reward_pouch:AtlasTexture
var reward_bubble:StyleBoxFlat
# Water visuals and physics share the shoreline traced on terrain.png.
const SHORE = [Vector2(0,340),Vector2(170,285),Vector2(280,220),Vector2(370,130),Vector2(280,60)]
const RIVER_POLYGON = [Vector2(0,155),Vector2(145,120),Vector2(260,70),Vector2(280,60),Vector2(370,130),Vector2(280,220),Vector2(170,285),Vector2(0,340)]

func _init(game: GameState) -> void:
	model = game

func _ready() -> void:
	y_sort_enabled = true
	reward_pouch=AtlasTexture.new();reward_pouch.atlas=preload("res://assets/ui/seed-pouch-reference-v001.png");reward_pouch.region=Rect2(796,211,196,177);reward_pouch.filter_clip=true
	reward_bubble=StyleBoxFlat.new();reward_bubble.bg_color=Color(.99,.92,.76,.86);reward_bubble.border_color=Color(.55,.39,.22,.85);reward_bubble.set_border_width_all(2);reward_bubble.set_corner_radius_all(12);reward_bubble.shadow_color=Color(0,0,0,.15);reward_bubble.shadow_size=3;reward_bubble.shadow_offset=Vector2(1,3)
	var terrain: Texture2D = preload(SceneStyle.TERRAIN)
	var background := Sprite2D.new()
	background.name = "Terrain"
	background.texture = terrain
	background.centered = false
	background.scale = Vector2(2400.0/terrain.get_width(),1350.0/terrain.get_height())
	background.z_index = -20
	add_child(background)
	var margin:=Sprite2D.new();margin.name="OverviewMargin";margin.texture=terrain; margin.centered=false
	margin.position=Vector2(-672,-378);margin.scale=background.scale*1.56;margin.z_index=-18
	var margin_material:=ShaderMaterial.new();margin_material.shader=preload("res://shaders/overview_margin.gdshader");margin.material=margin_material;add_child(margin)
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
	for i in VillageLayout.PLAYABLE.size():
		var a:Vector2=VillageLayout.PLAYABLE[i];var b:Vector2=VillageLayout.PLAYABLE[(i+1)%VillageLayout.PLAYABLE.size()]
		var boundary:=StaticBody2D.new();boundary.name="VillageBoundary"
		var edge:=CollisionShape2D.new();var segment:=SegmentShape2D.new();segment.a=a;segment.b=b;edge.shape=segment;boundary.add_child(edge);add_child(boundary)
	add_child(VillageLayout.new(model))
	prop("hut",DemoConfig.CHIEF_POSITION,340,Vector2(220,80),"ExistingHut")
	get_node("ExistingHut").set_hut_style(0)
	prop("props",Vector2(1035,660),65,Vector2(40,20),"PotteryAndGrindingStone")
	# Clean approved terrain: independent scenery owns both silhouette and footprint.
	# Removed all six legacy canopy masks and five painted-rock collision regions.
	for n in model.nodes():
		var root := Node2D.new()
		root.name = "Resource_"+str(n.id)
		root.position = DemoConfig.point(n.position)
		add_child(root)
		var icon := Sprite2D.new()
		icon.texture = AssetCatalog.texture("ENV-TREE" if n.kind == "wood" else "ENV-ROCK")
		var scale_class:float={"small":0.72,"medium":0.86,"large":1.0}.get(n.get("size","large"),1.0)
		var width:float=(200.0 if n.kind=="wood" else 125.0)*scale_class
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
		var resource_body:=get_child(get_child_count()-1)
		resource_body.name="ResourceCollision";resource_body.reparent(root)
	site = Node2D.new()
	site.position = DemoConfig.point(DemoConfig.get_data().build_site)
	add_child(site)
	for i in DemoConfig.MAX_RESIDENT_HOMES:
		var hut := prop("hut",DemoConfig.BUILD_SITES[i],230,Vector2.ZERO,"QuestHome"+str(i))
		homes.append(hut)
	home=homes[0]
	player = DemoPlayer.new()
	player.position = DemoConfig.point(model.state.position)
	add_child(player)
	# Wildlife stays outside the settlement and clear of the demo resource/build routes.
	for entry in [["deer",470,430,75,-0.8],["rabbit",1680,1040,30,0.6],["rabbit",1790,1080,28,-0.4],["bear",1950,620,78,-0.7],["deer",600,450,68,0.9]]:
		var animal := WorldAnimal.new()
		animal.name = "Wildlife_"+str(entry[0])+str(animals.size())
		animal.species = entry[0]
		animal.position = Vector2(entry[1],entry[2])
		animal.world_height = entry[3]
		animal.heading = entry[4]
		add_child(animal)
		animals.append(animal)
	for entry in [["female",1610,890],["sturdy_male",1570,920]]:
		var resident:=TrialResident.new();resident.variant=entry[0];resident.name="TrialResident_"+str(entry[0]);resident.position=Vector2(entry[1],entry[2]);add_child(resident);residents.append(resident)
		resident.visible=model.state.get("family_joined",false) or model.family_available()
		resident.set_physics_process(model.state.get("family_joined",false))
	objectives=WorldObjectives.new(self);add_child(objectives)
	feedback = WorldFeedback.new(self)
	add_child(feedback)
	add_child(WorldAmbient.new(self))
	add_child(ResourceRegrowth.new(self))
	model.changed.connect(refresh)
	refresh()
	call_deferred("restore_clear_position")

func restore_clear_position() -> void:
	# Existing saves remain valid when new scenery occupies their old position.
	await get_tree().physics_frame
	# The artwork changed the shoreline. Preserve progress, but never strand an old
	# save on the inaccessible northern bank.
	if not VillageLayout.ground_ok(player.position):player.position=DemoConfig.point(DemoConfig.get_data().spawn)
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
	for n in model.nodes():
		art_nodes[n.id].position=DemoConfig.point(n.position)
		art_nodes[n.id].visible=not exhausted(n)
		art_nodes[n.id].modulate=Color.WHITE
		art_nodes[n.id].get_node("ResourceCollision").get_child(0).set_deferred("disabled",exhausted(n))
		if exhausted(n) and selected==str(n.id):selected=""
		resource_labels[n.id].text = "%s %d/%d" % ["나무" if n.kind == "wood" else "돌",int(n.charges)-int(model.state.depleted.get(n.id,0)),int(n.charges)]
	for resident in residents:
		resident.visible=model.state.get("family_joined",false) or model.family_available()
		resident.collision_layer=1 if resident.visible else 0
		resident.set_physics_process(model.state.get("family_joined",false))
	var saved_homes:=model.homes()
	for i in homes.size():
		homes[i].visible=i<saved_homes.size()
		if i>=saved_homes.size():
			var old_body:=get_node_or_null("HomeCollision"+str(i))
			if old_body:remove_child(old_body);old_body.queue_free()
			continue
		homes[i].position=model.home_position(i)
		homes[i].set_hut_style(int(saved_homes[i].style))
		if not has_node("HomeCollision"+str(i)):
			var body := StaticBody2D.new()
			body.name = "HomeCollision"+str(i)
			body.position = homes[i].position
			var collision := CollisionShape2D.new()
			var shape := ConvexPolygonShape2D.new()
			shape.points = EnvironmentProp.hut_footprint(230)
			collision.shape = shape
			body.add_child(collision)
			add_child(body)
		get_node("HomeCollision"+str(i)).position=homes[i].position
	if selected_site>=0 and not model.site_free(selected_site):selected_site=-1
	if selected_site>=0:site.position=DemoConfig.BUILD_SITES[selected_site]
	elif model.built_count()<DemoConfig.MAX_RESIDENT_HOMES:
		for id in DemoConfig.BUILD_SITES.size():
			if model.site_free(id):site.position=DemoConfig.BUILD_SITES[id];break
	queue_redraw()

func exhausted(n: Dictionary) -> bool:
	return model.state.depleted.get(n.id,0) >= n.charges

func nearest() -> Dictionary:
	var result := {}
	var distance := float(DemoConfig.get_data().interact_radius)
	for n in model.nodes():
		var d := player.position.distance_to(DemoConfig.point(n.position))
		if not exhausted(n) and d < distance:
			distance = d
			result = n
	return result

func near_site() -> bool:
	return selected_site>=0 and model.site_free(selected_site) and model.built_count()<DemoConfig.MAX_RESIDENT_HOMES and player.position.distance_to(site.position) < 150 and player.position.y >= site.position.y

func interaction_at(screen_point:Vector2)->bool:
	var at:=get_global_transform_with_canvas().affine_inverse()*screen_point
	for n in model.nodes():
		if resource_hit(n,at):return true
	if site_at(at)>=0:return true
	for i in model.built_count():
		if model.reward_pending(i) and reward_hit(i,at):return true
	return false

func resource_hit(n:Dictionary,at:Vector2)->bool:
	if exhausted(n):return false
	var root:Node2D=art_nodes[n.id]
	var image:Sprite2D=root.get_child(0)
	return image.get_rect().has_point(image.transform.affine_inverse()*(at-root.position))

func reward_marker_rect(index:int)->Rect2:
	return Rect2(homes[index].position+Vector2(76,-244),Vector2(72,67))

func reward_hit(index:int,at:Vector2)->bool:
	return reward_marker_rect(index).grow(10).has_point(at) or Rect2(homes[index].position-Vector2(150,245),Vector2(300,260)).has_point(at)

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
			var box:=reward_marker_rect(i)
			var tail:=PackedVector2Array([box.position+Vector2(12,54),box.position+Vector2(2,78),box.position+Vector2(31,62)])
			draw_colored_polygon(tail,reward_bubble.bg_color)
			draw_polyline(tail,reward_bubble.border_color,2,true)
			draw_style_box(reward_bubble,box)
			draw_texture_rect(reward_pouch,Rect2(box.position+Vector2(7,7),Vector2(58,52)),false)
	if show_candidates and model.built_count()<DemoConfig.MAX_RESIDENT_HOMES:
		for id in DemoConfig.BUILD_SITES.size():
			if not model.site_free(id):continue
			draw_site(DemoConfig.BUILD_SITES[id],id==selected_site)

func draw_site(at:Vector2,chosen:bool)->void:
	var id:=DemoConfig.BUILD_SITES.find(at)
	if id<0:return
	var p:=VillageLayout.plot_polygon(id);var ring:=p.duplicate();ring.append(p[0])
	draw_colored_polygon(p,Color(.83,.66,.30,.15 if chosen else .045))
	draw_polyline(ring,Color(.96,.84,.54,.8 if chosen else .3),2,true)
	for i in 4:
		var post:=p[i];var next:=p[(i+1)%4]
		draw_polyline(PackedVector2Array([post-Vector2(0,16),post.lerp(next,.5)-Vector2(0,9),next-Vector2(0,16)]),Color(.65,.48,.26,.65),2,true)
		draw_line(post,post-Vector2(0,24),Color("88623c"),6,true)
		draw_line(post-Vector2(1,1),post-Vector2(1,24),Color("d6b777"),2,true)

func site_at(at:Vector2)->int:
	if model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES:return -1
	for id in DemoConfig.BUILD_SITES.size():
		if model.site_free(id) and Geometry2D.is_point_in_polygon(at,VillageLayout.plot_polygon(id)):return id
	return -1

func site_available(id:int)->bool:
	if not model.site_free(id) or model.built_count()>=DemoConfig.MAX_RESIDENT_HOMES:return false
	var at:Vector2=DemoConfig.BUILD_SITES[id]
	for animal in animals:
		if Geometry2D.is_point_in_polygon(animal.position,VillageLayout.plot_polygon(id)):return false
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=ConvexPolygonShape2D.new()
	shape.points=VillageLayout.plot_polygon(id);query.shape=shape;query.transform=Transform2D.IDENTITY;query.margin=8
	query.exclude=[player.get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func select_site(id:int)->bool:
	if not site_available(id):return false
	selected_site=id;site.position=DemoConfig.BUILD_SITES[id];queue_redraw();objectives.redraw();return true

func clear_site()->void:
	selected_site=-1;queue_redraw();objectives.redraw()

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
