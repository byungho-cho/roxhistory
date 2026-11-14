class_name ResidentPanel
extends Control
## Assignment state is shared by chief management and building entry bubbles.
var app:Node
var counter_button:DemoButton
var bubbles:Dictionary={}
var waiting_overlay: ColorRect
var assignment_list: VBoxContainer
var assignment_count: Label
var assignment_building := ""
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
func style_scroll(bar: ScrollBar, vertical: bool) -> void:
	for style_name: String in ["scroll","scroll_focus","grabber","grabber_highlight","grabber_pressed"]:
		var track := style_name.begins_with("scroll")
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("59401e33") if track else Color("a87336") if style_name == "grabber" else Color("bd8b49")
		skin.set_corner_radius_all(4)
		if not track:
			skin.border_color = Color("e5bd79")
			skin.set_border_width_all(1)
		skin.content_margin_left = 4 if vertical else 8
		skin.content_margin_right = skin.content_margin_left
		skin.content_margin_top = 8 if vertical else 4
		skin.content_margin_bottom = skin.content_margin_top
		bar.add_theme_stylebox_override(style_name,skin)

func content(title:String,subtitle:String,height := 664.0)->VBoxContainer:
	var scroll:ScrollContainer=app.show_modal(title,"",[],false,true,false,Vector2(560,height))
	scroll.name="ResidentAssignmentScroll"
	style_scroll(scroll.get_v_scroll_bar(),true)
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
	var skin := FigmaSlice.new("gold",42)
	skin.name = "AssignmentActionSkin"
	skin.show_behind_parent = true
	button.add_child(skin)
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for color_key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(color_key,Color("47240e"))
	button.custom_minimum_size=Vector2(80,44)
	return button
func open_slots(job: String, jobs: ResidentJobs) -> Array[String]:
	var slots: Array[String] = []
	if job in ["wood","stone"]:
		for index in maxi(0,jobs.gatherer_limit(job)-jobs.assigned_count(job)):slots.append("")
		return slots
	var kind := "farm" if job == "farmer" else "outpost"
	var buildings: Array = app.model.facilities() if kind == "farm" else app.model.outposts()
	for building in buildings:
		if str(building.get("kind","outpost")) != kind:continue
		var key := kind + ":" + str(building.uid)
		if jobs.assigned_to(key).is_empty():slots.append(key)
	return slots

func waiting(jobs: ResidentJobs) -> Array[String]:
	var ids: Array[String] = []
	for id in ResidentAdmission.ids(app.model.state):
		if jobs.entry(id).job == "idle":ids.append(id)
	return ids

func portrait_for(id: String) -> Texture2D:
	var index := ResidentAdmission.ids(app.model.state).find(id)
	return preload("res://assets/ui/d0010/resident-female-portrait.png") if index % 2 == 0 else preload("res://assets/ui/d0010/resident-male-portrait.png")

func assignment_icon(job: String) -> Texture2D:
	match job:
		"wood": return preload("res://assets/ui/d0009/resource-wood.png")
		"stone": return preload("res://assets/ui/d0009/resource-stone.png")
		"farmer": return preload("res://assets/ui/d0009/resource-grain.png")
	return icon(job)

