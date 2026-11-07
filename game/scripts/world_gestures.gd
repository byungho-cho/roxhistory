class_name WorldGestures
extends Node
# Touch ownership is fixed at press time. A UI finger never becomes a pinch.
var app: Node
var touches := {}
var pinching := false
var blocked := false
var start_distance := 1.0
var start_zoom := 1.0
var anchor_world:=Vector2.ZERO
var trace_events:=0
var mouse_start:=Vector2.INF
var mouse_last:=Vector2.ZERO
var middle_dragging:=false
var mouse_dragging:=false
var mouse_can_pan:=false
var panning:=false
var hold_at:=Vector2.INF
var hold_time:=0.0
var hold_consumed:=false
var moving_key:=""
var hold_pointer:=-1
var move_offset:=Vector2.ZERO
func _process(delta:float)->void:
	if not hold_at.is_finite():return
	if app.modal or not app.application_active or pinching or panning or mouse_dragging:hold_at=Vector2.INF;return
	hold_time+=delta
	if hold_time>=0.65:
		var at:=hold_at
		hold_at=Vector2.INF
		if app.choosing_plot:return
		var world_at:Vector2=app.world.get_global_transform_with_canvas().affine_inverse()*at
		var key:String=app.building_menu.hit_key(world_at)
		if key.is_empty():return
		hold_consumed=true
		if app.model.lookup_building(key).get("data",{}).has("upgrade"):
			app.toast("공사 완료 후 이동할 수 있어요");return
		var original:Vector2=app.model.building_position(key)
		app.start_building_move(key)
		if app.build_preview.moving_key!=key:return
		moving_key=key;move_offset=original-app.world.get_global_transform_with_canvas().affine_inverse()*at
		blocked=true;mouse_dragging=false;panning=false
func _init(owner_app: Node) -> void: app=owner_app
func clear() -> void:
	moving_key=""
	hold_at=Vector2.INF;hold_time=0.0;hold_consumed=false
	mouse_start=Vector2.INF
	middle_dragging=false;mouse_dragging=false;panning=false
	touches.clear();pinching=false;blocked=false
	if is_instance_valid(app.joystick): app.joystick.clear()
	if is_instance_valid(app.stage):
		for b in app.stage.find_children("*","Button",true,false):
			if b is DemoButton: b.clear()
	if is_instance_valid(app.world):
		app.world.player.camera.position_smoothing_enabled=true
		app.world.player.cancel_camera_guide()
func ui_hit(at: Vector2) -> bool:
	if app.modal: return true
	if at.y < app.safe.y+(112 if app.w<app.h else 76): return true
	for c in [app.joystick,app.gather_button,app.build_button,app.objective.get_parent()]:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(at): return true
	for button in app.stage.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.get_global_rect().has_point(at):return true
	# Collapsed action slots are empty world space, not invisible input blockers.
	return false
