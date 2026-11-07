extends SceneTree
# CPU texture sampling: catches transparent padding even with a headless renderer.
# This verifies geometry/alpha coverage, not GPU output or Android screenshots.
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame
func run()->void:
	var model:=GameState.new(SaveStore.new("user://corner_clouds_%s"%Time.get_ticks_usec()));model.start_new()
	var world:=DemoWorld.new(model);root.add_child(world);await frames(5)
	var clouds:VillageEdgeClouds=world.get_node("VillageEdgeClouds")
	check(clouds.get_child_count()==4,"Four corner decorations")
	check(clouds.visibility_layer==2,"Excluded from the GPS viewport")
	var textures:Array[Image]=[]
	for cloud in clouds.get_children():textures.append(cloud.texture.get_image())
	for dimensions in [Vector2i(1280,720),Vector2i(1972,1248),Vector2i(2340,1080),Vector2i(540,960)]:
		root.size=dimensions;await frames(3)
		for factor in [DemoPlayer.MIN_ZOOM,1.0,1.25,DemoPlayer.MAX_ZOOM,DemoPlayer.MIN_ZOOM]:
			world.player.zoom_at(world.get_viewport_rect().size*.5,factor);await frames(2)
			clouds._process(0)
			if factor==DemoPlayer.MAX_ZOOM:
				check(not clouds.visible,"Maximum zoom hides clouds: %s"%dimensions);continue
			check(clouds.visible and clouds.modulate.a>=.18 and clouds.modulate.a<=.301,"Readable zoom alpha: %s / %s"%[dimensions,factor])
			var viewport_size:=clouds.get_viewport_rect().size
			for i in 4:
				var cloud:Sprite2D=clouds.get_child(i)
				var transform:=cloud.get_global_transform_with_canvas()
				var bounds:Rect2=transform*cloud.get_rect()
				var clipped:=bounds.intersection(Rect2(Vector2.ZERO,viewport_size))
				check(is_equal_approx(clipped.size.y,20.0) and clipped.size.x<=90.01,"Thin corner footprint: %s / %d"%[dimensions,i])
				var inverse:=transform.affine_inverse()
				var image:Image=textures[i]
				var visible_pixels:=0
				var alpha_sum:=0.0
				for y in range(int(ceil(clipped.position.y)),int(floor(clipped.end.y))):
					for x in range(int(ceil(clipped.position.x)),int(floor(clipped.end.x))):
						var source:=inverse*Vector2(x+.5,y+.5)-cloud.get_rect().position
						var px:=Vector2i(source).clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)
						var alpha:=image.get_pixelv(px).a*clouds.modulate.a
						alpha_sum+=alpha
						if alpha>=.08:visible_pixels+=1
				check(visible_pixels>=100 and alpha_sum>=20.0,"Real cloud pixels inside corner: %s / %s / %d (%d pixels, %.1f alpha)"%[dimensions,factor,i,visible_pixels,alpha_sum])
	# Panning must not move the screen-space edge decoration.
	world.player.position+=Vector2(300,100);world.player.camera.force_update_scroll();await frames(3)
	clouds._process(0)
	check(clouds.get_global_transform_with_canvas().is_equal_approx(Transform2D.IDENTITY),"Camera pan is canceled")
	world.queue_free();await frames(2)
	print(JSON.stringify({"suite":"corner_clouds_visibility","checks":checks,"failures":failures,"rendering":"CPU alpha coverage, not device pixels"}))
	quit(0 if failures.is_empty() else 1)
