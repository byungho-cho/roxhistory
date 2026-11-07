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
var visitors:Array[TrialResident]=[]
var resource_tweens:Dictionary={}
var resources_initialized:=false
var reward_pouch:AtlasTexture
var reward_bubble:StyleBoxFlat
var reward_markers:Node2D
var reward_roof_bounds:=Rect2()
var boundary_level:=-1
var boundary_debug:=false
var boundary_root:Node2D
var boundary_pulse:Tween
# Water visuals and physics share the shoreline traced on terrain.png.
const SHORE = [Vector2(0,340),Vector2(170,285),Vector2(280,220),Vector2(370,130),Vector2(280,60)]
const RIVER_POLYGON = [Vector2(0,155),Vector2(145,120),Vector2(260,70),Vector2(280,60),Vector2(370,130),Vector2(280,220),Vector2(170,285),Vector2(0,340)]

func _init(game: GameState) -> void:
	model = game

func _ready() -> void:
	y_sort_enabled = true
	reward_roof_bounds=AssetCatalog.texture("BLD-HUT-L1").get_image().get_used_rect()
	reward_pouch=AtlasTexture.new();reward_pouch.atlas=preload("res://assets/ui/seed-pouch-reference-v001.png");reward_pouch.region=Rect2(796,211,196,177);reward_pouch.filter_clip=true
	reward_bubble=StyleBoxFlat.new();reward_bubble.bg_color=Color(.99,.92,.76,.86);reward_bubble.border_color=Color(.55,.39,.22,.85);reward_bubble.set_border_width_all(2);reward_bubble.set_corner_radius_all(12);reward_bubble.shadow_color=Color(0,0,0,.15);reward_bubble.shadow_size=3;reward_bubble.shadow_offset=Vector2(1,3)
	# Review-only low-resolution single image; no repeated/mirrored terrain.
	var terrain: Texture2D = preload("res://assets/village-ground-review-v002/ground-only.png")
	var background := Sprite2D.new()
	background.name = "Terrain"
	background.texture = terrain
	background.centered = false
	# Covers the 4286x2411 minimum-zoom overview with edge bleed.
	# Presentation only: existing object coordinates, movement and saves stay fixed.
	background.position=Vector2(-1200,-675)
	background.scale = Vector2(4800.0/terrain.get_width(),2700.0/terrain.get_height())
	background.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	background.z_index = -20
	add_child(background)

	# Small natural silhouettes entirely outside the expanded movement boundary.
	var mountains:=Node2D.new();mountains.name="NorthernMountains";mountains.z_index=-19;add_child(mountains)
	for entry in [["mountain-a-green-peak.png",500.0,260.0],["mountain-b-low-ridge.png",1100.0,330.0]]:
		var mountain:=Sprite2D.new();mountain.texture=load("res://assets/village-edge-v001/"+str(entry[0]))
		var used:Rect2=mountain.texture.get_image().get_used_rect()
		mountain.centered=false;mountain.offset=-Vector2(used.get_center().x,used.end.y)
		mountain.scale=Vector2.ONE*float(entry[2])/used.size.x;mountain.position=Vector2(float(entry[1]),-420)
		mountains.add_child(mountain)

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
	# Ground-only review has no river art; retain the old reserved shoreline physics.
	# Physics/playable boundaries remain unchanged until terrain review is approved.
	water.hide()
	polygon_body(PackedVector2Array(RIVER_POLYGON))
	boundary_root=Node2D.new();boundary_root.name="UnlockedBoundary";add_child(boundary_root)
	refresh_boundary()
	add_child(VillageLayout.new(model))
	prop("hut",DemoConfig.CHIEF_POSITION,340,Vector2(220,80),"ExistingHut")
	get_node("ExistingHut").set_hut_style(0)
	get_node("ExistingHut").sprite.position.y+=3.0
	prop("props",Vector2(1035,660),65,Vector2(40,20),"PotteryAndGrindingStone")
	get_node("PotteryAndGrindingStone").hide()
	# Clean approved terrain: independent scenery owns both silhouette and footprint.
	# Removed all six legacy canopy masks and five painted-rock collision regions.
	for n in model.nodes():add_resource_art(n)
	site = Node2D.new()
	site.position = DemoConfig.point(DemoConfig.get_data().build_site)
	add_child(site)
	for i in maxi(DemoConfig.MAX_RESIDENT_HOMES,model.built_count()):
		var hut := prop("hut",DemoConfig.BUILD_SITES[i],230,Vector2.ZERO,"QuestHome"+str(i))
		homes.append(hut)
	home=homes[0]
	player = DemoPlayer.new()
	var edge_clouds:=VillageEdgeClouds.new();edge_clouds.player=player;add_child(edge_clouds)
	player.position = DemoConfig.point(model.state.position)
	add_child(player)
	# Wildlife stays outside the settlement and clear of the demo resource/build routes.
	for entry in [["deer",470,430,75,-0.8],["rabbit",1680,1040,30,0.6],["rabbit",1790,1080,28,-0.4],["bear",1950,620,78,-0.7],["deer",600,450,68,0.9],["deer",-350,400,68,0.9],["rabbit",900,-130,30,0.6],["rabbit",2450,1430,30,0.6],["bear",2820,300,78,-0.7]]:
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
	reward_markers=Node2D.new();reward_markers.name="SeedRewards";reward_markers.z_index=12
	add_child(reward_markers);reward_markers.draw.connect(draw_rewards)
	model.changed.connect(reward_markers.queue_redraw)
	add_child(WorldAmbient.new(self))
	add_child(ResourceRegrowth.new(self))
	model.changed.connect(refresh)
	refresh()
	call_deferred("restore_clear_position")

