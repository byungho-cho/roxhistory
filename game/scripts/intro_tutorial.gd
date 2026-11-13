class_name IntroTutorial
extends Control

const HAND := preload("res://assets/ui/tutorial/RoxHistory_Tutorial_Hand_Diagonal_v2.png")
const HAND_TIP := Vector2(280,1118)/1254.0

var app: Node
var target_id := ""
var plot := Vector2.INF
var stage_index := -1
var rejected: Array[String] = []
var started_travel := false
var retry_in := 0.0
var press_at := Vector2.INF
var pointer := -2
var age := 0.0
var reminder := 0.0
var construction_focus := Vector2.INF

func _init(owner: Node) -> void:
	app = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45

func active() -> bool:
	return app.screen == "play" and not app.village_entry_active() and app.model.state.get("guided_intro", false) and FirstQuests.current(app.model.state) in [0, 1, 2]

func _process(delta: float) -> void:
	age += delta
	reminder = maxf(0, reminder-delta)
	if not active() or app.modal or not app.task.is_empty() or not app.navigation.action.is_empty():reminder = 0
	queue_redraw()
	if not active() or not app.application_active: return
	var current := FirstQuests.current(app.model.state)
	if current==2:
		var site:=Vector2.INF
		if app.model.chief_level()>0:
			site=app.model.building_position("chief")
		else:
			for job in app.model.construction_jobs():
				if job.kind=="chief":
					site=DemoConfig.point(job.position)
					break
		if site.is_finite():focus_construction(site)
		return
	if app.modal:return
	if stage_index != current:
		stage_index = current
		target_id = ""
		started_travel = false
		retry_in = 0
		rejected.clear()
	if current >= 2 or FirstQuests.intro_reward_ready(app.model.state, current): return
	if started_travel and app.navigation.action.is_empty() and app.task.is_empty():
		reject_target()
	if not target_id.is_empty() and not app.model.gather_available(target_id, "hero"):
		reject_target()
	if not target_id.is_empty(): return
	retry_in -= delta
	if retry_in > 0: return
	retry_in = 1.0
	var kind: String = FirstQuests.INTRO_KINDS[current]
	var choices: Array[Dictionary] = []
	for node in app.model.nodes():
		if node.kind == kind and node.id not in rejected and app.model.gather_available(node.id, "hero"):
			choices.append(node)
	var player: Vector2 = app.world.player.position
	choices.sort_custom(func(a, b):return player.distance_squared_to(DemoConfig.point(a.position)) < player.distance_squared_to(DemoConfig.point(b.position)))
	for node in choices:
		var at := DemoConfig.point(node.position)
		if player.distance_to(at) <= float(DemoConfig.get_data().interact_radius) or not app.navigation.plan_route(app.world.gather_stand(at, kind), []).is_empty():
			target_id = node.id
			app.world.player.hold_tutorial_camera(at-Vector2(0,48))
			return
	rejected.clear()

func reject_target() -> void:
	reminder = 0
	if not target_id.is_empty(): rejected.append(target_id)
	target_id = ""
	started_travel = false
	retry_in = 0

func handle_pointer(event: InputEvent) -> bool:
	var id := -2
	if event is InputEventScreenDrag and pointer==event.index and press_at.distance_to(event.position)>=14:
		press_at=Vector2.INF
	if event is InputEventMouseMotion and pointer==-1 and press_at.distance_to(event.position)>=14:
		press_at=Vector2.INF
	if event is InputEventScreenTouch: id = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not OS.has_feature("android"): id = -1
	if id == -2: return event is InputEventMouse or event is InputEventScreenDrag or event is InputEventGesture
	if event.pressed:
		if pointer == -2:
			pointer = id
			press_at = event.position
	elif pointer == id:
		pointer = -2
		if not (event is InputEventScreenTouch and event.canceled) and press_at.distance_to(event.position) < 14:
			tap(event.position)
	return true

