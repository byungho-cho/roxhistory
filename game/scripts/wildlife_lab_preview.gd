extends HybridCharacter

const REFERENCE := preload("res://scripts/res011_lab_preview.gd")
var animation:AnimationPlayer
var skeleton:Skeleton3D
var root_index:=-1
var source_root:=Vector3.ZERO
var cycle_stride:=Vector3.ZERO
var clip:="idle"

func _ready()->void:
	super._ready()
	var density:=display.scale
	viewport.size=Vector2i(1536,720)
	camera.size=7.0
	display.scale=density
	display.position=-camera.unproject_position(Vector3.ZERO)*display.scale

func build_villager()->void:
	var model=(load(model_path) as PackedScene).instantiate()
	pivot.add_child(model)
	model.scale=Vector3.ONE*1.24
	model.position.y=-.12
	pivot.rotation.y=REFERENCE.MOTION_HEADING
	camera.position=REFERENCE.GAME_CAMERA
	camera.look_at(REFERENCE.GAME_AIM)
	animation=model.find_children("*","AnimationPlayer",true,false)[0]
	animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	root_index=skeleton.find_bone("root")
	start("idle")

func length(key:String)->float:
	return animation.get_animation(key).length if animation.has_animation(key) else 0.0

func root_position()->Vector3:
	return skeleton.get_bone_pose_position(root_index) if root_index>=0 else Vector3.ZERO

func start(key:String)->void:
	clip=key if animation.has_animation(key) else "idle"
	pivot.position=Vector3.ZERO
	animation.play(clip,0.0)
	animation.seek(0,true)
	source_root=root_position()
	animation.seek(length(clip),true)
	cycle_stride=root_position()-source_root
	animation.seek(0,true)
	if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func sample(local_time:float,route:bool)->void:
	var span:=length(clip)
	var looping:=clip in ["walk","run","idle"]
	var cycle:=0
	var at:=minf(local_time,span)
	if looping:
		cycle=floori(local_time/span)
		at=fposmod(local_time,span)
		if route and clip in ["walk","run"] and cycle>=2:
			cycle=1
			at=span
	animation.seek(at,true)
	pivot.position=Vector3.ZERO
	if clip in ["walk","run"]:
		if route:
			pivot.position=skeleton.global_basis*Vector3(cycle_stride.x,0,cycle_stride.z)*cycle
		else:
			var delta:=root_position()-source_root
			pivot.position=-(skeleton.global_basis*Vector3(delta.x,0,delta.z))
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
