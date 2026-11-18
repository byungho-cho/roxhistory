extends HybridCharacter

const ASSETS := "res://assets/characters/d0051/"
const JUMP_MODEL := "res://assets/characters/d0055/hangyeol-auto-r03.glb"
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

var character := "hangyeol"
var shared_motion_view := false
var animation: AnimationPlayer
var environment: Environment
var cool_fill: DirectionalLight3D

func _ready() -> void:
	super._ready()
	if character=="hangyeol":
		var display_scale := display.scale
		viewport.size = Vector2i(768,720)
		camera.size = 7.0
		display.scale = display_scale
		display.position = -camera.unproject_position(Vector3.ZERO)*display.scale

func build_villager() -> void:
	var packed := load(JUMP_MODEL if character=="hangyeol" else ASSETS+character+"-combat.glb") as PackedScene
	var model := packed.instantiate() as Node3D
	pivot.add_child(model)
	model.scale = Vector3.ONE*1.24
	model.position.y = -.12
	pivot.rotation.y = MOTION_HEADING
	camera.position = GAME_CAMERA
	camera.look_at(GAME_AIM)
	animation = model.find_children("*","AnimationPlayer",true,false)[0]
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.play(CLIPS[character])
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

func duration() -> float:
	return animation.current_animation_length

func sample(seconds: float) -> void:
	animation.seek(clampf(seconds,0.0,duration()),true)
