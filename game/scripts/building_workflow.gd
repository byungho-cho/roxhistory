class_name BuildingWorkflow
extends Node
## Persisted building work is independent of hero movement, map and app visibility.
var app:Node
var confirmation_target:=-1
var confirmation_overlay:Control
var scaffold:Sprite2D
var retry_after:=0.0
var last_visual_level:=-1
var scaffold_fade_left:=0.0
var owned_progress:Dictionary={}
var construction_progress:Dictionary={}
var owned_confirmation:=""
var cancellation_confirmation:=""
var cancellation_overlay:Control
var owned_overlay:Control
var owned_retry:=0.0
var pending_growth_notice:=""
var upgrade_art_available: Dictionary = {}
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	app.model.changed.connect(refresh_visual)
	refresh_visual()
static func approved_texture(id:String)->Texture2D:
	if id.begins_with("BLD-CHIEF-"):return BuildingVisuals.texture("chief",int(id.get_slice("-",2).trim_prefix("L")))
	if id.begins_with("BLD-STONE_STORE-"):return BuildingVisuals.texture("stone_store",int(id.get_slice("-",2).trim_prefix("L")))
	if id.begins_with("BLD-WOOD_STORE-"):return BuildingVisuals.texture("wood_store",int(id.get_slice("-",2).trim_prefix("L")))
	if id.begins_with("BLD-FARM-"):return BuildingVisuals.texture("farm",int(id.get_slice("-",2).trim_prefix("L")))
	var entry:=AssetCatalog.entry(id)
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
# Packaged art does not change during a session. Keep the result, not the texture.
func has_upgrade_art(id: String) -> bool:
	if not upgrade_art_available.has(id):
		upgrade_art_available[id] = approved_texture(id)!=null
	return upgrade_art_available[id]

static func building_asset_id(kind:String,level:int=1)->String:
	return "BLD-%s-L%d"%[{"chief":"CHIEF","hut":"HUT","home":"HUT","outpost":"OUTPOST","hearth":"HEARTH","training":"TRAINING","shrine":"SHRINE","farm":"FARM","stone_store":"STONE_STORE","wood_store":"WOOD_STORE"}.get(kind,"HUT"),clampi(level,1,4)]
static func building_name(kind:String)->String:
	return {"chief":"촌장집","hut":"주민 움집","home":"주민 움집","outpost":"초소","hearth":"화덕","training":"훈련소","shrine":"신당","farm":"농장","stone_store":"채석장","wood_store":"제재소"}.get(kind,"건물")
static func cost_text(cost:Dictionary)->String:return "나무 %d개 · 돌 %d개"%[int(cost.get("wood",0)),int(cost.get("stone",0))]
func build_block_reason(kind:String,check_resources:bool=true)->String:
	var reason:String=app.model.building_requirement(kind,check_resources)
	if not reason.is_empty():return reason
	if approved_texture(building_asset_id(kind,1))==null:return "%s 확정 게임 에셋 준비 중"%building_name(kind)
	return ""
func outpost_block_reason()->String:return build_block_reason("outpost")
func upgrade_block_reason(target:int,check_resources:bool=true)->String:
	if target!=app.model.chief_level()+1:return "건물 단계가 변경되었어요. 다시 선택해 주세요"
	var reason:String=app.model.upgrade_requirement("chief",check_resources)
	if not reason.is_empty():return reason
	if check_resources and not app.model.can_upgrade_chief():return cost_text(app.model.building_cost("chief",target))+"가 필요해요"
	if not has_upgrade_art(building_asset_id("chief",target)):return "%d단계 촌장집 에셋 준비 중"%target
	return ""
func request_upgrade()->void:
	if app.modal or not app.application_active or app.screen!="play" or app.world_map_open:return
	var target:int=app.model.chief_level()+1
	var reason:=upgrade_block_reason(target,false)
	if not reason.is_empty():app.toast(reason);return
	var cost:Dictionary=app.model.building_cost("chief",target)
	show_upgrade_confirmation("chief",cost,func()->bool:return confirm_upgrade(target))
	confirmation_target=target
func show_upgrade_confirmation(key:String,cost:Dictionary,callback:Callable)->void:
	app.navigation.cancel()
	app.toast_time=0
	var found: Dictionary=app.model.lookup_building(key)
	var current: int=app.model.chief_level() if key=="chief" else int(found.get("data",{}).get("level",1))
	var title := building_name(str(found.get("kind","chief")))+" 업그레이드"
	var scroll: ScrollContainer=app.show_modal(title,"",[],false,true,false,Vector2(724,440),false,false,"popup_open","l")
	var header: HBoxContainer = scroll.get_parent().get_node("ModalHeader")
	var title_label := header.find_child("ModalTitle",true,false) as Label
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font",FigmaArt.BODY)
	title_label.add_theme_font_size_override("font_size",30)
	SharedPopupArt.update_header_title(title_label)
	var balance := Control.new()
	balance.custom_minimum_size.x = header.get_node("ModalClose").custom_minimum_size.x
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(balance)
	header.move_child(balance,0)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(preload("res://scripts/upgrade_popup_content.gd").new(app,str(found.get("kind","chief")),current,cost,callback,confirm_instant_upgrade.bind(key,current+1)))
	confirmation_overlay=app.overlay