func add_resource_art(n:Dictionary)->void:
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
	var indicator:=ResourceIndicator.new();indicator.kind=str(n.kind);indicator.z_index=10
	root.add_child(indicator)
	art_nodes[n.id]=root
	resource_labels[n.id]=indicator
	rect_body(Rect2(root.position-Vector2(28,24),Vector2(56,24)))
	var resource_body:=get_child(get_child_count()-1)
	resource_body.name="ResourceCollision";resource_body.reparent(root)

func restore_clear_position() -> void:
	# Existing saves remain valid when new scenery occupies their old position.
	await get_tree().physics_frame
	# The artwork changed the shoreline. Preserve progress, but never strand an old
	# save on the inaccessible northern bank.
	if not VillageBounds.rect_for_level(model.chief_level()).grow(-24).has_point(player.position):player.position=DemoConfig.point(DemoConfig.get_data().spawn)
	if not player.test_move(player.transform,Vector2.ZERO,null,0.08,true): return
	var original := player.position
	for radius in [48,96,160,240,360]:
		for i in 16:
			var candidate: Vector2 = original+Vector2.from_angle(i*TAU/16)*float(radius)
			if not VillageBounds.rect_for_level(model.chief_level()).grow(-24).has_point(candidate): continue
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
	refresh_boundary()
	refresh_chief()
	refresh_resources()
	refresh_residents()
	var saved_homes:=model.homes()
	while homes.size()<saved_homes.size():
		var hut:=prop("hut",Vector2.ZERO,230,Vector2.ZERO,"QuestHome"+str(homes.size()))
		homes.append(hut)
	for i in homes.size():
		homes[i].visible=i<saved_homes.size()
		if i>=saved_homes.size():
			var old_body:=get_node_or_null("HomeCollision"+str(i))
			if old_body:remove_child(old_body);old_body.queue_free()
			continue
		homes[i].position=model.home_position(i)
		homes[i].set_hut_style(int(saved_homes[i].style))
		var level:=int(saved_homes[i].get("level",1))
		BuildingVisuals.apply(homes[i].sprite,"home",level,230)
		homes[i].sprite.position.y-=homes[i].depth_visual.position.y
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
	refresh_outposts()
	refresh_facilities()
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
	var image:Sprite2D=homes[index].sprite
	var roof_local:=reward_roof_bounds.position+Vector2(reward_roof_bounds.size.x*.5,0)-image.texture.get_size()*.5
	var roof:=to_local(image.to_global(roof_local))
	# Tail tip stays three logical world pixels above the visible roof, including scaling.
	return Rect2(roof-Vector2(36,70),Vector2(72,67))

func reward_hit(index:int,at:Vector2)->bool:
	return reward_marker_rect(index).grow(10).has_point(at) or Rect2(homes[index].position-Vector2(150,245),Vector2(300,260)).has_point(at)

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	for animal in animals: animal.presentation_paused = player.presentation_paused
	var id := str(nearest().get("id",""))
	if id != selected:
		selected = id
		queue_redraw()
	for key in resource_labels:
		var indicator:ResourceIndicator=resource_labels[key]
		var icon:Sprite2D=art_nodes[key].get_child(0)
		indicator.update_geometry(icon.texture.get_height()*icon.scale.y,player.camera.zoom.x)
		indicator.visible=art_nodes[key].visible

