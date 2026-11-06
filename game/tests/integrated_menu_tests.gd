extends SceneTree
var app:Node
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(n:int)->void:
	for i in n:await process_frame
func touch(at:Vector2,down:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=down;root.push_input(event,true)
func _initialize()->void:call_deferred("run")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	app.model=GameState.new(SaveStore.new("user://integrated_%s"%Time.get_ticks_usec()));app.model.start_new()
	app.model.build(Vector2.ZERO,0);app.model.claim_reward(0)
	app.enter_game();await frames(15);app.set_process(false)
	var original:Dictionary=app.model.state.duplicate(true)
	for dimensions in [Vector2i(1280,720),Vector2i(540,960)]:
		root.size=dimensions;await frames(20);app._process(0)
		for factor in [DemoPlayer.MIN_ZOOM,DemoPlayer.MAX_ZOOM]:
			app.world.player.zoom_at(Vector2(app.w,app.h)*.5,factor);await frames(5)
			var menu:BuildingMenu=app.building_menu
			var sprite:Sprite2D=app.world.homes[0].sprite
			var offset:Vector2=app.world.player.camera.offset
			check(menu.show_at(sprite.get_global_transform_with_canvas()*Vector2.ZERO),"Building selects with screen point")
			await frames(5);menu.refresh()
			var bounds:Rect2=sprite.get_global_transform_with_canvas()*sprite.get_rect()
			check(menu.position.y>=bounds.end.y+7,"Menu stays below building")
			check(menu.upgrade_button.position.y>menu.demolish_button.position.y,"Downward U center")
			check(menu.close_button.global_position.x>=bounds.end.x,"Close is building right")
			check(menu.position.y+menu.size.y<=app.action_row.global_position.y-7,"Menu avoids bottom HUD")
			check(menu.find_children("*","Label",true,false).is_empty(),"No duplicate live menu names")
			check(menu.move_button.disabled,"Move never enabled")
			var art:TextureRect=menu.upgrade_button.art_feedback.get_node("IntegratedImage")
			check(art.texture.get_size()==Vector2(288,288) and art.size==Vector2(96,96),"Full canvas untrimmed")
			if "--capture-integrated" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://reports/integrated-menu-%dx%d-%s.png"%[dimensions.x,dimensions.y,str(factor)])
			var close_at:=menu.close_button.get_global_rect().get_center()
			touch(close_at,true);touch(close_at,false);await frames(2)
			check(not menu.visible,"Touch closes menu")
			check(app.world.player.camera.offset.is_equal_approx(offset),"Close restores camera offset")
		app._process(0);app.build_side.show();await frames(3)
		var side:BuildSideMenu=app.build_side
		check(absf(side.hut.get_global_rect().get_center().x-app.build_button.get_global_rect().get_center().x)<.1,"Hut centered on build")
		check(side.global_position.y+side.size.y<app.build_button.global_position.y,"Side row above build")
		check(side.hut.position.y==side.outpost_button.position.y,"Side row horizontal")
		check(side.outpost_button.disabled,"Outpost unlock condition retained")
		check(side.outpost_button.art_feedback.modulate==Color.WHITE,"No double disabled alpha")
		check(side.find_children("*","Label",true,false).is_empty(),"No duplicate side names")
		var before:Dictionary=app.model.state.duplicate(true)
		var blocked_at:=side.outpost_button.get_global_rect().get_center()
		touch(blocked_at,true);touch(blocked_at,false);await frames(2)
		check(not app.choosing_plot and app.model.state==before,"Disabled touch does not build or charge")
		if "--capture-integrated" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/integrated-side-%dx%d.png"%[dimensions.x,dimensions.y])
		side.hide()
	check(app.model.state==original,"Menus preserve save and resources")
	app.model.build(Vector2.ZERO,1);app.model.build(Vector2.ZERO,2)
	app.world.player.position+=Vector2(-250,0)
	app.build_side.show();await frames(5)
	check(not app.build_side.outpost_button.disabled,"Unlocked outpost uses normal art")
	check(app.build_side.outpost_button.art_feedback.get_node("IntegratedImage").texture==IntegratedMenuArt.texture("side-outpost","normal"),"Approved normal side state")
	if "--capture-integrated" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/integrated-side-unlocked.png")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
