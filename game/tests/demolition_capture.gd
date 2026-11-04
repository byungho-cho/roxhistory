extends SceneTree
var app:Node
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func run()->void:
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 for i in 3:await process_frame
 app.start_region()
 for i in 3:await process_frame
 var next:Dictionary=app.model.state.duplicate(true);next.wood=2;next.stone=2;app.model.commit(next)
 app.model.build(Vector2.ZERO,0);app.model.claim_reward(0)
 app.chrome.clear_effects()
 app.world.player.position=Vector2(1170,880);app.world.player.resume_camera()
 for i in 20:await process_frame
 var key:String=app.model.home_key(0)
 DirAccess.make_dir_recursive_absolute("res://reports/demolition-video")
 for tick in 360:
  if tick==30:
   var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
   event.position=app.world.get_global_transform_with_canvas()*(app.model.home_position(0)+Vector2(0,-100))
   app.gestures._input(event)
  if tick==85:
   var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
   app.gestures._input(event)
  if tick==150:app.confirm_demolition(key)
  await process_frame;await RenderingServer.frame_post_draw
  if tick%2==0:root.get_texture().get_image().save_png("res://reports/demolition-video/frame-%04d.png"%(tick/2))
 print("DEMOLITION_CAPTURE homes=",app.model.built_count()," wood=",app.model.state.wood," stone=",app.model.state.stone)
 quit()
