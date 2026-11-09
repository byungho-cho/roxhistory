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
var depot_home:=Vector2.INF
var station_key:=""
var farm_origin:=Vector2.INF
var farm_stand:=Vector2.INF
const RESIDENT_LAYER:=2
const FARM_STANDS:=[Vector2(135,72),Vector2(-135,72),Vector2(0,220)]
var variant:="female"
var visual:HybridCharacter
var origin:=Vector2.ZERO
var destination:=Vector2.ZERO
var phase:=0.0
var rest_time:=2.0
var rng:=RandomNumberGenerator.new()
var idle_time:=0.0
var visual_elapsed:=0.0
const WORK_WALK_FACTOR:=.5
const GATHER_MULTIPLIER:=10.0
func gather_seconds()->float:return float(DemoConfig.get_data().gather_seconds)*GATHER_MULTIPLIER
var duty_clock:=0.0
var patrol_step:=-1
func _ready()->void:
	if resident_id.is_empty():resident_id="resident-0" if variant=="female" else "resident-1"
	# Other residents are pass-through; terrain, buildings and wildlife remain solid.
	collision_layer=RESIDENT_LAYER
	collision_mask=1
	jobs=ResidentJobs.new(get_parent().model)
	origin=position;destination=position;rng.seed=abs(resident_id.hash())+122;rest_time=2.0+float(abs(resident_id.hash())%30)/10.0
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=12;shape.shape=circle;add_child(shape)
	visual=HybridCharacter.new();visual.model_path="res://assets/characters/residents/"+variant+".glb";visual.render_size_factor=.5;add_child(visual);visual.scale=Vector2.ONE*(1.08 if variant=="female" else 1.16);visual.set_enabled(true)
	visual.ambient_offset=float(abs(resident_id.hash())%2600)/100.0
	queue_redraw()
func _draw()->void:
	draw_set_transform(Vector2(4,-2),0,Vector2(1,.28));draw_circle(Vector2.ZERO,20,SceneStyle.CONTACT_COLOR);draw_set_transform(Vector2.ZERO)
	if job_phase=="harvest":
		draw_rect(Rect2(-20,-66,40,5),Color(0,0,0,.65))
		draw_rect(Rect2(-19,-65,38*clampf(1-job_timer/(1.2 if job_kind=="farmer" else gather_seconds()),0,1),3),Color("bfd274"))
func _physics_process(delta:float)->void:
	var world:DemoWorld=get_parent()
	if world.simulation_paused:
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	duty_clock+=delta
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
		ActorMovement.move(self,ActorMovement.direction_to(position,destination,delta) if offset.length()>3 else Vector2.ZERO)
		if offset.length()<3 or position.distance_to(before)<.01:
			rest_time=rng.randf_range(2.5,5.0)
			visual.ambient_offset=fposmod(visual.ambient_offset+9.7,26.0)
	queue_redraw()
	var travelled:=position.distance_to(before)
	if travelled>.01:phase=fposmod(phase+travelled/(visual.stride_world_length()*visual.scale.x)*TAU,TAU);idle_time=0
	else:idle_time+=delta
	visual.idle_elapsed=idle_time
	visual.ambient_allowed=job_kind=="idle" and jobs.entry(resident_id).cargo.is_empty()
	visual_elapsed+=delta
	var screen_point:=get_global_transform_with_canvas().origin
	if not Rect2(Vector2(-120,-120),get_viewport_rect().size+Vector2(240,240)).has_point(screen_point):
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		visual_elapsed=0
		return
	if visual_elapsed>=1.0/30.0:
		visual.set_render_zoom(world.player.zoom_factor)
		visual.work_kind=job_kind
		var action:=job_kind if job_phase=="harvest" else "farm_care" if job_kind=="farmer" and job_phase=="farm_wait" else "guard" if job_kind=="guard" else ""
		var facing:Vector2=(farm_origin-position).normalized() if action=="farm_care" or (job_kind=="farmer" and job_phase=="harvest") else velocity.normalized()
		visual.animate(visual_elapsed,facing,phase,travelled>.01,action,duty_clock if action in ["farm_care","guard"] else maxf(0,(1.2 if job_kind=="farmer" else gather_seconds())-job_timer),false)
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		visual_elapsed=0

