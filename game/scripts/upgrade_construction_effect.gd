class_name UpgradeConstructionEffect
extends Node2D
## Shared construction drawing, independent from the hero's current activity.
var app:Node
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:name="ChiefUpgradeEffects";visibility_layer=2;z_index=4
func _process(_delta:float)->void:
	visible=app.model.state.has("chief_upgrade") and app.screen=="play" and not app.world_map_open and app.application_active
	if visible:queue_redraw()
func _draw()->void:
	if not app.model.state.has("chief_upgrade"):return
	var job:Dictionary=app.model.state.chief_upgrade
	var duration:float=job.finishes_at-job.started_at
	var elapsed:float=clampf(duration-app.model.chief_upgrade_remaining(),0,duration)
	WorldFeedback.draw_build_activity(self,DemoConfig.CHIEF_POSITION,VillageLayout.polygon(VillageLayout.CHIEF,6),elapsed,elapsed/maxf(.001,duration))
