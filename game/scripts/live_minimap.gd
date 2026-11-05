class_name LiveMinimap
extends Node
## Low-resolution, throttled render of the real scene. No copied gameplay state.
const PIXELS:=192
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
	var scale_factor:=PIXELS/DemoPlayer.WORLD_SIZE.y
	village_view.canvas_transform=Transform2D(Vector2(scale_factor,0),Vector2(0,scale_factor),(Vector2.ONE*PIXELS-DemoPlayer.WORLD_SIZE*scale_factor)*.5)
	map_view=make_view()
	overview=VillageWorldMap.new(app);map_view.add_child(overview)
	overview.size=Vector2(app.w,app.h)*5;overview.show();overview.set_process_input(false)
	var map_scale:float=PIXELS/(app.h*5)
	map_view.canvas_transform=Transform2D(Vector2(map_scale,0),Vector2(0,map_scale),(Vector2.ONE*PIXELS-Vector2(app.w,app.h)*5*map_scale)*.5)
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
	if app.world_map_open:return world_point/(app.h*5)
	return (world_point-DemoPlayer.WORLD_SIZE*.5)/DemoPlayer.WORLD_SIZE.y
