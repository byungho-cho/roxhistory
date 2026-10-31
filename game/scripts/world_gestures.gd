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
func _init(owner_app: Node) -> void: app=owner_app
func clear() -> void:
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
	if at.y < app.safe.y+76: return true
	for c in [app.joystick,app.gather_button,app.build_button,app.objective.get_parent(),app.context_panel]:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(at): return true
	for button in app.stage.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.get_global_rect().has_point(at):return true
	var row: Control=app.gather_button.get_parent()
	return row.get_global_rect().has_point(at)
func _input(event: InputEvent) -> void:
	if OS.has_feature("android") and app.test_mode and trace_events<30 and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		trace_events+=1;print("PLAY_TOUCH ",event.as_text()," active=",app.application_active," screen=",app.screen)
	if app.screen!="play" or not is_instance_valid(app.world) or not app.application_active: return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index]={"at":event.position,"ui":ui_hit(event.position)}
			var world_fingers: Array=[]
			var has_ui:=false
			for key in touches:
				if touches[key].ui: has_ui=true
				else: world_fingers.append(key)
			if not has_ui and world_fingers.size()==2 and not blocked:
				pinching=true;blocked=true
				start_distance=maxf(20,touches[world_fingers[0]].at.distance_to(touches[world_fingers[1]].at))
				start_zoom=app.world.player.zoom_factor
				if OS.has_feature("android") and app.test_mode: print("PLAY_PINCH_BEGIN ",start_zoom)
				var midpoint: Vector2=(touches[world_fingers[0]].at+touches[world_fingers[1]].at)*0.5
				anchor_world=get_viewport().get_canvas_transform().affine_inverse()*midpoint
				app.cancel_task();app.joystick.clear();app.world.player.direction=Vector2.ZERO
				app.world.player.cancel_camera_guide()
				app.world.player.camera.position_smoothing_enabled=false
			if touches.size()>2 and pinching:
				pinching=false;app.world.player.camera.position_smoothing_enabled=true
		else:
			touches.erase(event.index)
			if pinching and touches.size()<2:
				pinching=false;app.world.player.camera.position_smoothing_enabled=true
				if OS.has_feature("android") and app.test_mode: print("PLAY_PINCH_END ",app.world.player.zoom_factor)
		if blocked:
			get_viewport().set_input_as_handled()
			if touches.is_empty(): blocked=false
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index].at=event.position
		if pinching and touches.size()==2:
			var pair:=touches.values()
			var midpoint: Vector2=(pair[0].at+pair[1].at)*0.5
			var ratio: float=pair[0].at.distance_to(pair[1].at)/start_distance
			app.world.player.zoom_at(midpoint,start_zoom*ratio,anchor_world)
		if blocked: get_viewport().set_input_as_handled()
