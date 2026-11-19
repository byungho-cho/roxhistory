extends "res://scripts/res011_lab_preview.gd"
# Preview-only clocks. Deployed models, other clips and global Timing stay intact.
var variant:="A"
const CLIP_NAME:="d0064_run_C"

func build_villager()->void:
	super.build_villager()
	if variant=="C":
		var library=animation.get_animation_library("").duplicate()
		library.add_animation(CLIP_NAME,load("res://assets/characters/d0064/"+character+"-run-C.tres"))
		animation.remove_animation_library("")
		animation.add_animation_library("",library)

func motion_duration(key:String)->float:
	if key!="run":return super.motion_duration(key)
	if variant=="A":return Timing.RUN_PERIOD
	return animation.get_animation("run").length/1.5 if variant=="B" else animation.get_animation(CLIP_NAME).length

func sample_motion(key:String,seconds:float)->void:
	if key!="run":super.sample_motion(key,seconds);return
	motion_key="run"
	var clip:=CLIP_NAME if variant=="C" else "run"
	var at:=fposmod(seconds,motion_duration("run"))
	if variant=="A":at=Timing.sample(character,"run",at,animation.get_animation("run").length)
	elif variant=="B":at*=1.5
	if animation.current_animation!=clip:animation.play(clip,0.0)
	animation.seek(at,true)
	pivot.position=Vector3.ZERO
	var delta:=skeleton.get_bone_pose_position(root_bone)-skeleton.get_bone_rest(root_bone).origin
	pivot.position=-(skeleton.global_basis*Vector3(delta.x,0,delta.z))
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
