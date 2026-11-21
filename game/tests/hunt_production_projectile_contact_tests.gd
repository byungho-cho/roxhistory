extends SceneTree
const Flight=preload("res://scripts/hunt_production_projectile_contact.gd")
var failures:=0
var checks:=0
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func _capsule(x:float,z:=0.0)->Dictionary:
	return {"a":Vector3(x,.6,z),"b":Vector3(x,1.4,z),"radius":.15}

func _run()->void:
	var f:=Flight.new()
	var origin:=Vector3(0,1,0)
	var aim:=Vector3(3,1,0)
	var fixed:=_capsule(3)
	var payload:={"damage":27,"action":9}
	_check(f.launch(origin,aim,20,8,payload),"launch")
	_check(f.position==origin and f.active,"stone starts at actual release marker")
	_check(not f.launch(origin,aim,20,8),"one stone at a time")
	payload.damage=99
	var event:=f.step(.25,fixed,fixed)
	_check(event.get("kind")=="hit","low-FPS swept hit through capsule")
	_check(event.get("payload",{}).get("damage")==27,"payload snapshot")
	_check(not f.active and f.step(1,fixed,fixed).is_empty(),"hit emitted once")
	var coarse_age:=float(event.get("age",-1))
	f.launch(origin,aim,20,8)
	for i in range(40):
		event=f.step(.008,fixed,fixed)
		if not event.is_empty():
			break
	_check(event.get("kind")=="hit" and absf(float(event.get("age",-2))-coarse_age)<.0001,"small versus large frames agree")
	f.launch(origin,aim,20,8)
	event=f.step(.6,fixed,_capsule(3,4))
	_check(event.get("kind")=="expired","target leaves path after release")
	_check(not f.active and f.step(.6,fixed,fixed).is_empty(),"miss cannot apply later damage")
	f.launch(origin,aim,20,8)
	event=f.step(.22,_capsule(2,-2),_capsule(2,2.4))
	_check(event.get("kind")=="hit","moving capsule crosses path between frames")
	f.launch(origin,aim,20,1)
	event=f.step(.25,fixed,fixed)
	_check(event.get("reason")=="range" and f.position.x<1.01,"range stops before a far target")
	f.launch(origin,aim,20,8,{},.04)
	event=f.step(.25,fixed,fixed)
	_check(event.get("reason")=="lifetime" and absf(float(event.age)-.04)<.00001,"lifetime stops within large frame")
	f.launch(origin,Vector3(1,-2,0),20,8)
	event=f.step(.25)
	_check(event.get("reason")=="ground" and absf(f.position.y)<.00001,"floor terminates flight")
	f.launch(origin,aim,20,8)
	_check(f.step(0,fixed,fixed).is_empty() and f.position==origin,"zero delta does not advance")
	f.cancel()
	_check(not f.active and f.step(.25,fixed,fixed).is_empty(),"cancel emits no impact")
	f.launch(origin,aim,20,8)
	event=f.step(.6,fixed,{})
	_check(event.get("kind")=="expired","removed target cannot be hit")
	print("Production projectile contact: ",checks," checks, ",failures," failures")
	quit(int(failures>0))