func _draw() -> void:
	if not is_instance_valid(player): return
	if show_candidates:
		for id in DemoConfig.BUILD_SITES.size():
			if not model.site_free(id):continue
			draw_site(DemoConfig.BUILD_SITES[id],id==selected_site)

func draw_rewards()->void:
	for i in model.built_count():
		if model.reward_pending(i):
			var rect:=reward_marker_rect(i)
			var body:=Rect2(rect.position,Vector2(rect.size.x,rect.size.y-8))
			reward_markers.draw_style_box(reward_bubble,body)
			var tip:=Vector2(rect.get_center().x,rect.end.y)
			var tail:=PackedVector2Array([tip+Vector2(-7,-9),tip,tip+Vector2(7,-9)])
			reward_markers.draw_colored_polygon(tail,reward_bubble.bg_color)
			reward_markers.draw_polyline(tail,reward_bubble.border_color,2,true)
			reward_markers.draw_texture_rect(AssetCatalog.texture("UI-SEED"),Rect2(body.position+Vector2(10,5),Vector2(52,48)),false)

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
	for id in DemoConfig.BUILD_SITES.size():
		if model.site_free(id) and Geometry2D.is_point_in_polygon(at,VillageLayout.plot_polygon(id)):return id
	return -1

func site_available(id:int)->bool:
	if not model.site_free(id):return false
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

func refresh_outposts()->void:
	var wanted:Array[String]=[]
	for entry in model.outposts():
		var node_name:String="Outpost_"+str(entry.uid)
		wanted.append(node_name)
		var texture:=BuildingWorkflow.approved_texture("BLD-OUTPOST-L%d"%int(entry.get("level",1)))
		if texture==null:continue
		var body:=get_node_or_null(node_name) as StaticBody2D
		if body==null:
			body=StaticBody2D.new();body.name=node_name;body.visibility_layer=2
			var image:=Sprite2D.new();image.visibility_layer=2
			image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;body.add_child(image)
			add_building_collision(body,230)
			add_child(body)
		body.position=model.building_position("outpost:"+str(entry.uid))
		BuildingVisuals.apply(body.get_child(0),"outpost",int(entry.get("level",1)),230)
	remove_stale_buildings("Outpost_",wanted)

func refresh_facilities()->void:
	var wanted:Array[String]=[]
	for entry in model.facilities():
		var node_name:String="Facility_"+str(entry.uid)
		wanted.append(node_name)
		var kind:=str(entry.kind)
		var asset:="BLD-%s-L%d"%[kind.to_upper(),int(entry.get("level",1))]
		var texture:=BuildingWorkflow.approved_texture(asset)
		if texture==null:continue
		var body:=get_node_or_null(node_name) as StaticBody2D
		if body==null:
			body=StaticBody2D.new();body.name=node_name;body.visibility_layer=2
			var image:=Sprite2D.new();image.visibility_layer=2
			image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;body.add_child(image)
			add_building_collision(body,230)
			add_child(body)
		body.position=model.building_position(kind+":"+str(entry.uid))
		var sprite:=body.get_child(0) as Sprite2D
		BuildingVisuals.apply(sprite,kind,int(entry.get("level",1)),230)
	remove_stale_buildings("Facility_",wanted)

func add_building_collision(body:StaticBody2D,width:float)->void:
	var collision:=CollisionShape2D.new();var shape:=ConvexPolygonShape2D.new()
	shape.points=EnvironmentProp.hut_footprint(width);collision.shape=shape;body.add_child(collision)

func remove_stale_buildings(prefix:String,wanted:Array[String])->void:
	for child in get_children():
		if str(child.name).begins_with(prefix) and not str(child.name) in wanted:
			remove_child(child);child.queue_free()

func building_sprite(key:String)->Sprite2D:
	if key=="chief":return get_node("ExistingHut").sprite if model.chief_level()>0 else null
	var found:=model.lookup_building(key)
	if found.is_empty():return null
	if found.collection=="homes":
		var index:=int(found.index)
		return homes[index].sprite if index>=0 and index<homes.size() else null
	var prefix:="Outpost_" if found.collection=="outposts" else "Facility_"
	var body:=get_node_or_null(prefix+str(found.data.uid))
	return body.get_child(0) as Sprite2D if body!=null else null

