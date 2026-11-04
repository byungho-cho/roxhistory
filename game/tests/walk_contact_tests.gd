extends SceneTree
var failed:Array[String]=[]
var checks:=0
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failed.append(label);push_error(label)
func run()->void:
	var hero:=HybridCharacter.new();root.add_child(hero);await process_frame
	hero.set_enabled(true)
	var samples:Array[Dictionary]=[]
	var baseline:Dictionary={}
	for step in 101:
		var t:=step/100.0
		hero.apply_walk_clip(t*TAU,1.0)
		hero.rig.force_update_all_bone_transforms()
		var row:Dictionary={"phase":t}
		for side in ["L","R"]:
			var foot:Vector3=hero.rig.get_bone_global_pose(hero.bones["foot"+side]).origin
			row[side]=[foot.x,foot.y,foot.z]
			if step==0:baseline[side]=foot.y
		samples.append(row)
	var double_support:=0
	for row in samples:
		var supported:=0
		for side in ["L","R"]:
			var height:float=row[side][1]-baseline[side]
			if absf(height)<.012:supported+=1
			check(height>-.015,"Ankle never penetrates support plane: "+side+str(row.phase))
		check(supported>=1,"At least one supporting foot: "+str(row.phase))
		if supported==2:double_support+=1
	check(double_support>=10,"Walking has double support rather than an airborne run")
	for side in ["L","R"]:
		var max_lift:=0.0
		for row in samples:max_lift=maxf(max_lift,row[side][1]-baseline[side])
		check(max_lift>.17 and max_lift<.21,"Clear swing clearance without exaggerated high steps: "+side)
		var a:Array=samples[0][side];var b:Array=samples[100][side]
		check(Vector3(a[0],a[1],a[2]).distance_to(Vector3(b[0],b[1],b[2]))<.001,"Seamless foot loop: "+side)
	var result:Dictionary={"checks":checks,"failed":failed,"double_support_samples":double_support,"samples":samples,"scope":"Skeleton ankle trajectories; not a claim of visually perfect foot locking or Android validation"}
	FileAccess.open("res://reports/walk-contact-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("Walk contact checks: ",checks," failures: ",failed," double support: ",double_support)
	quit(0 if failed.is_empty() else 1)
