extends SceneTree
var checks:=0
var failures:Array[String]=[]
var family_presses:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame
func touch(button:Button)->void:
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.pressed=down;event.position=button.get_global_rect().get_center()
		root.push_input(event,true);await process_frame
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	app.model=GameState.new(SaveStore.new("user://mobile_controls_%s"%Time.get_ticks_usec()));app.model.start_new();app.enter_game();await frames(15)
	var state:Dictionary=app.model.state.duplicate(true);state.wood=40;state.stone=40;app.model.commit(state)
	app.build_side.select_hut();app.build_preview.select(0);await frames(4)
	var cancel:Button=app.build_preview.controls.get_child(0)
	var confirm:Button=app.build_preview.controls.get_child(1)
	check(cancel is DemoButton and confirm is DemoButton,"Both placement controls use existing touch implementation")
	await touch(cancel)
	check(app.build_preview.site_id==-1 and not app.choosing_plot,"Screen touch cancel dismisses placement")
	check(app.model.state.wood==40 and app.model.built_count()==0,"Cancel preserves resources and buildings")
	app.build_side.select_hut();app.build_preview.select(0);await frames(4)
	await touch(confirm)
	check(app.task=="build","Screen touch confirm starts construction")
	app.cancel_task()
	state=app.model.state.duplicate(true);state.family_unlocked=true;app.model.commit(state)
	app.family._process(0);await frames(3)
	app.family.bubble.pressed.connect(func():family_presses+=1)
	await touch(app.family.bubble)
	check(family_presses==1,"Family touch emits exactly one press")
	check(app.navigation.action=="family" or app.task=="family","Family touch starts existing route/dialogue")
	app.cancel_task();app.family._process(0);await frames(2)
	var motion:=InputEventMouseMotion.new();motion.position=app.family.bubble.get_global_rect().get_center();root.push_input(motion,true);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=app.family.bubble.get_global_rect().get_center();root.push_input(event,true);await process_frame
	check(family_presses==2,"Family mouse click remains single press")
	check(app.navigation.action=="family" or app.task=="family","Family mouse keeps existing route/dialogue")
	app.cancel_task()
	for viewport_size in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(1080,2400)]:
		root.size=viewport_size;await frames(15);app._process(0)
		app.building_menu.selected_key="chief";app.building_menu.show();app.building_menu.refresh()
		var rect:Rect2=app.building_menu.get_global_rect()
		if "--capture-mobile" in OS.get_cmdline_user_args():
			await frames(8);await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://reports/mobile-controls")
			root.get_texture().get_image().save_png("res://reports/mobile-controls/menu-%dx%d.png"%[viewport_size.x,viewport_size.y])
		check(rect.end.y<=app.action_row.global_position.y-7,"Building menu stays above action row %s"%viewport_size)
		check(rect.position.x>=app.safe.x and rect.end.x<=app.w-app.safe.x+1,"Menu stays horizontally within safe area")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