# Read-only status used by the resident assignment panel. No rewards occur here.
func work_status()->String:
	if not jobs.available(resident_id):return "방문 중"
	if jobs.model.chief_level()<=0:return "촌장집 필요"
	var item:=jobs.entry(resident_id)
	if not item.cargo.is_empty():
		if job_phase=="wait":return "전달 대기"
		return "주민 움집으로 운반 중"
	if item.job=="idle":return "미배정"
	if item.job=="guard":return "초소 근무 중" if job_phase=="guard" else "초소로 이동 중"
	if item.job=="farmer":
		var cycle:=FarmProduction.entry(jobs.model,str(item.get("building","")))
		return "수확 중" if job_phase=="harvest" else {"prepare":"재배 준비","grow":"농장 관리 중","ready":"수확 준비","harvest":"수확 준비"}.get(cycle.phase,"농장으로 이동 중")
	return {"travel":"자원으로 이동 중","harvest":"채집 중","wait":"자원·경로 대기"}.get(job_phase,"작업 준비 중")

# A stopped/reassigned worker first delivers the existing load, never discards it.
func _job_tick(delta:float)->bool:
	var item:=jobs.entry(resident_id)
	if not jobs.available(resident_id):jobs.model.release_gather(resident_id);return false
	if item.job!=job_kind:
		jobs.model.release_gather(resident_id)
		job_kind=item.job;job_route.clear();job_phase="idle";job_timer=0;farm_stand=Vector2.INF
	if item.cargo.is_empty() and job_kind in ["wood","stone"] and ResourceStorage.room(jobs.model,job_kind)<=0:_job_wait();return true
	if job_kind in ["wood","stone"] and job_phase in ["travel","harvest"] and not jobs.model.owns_gather(job_target,resident_id):
		job_route.clear();job_phase="idle";job_timer=0
	if jobs.model.chief_level()<=0:
		jobs.model.release_gather(resident_id)
		# Keep paid cargo and assigned intent intact until a depot exists again.
		velocity=Vector2.ZERO;job_route.clear();job_phase="wait";job_timer=2.0;job_depot=Vector2.INF
		return true
	if item.cargo.is_empty() and job_kind=="idle":return false
	velocity=Vector2.ZERO
	if job_timer>0 and job_phase=="wait":
		job_timer-=delta;return true
	if not item.cargo.is_empty():
		jobs.model.release_gather(resident_id)
		if not depot_home.is_finite() or not ResourceStorage.destination_exists(jobs.model,str(item.cargo.kind),depot_home):
			depot_home=ResourceStorage.destination(jobs.model,str(item.cargo.kind),position);job_depot=Vector2.INF;job_route.clear()
		if not depot_home.is_finite():_job_wait();return true
		if not job_depot.is_finite():
			for offset in [Vector2(0,90),Vector2(90,50),Vector2(-90,50),Vector2(0,-90)]:
				if _plan_job_route(depot_home+offset):job_depot=depot_home+offset;break
		if not job_depot.is_finite():_job_wait();return true
		var depot:=job_depot
		if position.distance_to(depot)<=5:
			if not jobs.deposit(resident_id):_job_wait();return true
			job_phase="idle";job_timer=0;job_route.clear();job_depot=Vector2.INF;depot_home=Vector2.INF;return true
		if job_route.is_empty():
			if not _plan_job_route(depot):_job_wait();return true
		job_phase="return"
	elif job_kind in ["farmer","guard"]:
		_station_tick(delta,item);return true
	elif job_phase=="harvest":
		job_timer-=delta
		if job_timer<=0:
			var harvested:=false
			for node in jobs.model.nodes():
				if node.id==job_target and position.distance_to(DemoConfig.point(node.position))<=float(DemoConfig.get_data().interact_radius):
					harvested=jobs.harvest(resident_id,job_target);break
			job_route.clear()
			if harvested:job_phase="idle";job_timer=0
			else:_job_wait()
		return true
	elif job_route.is_empty():
		var candidates:Array=jobs.model.nodes()
		candidates.sort_custom(func(a,b):return position.distance_squared_to(DemoConfig.point(a.position))<position.distance_squared_to(DemoConfig.point(b.position)))
		for node in candidates:
			if node.kind!=job_kind or int(jobs.model.state.depleted.get(node.id,0))>=int(node.charges) or not jobs.model.gather_available(node.id,resident_id):continue
			for side in [Vector2(0,65),Vector2(65,0),Vector2(-65,0),Vector2(0,-65)]:
				if _plan_job_route(DemoConfig.point(node.position)+side) and jobs.model.claim_gather(node.id,resident_id):job_target=node.id;job_phase="travel";break
			if not job_route.is_empty():break
		if job_route.is_empty():_job_wait();return true
	if job_route.is_empty():return true
	var offset:=job_route[0]-position
	if offset.length()<=3:
		job_route.remove_at(0)
		if job_route.is_empty() and job_phase=="travel":job_phase="harvest";job_timer=gather_seconds()
		return true
	var before:=position
	ActorMovement.move(self,ActorMovement.direction_to(position,job_route[0],delta,job_walk_factor()),job_walk_factor())
	job_stuck=job_stuck+delta if position.distance_to(before)<.01 else 0.0
	if job_stuck>1.5:job_route.clear();_job_wait()
	return true

