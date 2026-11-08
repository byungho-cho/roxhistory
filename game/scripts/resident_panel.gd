class_name ResidentPanel
extends Control
## Assignment state is shared by chief management and building entry bubbles.
var app:Node
var counter_button:DemoButton
var bubbles:Dictionary={}
const JOB_NAMES:={"idle":"미배정","wood":"나무꾼","stone":"석재꾼","farmer":"농부","guard":"보초"}
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name="ResidentPanel";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=4;process_priority=30
	counter_button=app.button(self,"",show_summary);counter_button.name="ResidentCounter";counter_button.z_index=28
	counter_button.custom_minimum_size=Vector2.ZERO
	var bounds:Rect2=app.chrome.slot("residents")
	counter_button.position=bounds.position-Vector2(0,4);counter_button.size=Vector2(bounds.size.x,44)
	for state in ["normal","hover","pressed","disabled","focus"]:counter_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
func job_name(job:String)->String:return JOB_NAMES.get(job,"미배정")
func id_at(index:int)->String:
	var ids:=ResidentAdmission.ids(app.model.state)
	return ids[index] if index>=0 and index<ids.size() else ""
func resident_line(index:int)->String:
	var id:=id_at(index);var item:=ResidentJobs.new(app.model).entry(id)
	return "%s · %s · %s"%[display_name(id),job_name(item.job),status(id)]
func display_name(id:String)->String:return "주민 %d"%(int(id.trim_prefix("resident-"))+1)
func status(id:String)->String:
	for actor in app.world.residents:
		if actor.resident_id==id:return actor.work_status()
	return "일을 배정해 주세요"
func icon(job:String)->Texture2D:
	match job:
		"farmer":return preload("res://assets/ui/resident-work-v001/grain.png")
		"guard":return preload("res://assets/ui/resident-work-v001/outpost.png")
		"wood","stone":return DemoArt.icon(job)
	return preload("res://assets/ui/resident-work-v001/resident.png")
func art(parent:Control,texture:Texture2D,dimensions:Vector2)->TextureRect:
	var image:=TextureRect.new();image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image
func content(title:String,subtitle:String)->VBoxContainer:
	var scroll:ScrollContainer=app.show_modal(title,"",[],false,true,false,Vector2(560,664))
	scroll.name="ResidentAssignmentScroll"
	var list:=VBoxContainer.new();list.name="AssignmentContent";list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",14);scroll.add_child(list)
	var text:Label=app.label(list,subtitle,17);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return list
func card(parent:Control)->HBoxContainer:
	var panel:=PanelContainer.new();parent.add_child(panel)
	var skin:=StyleBoxFlat.new();skin.bg_color=Color(1,.94,.77,.20);skin.border_color=Color("c8a46d");skin.set_border_width_all(1);skin.set_corner_radius_all(5);skin.content_margin_left=10;skin.content_margin_right=10;skin.content_margin_top=12;skin.content_margin_bottom=12;panel.add_theme_stylebox_override("panel",skin)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);panel.add_child(row);return row
func action(parent:Control,text:String,callback:Callable)->DemoButton:
	var button:DemoButton=app.button(parent,text,callback)
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var source:=preload("res://assets/ui/v0160/quest-selected-bg.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=Rect2(0,source.get_height()*.2039/1.4058,source.get_width(),source.get_height()/1.4058);crop.filter_clip=true
	var image:=TextureRect.new();image.name="AssignmentActionSkin";image.texture=crop;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;image.show_behind_parent=true;button.add_child(image);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.custom_minimum_size=Vector2(80,44)
	return button
func show_summary(_page:int=0)->void:
	if app.screen!="play" or not app.application_active or app.world_map_open:return
	var jobs:=ResidentJobs.new(app.model);var working:=0
	for id in ResidentAdmission.ids(app.model.state):
		if jobs.entry(id).job!="idle":working+=1
	var list:=content("전체 주민 배분","일하는 주민 %d · 미배정 %d\n촌장과 별도 건설자는 일반 주민에서 제외합니다."%[working,app.model.resident_count()-working])
	for index in app.model.resident_count():
		var id:=id_at(index);var item:=jobs.entry(id);var row:=card(list)
		art(row,icon("idle"),Vector2(50,50))
		var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words)
		app.label(words,display_name(id)+" · "+job_name(item.job),20);app.label(words,status(id),15)
		art(row,icon(item.job),Vector2(42,42))
		var selected:int=index;action(row,"변경",func():show_assignment(selected))
	if app.model.resident_count()==0:app.label(list,"방문객을 맞이하고 주민 움집을 마련해 주세요.",18)
	app.label(list,"주민을 선택해 일을 변경합니다.",16)
