extends SceneTree
var app:Node
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func tap(at:Vector2)->void:app.world_tap(app.world.get_global_transform_with_canvas()*at)
func run()->void:
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
 app.start_region();app.close_modal();await process_frame;await physics_frame
 for a in app.world.animals:a.set_physics_process(false)
 for r in app.world.residents:r.set_physics_process(false)
 var next:Dictionary=app.model.state.duplicate(true);next.wood=1;next.stone=1;app.model.commit(next)
 app.world.player.position=Vector2(1150,900)
 DirAccess.make_dir_recursive_absolute("res://reports/site-video")
 var samples:Array=[]
 for tick in 360:
  if tick==20:tap(DemoConfig.BUILD_SITES[3])
  if tick==40:app.cancel_build_preview()
  if tick==50:tap(DemoConfig.BUILD_SITES[0])
  if tick==265 and app.model.built_count()==1:tap(app.world.reward_marker_rect(0).get_center())
  await process_frame
  if tick%2==0:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://reports/site-video/frame-%04d.png"%(tick/2))
   samples.append({"frame":tick,"seconds":tick/60.0,"task":app.task,"remaining":app.task_remaining,"homes":app.model.built_count(),"tokens":app.model.state.tokens,"site":app.world.selected_site})
 FileAccess.open("res://reports/site-video/samples.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
 quit()
