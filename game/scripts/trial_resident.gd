class_name TrialResident
extends CharacterBody2D
# Existing approved residents, with persistent single-load hauling jobs.
var resident_id:=""
var jobs:ResidentJobs
var job_phase:="idle"
var job_target:=""
var job_kind:="idle"
var job_timer:=0.0
var job_route:=PackedVector2Array()
var job_stuck:=0.0
var job_depot:=Vector2.INF
var variant:="female"
var visual:HybridCharacter
var origin:=Vector2.ZERO
var destination:=Vector2.ZERO
var phase:=0.0
var rest_time:=2.0
var rng:=RandomNumberGenerator.new()
var idle_time:=0.0
var visual_elapsed:=0.0
func _ready()->void:
	if resident_id.is_empty():resident_id="resident-0" if variant=="female" else "resident-1"
	jobs=ResidentJobs.new(get_parent().model)
	origin=position;destination=position;rng.seed=abs(resident_id.hash())+122;rest_time=2.0+float(abs(resident_id.hash())%30)/10.0
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=12;shape.shape=circle;add_child(shape)
	visual=HybridCharacter.new();visual.model_path="res://assets/characters/residents/"+variant+".glb";visual.render_size_factor=.5;add_child(visual);visual.scale=Vector2.ONE*(1.08 if variant=="female" else 1.16);visual.set_enabled(true)
	queue_redraw()
func _draw()->void:
	draw_set_transform(Vector2(4,-2),0,Vector2(1,.28));draw_circle(Vector2.ZERO,20,SceneStyle.CONTACT_COLOR);draw_set_transform(Vector2.ZERO)
func _physics_process(delta:float)->void:
	var world:DemoWorld=get_parent()
	if world.player.presentation_paused:
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	var before:=position
	if _job_tick(delta):
		pass
	elif rest_time>0:
		rest_time-=delta;velocity=Vector2.ZERO
		if rest_time<=0:
			for i in 12:
				var point:=origin+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(30,70)
				var pose:=transform;pose.origin=point
				if world.playable_rect().grow(-24).has_point(point) and not test_move(pose,Vector2.ZERO,null,.08,true) and not test_move(transform,point-position):destination=point;break
	else:
		var offset:=destination-position
		velocity=offset.normalized()*48 if offset.length()>3 else Vector2.ZERO
		move_and_slide()
		if offset.length()<3 or position.distance_to(before)<.01:rest_time=rng.randf_range(2.5,5.0)
	var travelled:=position.distance_to(before)
	if travelled>.01:phase=fposmod(phase+travelled/(visual.stride_world_length()*visual.scale.x)*TAU,TAU);idle_time=0
	else:idle_time+=delta
	visual.idle_elapsed=idle_time
	visual_elapsed+=delta
	var screen_point:=get_global_transform_with_canvas().origin
	if not Rect2(Vector2(-120,-120),get_viewport_rect().size+Vector2(240,240)).has_point(screen_point):
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		visual_elapsed=0
		return
	if visual_elapsed>=1.0/30.0:
		visual.set_render_zoom(world.player.zoom_factor)
		visual.animate(visual_elapsed,velocity.normalized(),phase,travelled>.01,job_kind if job_phase=="harvest" else "",clampf(1.0-job_timer/float(DemoConfig.get_data().gather_seconds),0,1),false)
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		visual_elapsed=0

# Read-only status used by the resident assignment panel. No rewards occur here.
func work_status()->String:
	if not jobs.available(resident_id):return "방문 중"
	if jobs.model.chief_level()<=0:return "촌장집 필요"
	var item:=jobs.entry(resident_id)
	if not item.cargo.is_empty():
		if job_phase=="wait":return "전달 대기"
		return "촌장집으로 이동 중"
	if item.job=="idle":return "쉬는 중"
	return {"travel":"자원으로 이동 중","harvest":"채집 중","wait":"자원·경로 대기"}.get(job_phase,"작업 준비 중")