func _input(event: InputEvent) -> void:
	if app.map_transition_active:return
	if app.menu_animating and is_instance_valid(app.action_row) and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion):
		if app.action_row.get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled();return
	if OS.has_feature("android") and app.test_mode and trace_events<30 and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		trace_events+=1;print("PLAY_TOUCH ",event.as_text()," active=",app.application_active," screen=",app.screen)
	if app.world_map_open or app.screen!="play" or not is_instance_valid(app.world) or not app.application_active: return
	if not moving_key.is_empty() and handle_building_drag(event):return
	if event is InputEventMouseButton and not OS.has_feature("android"):
		if event.button_index==MOUSE_BUTTON_MIDDLE:
			middle_dragging=event.pressed and not ui_hit(event.position)
			mouse_last=event.position;hold_at=Vector2.INF
			get_viewport().set_input_as_handled();return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and not ui_hit(event.position):
			app.navigation.cancel();app.world.player.zoom_at(event.position,app.world.player.zoom_factor*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.12));get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_start=event.position if not ui_hit(event.position) else Vector2.INF
				hold_at=mouse_start;hold_time=0.0;hold_consumed=false;hold_pointer=-1
				mouse_last=event.position;mouse_can_pan=not app.world.interaction_at(event.position)
			else:
				hold_at=Vector2.INF
				if not hold_consumed and not mouse_dragging and mouse_start.is_finite() and mouse_start.distance_to(event.position)<12:app.world_tap(event.position)
				if mouse_dragging:blocked=false
				mouse_dragging=false
				mouse_start=Vector2.INF
	if event is InputEventMouseMotion and middle_dragging:
		app.world.player.pan_camera(event.position-mouse_last);mouse_last=event.position
		get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and mouse_start.is_finite() and mouse_can_pan and app.world.player.can_pan():
		if mouse_start.distance_to(event.position)>12 or mouse_dragging:
			if not mouse_dragging:app.navigation.cancel();mouse_last=mouse_start
			mouse_dragging=true;blocked=true
			app.world.player.pan_camera(event.position-mouse_last);get_viewport().set_input_as_handled()
		mouse_last=event.position
	if event is InputEventMouseMotion and hold_at.is_finite() and hold_at.distance_to(event.position)>12:hold_at=Vector2.INF
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index]={"at":event.position,"start":event.position,"ui":ui_hit(event.position),"moved":false,"pan":not app.world.interaction_at(event.position)}
			hold_at=event.position if touches.size()==1 and not ui_hit(event.position) else Vector2.INF
			hold_time=0.0;hold_consumed=false;hold_pointer=event.index
			var world_fingers: Array=[]
			var has_ui:=false
			for key in touches:
				if touches[key].ui: has_ui=true
				else: world_fingers.append(key)
			if not has_ui and world_fingers.size()==2 and (not blocked or panning):
				panning=false
				pinching=true;blocked=true
				start_distance=maxf(20,touches[world_fingers[0]].at.distance_to(touches[world_fingers[1]].at))
				start_zoom=app.world.player.zoom_factor
				if OS.has_feature("android") and app.test_mode: print("PLAY_PINCH_BEGIN ",start_zoom)
				var midpoint: Vector2=(touches[world_fingers[0]].at+touches[world_fingers[1]].at)*0.5
				anchor_world=get_viewport().get_canvas_transform().affine_inverse()*midpoint
				app.navigation.cancel();app.joystick.clear();app.world.player.direction=Vector2.ZERO
				app.world.player.cancel_camera_guide()
				app.world.player.camera.position_smoothing_enabled=false
			if touches.size()>2 and pinching:
				pinching=false;app.world.player.camera.position_smoothing_enabled=true
		else:
			hold_at=Vector2.INF
			if touches.has(event.index) and not blocked:
				var finger:Dictionary=touches[event.index]
				if not hold_consumed and not finger.ui and not finger.moved and finger.start.distance_to(event.position)<12:app.world_tap(event.position)
			touches.erase(event.index)
			if pinching and touches.size()<2:
				pinching=false;app.world.player.camera.position_smoothing_enabled=true
				if OS.has_feature("android") and app.test_mode: print("PLAY_PINCH_END ",app.world.player.zoom_factor)
		if blocked:
			get_viewport().set_input_as_handled()
			if touches.is_empty(): blocked=false;panning=false
	elif event is InputEventScreenDrag and touches.has(event.index):
		if hold_at.is_finite() and hold_at.distance_to(event.position)>12:hold_at=Vector2.INF
		var last:Vector2=touches[event.index].at
		var was_moved:bool=touches[event.index].moved
		if touches[event.index].start.distance_to(event.position)>12:touches[event.index].moved=true
		touches[event.index].at=event.position
		if not pinching and (not blocked or panning) and touches.size()==1 and not touches[event.index].ui and touches[event.index].pan and touches[event.index].moved and app.world.player.can_pan():
			if not was_moved:app.navigation.cancel();last=touches[event.index].start
			blocked=true;panning=true;app.world.player.pan_camera(event.position-last)
		if pinching and touches.size()==2:
			var pair:=touches.values()
			var midpoint: Vector2=(pair[0].at+pair[1].at)*0.5
			var ratio: float=pair[0].at.distance_to(pair[1].at)/start_distance
			app.world.player.zoom_at(midpoint,start_zoom*ratio,anchor_world)
		if blocked: get_viewport().set_input_as_handled()

func handle_building_drag(event:InputEvent)->bool:
	if app.modal or not app.build_preview.active():moving_key="";return false
	# A second finger transfers ownership to pinch, never to a placement tap.
	if event is InputEventScreenTouch and event.pressed and event.index!=hold_pointer:
		moving_key="";blocked=false;hold_at=Vector2.INF;return false
	var release:=false
	var point:=Vector2.INF
	if event is InputEventMouseMotion and hold_pointer==-1:point=event.position
	elif event is InputEventScreenDrag and event.index==hold_pointer:point=event.position
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and hold_pointer==-1:
		point=event.position;release=true
	elif event is InputEventScreenTouch and not event.pressed and event.index==hold_pointer:
		point=event.position;release=true
	if not point.is_finite():return false
	var world_at:Vector2=app.world.get_global_transform_with_canvas().affine_inverse()*point+move_offset
	app.build_preview.select_position(world_at,app.build_preview.kind,moving_key)
	if release:
		touches.erase(hold_pointer);moving_key="";mouse_start=Vector2.INF;hold_at=Vector2.INF
		blocked=not touches.is_empty();hold_consumed=true
	get_viewport().set_input_as_handled();return true
