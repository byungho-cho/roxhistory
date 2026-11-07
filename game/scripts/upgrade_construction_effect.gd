class_name UpgradeConstructionEffect
extends Node2D
## One existing effect vocabulary for every construction and upgrade job.
var app:Node
var building_key:="chief"
var construction_uid:=""
var scaffold:Sprite2D
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name=("ConstructionEffects_"+construction_uid.replace(":","_")) if not construction_uid.is_empty() else ("ChiefUpgradeEffects" if building_key=="chief" else "OwnedUpgradeEffects_"+building_key.replace(":","_"))
	visibility_layer=2;z_index=4
	if not construction_uid.is_empty() or building_key!="chief":
		scaffold=Sprite2D.new();scaffold.texture=preload("res://assets/effects/construction-scaffold.png");scaffold.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;scaffold.visibility_layer=2
		scaffold.scale=Vector2.ONE*250/scaffold.texture.get_width();add_child(scaffold)
func _process(_delta:float)->void:
	var job:=job_data()
	visible=not job.is_empty() and app.screen=="play" and not app.world_map_open and app.application_active
	if visible:
		if is_instance_valid(scaffold):scaffold.position=job_position()+Vector2(0,-scaffold.texture.get_height()*scaffold.scale.y*.5+40)
		queue_redraw()
	elif (building_key!="chief" or not construction_uid.is_empty()) and job.is_empty():queue_free()
func _draw()->void:
	var job:=job_data()
	if job.is_empty():return
	var duration:float=maxf(.001,float(job.get("clock_duration",job.finishes_at-job.started_at)))
	var elapsed:float=clampf(duration-maxf(0,float(job.finishes_at)-Time.get_unix_time_from_system()),0,duration)
	var at:=job_position()
	var shape:=EnvironmentProp.hut_footprint(300 if building_key=="chief" and construction_uid.is_empty() else 230)
	for i in shape.size():shape[i]+=at
	WorldFeedback.draw_build_activity(self,at,shape,elapsed,elapsed/duration)
func job_data()->Dictionary:
	if not construction_uid.is_empty():return app.building_workflow.construction_job(construction_uid)
	if building_key=="chief":return app.model.state.get("chief_upgrade",{})
	return app.model.lookup_building(building_key).get("data",{}).get("upgrade",{})
func job_position()->Vector2:
	if not construction_uid.is_empty():return DemoConfig.point(job_data().get("position",[0,0]))
	return app.model.building_position(building_key)
