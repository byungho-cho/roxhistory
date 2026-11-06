extends SceneTree
var app:Node
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame;await physics_frame
func home_point()->Vector2:
	var sprite:Sprite2D=app.world.homes[0].sprite
	return app.world.get_global_transform_with_canvas()*sprite.global_position
func mouse(at:Vector2,pressed:bool)->InputEventMouseButton:
	var event:=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;return event
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(4);app.test_mode=true
	app.model=GameState.new(SaveStore.new("user://menu_%s"%Time.get_ticks_usec()));app.model.start_new()
	var state:Dictionary=app.model.state.duplicate(true);state.wood=100;state.stone=100;app.model.commit(state)
	check(app.model.build(Vector2.ZERO,0),"Fixture house built at normal 20/20 cost")
	app.enter_game();await frames(8)
	var menu:BuildingMenu=app.building_menu
	var before:Dictionary=app.model.state.duplicate(true)
	app.world_tap(home_point());await frames(2)
	check(menu.visible and menu.selected_key==app.model.home_key(0),"Building click opens stable-key menu")
	check(app.model.state==before and menu.demolish_button.disabled,"Building click does not consume pending seed reward")
	check(menu.move_button.disabled and not menu.upgrade_button.disabled,"Movement unavailable; approved resident upgrade available")
	menu.close();app.world_tap(app.world.get_global_transform_with_canvas()*app.world.reward_marker_rect(0).get_center());await frames(2)
	check(not app.model.reward_pending(0),"Seed bubble still grants reward")
	app.world_tap(home_point());await frames(2)
	check(not menu.demolish_button.disabled,"Claimed resident house can be demolished")
	menu.demolish();await frames(2)
	check(app.modal and app.demolition_key==app.model.home_key(0),"Demolition opens existing confirmation with key")
	var buttons:Array=app.overlay.find_children("*","Button",true,false)
	check(buttons.size()==2 and buttons[0].text=="" and buttons[1].text=="","Popup uses close/demolish icons")
	before=app.model.state.duplicate(true);app.close_modal()
	check(app.model.state==before,"Cancel leaves resources and buildings untouched")
	menu.close();app.gestures._input(mouse(home_point(),true));app.gestures._process(.66);app.gestures._input(mouse(home_point(),false));await frames(2)
	check(menu.visible and not app.modal,"Long hold opens menu and consumes release")
	var key:String=app.model.home_key(0);menu.demolish();app.confirm_demolition(key);app.confirm_demolition(key);await frames(3)
	check(app.model.built_count()==0 and app.model.state.wood==98 and app.model.state.stone==98,"Single confirmed refund is 18/18, duplicate ignored")
	var loaded:=GameState.new(app.model.store)
	check(loaded.built_count()==0 and loaded.state.tokens==10 and loaded.state.wood==98,"Demolition/reward survive reload")
	var chief:Sprite2D=app.world.get_node("ExistingHut").sprite
	app.world_tap(app.world.get_global_transform_with_canvas()*chief.global_position);await frames(2)
	check(menu.selected_key=="chief" and menu.demolish_button.disabled,"Chief cannot be demolished")
	check(menu.upgrade_button.disabled and not menu.upgrade_button.hint_text.is_empty(),"Chief upgrade explains unavailable condition")
	check(menu.position.x>=app.safe.x and menu.position.x+menu.size.x<=app.w-app.safe.x,"Menu clamped inside horizontal safe area")
	var chief_point:Vector2=app.world.get_global_transform_with_canvas()*chief.global_position
	menu.close()
	var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=chief_point;touch.pressed=true
	app.gestures._input(touch);app.gestures._process(.66);touch.pressed=false;app.gestures._input(touch);await frames(2)
	check(menu.visible and menu.selected_key=="chief","Touch longpress and release do not click through")
	check(app.gestures.ui_hit(menu.upgrade_button.global_position+menu.upgrade_button.size*.5),"Disabled menu button still owns touch input")
	var camera_before:Vector2=app.world.player.camera.position
	app.world_tap(Vector2(20,app.h*.5));await frames(2)
	check(not menu.visible and app.navigation.action=="" and app.world.player.camera.position==camera_before,"Outside tap only closes menu")
	menu.show_at(chief_point)
	app.switch_map_scene();await frames(2);check(not menu.visible,"Map transition closes menu")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