func tap(at: Vector2) -> void:
	if not app.task.is_empty() or not app.navigation.action.is_empty(): return
	var current := FirstQuests.current(app.model.state)
	if FirstQuests.intro_reward_ready(app.model.state,current):return
	var world_at: Vector2 = app.world.get_global_transform_with_canvas().affine_inverse()*at
	if current < 2:
		for node in app.model.nodes():
			if node.id != target_id or not app.world.resource_hit(node,world_at): continue
			var point := DemoConfig.point(node.position)
			reminder = 0
			if app.world.player.position.distance_to(point) <= float(DemoConfig.get_data().interact_radius):
				app.gather_action(node.id)
			else:
				started_travel = app.navigation.start("gather",node.id,app.world.gather_stand(point,node.kind))
				if not started_travel: reject_target()
			return
		reminder = .7
		return
	if app.model.pending_construction_count("chief") > 0: return
	reminder = 0
	if not app.choosing_plot:
		if app.build_button.get_global_rect().has_point(at):app.construction_menu()
		else:reminder = .7
	elif app.build_preview.active():
		if app.build_preview.cost_display.confirm_button.get_global_rect().has_point(at):app.confirm_build_preview()
		elif app.build_preview.cost_display.cancel_button.get_global_rect().has_point(at):app.cancel_build_preview()
		else:reminder = .7
	elif plot.is_finite() and world_at.distance_to(plot) < 65:
		if app.world.placement_requirement("chief",plot).is_empty():app.build_preview.select_position(plot,"chief")
		else:choose_plot()
	else:reminder = .7

func choose_plot() -> bool:
	var center := DemoConfig.CHIEF_POSITION
	for radius in range(0, 601, 75):
		for i in (1 if radius == 0 else 16):
			var candidate := center + Vector2.from_angle(TAU*i/16.0)*radius
			if not app.world.placement_requirement("chief",candidate).is_empty(): continue
			plot = candidate
			focus_construction(plot)
			app.toast("표시된 부지를 눌러 주세요")
			return true
	return false

func focus_construction(site:Vector2)->void:
	if construction_focus==site and app.world.player.manual_camera:return
	construction_focus=site
	app.world.player.hold_tutorial_camera(site-Vector2(0,50))

func _draw() -> void:
	if not active() or app.modal or not app.application_active or not app.task.is_empty() or not app.navigation.action.is_empty(): return
	var current := FirstQuests.current(app.model.state)
	var at := Vector2.INF
	var transform_to_screen: Transform2D = app.world.get_global_transform_with_canvas()
	if current < 2:
		var target: Node2D = app.world.art_nodes.get(target_id)
		if is_instance_valid(target):
			var sprite: Sprite2D = target.get_child(0)
			at = sprite.get_global_transform_with_canvas()*BuildingVisuals.visible_rect(sprite).get_center()
	elif app.model.pending_construction_count("chief") == 0:
		if not app.choosing_plot: at = app.build_button.get_global_rect().get_center()
		elif app.build_preview.active() and app.build_preview.cost_display.visible: at = app.build_preview.cost_display.confirm_button.get_global_rect().get_center()
		elif plot.is_finite(): at = transform_to_screen*plot
	if not at.is_finite() or not get_viewport_rect().has_point(at): return
	if reminder > 0.0:
		var fraction := reminder / .7
		draw_arc(at, lerpf(22, 72, fraction), 0, TAU, 48, Color(1,.86,.35,minf(1.0,fraction*3)), 3, true)
		return
	var phase := fposmod(age,1.1)/1.1
	draw_arc(at, 26+phase*12, 0, TAU, 40, Color(1,.84,.3,1-phase*.55), 3, true)
	var lift:=1.0-smoothstep(.05,.37,phase)+smoothstep(.55,.92,phase)
	var tip:=at+Vector2(0,-14*lift)
	var extent:=minf(82.0,minf((app.w-tip.x)/(1.0-HAND_TIP.x),tip.y/HAND_TIP.y))
	if extent>0:
		draw_texture_rect(HAND,Rect2(tip-HAND_TIP*extent,Vector2.ONE*extent),false)