func completed_building_positions()->Array:
	var result:Array=[]
	if model.chief_level()>0:result.append(model.building_position("chief"))
	for i in model.built_count():result.append(model.home_position(i))
	for i in model.outposts().size():result.append(model.outpost_position(i))
	for entry in model.facilities():result.append(model.building_position(str(entry.kind)+":"+str(entry.uid)))
	return result

func placement_requirement(kind:String,at:Vector2,ignore_key:String="")->String:
	var reason:=model.placement_requirement(kind,at,ignore_key)
	if not reason.is_empty():return reason
	if not at.is_finite():return "마을 안의 위치를 선택해 주세요"
	var width:=340.0 if kind=="chief" else 230.0
	var points:=EnvironmentProp.hut_footprint(width)
	for point in points:
		if not playable_rect().grow(-24).has_point(at+point):return "마을 경계 안에 지어 주세요"
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=ConvexPolygonShape2D.new()
	shape.points=points;query.shape=shape;query.transform=Transform2D(0,at);query.margin=12
	var excluded:Array[RID]=[]
	if not ignore_key.is_empty():
		var found:=model.lookup_building(ignore_key)
		if not found.is_empty():
			var body:CollisionObject2D
			if ignore_key=="chief":body=get_node("ExistingHut/Footprint")
			elif found.collection=="homes":body=get_node_or_null("HomeCollision"+str(found.index))
			else:body=get_node_or_null(("Outpost_" if found.collection=="outposts" else "Facility_")+str(found.data.uid))
			if body!=null:excluded.append(body.get_rid())
	for animal in animals:
		if is_instance_valid(animal.footprint_body):excluded.append(animal.footprint_body.get_rid())
	query.exclude=excluded
	if not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():return "건물·자원·주민과 겹치지 않는 곳을 선택해 주세요"
	return ""

func evacuate_animals(at:Vector2,kind:String)->void:
	var width:=340.0 if kind=="chief" else 230.0
	for animal in animals:
		if ((animal.position-at)/Vector2(width*.65,width*.4)).length()>1.0:continue
		var relocated:=false
		for radius in [width, width*1.5, width*2.0, width*3.0, 1200.0]:
			for i in 32:
				var candidate:Vector2=at+Vector2.from_angle(i*TAU/32.0)*radius
				if animal.safe_ground(candidate):
					animal.position=candidate;animal.home_position=candidate;animal.destination=candidate;animal.resting=1.0
					relocated=true;break
			if relocated:break

func refresh_boundary()->void:
	if boundary_level==model.chief_level() and boundary_debug==model.debug_show_boundary:return
	boundary_level=model.chief_level();boundary_debug=model.debug_show_boundary
	if boundary_pulse!=null:boundary_pulse.kill()
	for child in boundary_root.get_children():
		boundary_root.remove_child(child);child.queue_free()
	var polygon:=VillageBounds.polygon_for_level(boundary_level)
	for i in polygon.size():
		var boundary:=StaticBody2D.new();boundary.name="VillageBoundary"
		var edge:=CollisionShape2D.new();var segment:=SegmentShape2D.new()
		segment.a=polygon[i];segment.b=polygon[(i+1)%polygon.size()]
		edge.shape=segment;boundary.add_child(edge);boundary_root.add_child(boundary)
	var outline:=Line2D.new();outline.name="UnlockedPerimeter";outline.points=polygon;outline.closed=true
	outline.width=3;outline.default_color=Color("ed514b");outline.z_index=-14
	outline.visible=boundary_debug;boundary_root.add_child(outline)

func playable_rect()->Rect2:
	return VillageBounds.rect_for_level(model.chief_level())

func refresh_chief()->void:
	var chief:=get_node("ExistingHut") as EnvironmentProp
	var exists:=model.chief_level()>0
	chief.visible=exists
	if exists:
		chief.position=model.building_position("chief")
		BuildingVisuals.apply(chief.sprite,"chief",model.chief_level(),340)
		chief.sprite.position.y-=chief.depth_visual.position.y
	var body:=chief.get_node("Footprint") as StaticBody2D
	body.collision_layer=1 if exists else 0
	body.collision_mask=1 if exists else 0
	body.get_child(0).set_deferred("disabled",not exists)

