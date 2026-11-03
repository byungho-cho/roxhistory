class_name TrialResident
extends CharacterBody2D
# Two visual/locomotion prototypes only: no economy, jobs, dialogue or rewards.
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
	origin=position;destination=position;rng.seed=122 if variant=="female" else 347;rest_time=2 if variant=="female" else 4
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
	if rest_time>0:
		rest_time-=delta;velocity=Vector2.ZERO
		if rest_time<=0:
			for i in 12:
				var point:=origin+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(30,70)
				var pose:=transform;pose.origin=point
				if not test_move(pose,Vector2.ZERO,null,.08,true) and not test_move(transform,point-position):destination=point;break
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
		visual.animate(visual_elapsed,velocity.normalized(),phase,travelled>.01,"",0,false)
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		visual_elapsed=0
