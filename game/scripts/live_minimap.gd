class_name LiveMinimap
extends Node
## Low-resolution, throttled render of the real scene. No copied gameplay state.
const PIXELS:=192
const CONTENT_ZOOM:=0.7
var app:Node
var village_view:SubViewport
var map_view:SubViewport
var overview:VillageWorldMap
var elapsed:=0.0
func _init(owner_app:Node)->void:app=owner_app
func make_view()->SubViewport:
	var view:=SubViewport.new()
	view.size=Vector2i(PIXELS,PIXELS);view.disable_3d=true
	view.gui_disable_input=true;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(view)
	return view
func _ready()->void:
	village_view=make_view();village_view.world_2d=app.world.get_world_2d()
	village_view.canvas_cull_mask=1
	for actor in [app.world.player]+app.world.residents+app.world.animals:exclude_actor_from_minimap(actor)
	for prop in app.world.environment_props:
		if prop.kind in ["hut","props"]:exclude_actor_from_minimap(prop)
	for indicator in app.world.resource_labels.values():exclude_actor_from_minimap(indicator)
	exclude_actor_from_minimap(app.world.reward_markers)
	for child in app.world.get_children():
		if child is VillageLayout or child is BuildPreview or child is TravelTrail or child is WorldFeedback or child is WorldObjectives or child is WorldAmbient:exclude_actor_from_minimap(child)
	if is_instance_valid(app.world.feedback.preview):exclude_actor_from_minimap(app.world.feedback.preview)
	var scale_factor:=PIXELS/DemoPlayer.WORLD_SIZE.y*CONTENT_ZOOM
	village_view.canvas_transform=Transform2D(Vector2(scale_factor,0),Vector2(0,scale_factor),Vector2.ONE*PIXELS*.5-VillageBounds.WORLD_RECT.get_center()*scale_factor)
	var backing:=CanvasLayer.new();backing.layer=-100;backing.custom_viewport=village_view;village_view.add_child(backing)
	var ground:=TextureRect.new();ground.texture=load("res://assets/terrain-review-v001/ground-a.png");ground.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ground.size=Vector2.ONE*PIXELS
	var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/minimap_terrain_extension.gdshader");ground.material=mat;backing.add_child(ground)
	map_view=make_view()
	overview=VillageWorldMap.new(app);overview.natural_only=true;map_view.add_child(overview)
	overview.size=Vector2(app.w,app.h)*5/CONTENT_ZOOM;overview.show();overview.set_process_input(false)
	var map_scale:float=PIXELS/(app.h*5)*CONTENT_ZOOM
	map_view.canvas_transform=Transform2D(Vector2(map_scale,0),Vector2(0,map_scale),(Vector2.ONE*PIXELS-overview.size*map_scale)*.5)
	village_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	map_view.render_target_update_mode=SubViewport.UPDATE_ONCE
func _process(delta:float)->void:
	if not app.application_active or app.screen!="play":return
	elapsed+=delta
	if elapsed<.2:return
	elapsed=0
	if app.world_map_open:
		overview.queue_redraw();map_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	else:village_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	app.chrome.queue_redraw()
func current_texture()->Texture2D:
	return map_view.get_texture() if app.world_map_open else village_view.get_texture()
func normalized_point(world_point:Vector2)->Vector2:
	# Same uniform scale and centering used by each render target.
	if app.world_map_open:return world_point/(app.h*5)*CONTENT_ZOOM
	return (world_point-VillageBounds.WORLD_RECT.get_center())/DemoPlayer.WORLD_SIZE.y*CONTENT_ZOOM

func exclude_actor_from_minimap(node:Node)->void:
	# Main viewport keeps both layers. The GPS alone renders static layer 1.
	if node is CanvasItem:node.visibility_layer=2
	for child in node.get_children():exclude_actor_from_minimap(child)
