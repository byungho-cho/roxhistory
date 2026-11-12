extends Node2D

const RESIDENT := preload("res://scripts/resident_sprite.gd")
const WALK_STRIDE := DemoPlayer.STRIDE*1.16
const LEFT := Vector2(135,340)
const RIGHT := Vector2(825,340)
var pose_count := 6
var body := CharacterBody2D.new()
var sprite: RESIDENT
var target := RIGHT
var phase := 0.0
var visual_elapsed := 0.0
var distance := 0.0
var elapsed := 0.0
var samples := 0
var changes := 0
var previous_frame := Rect2()

func _ready() -> void:
	var ground := Sprite2D.new()
	ground.texture = preload("res://assets/village-ground-review-v002/ground-only.png")
	ground.centered = false
	ground.scale = get_viewport_rect().size/ground.texture.get_size()
	add_child(ground)
	body.position = LEFT
	add_child(body)
	sprite = RESIDENT.new()
	sprite.walk_pose_count = pose_count
	body.add_child(sprite)
	var tag := Label.new()
	tag.text = "%d poses  |  fixed camera" % pose_count
	tag.position = Vector2(26,26)
	tag.add_theme_font_size_override("font_size",22)
	tag.add_theme_color_override("font_outline_color",Color.BLACK)
	tag.add_theme_constant_override("outline_size",5)
	add_child(tag)
	print("WALK_TRIAL_START poses=%d speed=%.2f stride=%.2f" % [pose_count,ActorMovement.speed(),WALK_STRIDE])


func _physics_process(delta: float) -> void:
	var before := body.position
	if before.distance_to(target)<=.2:
		target = LEFT if target==RIGHT else RIGHT
	ActorMovement.move(body,ActorMovement.direction_to(before,target,delta))
	var travelled := body.position.distance_to(before)
	distance += travelled
	phase = fposmod(phase+travelled/WALK_STRIDE*TAU,TAU)
	visual_elapsed += delta
	if visual_elapsed>=1.0/30.0:
		visual_elapsed = 0.0
		sprite.pose(body.velocity.normalized(),phase,travelled>.01,"",0.0,0.0,{})
		samples += 1
		if sprite.region_rect!=previous_frame:
			changes += 1
			previous_frame = sprite.region_rect
	elapsed += delta
	if elapsed>=15.0 and elapsed-delta<15.0:
		print("WALK_TRIAL poses=%d seconds=%.2f travelled=%.2f pose_samples=%d pose_changes=%d" % [pose_count,elapsed,distance,samples,changes])