# A stopped/reassigned worker first delivers the existing load, never discards it.
func _job_tick(delta:float)->bool:
	var item:=jobs.entry(resident_id)
	if not jobs.available(resident_id):return false
	if item.job!=job_kind:
		job_kind=item.job;job_route.clear();job_phase="idle";job_timer=0
	if jobs.model.chief_level()<=0:
		# Keep paid cargo and assigned intent intact until a depot exists again.
		velocity=Vector2.ZERO;job_route.clear();job_phase="wait";job_timer=2.0;job_depot=Vector2.INF
		return true
	if item.cargo.is_empty() and job_kind=="idle":return false
	velocity=Vector2.ZERO
	if job_timer>0 and job_phase=="wait":
		job_timer-=delta;return true
	if not item.cargo.is_empty():
		var index:=int(resident_id.trim_prefix("resident-"))
		var x_offsets:=[-35,35,-70,0,70]
		var depot:=jobs.model.building_position("chief")+Vector2(x_offsets[index%5],110+30*(index/5))
		if depot!=job_depot:job_route.clear();job_depot=depot
		if position.distance_to(depot)<=5:
			jobs.deposit(resident_id);job_phase="wait";job_timer=2;job_route.clear();return true
		if job_route.is_empty():
			if not _plan_job_route(depot):_job_wait();return true
		job_phase="return"
	elif job_phase=="harvest":
		job_timer-=delta
		if job_timer<=0:
			for node in jobs.model.nodes():
				if node.id==job_target and position.distance_to(DemoConfig.point(node.position))<=float(DemoConfig.get_data().interact_radius):
					jobs.harvest(resident_id,job_target);break
			job_route.clear();_job_wait()
		return true
	elif job_route.is_empty():
		var candidates:Array=jobs.model.nodes()
		candidates.sort_custom(func(a,b):return position.distance_squared_to(DemoConfig.point(a.position))<position.distance_squared_to(DemoConfig.point(b.position)))
		for node in candidates:
			if node.kind!=job_kind or int(jobs.model.state.depleted.get(node.id,0))>=int(node.charges):continue
			for side in [Vector2(0,65),Vector2(65,0),Vector2(-65,0),Vector2(0,-65)]:
				if _plan_job_route(DemoConfig.point(node.position)+side):job_target=node.id;job_phase="travel";break
			if not job_route.is_empty():break
		if job_route.is_empty():_job_wait();return true
	if job_route.is_empty():return true
	var offset:=job_route[0]-position
	if offset.length()<=3:
		job_route.remove_at(0)
		if job_route.is_empty() and job_phase=="travel":job_phase="harvest";job_timer=float(DemoConfig.get_data().gather_seconds)
		return true
	var before:=position
	velocity=offset.normalized()*minf(float(DemoConfig.get_data().move_speed),offset.length()/maxf(delta,.001));move_and_slide()
	job_stuck=job_stuck+delta if position.distance_to(before)<.01 else 0.0
	if job_stuck>1.5:job_route.clear();_job_wait()
	return true

func _job_wait()->void:
	job_phase="wait";job_timer=2.0;job_stuck=0

func _plan_job_route(target:Vector2)->bool:
	var target_pose:=transform;target_pose.origin=target
	if not VillageBounds.rect_for_level(jobs.model.chief_level()).grow(-24).has_point(target) or not VillageLayout.ground_ok(target) or test_move(target_pose,Vector2.ZERO,null,.08,true):return false
	if not test_move(transform,target-position):job_route=PackedVector2Array([target]);return true
	var cells:=VillageBounds.navigation_cells()
	var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,cells);grid.cell_size=Vector2.ONE*VillageBounds.NAV_CELL;grid.offset=VillageBounds.WORLD_RECT.position+grid.cell_size*.5;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in cells.y:
		for x in cells.x:
			var cell:=Vector2i(x,y);var point:=grid.get_point_position(cell);var pose:=transform;pose.origin=point
			grid.set_point_solid(cell,not VillageBounds.rect_for_level(jobs.model.chief_level()).grow(-24).has_point(point) or not VillageLayout.ground_ok(point) or test_move(pose,Vector2.ZERO,null,.08,true))
	var start:=Vector2i(((position-VillageBounds.WORLD_RECT.position)/VillageBounds.NAV_CELL).floor())
	var finish:=Vector2i(((target-VillageBounds.WORLD_RECT.position)/VillageBounds.NAV_CELL).floor())
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(finish) or grid.is_point_solid(finish):return false
	grid.set_point_solid(start,false)
	var result:=grid.get_point_path(start,finish)
	if result.is_empty():return false
	var pose:=transform;pose.origin=result[-1]
	if test_move(pose,target-result[-1]):return false
	result.remove_at(0);result.append(target);job_route=result;return true