func upgrade_description(cost:Dictionary,target:int)->String:
	return "%s\n공사 시간 %d초\n앱을 닫아도 공사가 진행돼요"%[cost_text(cost),int(app.model.building_duration(target))]
func confirm_upgrade(target:int)->bool:
	if not app.modal or not app.application_active or confirmation_target!=target or not is_instance_valid(confirmation_overlay) or app.overlay!=confirmation_overlay:return false
	var reason:=upgrade_block_reason(target)
	if not reason.is_empty():app.toast(reason);return false
	if not app.model.upgrade_chief():return false
	app.audio.cue("upgrade_spend")
	confirmation_target=-1;app.close_modal();refresh_visual();return true
func refresh_visual()->void:
	if not is_instance_valid(app.world):return
	var level:int=app.model.chief_level()
	var changed:=last_visual_level>=1 and level>last_visual_level
	if changed:
		scaffold_fade_left=.35
		pending_growth_notice="촌장집 %d단계 · 마을 경계가 넓어졌어요"%level
	last_visual_level=level
	if not is_instance_valid(scaffold):
		scaffold=Sprite2D.new();scaffold.name="ChiefUpgradeScaffold";scaffold.visibility_layer=2
		scaffold.texture=preload("res://assets/effects/construction-scaffold.png")
		scaffold.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		scaffold.scale=Vector2.ONE*300/scaffold.texture.get_width()
		app.world.add_child(scaffold)
	if not app.world.has_node("ChiefUpgradeEffects"):app.world.add_child(UpgradeConstructionEffect.new(app))
	update_scaffold()
func update_scaffold()->void:
	if not is_instance_valid(scaffold):return
	scaffold.position=app.model.building_position("chief")+Vector2(0,-scaffold.texture.get_height()*scaffold.scale.y*.5+55)
	scaffold.visible=(app.model.state.has("chief_upgrade") or scaffold_fade_left>0) and app.screen=="play" and not app.world_map_open and app.application_active
	if not app.model.state.has("chief_upgrade"):
		scaffold.modulate.a=scaffold_fade_left/.35;return
	if scaffold.visible:
		var job:Dictionary=app.model.state.chief_upgrade
		var duration:float=float(job.get("clock_duration",job.finishes_at-job.started_at))
		var progress:=clampf(1.0-app.model.chief_upgrade_remaining()/maxf(.001,duration),0,1)
		scaffold.modulate.a=smoothstep(0,.12,progress)
func _process(delta:float)->void:
	if not pending_growth_notice.is_empty() and app.screen=="play" and not app.modal and not app.choosing_plot and not app.world_map_open and app.application_active:
		app.show_character_guide(pending_growth_notice,"넓어진 마을에서 채집하고 새로운 건물을 지어 보세요.")
		pending_growth_notice=""
	scaffold_fade_left=maxf(0,scaffold_fade_left-delta);update_scaffold()
	retry_after=maxf(0,retry_after-delta)
	if retry_after<=0:
		var jobs:Array=app.model.construction_jobs().duplicate(true)
		if app.model.finish_constructions():
			for job in jobs:
				if construction_job(str(job.uid)).is_empty():
					close_completed_cancellation(str(job.uid),false)
					if is_instance_valid(app.world) and app.screen=="play":app.world.feedback.built(DemoConfig.point(job.position))
		var pending: Dictionary={}
		for key in OwnedBuildingUpgrades.keys(app.model):
			var found: Dictionary=app.model.lookup_building(key)
			if found.data.has("upgrade"): pending[key]=int(found.data.upgrade.to)
		if OwnedBuildingUpgrades.finish(app.model):
			for key in pending:
				var current: Dictionary=app.model.lookup_building(key)
				if int(current.get("data",{}).get("level",0))==pending[key]:
					close_completed_cancellation(key,true)
					show_upgrade_completed(key,pending[key])
		if app.model.state.has("chief_upgrade") and app.model.chief_upgrade_remaining()<=0:
			if app.model.finish_chief_upgrade():
				close_completed_cancellation("chief",true)
				show_upgrade_completed("chief",app.model.chief_level())
		retry_after=.1
	update_owned_upgrades();update_constructions()
