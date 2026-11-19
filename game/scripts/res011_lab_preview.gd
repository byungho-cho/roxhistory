extends HybridCharacter

const ASSETS := "res://assets/characters/d0057/"
const Timing := preload("res://scripts/motion_timing.gd")
const Catalog := preload("res://scripts/lab_motion_catalog.gd")
const JUMP_MODEL := "res://assets/characters/res050/hangyeol-latest.glb"
const JUMP_CLIP := "jump_spear_auto_r03"
const JUMP_SECONDS := 3.2
const JUMP_CONTACT_SECONDS := 94.0/60.0
const CLIPS := {"hangyeol":JUMP_CLIP,"saebom":"sling_cast"}
const GAME_CAMERA := Vector3(.33,7.05,6.0)
const GAME_AIM := Vector3(.33,1.45,0.0)
const MOTION_RENDER_FACTOR := .75
const MOTION_DISPLAY_SCALE := .92
const MOTION_GROUND_Y := 325.0
const MOTION_HEADING := atan2(1.0,.28)

var skeleton: Skeleton3D
var root_bone := -1
var last_sample := 0.0
var extract_tail := 0.0
var motion_key := "idle"
var timeline: Dictionary = {}
var character := "hangyeol"
var shared_motion_view := false
var animation: AnimationPlayer
var use_run_candidate := true
var extra_motions := false
var excluded_playlist_clips:PackedStringArray=[]
var environment: Environment
var cool_fill: DirectionalLight3D

func _ready() -> void:
	super._ready()
	var display_scale := display.scale
	viewport.size = Vector2i(768,720)
	camera.size = 7.0
	display.scale = display_scale
	display.position = -camera.unproject_position(Vector3.ZERO)*display.scale

func build_villager() -> void:
	var packed := load(JUMP_MODEL if character=="hangyeol" else "res://assets/characters/res050/saebom-latest.glb") as PackedScene
	var model := packed.instantiate() as Node3D
	pivot.add_child(model)
	model.scale = Vector3.ONE*1.24
	model.position.y = -.12
	pivot.rotation.y = MOTION_HEADING
	camera.position = GAME_CAMERA
	camera.look_at(GAME_AIM)
	animation = model.find_children("*","AnimationPlayer",true,false)[0]
	if extra_motions:preload("res://scripts/model_motion_profile.gd").install(animation,character)
	if use_run_candidate:
		var library:=animation.get_animation_library("").duplicate()
		library.remove_animation("run")
		library.add_animation("run",load("res://assets/characters/d0064/"+character+"-run-C.tres"))
		animation.remove_animation_library("");animation.add_animation_library("",library)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	root_bone = skeleton.find_bone("root")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	timeline = JSON.parse_string(FileAccess.get_file_as_string(ASSETS+character+"-timeline.json"))
	animation.play("idle")
	animation.advance(0.0)
	if character=="saebom" and not shared_motion_view:
		var lighting := viewport.find_children("*","WorldEnvironment",true,false)[0] as WorldEnvironment
		environment = lighting.environment
		cool_fill = DirectionalLight3D.new()
		cool_fill.rotation_degrees = Vector3(-18,42,0)
		cool_fill.light_color = Color("e8edff")
		cool_fill.shadow_enabled = false
		camera.get_parent().add_child(cool_fill)
		set_corrected_light(true)

func set_corrected_light(corrected: bool) -> void:
	if not is_instance_valid(cool_fill): return
	environment.ambient_light_energy = .65 if corrected else .50
	cool_fill.light_energy = .28 if corrected else 0.0

func motion_supported(key: String) -> bool:
	return Catalog.CLIPS[character].has(key)

func playlist() -> Array:
	var result:Array=[]
	var cursor:=0.0
	for source in timeline.segments:
		if source.clip in excluded_playlist_clips:continue
		var segment:Dictionary=source.duplicate()
		var old_native:float=segment.native_length
		var native:float=animation.get_animation(segment.clip).length
		segment.native_length=native
		var loops:float=roundf(float(segment.duration)/old_native) if segment.clip in ["walk","run"] else float(segment.duration)/old_native
		var length:float=Timing.duration(character,segment.clip,native)*loops
		segment.start=cursor
		segment.end=cursor+length
		cursor+=length
		result.append(segment)
	return result

func motion_duration(key: String) -> float:
	if not motion_supported(key): return 0.0
	if key=="full": return float(playlist()[-1].end)
	var clip:String=Catalog.CLIPS[character][key]
	return Timing.duration(character,clip,animation.get_animation(clip).length)

func duration() -> float:
	return motion_duration(motion_key)

func sample(seconds: float) -> void:
	sample_motion(motion_key,seconds)

func sample_motion(key: String, seconds: float) -> void:
	motion_key = key if motion_supported(key) else "idle"
	var clip: String = Catalog.CLIPS[character][motion_key]
	var at := seconds
	if clip=="playlist":
		clip="idle"
		for segment in playlist():
			if seconds<float(segment.end):
				clip=segment.clip
				var period:=Timing.duration(character,clip,float(segment.native_length))
				at=fposmod(maxf(0.0,seconds-float(segment.start)),period)
				break
	sample_clip(clip,at,seconds)

func sample_clip(clip:String,at:float,source_clock:=NAN)->void:
	var previous:String=animation.current_animation
	var clock:=at if is_nan(source_clock) else source_clock
	var dt:=clampf(clock-last_sample,0.0,.1)
	if clock<last_sample:dt=1.0/30.0
	last_sample=clock
	if previous!=clip:
		if previous in ["walk","run"]:extract_tail=.1
		var addition:=clip.begins_with("req") or previous.begins_with("req")
		if addition:skeleton.reset_bone_poses()
		animation.play(clip,.1 if Timing.enabled and clip!=JUMP_CLIP and not addition else 0.0)
	animation.advance(dt if Timing.enabled else 0.0)
	animation.seek(Timing.sample(character,clip,at,animation.get_animation(clip).length),true)
	# Extract locomotion only for this fixed lab comparison, without deleting any source channels.
	# Skill/recoil travel remains native. The real hunt keeps its original controller and models.
	extract_tail=maxf(0.0,extract_tail-dt)
	pivot.position=Vector3.ZERO
	if Timing.enabled and clip!=JUMP_CLIP and not clip.begins_with("req") and root_bone>=0 and (clip in ["walk","run"] or extract_tail>0):
		var delta:=skeleton.get_bone_pose_position(root_bone)-skeleton.get_bone_rest(root_bone).origin
		pivot.position=-(skeleton.global_basis*Vector3(delta.x,0,delta.z))