func _job_wait()->void:
	jobs.model.release_gather(resident_id)
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

func _home_exists(at:Vector2)->bool:
	for i in jobs.model.built_count():
		if jobs.model.home_position(i)==at:return true
	return false

func _station_tick(delta:float,item:Dictionary)->void:
	var key:=str(item.get("building",""))
	var found:=jobs.model.lookup_building(key)
	if found.is_empty():_job_wait();return
	if station_key!=key:
		station_key=key;job_phase="idle";job_route.clear();job_timer=0;farm_stand=Vector2.INF
	var at:Vector2=found.position+Vector2(0,90)
	if job_kind=="farmer":
		if farm_origin!=found.position:
			farm_origin=found.position;farm_stand=Vector2.INF;job_route.clear()
		if not farm_stand.is_finite() or (job_route.is_empty() and position.distance_to(farm_stand)>5):
			farm_stand=Vector2.INF
			for offset in FARM_STANDS:
				var candidate:Vector2=found.position+offset
				if _plan_job_route(candidate):
					farm_stand=candidate
					break
			if not farm_stand.is_finite():_job_wait();return
		at=farm_stand
	if job_kind=="guard":
		var step:=int(duty_clock/8.0)%3
		if step!=patrol_step:patrol_step=step;job_route.clear()
		at=found.position+[Vector2(-65,90),Vector2(0,115),Vector2(65,90)][step]
	if position.distance_to(at)>5:
		if job_route.is_empty() and not _plan_job_route(at):_job_wait();return
		if not job_route.is_empty():
			if position.distance_to(job_route[0])<=3:job_route.remove_at(0)
			elif not job_route.is_empty():
				var before:=position
				ActorMovement.move(self,ActorMovement.direction_to(position,job_route[0],delta,job_walk_factor()),job_walk_factor())
				job_stuck=job_stuck+delta if position.distance_to(before)<.01 else 0.0
				if job_stuck>1.5:job_route.clear();_job_wait();return
		job_phase="station_travel";return
	job_route.clear()
	if job_kind=="guard":job_phase="guard";return
	if found.data.has("upgrade"):job_phase="wait";return
	var cycle:=FarmProduction.entry(jobs.model,key)
	if cycle.phase not in ["ready","harvest"] or ResourceStorage.room(jobs.model,"grain")<=0:job_phase="farm_wait";return
	if job_phase!="harvest":job_phase="harvest";job_timer=1.2
	job_timer-=delta
	if job_timer<=0:
		FarmProduction.harvest(jobs.model,resident_id,key);job_phase="farm_wait"

func job_walk_factor()->float:
	if job_kind in ["wood","stone"] or jobs.entry(resident_id).cargo.get("kind","") in ["wood","stone"]:
		return .3 if not jobs.entry(resident_id).cargo.is_empty() else .5
	return WORK_WALK_FACTOR if job_kind=="farmer" or not jobs.entry(resident_id).cargo.is_empty() else 1.0

func _exit_tree()->void:
	if jobs:jobs.model.release_gather(resident_id)
