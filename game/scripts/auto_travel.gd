class_name AutoTravel
extends Node
# Rebuild against physics on each request: newly built homes are obstacles too.
var app: Node
var path := PackedVector2Array()
var action := ""
var target := ""
var stuck := 0.0
var previous := Vector2.INF
var trail: TravelTrail
var retry_count := 0
var blocked_cells: Array[Vector2i] = []
func _init(owner_app:Node) -> void:app=owner_app
func cancel() -> void:
	path.clear();action="";target="";stuck=0;retry_count=0;blocked_cells.clear()
	if is_instance_valid(trail):trail.clear()
	if is_instance_valid(app.world):app.world.player.work_destination=Vector2.INF
func start(kind:String,id:String,destination:Vector2,retry:int=0,blocked:Array=[],quiet:bool=false) -> bool:
	if not is_instance_valid(trail):
		trail=TravelTrail.new(self);app.world.add_child(trail)
	if not destination.is_finite():return false
	var player:DemoPlayer=app.world.player
	if kind=="move":
		var pose:=player.transform;pose.origin=destination
		if not app.world.playable_rect().grow(-24).has_point(destination) or not VillageLayout.ground_ok(destination) or player.test_move(pose,Vector2.ZERO,null,.08,true):
			if not quiet:app.toast("이곳으로 이동할 수 없어요")
			return false
	var planned:=plan_route(destination,blocked)
	if planned.is_empty():
		if not quiet:app.toast("이곳으로 가는 길이 막혀 있어요")
		return false
	if not app.task.is_empty():
		planned.append(destination)
		app.reserve_action({"kind":kind,"id":id,"at":destination,"path":planned})
		return true
	# Only an accepted route is a movement command. Rejected clicks preserve work.
	app.cancel_task(true,retry>0)
	retry_count=retry;blocked_cells.assign(blocked)
	app.world.player.resume_camera()
	path=planned;path.remove_at(0)
	if path.is_empty() or path[-1].distance_to(destination)>.01:path.append(destination)
	action=kind;target=id;previous=player.position
	player.work_destination=path[0]
	return true
func _physics_process(delta:float) -> void:
	if app.world_map_open or app.map_transition_active:return
	if action=="" or not is_instance_valid(app.world):return
	var player:DemoPlayer=app.world.player
	if app.modal:return # Informational UI pauses the queued route, just like active work.
	if not app.application_active:cancel();return
	if player.position.distance_to(previous)<.05:stuck+=delta
	else:stuck=0
	previous=player.position
	if stuck>1.5:
		# Moving wildlife or a clipped grid corner can invalidate a previously safe route.
		# Retry a bounded number of times, excluding the blocked waypoint this request.
		if retry_count<2 and path.size()>1:
			var kind:=action;var id:=target;var destination:=path[-1]
			var blocked:=blocked_cells.duplicate();blocked.append(Vector2i(((path[0]-VillageBounds.WORLD_RECT.position)/VillageBounds.NAV_CELL).floor()))
			if not start(kind,id,destination,retry_count+1,blocked):
				cancel();app.toast("이동이 막혔어요. 다른 위치를 선택해 주세요")
		else:
			cancel();app.toast("이동이 막혔어요. 다른 위치를 선택해 주세요")
		return
	if player.position.distance_to(path[0])>3:return
	path.remove_at(0)
	if not path.is_empty():player.work_destination=path[0];return
	var next:=action;var id:=target;cancel()
	if next=="move":return
	elif next=="family":app.family.begin();return
	elif next=="build":
		if str(app.world.selected_site)==id:app.build_action()
		else:app.toast("건설 부지 선택이 바뀌었어요")
	elif str(app.world.nearest().get("id",""))==id:app.gather_action(id)
	else:app.toast("채집 대상이 바뀌었어요. 다시 선택해 주세요")

func plan_route(destination:Vector2,blocked:Array)->PackedVector2Array:
	var player:DemoPlayer=app.world.player
	# A precise short/open route must not fail merely because its grid-cell
	# center touches scenery. Swept body collision still protects obstacles.
	if blocked.is_empty() and segment_ground_ok(player.position,destination) and not player.test_move(player.global_transform,destination-player.global_position):
		return PackedVector2Array([player.position,destination])
	var cells:=VillageBounds.navigation_cells()
	var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,cells);grid.cell_size=Vector2.ONE*VillageBounds.NAV_CELL;grid.offset=VillageBounds.WORLD_RECT.position+grid.cell_size*.5;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in cells.y:
		for x in cells.x:
			var point:=grid.get_point_position(Vector2i(x,y))
			var pose:=player.global_transform;pose.origin=point
			grid.set_point_solid(Vector2i(x,y),not app.world.playable_rect().grow(-24).has_point(point) or not VillageLayout.ground_ok(point) or player.test_move(pose,Vector2.ZERO,null,.08,true))
	for cell in blocked:
		if grid.is_in_boundsv(cell):grid.set_point_solid(cell,true)
	var from:=Vector2i(((player.position-VillageBounds.WORLD_RECT.position)/VillageBounds.NAV_CELL).floor())
	var to:=Vector2i(((destination-VillageBounds.WORLD_RECT.position)/VillageBounds.NAV_CELL).floor())
	if not grid.is_in_boundsv(from):return PackedVector2Array()
	grid.set_point_solid(from,false)
	var candidates:Array[Vector2i]=[]
	for y in range(maxi(0,to.y-2),mini(cells.y,to.y+3)):
		for x in range(maxi(0,to.x-2),mini(cells.x,to.x+3)):
			var cell:=Vector2i(x,y);var point:=grid.get_point_position(cell)
			var pose:=player.global_transform;pose.origin=point
			if not grid.is_point_solid(cell) and not player.test_move(pose,destination-point):candidates.append(cell)
	candidates.sort_custom(func(a,b):return grid.get_point_position(a).distance_squared_to(destination)<grid.get_point_position(b).distance_squared_to(destination))
	# The closest free cell may be across a wall. Try other reachable contacts.
	for cell in candidates:
		var planned:=grid.get_point_path(from,cell)
		if not planned.is_empty():return planned
	return PackedVector2Array()

func segment_ground_ok(from:Vector2,to:Vector2)->bool:
	var steps:=maxi(1,int(ceil(from.distance_to(to)/24.0)))
	for i in range(steps+1):
		if not VillageLayout.ground_ok(from.lerp(to,float(i)/steps)):return false
	return true