func confirm_instant_upgrade(key: String, target: int) -> bool:
	if not app.modal or not app.application_active or not is_instance_valid(confirmation_overlay) or app.overlay!=confirmation_overlay:
		return false
	var reason := upgrade_block_reason(target) if key=="chief" else owned_upgrade_reason(key)
	if not reason.is_empty():
		app.toast(reason)
		return false
	if not app.model.instant_upgrade(key,target): return false
	app.audio.cue("upgrade_diamond_complete")
	app.close_modal()
	return true

func show_upgrade_completed(key: String, level: int) -> void:
	if not is_instance_valid(app.world) or app.screen!="play" or app.world_map_open or not app.application_active:return
	var at: Vector2=app.model.building_position(key)
	var screen_point: Vector2=app.world.get_global_transform_with_canvas()*at
	if not Rect2(0,0,app.w,app.h).has_point(screen_point):
		app.world.player.play_village_gesture(&"cheer")
		return
	var player: DemoPlayer = app.world.player
	var fanfare := func():
		if app.screen=="play" and not app.world_map_open and app.application_active:
			app.audio.cue("upgrade_fanfare")
			if is_instance_valid(player):
				player.play_village_gesture(&"cheer")
	app.world.add_child(preload("res://scripts/village_upgrade_feedback.gd").new(at,level,fanfare))

func owned_upgrade_reason(key:String,check_resources:bool=true)->String:
	var found:Dictionary=app.model.lookup_building(key)
	if found.is_empty():return "건물을 찾을 수 없어요"
	var reason:String=app.model.upgrade_requirement(key,check_resources)
	if not reason.is_empty():return reason
	var target:=int(found.data.get("level",1))+1
	if not has_upgrade_art(building_asset_id(str(found.kind),target)):return "%s %d단계 확정 에셋 준비 중"%[building_name(str(found.kind)),target]
	return ""
func request_owned_upgrade(key:String)->void:
	if key=="chief":request_upgrade();return
	if app.modal or not app.application_active or app.screen!="play" or app.world_map_open:return
	var reason:=owned_upgrade_reason(key,false)
	if not reason.is_empty():app.toast(reason);return
	var found:Dictionary=app.model.lookup_building(key)
	var target:=int(found.data.get("level",1))+1
	owned_confirmation=key
	var cost:Dictionary=app.model.building_cost(str(found.kind),target)
	show_upgrade_confirmation(key,cost,func()->bool:return confirm_owned_upgrade(key,target))
	owned_overlay=app.overlay
func confirm_owned_upgrade(key:String,target:int)->bool:
	if not app.modal or not app.application_active or owned_confirmation!=key or not is_instance_valid(owned_overlay) or app.overlay!=owned_overlay:return false
	var found:Dictionary=app.model.lookup_building(key)
	if found.is_empty() or int(found.data.get("level",1))+1!=target:return false
	var reason:=owned_upgrade_reason(key)
	if not reason.is_empty():app.toast(reason);return false
	if not OwnedBuildingUpgrades.start(app.model,key):return false
	app.audio.cue("upgrade_spend")
	owned_confirmation="";app.close_modal();return true
func update_owned_upgrades()->void:
	for key in owned_progress.keys():
		if app.model.lookup_building(key).get("data",{}).get("upgrade",{}).is_empty():
			if is_instance_valid(owned_progress[key]):owned_progress[key].queue_free()
			owned_progress.erase(key)
	if not is_instance_valid(app.stage) or not is_instance_valid(app.world):return
	for key in OwnedBuildingUpgrades.keys(app.model):
		var found:Dictionary=app.model.lookup_building(key)
		if not found.data.has("upgrade"):continue
		if not is_instance_valid(owned_progress.get(key)):
			var progress:=ConstructionProgress.new(app,false,true);progress.building_key=key;app.stage.add_child(progress);owned_progress[key]=progress
		var effect_name:="OwnedUpgradeEffects_"+key.replace(":","_")
		if not app.world.has_node(effect_name):
			var effect:=UpgradeConstructionEffect.new(app);effect.building_key=key;app.world.add_child(effect)
func construction_job(uid:String)->Dictionary:
	for job in app.model.construction_jobs():
		if str(job.uid)==uid:return job
	return {}
func update_constructions()->void:
	for uid in construction_progress.keys():
		if construction_job(uid).is_empty():
			if is_instance_valid(construction_progress[uid]):construction_progress[uid].queue_free()
			construction_progress.erase(uid)
	if not is_instance_valid(app.stage) or not is_instance_valid(app.world):return
	for job in app.model.construction_jobs():
		var uid:=str(job.uid)
		if not is_instance_valid(construction_progress.get(uid)):
			var progress:=ConstructionProgress.new(app);progress.construction_uid=uid;app.stage.add_child(progress);construction_progress[uid]=progress
		var effect_name:="ConstructionEffects_"+uid.replace(":","_")
		if not app.world.has_node(effect_name):
			var effect:=UpgradeConstructionEffect.new(app);effect.construction_uid=uid;app.world.add_child(effect)
