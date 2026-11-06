class_name UpgradeConstructionEffect
extends Node2D
## Shared construction drawing, independent from the hero's current activity.
var app:Node
var building_key:="chief"
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:name="ChiefUpgradeEffects" if building_key=="chief" else "OwnedUpgradeEffects_"+building_key.replace(":","_");visibility_layer=2;z_index=4
func _process(_delta:float)->void:
	visible=not job_data().is_empty() and app.screen=="play" and not app.world_map_open and app.application_active
	if visible:queue_redraw()
	elif building_key!="chief" and job_data().is_empty():queue_free()
func _draw()->void:
	if job_data().is_empty():return
	var job:Dictionary=job_data()
	var duration:float=job.finishes_at-job.started_at
	var elapsed:float=clampf(Time.get_unix_time_from_system()-float(job.started_at),0,duration)
	var at:Vector2=DemoConfig.CHIEF_POSITION if building_key=="chief" else OwnedBuildingUpgrades.lookup(app.model,building_key).position
	var shape:=EnvironmentProp.hut_footprint(300)
	for i in shape.size():shape[i]+=at
	WorldFeedback.draw_build_activity(self,at,VillageLayout.polygon(VillageLayout.CHIEF,6) if building_key=="chief" else shape,elapsed,elapsed/maxf(.001,duration))

func job_data()->Dictionary:
	if building_key=="chief":return app.model.state.get("chief_upgrade",{})
	return OwnedBuildingUpgrades.lookup(app.model,building_key).get("data",{}).get("upgrade",{})