func refresh_resources()->void:
	var active:Array[String]=[]
	var reveal_index:=0
	for n in model.nodes():
		active.append(str(n.id))
		var created:=not art_nodes.has(n.id)
		if created:add_resource_art(n)
		var node:=art_nodes[n.id] as Node2D
		var was_active:=bool(node.get_meta("resource_active",false))
		var alive:=not exhausted(n)
		node.position=DemoConfig.point(n.position)
		node.set_meta("resource_active",alive)
		# Harvestability and collision change immediately, independent of the fade.
		var body:=node.get_node("ResourceCollision") as StaticBody2D
		body.collision_layer=1 if alive else 0
		body.collision_mask=1 if alive else 0
		body.get_child(0).set_deferred("disabled",not alive)
		if alive and (not was_active or created):
			resource_transition(str(n.id),true,float(reveal_index)*.10 if resources_initialized else 0.0,resources_initialized)
			reveal_index+=1
		elif not alive and was_active:resource_transition(str(n.id),false)
		elif not alive and not was_active and not resource_tweens.has(n.id):node.hide()
		if not alive and selected==str(n.id):selected=""
		resource_labels[n.id].update_amount(float(n.charges)-float(model.state.depleted.get(n.id,0)),float(n.charges))
	for id in art_nodes:
		if str(id) in active:continue
		var node:=art_nodes[id] as Node2D
		node.hide();node.set_meta("resource_active",false)
		var body:=node.get_node("ResourceCollision") as StaticBody2D
		body.collision_layer=0;body.collision_mask=0
		body.get_child(0).set_deferred("disabled",true)
	resources_initialized=true

func resource_transition(id:String,reveal:bool,delay:float=0.0,animate:bool=true)->void:
	if resource_tweens.has(id):
		var old:=resource_tweens[id] as Tween
		if old!=null:old.kill()
		resource_tweens.erase(id)
	var node:=art_nodes[id] as Node2D
	if not animate:
		node.visible=reveal;node.modulate=Color.WHITE;return
	node.show()
	var tween:=create_tween();resource_tweens[id]=tween
	if reveal:
		node.modulate=Color(1,1,1,0)
		if delay>0:tween.tween_interval(delay)
		tween.tween_property(node,"modulate:a",1.0,.55).set_trans(Tween.TRANS_SINE)
	else:
		tween.tween_property(node,"modulate:a",.22,.12)
		tween.tween_property(node,"modulate:a",.85,.12)
		tween.tween_property(node,"modulate:a",.18,.12)
		tween.tween_property(node,"modulate:a",.7,.12)
		tween.tween_property(node,"modulate:a",0.0,.32)
		tween.tween_callback(node.hide)
	tween.tween_callback(func():resource_tweens.erase(id))

func refresh_residents()->void:
	var admitted:=model.resident_count()
	while residents.size()>admitted:
		var actor:TrialResident=residents.pop_back();remove_child(actor);actor.queue_free()
	while residents.size()<admitted:
		var index:=residents.size()
		var resident:=TrialResident.new();resident.variant="female" if index%2==0 else "sturdy_male"
		resident.resident_id="resident-%d"%index;resident.name="Resident_%d"%index
		resident.position=resident_spawn_position(index);add_child(resident);residents.append(resident)
	var visiting:=model.family_visitor_count() if model.family_available() else 0
	while visitors.size()>visiting:
		var visitor:TrialResident=visitors.pop_back();remove_child(visitor);visitor.queue_free()
	while visitors.size()<visiting:
		var index:=visitors.size()
		var visitor:=TrialResident.new();visitor.variant="female" if index%2==0 else "sturdy_male"
		visitor.resident_id="visitor-%d"%index;visitor.name="Visitor_%d"%index
		visitor.position=Vector2(1570+index*40,920-index%2*30);add_child(visitor)
		visitor.collision_layer=0;visitor.collision_mask=0;visitor.set_physics_process(false);visitors.append(visitor)

func resident_spawn_position(index:int)->Vector2:
	var center:=model.home_position(index%model.built_count()) if model.built_count()>0 else DemoConfig.point(model.state.position)
	for radius in [100.0,150.0,210.0,280.0]:
		for step in 16:
			var at:Vector2=center+Vector2.from_angle((step+index)*TAU/16.0)*radius
			var pose:=player.transform;pose.origin=at
			if playable_rect().grow(-32).has_point(at) and not player.test_move(pose,Vector2.ZERO,null,.08,true):return at
	return DemoConfig.point(model.state.position)