func request_cancel_construction(uid:String)->void:request_cancel(uid,false)
func request_cancel_upgrade(key:String)->void:request_cancel(key,true)
func request_cancel(key:String,upgrade:bool)->void:
	if app.camera_modal():app.close_modal()
	if app.modal or not app.application_active or app.screen!="play" or app.world_map_open:return
	var job := cancellation_job(key,upgrade)
	if job.is_empty():return
	cancellation_confirmation=cancellation_token(key,upgrade)
	var content: ScrollContainer = app.show_modal("공사를 취소할까요?","",[],false,true,false,Vector2(560,340),false,false,"popup_open","m")
	cancellation_overlay=app.overlay
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation",12)
	content.add_child(layout)
	var intro := RichTextLabel.new()
	intro.bbcode_enabled = true
	intro.fit_content = true
	intro.text = "사용한 재료는 [color=#a52b22][b]90%[/b][/color] 돌려드려요"
	intro.add_theme_color_override("default_color",Color("493220"))
	layout.add_child(intro)
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation",16)
	table.add_theme_constant_override("v_separation",8)
	layout.add_child(table)
	for index in 3:
		var heading: Label = app.label(table,["재료","사용한 재료","돌려받는 재료"][index],15,Color("175789") if index==2 else Color("493220"))
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_theme_font_override("font",FigmaArt.BODY)
	var returned := BuildingRules.cancellation_refund(job.cost)
	for material in ["wood","stone"]:
		var kind := HBoxContainer.new()
		table.add_child(kind)
		var icon: TextureRect = app.picture(kind,DemoArt.icon(material),Rect2(0,0,26,26))
		icon.custom_minimum_size = Vector2(26,26)
		app.label(kind,"목재" if material=="wood" else "석재",16,Color("493220"))
		app.label(table,"%d개"%int(job.cost[material]),16,Color("493220"))
		var amount: Label = app.label(table,"%d개"%int(returned[material]),16,Color("175789"))
		amount.add_theme_font_override("font",FigmaArt.BODY)
	var actions := app.overlay.find_child("ModalActions",true,false) as HBoxContainer
	actions.get_parent().show()
	cancel_action(actions,"공사 계속",app.close_modal,false)
	cancel_action(actions,"공사 취소",confirm_cancel.bind(key,upgrade),true)

func cancel_action(parent: Control, title: String, callback: Callable, ruby: bool) -> void:
	var control: Button = app.button(parent,title,callback)
	control.custom_minimum_size = Vector2(176,44)
	SharedPopupArt.button_style(control,"stone","red" if ruby else "silver")

func cancellation_job(key: String, upgrade: bool) -> Dictionary:
	if not upgrade: return construction_job(key)
	if key=="chief":return app.model.state.get("chief_upgrade",{})
	return app.model.lookup_building(key).get("data",{}).get("upgrade",{})

func cancellation_token(key: String, upgrade: bool) -> String:
	return ("upgrade:" if upgrade else "build:")+key

func close_completed_cancellation(key: String, upgrade: bool) -> void:
	if cancellation_confirmation==cancellation_token(key,upgrade) and is_instance_valid(cancellation_overlay) and app.overlay==cancellation_overlay:
		cancellation_confirmation=""
		app.close_modal()

func confirm_cancel(key:String,upgrade:bool)->bool:
	var token:=cancellation_token(key,upgrade)
	if not app.modal or not app.application_active or cancellation_confirmation!=token or not is_instance_valid(cancellation_overlay) or app.overlay!=cancellation_overlay:return false
	var job := cancellation_job(key,upgrade)
	if job.is_empty(): return false
	if float(job.finishes_at)<=Time.get_unix_time_from_system():
		retry_after=0.0
		_process(0.0)
		return false
	var success:bool=app.model.cancel_upgrade(key) if upgrade else app.model.cancel_construction(key)
	if success:
		cancellation_confirmation=""
		app.close_modal()
		app.toast("공사를 취소하고 사용한 재료의 90%를 돌려드렸어요")
	return success
static func apply_outpost_sprite(image:Sprite2D,level:int)->void:
	var id:=building_asset_id("outpost",level)
	var texture:=approved_texture(id)
	if texture==null:return
	image.texture=texture
	var entry:=AssetCatalog.entry(id)
	if entry.has("ground_pivot"):
		image.centered=false;image.scale=Vector2.ONE*float(entry.display_ground_width)/float(entry.ground_span)
		image.position=-Vector2(entry.ground_pivot[0],entry.ground_pivot[1])*image.scale+Vector2(0,3)
	else:
		image.centered=true;image.scale=Vector2.ONE*180/texture.get_width();image.position=Vector2(0,-texture.get_height()*image.scale.y*.3+3)
