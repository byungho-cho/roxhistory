class_name ResourceRegrowth
extends Node
var world:DemoWorld
var elapsed:=0.0
func _init(owner_world:DemoWorld)->void:world=owner_world
func _physics_process(delta:float)->void:
	if world.player.presentation_paused:return
	elapsed+=delta
	if elapsed<1:return
	elapsed=0
	var now:=Time.get_unix_time_from_system()
	if world.model.ensure_respawn_timers(now):return
	var next:=world.model.state
	for n in world.model.nodes():
		if not world.exhausted(n) or float(next.respawn_due.get(n.id,INF))>now:continue
		var at:=find_position(DemoConfig.point(n.position))
		if at.is_finite():world.model.respawn(n.id,at,now)
		return # At most one persistent transaction per tick.

func find_position(old:Vector2)->Vector2:
	var cells:=Vector2i((VillageBounds.WORLD_SIZE/40).ceil())
	var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,cells);grid.cell_size=Vector2(40,40);grid.offset=VillageBounds.WORLD_RECT.position+Vector2(20,20)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in cells.y:
		for x in cells.x:
			var at:=grid.get_point_position(Vector2i(x,y))
			var pose:=world.player.transform;pose.origin=at
			grid.set_point_solid(Vector2i(x,y),not world.playable_rect().grow(-32).has_point(at) or world.player.test_move(pose,Vector2.ZERO,null,.08,true))
	var start:=Vector2i(((world.player.position-VillageBounds.WORLD_RECT.position)/40).floor())
	if not grid.region.has_point(start):return Vector2.INF
	grid.set_point_solid(start,false)
	for attempt in 300:
		var cell:=Vector2i(randi_range(3,cells.x-4),randi_range(3,cells.y-4))
		var at:=grid.get_point_position(cell)
		if not world.playable_rect().grow(-130).has_point(at) or at.distance_to(old)<180 or grid.is_point_solid(cell):continue
		var clear:=true
		for rock in SceneStyle.PAINTED_ROCKS:
			if at.distance_to(rock)<110:clear=false
		for home in (DemoConfig.HOME_SITES+DemoConfig.BUILD_SITES)+[DemoConfig.CHIEF_POSITION]:
			if at.distance_to(home+Vector2(0,-40))<240:clear=false
		for n in world.model.nodes():
			if not world.exhausted(n) and at.distance_to(DemoConfig.point(n.position))<150:clear=false
		for i in world.SHORE.size()-1:
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at,world.SHORE[i],world.SHORE[i+1]))<100:clear=false
		if not clear:continue
		var area:=PhysicsShapeQueryParameters2D.new();var shape:=CircleShape2D.new();shape.radius=65
		area.shape=shape;area.transform=Transform2D(0,at)
		if not world.get_world_2d().direct_space_state.intersect_shape(area,1).is_empty():continue
		if grid.get_id_path(start,cell).is_empty():continue
		return at
	return Vector2.INF # Retry later; never place a resource at an invalid fallback.
