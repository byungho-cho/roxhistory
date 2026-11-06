class_name BuildingWorkflow
extends Node
## Connects durable upgrade work to existing UI/scenery without placeholder art.
var app:Node
var confirmation_target:=-1
var scaffold:Sprite2D
var retry_after:=0.0
var last_visual_level:=-1
var transition:Tween
var previous_visual:Sprite2D
var scaffold_fade_left:=0.0
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	app.model.changed.connect(refresh_visual)
	refresh_visual()

static func approved_texture(id:String)->Texture2D:
	var entry:=AssetCatalog.entry(id)
	# Explicit approval is required; catalog's generic rock fallback is forbidden.
	if not entry.get("approved",false):return null
	var path:String=entry.get("file","")
	if path.is_empty() or not ResourceLoader.exists(path):return null
	var source:=load(path) as Texture2D
	if source==null:return null
	if entry.has("source_size") and source.get_size()!=Vector2(entry.source_size[0],entry.source_size[1]):return null
	if entry.has("crop"):
		var crop:Array=entry.crop
		if crop.size()!=4:return null
		if not Rect2(Vector2.ZERO,source.get_size()).encloses(Rect2(crop[0],crop[1],crop[2],crop[3])):return null
	return AssetCatalog.texture(id)

func outpost_block_reason()->String:
	if not app.model.can_build_outpost():return app.model.outpost_requirement()
	if approved_texture("BLD-OUTPOST-L1")==null:return "초소 1레벨 확정 게임 에셋 준비 중"
	return ""

func upgrade_block_reason(target:int)->String:
	if app.model.state.has("chief_upgrade"):return "주인공 움집 업그레이드가 진행 중이에요"
	if app.model.chief_level()>=4:return "최대 4단계 움집이에요"
	if app.model.outposts().is_empty():return "초소 1개를 먼저 완성해 주세요"
	if target!=app.model.chief_level()+1:return "건물 단계가 변경되었어요. 다시 선택해 주세요"
	if not app.model.can_upgrade_chief():
		var cost:Dictionary=app.model.chief_upgrade_cost()
		return "나무 %d개와 돌 %d개가 필요해요"%[cost.wood,cost.stone]
	if approved_texture("BLD-CHIEF-L%d"%target)==null:return "%d단계 주인공 움집 에셋 준비 중"%target
	return ""

# Approved radial-menu upgrade action calls this guarded entry point.
func request_upgrade()->void:
	if app.modal or not app.application_active or app.screen!="play" or app.world_map_open:return
	var target:int=app.model.chief_level()+1
	var reason:=upgrade_block_reason(target)
	if not reason.is_empty():app.toast(reason);return
	var cost:Dictionary=app.model.chief_upgrade_cost()
	app.show_modal("주인공 움집 %d단계 업그레이드"%target,"나무 %d개 · 돌 %d개\n공사 시간 %d초\n앱을 닫아도 공사가 진행돼요"%[cost.wood,cost.stone,int(app.model.chief_upgrade_duration(target))],[{"text":"취소","action":app.close_modal},{"text":"업그레이드","action":func():confirm_upgrade(target)}],true,true)
	confirmation_target=target

func confirm_upgrade(target:int)->bool:
	if not app.modal or not app.application_active or confirmation_target!=target:return false
	var reason:=upgrade_block_reason(target)
	if not reason.is_empty():app.close_modal();app.toast(reason);return false
	if not app.model.upgrade_chief():return false
	app.close_modal()
	refresh_visual()
	return true

func refresh_visual()->void:
	if not is_instance_valid(app.world):return
	var chief:EnvironmentProp=app.world.get_node("ExistingHut")
	var level:int=app.model.chief_level()
	var changed:=last_visual_level>=1 and level!=last_visual_level
	var texture:=approved_texture("BLD-CHIEF-L%d"%level)
	if changed and texture!=null:
		if is_instance_valid(transition):transition.kill()
		if is_instance_valid(previous_visual):previous_visual.queue_free()
		previous_visual=Sprite2D.new();previous_visual.texture=chief.sprite.texture;previous_visual.transform=chief.sprite.transform;previous_visual.visibility_layer=2
		previous_visual.texture_filter=chief.sprite.texture_filter;chief.sprite.get_parent().add_child(previous_visual)
		chief.sprite.modulate.a=0
		transition=create_tween().set_parallel(true)
		transition.tween_property(previous_visual,"modulate:a",0.0,.35)
		transition.tween_property(chief.sprite,"modulate:a",1.0,.35)
		transition.chain().tween_callback(previous_visual.queue_free)
		scaffold_fade_left=.35
	last_visual_level=level
	if texture!=null:
		var previous_size:=texture.get_size()*chief.configured_width*EnvironmentProp.BUILDING_IMAGE_SCALE/texture.get_width()
		chief.sprite.texture=texture
		chief.sprite.scale=(previous_size-Vector2(4,4))/texture.get_size()
		chief.sprite.position.y=-previous_size.y*.30+6.0-chief.depth_visual.position.y
	if not is_instance_valid(scaffold):
		scaffold=Sprite2D.new();scaffold.name="ChiefUpgradeScaffold";scaffold.visibility_layer=2
		scaffold.texture=preload("res://assets/effects/construction-scaffold.png")
		scaffold.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		scaffold.scale=Vector2.ONE*300/scaffold.texture.get_width()
		scaffold.position=DemoConfig.CHIEF_POSITION+Vector2(0,-scaffold.texture.get_height()*scaffold.scale.y*.5+55)
		app.world.add_child(scaffold)
	if not app.world.has_node("ChiefUpgradeEffects"):app.world.add_child(UpgradeConstructionEffect.new(app))
	update_scaffold()

func update_scaffold()->void:
	if not is_instance_valid(scaffold):return
	scaffold.visible=(app.model.state.has("chief_upgrade") or scaffold_fade_left>0) and app.screen=="play" and not app.world_map_open and app.application_active
	if not app.model.state.has("chief_upgrade"):
		scaffold.modulate.a=scaffold_fade_left/.35
		return
	if scaffold.visible:
		var job:Dictionary=app.model.state.chief_upgrade
		var duration:float=job.finishes_at-job.started_at
		var progress:=clampf(1.0-app.model.chief_upgrade_remaining()/duration,0,1)
		scaffold.modulate.a=smoothstep(0,.12,progress)

func _process(delta:float)->void:
	scaffold_fade_left=maxf(0,scaffold_fade_left-delta)
	update_scaffold()
	if not app.model.state.has("chief_upgrade"):return
	retry_after=maxf(0,retry_after-delta)
	if app.model.chief_upgrade_remaining()>0 or retry_after>0:return
	# Durable completion is independent of map, modal, movement and ordinary work.
	if app.model.finish_chief_upgrade():
		if is_instance_valid(app.world) and app.screen=="play":app.world.feedback.built(DemoConfig.CHIEF_POSITION)
	else:retry_after=1.0