func assignment_slot(parent: Control, callback: Callable, texture: Texture2D, rect: Rect2, caption: String, state := "occupied") -> DemoButton:
	var button: DemoButton = app.button(parent,"",callback)
	button.custom_minimum_size = Vector2(70,70)
	var backgrounds := {
		"occupied": preload("res://assets/ui/d0010/slot-occupied.png"),
		"locked": preload("res://assets/ui/d0010/slot-locked.png"),
		"open": preload("res://assets/ui/d0010/slot-open.png"),
		"picker": preload("res://assets/ui/d0010/slot-picker-unassigned.png"),
	}
	for style in ["normal","pressed","hover","focus","disabled"]:
		button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	var background: TextureRect = app.picture(button,backgrounds[state],Rect2(0,0,70,70))
	background.name = "SlotBackground"
	button.clip_contents = state == "occupied"
	var picture: TextureRect = app.picture(button,texture,rect)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var name_label: Label = app.label(button,caption,11 if state == "occupied" else 12 if state == "picker" else 9,Color("fff0cf") if state == "occupied" else Color("49321e"))
	name_label.name = "ResidentCaption"
	name_label.position = Vector2(0,53)
	name_label.size = Vector2(70,18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if state == "locked":
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
	return button

func textured_action(parent: Control, caption: String, callback: Callable, texture: Texture2D) -> DemoButton:
	var button := action(parent,caption,callback)
	button.get_node("AssignmentActionSkin").hide()
	var art_rect: TextureRect = app.picture(button,texture,Rect2())
	art_rect.show_behind_parent = true
	art_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button

func show_summary(_page:int=0)->void:
	if app.screen!="play" or not app.application_active or app.world_map_open:return
	open_assignment_panel()

func open_assignment_panel(key := "") -> void:
	close_waiting()
	assignment_building = key
	var heading_text := "주민 배정"
	if not key.is_empty():
		heading_text = BuildingWorkflow.building_name(key.get_slice(":",0)) + " · 주민 배정"
	var list := content(heading_text,"",664.0 if key.is_empty() else 216.0)
	assignment_list = list
	var header: HBoxContainer = list.get_parent().get_parent().get_node("ModalHeader")
	var heading: Label = header.get_child(0)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = HudButtons.DIAMETER
	header.add_child(spacer)
	header.move_child(spacer,0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.remove_theme_font_override("font")
	var count: Label = list.get_child(0)
	assignment_count = count
	count.add_theme_font_override("font",FigmaArt.BODY)
	count.add_theme_font_size_override("font_size",14)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var content_box := list.get_parent().get_parent() as VBoxContainer
	list.add_theme_constant_override("separation",6)
	list.remove_child(count)
	content_box.add_child(count)
	content_box.move_child(count,1)
	content_box.add_theme_constant_override("separation",4)
	var header_gap := Control.new()
	header_gap.custom_minimum_size.y = 14
	content_box.add_child(header_gap)
	content_box.move_child(header_gap,2)
	refresh_assignment_panel()

func refresh_assignment_panel() -> void:
	if not is_instance_valid(assignment_list) or not is_instance_valid(app.overlay) or not app.overlay.is_ancestor_of(assignment_list):
		return
	close_waiting()
	var list := assignment_list
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var jobs := ResidentJobs.new(app.model)
	var ids := ResidentAdmission.ids(app.model.state)
	var key := assignment_building
	var scoped := not key.is_empty()
	var building: Dictionary = app.model.lookup_building(key) if scoped else {}
	var scoped_job: String = ResidentJobs.BUILDING_JOBS.get(building.get("kind",""),"")
	var assigned := jobs.assigned_ids(key)
	var limit := jobs.gatherer_limit(scoped_job) if scoped_job in ["wood","stone"] else 1
	assignment_count.text = "%d/%d" % ([assigned.size(),limit] if scoped else [ids.size()-waiting(jobs).size(),ids.size()])
	var visible_jobs: Array = [scoped_job] if scoped else ["wood","stone","farmer","guard"]
	for job: String in visible_jobs:
		if job.is_empty(): continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		list.add_child(row)
		var identity := Control.new()
		identity.custom_minimum_size = Vector2(76,76)
		row.add_child(identity)
		var resource: TextureRect = app.picture(identity,assignment_icon(job),Rect2(13,7,50,44))
		resource.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		app.picture(identity,preload("res://assets/ui/d0009/job-name-brush.png"),Rect2(2,40,72,17))
		var title: Label = app.label(identity,job_name(job),13,Color.WHITE)
		title.position = Vector2(0,39)
		title.size = Vector2(76,18)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var auto := textured_action(identity,"자동 배치",auto_assign.bind(job,key),preload("res://assets/ui/d0010/auto-assign-plate.png"))
		auto.custom_minimum_size = Vector2.ZERO
		auto.position = Vector2(8,57)
		auto.size = Vector2(60,20)
		auto.add_theme_font_size_override("font_size",9)
		for color_key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
			auto.add_theme_color_override(color_key,Color("fff0cf"))
		var rail := ScrollContainer.new()
		rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		style_scroll(rail.get_h_scroll_bar(),false)
		rail.custom_minimum_size.y = 86
		row.add_child(rail)
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation",15)
		var padding := MarginContainer.new()
		padding.add_theme_constant_override("margin_top",7)
		padding.add_theme_constant_override("margin_right",8)
		rail.add_child(padding)
		padding.add_child(slots)
		for id in ids:
			var item := jobs.entry(id)
			if item.job != job or (scoped and not assigned.has(id)): continue
			var target := str(item.get("building",""))
			var slot := assignment_slot(slots,show_waiting.bind(job,target,id),portrait_for(id),Rect2(-3,3,76,72),display_name(id))
			var holder := Control.new()
			holder.custom_minimum_size = slot.custom_minimum_size
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slots.add_child(holder)
			slot.reparent(holder,false)
			slot.position = Vector2.ZERO
			slot.size = holder.custom_minimum_size
			var remove := HudButtons.create(holder,false,unassign_resident.bind(id),"UnassignResident")
			remove.custom_minimum_size = Vector2(18,18)
			remove.size = Vector2(18,18)
			remove.position = Vector2(59,-5)
			remove.art_feedback.get_node("Icon").size = remove.size
		for target in available_slots(job,jobs,key):
			assignment_slot(slots,show_waiting.bind(job,target),preload("res://assets/ui/d0010/slot-silhouette.png"),Rect2(21,13,28,28),"주민 추가","open")
		var locked := "" if scoped and job not in ["wood","stone"] else unlock_hint(job)
		if not locked.is_empty():
			var level := limit+1 if scoped else next_unlock_level(job)
			var levels := range(level,5) if job in ["wood","stone"] else [level]
			for required_level: int in levels:
				var caption := "Lv%d 해제" % required_level if required_level > 0 else "건설 후 해제"
				assignment_slot(slots,func(): pass,preload("res://assets/ui/v0158/lock.png"),Rect2(23,14,24,28),caption,"locked")
		if not scoped: list.add_child(HSeparator.new())

func next_unlock_level(job: String) -> int:
	if job in ["wood","stone"]: return ResidentJobs.new(app.model).gatherer_limit(job)+1
	if job == "guard" and app.model.chief_level() < BuildingRules.REQUIRED_HQ["outpost"]:
		return BuildingRules.REQUIRED_HQ["outpost"]
	var level: int = app.model.chief_level()
	if job == "farmer" and level < 1: return 1
	if job == "farmer" and app.model.built_count() > 0 and level < 3:
		var farms: int = app.model.pending_construction_count("farm")
		for building in app.model.facilities():
			if building.kind == "farm": farms += 1
		if farms >= level: return level+1
	return 0

func available_slots(job: String, jobs: ResidentJobs, key: String) -> Array[String]:
	var slots := open_slots(job,jobs)
	if key.is_empty(): return slots
	var scoped: Array[String] = []
	if job in ["wood","stone"]:
		for slot in slots: scoped.append(key)
	elif slots.has(key):
		scoped.append(key)
	return scoped

func unlock_hint(job: String) -> String:
	if job in ["wood","stone"]:
		var store := ResourceStorage.building(app.model,job)
		if not store.is_empty() and int(store.get("level",1)) < 4:
			return "%s Lv.%d에서 자리가 하나 더 열려요." % [BuildingWorkflow.building_name(store.kind),int(store.get("level",1))+1]
	if job == "farmer":
		var level: int = app.model.chief_level()
		if level < 1:return "촌장집 Lv.1과 주민 움집을 갖추고 농장을 지어 주세요."
		if app.model.built_count() == 0:return "주민 움집을 지으면 농장을 지을 수 있어요."
		var farms: int = app.model.pending_construction_count("farm")
		for building in app.model.facilities():
			if building.kind == "farm":farms += 1
		if farms < mini(3,level):return "농장을 완공하면 자리가 열려요."
		if level < 3:return "촌장집 Lv.%d에서 농장 한도가 늘어요." % (level+1)
	if job == "guard":
		var level := int(BuildingRules.REQUIRED_HQ["outpost"])
		if app.model.chief_level() < level:return "촌장집 Lv.%d에서 초소를 지을 수 있어요." % level
		if app.model.outposts().size() < 3:return "초소를 완공하면 자리가 열려요."
	return ""

func close_waiting() -> void:
	if is_instance_valid(waiting_overlay):
		waiting_overlay.hide()
		waiting_overlay.queue_free()
		waiting_overlay = null

func show_waiting(job: String, target: String, occupant := "") -> void:
	if not app.application_active or not is_instance_valid(app.overlay):return
	var jobs := ResidentJobs.new(app.model)
	if occupant.is_empty() and not available_slots(job,jobs,assignment_building).has(target):
		app.toast("열린 작업 자리가 없어요.")
		return
	close_waiting()
	waiting_overlay = ColorRect.new()
	waiting_overlay.color = Color(0,0,0,.48)
	waiting_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	app.overlay.add_child(waiting_overlay)
	waiting_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var width := minf(520,app.w-2*app.safe.x-22)
	var height := minf(230 if not occupant.is_empty() else 174,app.h-2*app.safe.y-24)
	var panel: PanelContainer = app.box(waiting_overlay,Rect2((app.w-width)*.5,(app.h-height)*.5,width,height))
	var list: VBoxContainer = app.column(panel,8)
	var header := HBoxContainer.new()
	list.add_child(header)
	var title: Label = app.label(header,"%s 배정할 주민"%job_name(job),22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HudButtons.create(header,false,close_waiting,"CloseWaiting")
	var ids := waiting(jobs)
	app.label(list,"미배정 %d명 · 주민을 누르면 바로 배정합니다."%ids.size() if occupant.is_empty() else "%s · 교체할 주민을 선택하세요."%display_name(occupant),16)
	var rail := ScrollContainer.new()
	rail.custom_minimum_size.y = 80
	rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	style_scroll(rail.get_h_scroll_bar(),false)
	list.add_child(rail)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_child(slots)
	var selected := [""]
	var replace: DemoButton
	if not occupant.is_empty():
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override("separation",12)
		list.add_child(actions)
		replace = action(actions,"교체",func(): select_waiting(job,target,str(selected[0]),occupant))
		replace.custom_minimum_size = Vector2(120,38)
		replace.disabled = true
		var release := action(actions,"배정 해제",unassign_resident.bind(occupant))
		release.get_node("AssignmentActionSkin").hide()
		var metal := ColorRect.new()
		metal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		metal.show_behind_parent = true
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/dark_metal_button.gdshader")
		material.set_shader_parameter("face",preload("res://assets/ui/d0010/dark-metal-face.png"))
		metal.material = material
		release.add_child(metal)
		metal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for color_key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
			release.add_theme_color_override(color_key,Color("f3f5f6"))
		release.custom_minimum_size = Vector2(120,38)
		actions.move_child(release,0)
	for id in ids:
		var callback := select_waiting.bind(job,target,id,occupant)
		if is_instance_valid(replace):
			callback = choose_replacement.bind(id,selected,replace,slots)
		var slot := assignment_slot(slots,callback,portrait_for(id),Rect2(9,3,52,52),display_name(id),"picker")
		slot.set_meta("resident_id",id)

func choose_replacement(id: String, selected: Array, replace: DemoButton, slots: HBoxContainer) -> void:
	selected[0] = id
	replace.disabled = false
	for slot: DemoButton in slots.get_children():
		var is_selected: bool = slot.get_meta("resident_id") == id
		var background: TextureRect = slot.get_node("SlotBackground")
		background.texture = preload("res://assets/ui/d0010/slot-occupied.png") if is_selected else preload("res://assets/ui/d0010/slot-picker-unassigned.png")
		var caption: Label = slot.get_node("ResidentCaption")
		caption.add_theme_color_override("font_color",Color("fff0cf") if is_selected else Color("49321e"))

func select_waiting(job: String, target: String, id: String, occupant: String) -> void:
	if occupant.is_empty():
		assign_waiting(job,target,id)
		return
	var jobs := ResidentJobs.new(app.model)
	if jobs.replace_assignment(occupant,id,job,target):
		refresh_assignment_panel()
	else:
		app.toast("주민이나 작업 자리 상태가 바뀌었어요.")

func unassign_resident(id: String) -> void:
	if ResidentJobs.new(app.model).assign(id,"idle"):
		refresh_assignment_panel()

func assign_waiting(job: String, target: String, id: String) -> void:
	var jobs := ResidentJobs.new(app.model)
	if not waiting(jobs).has(id) or not available_slots(job,jobs,assignment_building).has(target):
		refresh_assignment_panel()
		app.toast("주민이나 작업 자리 상태가 바뀌었어요.")
		return
	if jobs.assign(id,job,target):
		refresh_assignment_panel()
		app.toast("%s · %s"%[display_name(id),job_name(job)])

func auto_assign(job: String, key: String) -> void:
	var jobs := ResidentJobs.new(app.model)
	var assigned := 0
	var ids := waiting(jobs)
	var slots := available_slots(job,jobs,key)
	if slots.is_empty():app.toast("열린 작업 자리가 없어요.");return
	if ids.is_empty():app.toast("미배정 주민이 없어요.");return
	for i in mini(ids.size(),slots.size()):
		if not waiting(jobs).has(ids[i]) or not available_slots(job,jobs,key).has(slots[i]):break
		if not jobs.assign(ids[i],job,slots[i]):break
		assigned += 1
	refresh_assignment_panel()
	app.toast("%s %d명을 배정했어요."%[job_name(job),assigned])
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
	var jobs := ResidentJobs.new(app.model)
	if job in ["wood","stone"] and jobs.entry(id_at(index)).job != job and jobs.assigned_count(job) >= jobs.gatherer_limit(job):
		app.toast("이 직업의 배정 자리가 가득 찼어요.")
		return
	if jobs.assign(id_at(index),job,building):
		app.close_modal();app.toast("%s · %s"%[display_name(id_at(index)),job_name(job)])
func show_building(key: String) -> void:
	if key == "chief":
		show_summary()
	elif not app.model.lookup_building(key).is_empty() and ResidentJobs.BUILDING_JOBS.has(key.get_slice(":",0)):
		open_assignment_panel(key)

func assignment_menu_open(key: String) -> bool:
	return app.building_menu.visible and app.building_menu.selected_key == key

func building_at_bubble(screen_point: Vector2) -> String:
	if app.choosing_plot:return ""
	for key in bubbles:
		var button: DemoButton = bubbles[key]
		if button.is_visible_in_tree() and button.get_global_rect().has_point(screen_point):
			return key
	return ""

func open_bubble_assignment(key: String) -> void:
	if assignment_menu_open(key) and not app.choosing_plot and not app.modal:
		show_building(key)

func _process(_delta:float)->void:
	if not is_instance_valid(app.world):return
	var keys:Array[String]=[]
	if app.model.chief_level()>0:keys.append("chief")
	for key in OwnedBuildingUpgrades.keys(app.model):
		if ResidentJobs.BUILDING_JOBS.has(key.get_slice(":",0)):keys.append(key)
	for key in bubbles.keys():
		if not key in keys:bubbles[key].queue_free();bubbles.erase(key)
	for key in keys:
		if not bubbles.has(key):
			var target:=key;var button:DemoButton=app.button(self,"",open_bubble_assignment.bind(target));button.name="AssignmentBubble_"+key.replace(":","_")
			var frame:=StyleBoxFlat.new();frame.bg_color=Color("f4e5bf");frame.border_color=Color("aa8348");frame.set_border_width_all(1);frame.set_corner_radius_all(8)
			for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			button.custom_minimum_size=Vector2(46,44);button.size=button.custom_minimum_size
			var visual:=Panel.new();visual.name="BubbleVisual";visual.mouse_filter=Control.MOUSE_FILTER_IGNORE;visual.add_theme_stylebox_override("panel",frame);visual.size=Vector2(46,44);visual.pivot_offset=Vector2(23,22);button.add_child(visual)
			var portrait:=art(visual,icon("idle"),Vector2.ZERO);portrait.name="AssignmentPortrait";portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bubbles[key]=button
		var button:DemoButton=bubbles[key];var occupant:=ResidentJobs.new(app.model).assigned_to(key)
		button.get_node("BubbleVisual/AssignmentPortrait").modulate.a=1.0 if key=="chief" or not occupant.is_empty() else .18
		var emphasized := assignment_menu_open(key)
		var input_filter := Control.MOUSE_FILTER_STOP if emphasized and not app.choosing_plot else Control.MOUSE_FILTER_IGNORE
		if button.mouse_filter != input_filter:
			button.clear()
			button.mouse_filter = input_filter
		button.get_node("BubbleVisual").scale=Vector2.ONE*(1.0 if emphasized else .5)
		var sprite:Sprite2D=app.world.building_sprite(key)
		button.visible=not app.modal and app.screen=="play" and not app.world_map_open and is_instance_valid(sprite) and sprite.is_visible_in_tree()
		if button.visible:
			var bounds:Rect2=sprite.get_global_transform_with_canvas()*BuildingVisuals.visible_rect(sprite)
			var visual_height:float=44.0*(1.0 if emphasized else .5)
			button.position=Vector2(bounds.get_center().x-23,bounds.position.y-22-visual_height*.5+8)
			button.set_meta("roof_anchor",Vector2(bounds.get_center().x,bounds.position.y))
			button.visible=bounds.intersects(Rect2(0,0,app.w,app.h).grow(4)) and not hud_occludes(button.get_global_rect())

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