func show_assignment(index:int,selected_job:String="",selected_building:String="")->void:
	var id:=id_at(index)
	if id.is_empty():show_summary();return
	var jobs:=ResidentJobs.new(app.model);var item:=jobs.entry(id)
	if selected_job.is_empty():selected_job=str(item.job);selected_building=str(item.get("building",""))
	var list:=content("일 선택",display_name(id))
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);list.add_child(row)
	for job in ["wood","stone","farmer","guard","idle"]:
		var choice:String=job
		var button:=action(row,"",func():show_assignment(index,choice,""));button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size=Vector2(0,88)
		button.get_node("AssignmentActionSkin").hide()
		var outline:=StyleBoxFlat.new();outline.bg_color=Color("f6e9c7");outline.border_color=Color("8aa151") if job==selected_job else Color("c8a46d");outline.set_border_width_all(2 if job==selected_job else 1);outline.set_corner_radius_all(4)
		for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,outline)
		var layout:=VBoxContainer.new();layout.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(layout);layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art(layout,icon(job),Vector2(42,46))
		var text:Label=app.label(layout,job_name(job),16);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if selected_job in ["farmer","guard"]:
		var kind:="farm" if selected_job=="farmer" else "outpost"
		app.label(list,"일할 농장 선택" if kind=="farm" else "근무할 초소 선택",21)
		var buildings:Array=app.model.facilities() if kind=="farm" else app.model.outposts();var count:=0
		for building in buildings:
			if str(building.get("kind","outpost"))!=kind:continue
			count+=1;var key:=kind+":"+str(building.uid);var occupant:=jobs.assigned_to(key)
			var entry:=card(list);art(entry,icon(selected_job),Vector2(52,52))
			var text:Label=app.label(entry,("농장" if kind=="farm" else "초소")+" %d · "%count+("배정 가능" if occupant.is_empty() else display_name(occupant)+" 배정됨"),18);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var target:=key;var choose:=action(entry,"선택됨" if key==selected_building else "선택",func():show_assignment(index,selected_job,target));choose.disabled=not occupant.is_empty() and occupant!=id
		if count==0:app.label(list,"먼저 해당 건물을 지어 주세요.",18)
		app.label(list,"건물마다 주민 1명",16)
	var confirm:=action(list,"배정하기",func():assign(index,selected_job,selected_building));confirm.name="ConfirmResidentAssignment";confirm.disabled=selected_job in ["farmer","guard"] and selected_building.is_empty()
func assign(index:int,job:String,building:String="")->void:
	if not app.application_active:return
	if ResidentJobs.new(app.model).assign(id_at(index),job,building):
		app.close_modal();app.toast("%s · %s"%[display_name(id_at(index)),job_name(job)])
func show_building(key:String)->void:
	if key=="chief":show_summary();return
	var found:Dictionary=app.model.lookup_building(key)
	if found.is_empty():return
	var jobs:=ResidentJobs.new(app.model);var occupant:=jobs.assigned_to(key)
	var list:=content(("농장" if found.kind=="farm" else "초소")+" · 주민 배정",("농부" if found.kind=="farm" else "보초")+" %d / 1명"%(0 if occupant.is_empty() else 1))
	if not occupant.is_empty():action(list,display_name(occupant)+" 배정 해제",func():jobs.assign(occupant,"idle");show_building(key))
	for index in app.model.resident_count():
		var id:=id_at(index);var item:=jobs.entry(id);var row:=card(list)
		art(row,icon("idle"),Vector2(48,48));var text:Label=app.label(row,display_name(id)+" · "+job_name(item.job),18);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var target:int=index;var button:=action(row,"배정",func():assign(target,"farmer" if found.kind=="farm" else "guard",key));button.disabled=not occupant.is_empty()
	app.label(list,"선택한 주민의 기존 배정은 해제됩니다.",15)
