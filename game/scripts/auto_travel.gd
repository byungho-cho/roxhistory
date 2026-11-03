class_name AutoTravel
extends Node
# Rebuild against physics on each request: newly built homes are obstacles too.
var app: Node
var path := PackedVector2Array()
var action := ""
var target := ""
var stuck := 0.0
var previous := Vector2.INF
func _init(owner_app:Node) -> void:app=owner_app
func cancel() -> void:
	path.clear();action="";target="";stuck=0
	if is_instance_valid(app.world):app.world.player.work_destination=Vector2.INF
func start(kind:String,id:String,destination:Vector2) -> void:
	cancel()
	if not destination.is_finite():app.toast("이곳으로 이동할 수 없어요");return
	var player:DemoPlayer=app.world.player
	var grid:=AStarGrid2D.new();grid.region=Rect2i(0,0,100,56);grid.cell_size=Vector2(24,24);grid.offset=Vector2(12,12);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in 56:
		for x in 100:
			var point:=Vector2(x*24+12,y*24+12)
			var transform:=player.transform;transform.origin=point
			grid.set_point_solid(Vector2i(x,y),point.x<40 or point.x>2360 or point.y<40 or point.y>1310 or player.test_move(transform,Vector2.ZERO,null,.08,true))
	var from:=Vector2i((player.position-Vector2(12,12))/24)
	var to:=Vector2i((destination-Vector2(12,12))/24)
	grid.set_point_solid(from,false)
	# Exact contact point may fall in an occupied cell; choose a nearby free endpoint.
	var best:=Vector2i(-1,-1);var distance:=INF
	for y in range(maxi(0,to.y-2),mini(56,to.y+3)):
		for x in range(maxi(0,to.x-2),mini(100,to.x+3)):
			var cell:=Vector2i(x,y);var point:=grid.get_point_position(cell)
			var transform:=player.transform;transform.origin=point
			if not grid.is_point_solid(cell) and not player.test_move(transform,destination-point) and point.distance_to(destination)<distance:
				best=cell;distance=point.distance_to(destination)
	if best.x<0:app.toast("이곳으로 이동할 수 없어요");return
	path=grid.get_point_path(from,best)
	if path.is_empty():app.toast("이곳으로 가는 길이 막혀 있어요");return
	path.remove_at(0);path.append(destination)
	action=kind;target=id;previous=player.position
	player.work_destination=path[0]
func _physics_process(delta:float) -> void:
	if action=="" or not is_instance_valid(app.world):return
	var player:DemoPlayer=app.world.player
	if app.modal or not app.application_active or app.gestures.blocked:cancel();return
	if player.position.distance_to(previous)<.05:stuck+=delta
	else:stuck=0
	previous=player.position
	if stuck>1.5:cancel();app.toast("이동이 막혔어요. 다른 위치를 선택해 주세요");return
	if player.position.distance_to(path[0])>3:return
	path.remove_at(0)
	if not path.is_empty():player.work_destination=path[0];return
	var next:=action;var id:=target;cancel()
	if next=="build":app.build_action()
	elif str(app.world.nearest().get("id",""))==id:app.gather_action()
	else:app.toast("채집 대상이 바뀌었어요. 다시 선택해 주세요")
