class_name TrainingHunter
extends Node2D
## Cosmetic practice actor, not a resident/job/combat participant.
var visual:HybridCharacter
var offset:=0.0
var side:=1
var clock:=0.0
var render_elapsed:=0.0
func _init(facing:int,phase_offset:float)->void:side=facing;offset=phase_offset;visibility_layer=2
func _ready()->void:
	name="TrainingHunter";visual=HybridCharacter.new();visual.model_path="res://assets/characters/residents/sturdy_male.glb";visual.render_size_factor=.5
	add_child(visual);visual.scale=Vector2.ONE*.9;visual.set_enabled(true);visual.use_training_spear();queue_redraw()
func _draw()->void:
	draw_set_transform(Vector2(2,-1),0,Vector2(1,.28));draw_circle(Vector2.ZERO,17,SceneStyle.CONTACT_COLOR)
func _process(delta:float)->void:
	var world:=get_parent().get_parent().get_parent() as DemoWorld
	if not is_visible_in_tree() or (world and world.simulation_paused):
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;return
	clock+=delta;render_elapsed+=delta
	var point:=get_global_transform_with_canvas().origin
	if not Rect2(Vector2(-120,-120),get_viewport_rect().size+Vector2(240,240)).has_point(point):
		visual.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;return
	if render_elapsed<1.0/30:return
	if world:visual.set_render_zoom(world.player.zoom_factor)
	visual.work_kind="training";visual.animate(render_elapsed,Vector2(side,0),0,false,"training",clock+offset,false)
	visual.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;render_elapsed=0