func _process(_delta:float)->void:
	if not is_instance_valid(app.world):return
	var keys:Array[String]=[]
	if app.model.chief_level()>0:keys.append("chief")
	for key in OwnedBuildingUpgrades.keys(app.model):
		if key.begins_with("farm:") or key.begins_with("outpost:"):keys.append(key)
	for key in bubbles.keys():
		if not key in keys:bubbles[key].queue_free();bubbles.erase(key)
	for key in keys:
		if not bubbles.has(key):
			var target:=key;var button:DemoButton=app.button(self,"",func():show_building(target));button.name="AssignmentBubble_"+key.replace(":","_")
			var frame:=StyleBoxFlat.new();frame.bg_color=Color("f4e5bf");frame.border_color=Color("aa8348");frame.set_border_width_all(1);frame.set_corner_radius_all(8)
			for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,frame)
			button.custom_minimum_size=Vector2(46,44);button.size=button.custom_minimum_size
			var portrait:=art(button,icon("idle"),Vector2.ZERO);portrait.name="AssignmentPortrait";portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bubbles[key]=button
		var button:DemoButton=bubbles[key];var occupant:=ResidentJobs.new(app.model).assigned_to(key)
		button.get_node("AssignmentPortrait").modulate.a=1.0 if key=="chief" or not occupant.is_empty() else .18
		button.tooltip_text="전체 주민 배분" if key=="chief" else "주민 배정 · "+("미배정" if occupant.is_empty() else display_name(occupant))
		var sprite:Sprite2D=app.world.building_sprite(key)
		button.visible=not app.modal and app.screen=="play" and not app.world_map_open and is_instance_valid(sprite) and sprite.is_visible_in_tree()
		if button.visible:
			var bounds:Rect2=sprite.get_global_transform_with_canvas()*sprite.get_rect()
			button.position=Vector2(bounds.get_center().x-23,bounds.position.y-36)
			button.visible=not hud_occludes(button.get_global_rect())

func fixed_hud_rects()->Array[Rect2]:
	var rects:Array[Rect2]=[Rect2(app.safe+Vector2(-5,-3),Vector2(210,66))]
	for key in ["wood","stone","tokens","residents"]:rects.append(app.chrome.slot(key).grow(2))
	rects.append(Rect2(Vector2(app.w-app.safe.x-108,app.safe.y-5),Vector2(116,122)))
	for control in [app.objective.get_parent(),app.map_toggle]:
		if control is Control and is_instance_valid(control) and control.is_visible_in_tree():rects.append(control.get_global_rect())
	for button in app.action_row.get_children():
		if button is Control and button.is_visible_in_tree():rects.append(button.get_global_rect())
	return rects

func protected_hud_rects()->Array[Rect2]:
	var rects:=fixed_hud_rects()
	if is_instance_valid(app.family.bubble) and app.family.bubble.is_visible_in_tree():rects.append(app.family.bubble.get_global_rect())
	for child in app.stage.get_children():
		if child is ConstructionProgress and child.is_visible_in_tree():
			rects.append(child.get_global_rect().grow(6))
			if is_instance_valid(child.cancel_button):rects.append(child.cancel_button.get_global_rect())
	return rects
func hud_occludes(bounds:Rect2)->bool:
	for rect in protected_hud_rects():
		if rect.intersects(bounds):return true
	return false

func fixed_hud_at(point:Vector2)->bool:
	for rect in fixed_hud_rects():
		if rect.has_point(point):return true
	return false
