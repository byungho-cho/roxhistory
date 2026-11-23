extends SceneTree
const Art=preload("res://scripts/hunt_production_saebom_rally_vfx.gd")
const Silver=preload("res://scripts/saebom_rally_silver_vfx.gd")
const Rig=preload("res://scripts/hunt_production_saebom_rig.gd")
var failed:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failed+=1
  push_error(label)
func run()->void:
 var field:=Node2D.new()
 var unit_group:=Node2D.new()
 root.add_child(field)
 field.add_child(unit_group)
 var bom:=Rig.new()
 unit_group.add_child(bom)
 bom.position=Vector2(475,280)
 bom.set_enabled(true)
 var art:=Art.new()
 art.setup(field,unit_group,bom)
 var positions:Array[Vector2]=[Vector2(395,305),Vector2(534,314),bom.position]
 var alive:Array[bool]=[true,false,true]
 var applied:Array[int]=[0,2,2]
 var clocks:Array[float]=[0.,0.,0.]
 check(art.back_layer.get_index()<unit_group.get_index() and art.front_layer.z_index>unit_group.z_index,"Actual back layer orders behind actor and front layer above")
 check(not art.active,"Fresh helper does not draw")
 art.start(2)
 art.tick(.25,positions,alive,clocks)
 art.release(applied)
 check(art.recipients==[0,2] and not art._has_active_buff(),"Cosmetic release never invents a rules buff")
 check(Silver.frames.size()==150 and Silver.frames[0].get_size()==Vector2(192,192),"Single shared approved 192px sheet sequence loads during setup")
 var shared0:Texture2D=Silver.frames[0]
 Silver.prepare()
 check(Silver.frames[0]==shared0,"Setup reuses the same cached frame resource")
 check(Silver.frame_index(5.,5.)==0 and Silver.frame_index(3.,5.)==60 and Silver.frame_index(.001,5.)==149 and Silver.frame_index(0.,5.)==-1,"Thirty-FPS source uses actual rule clock and excludes true expiry")
 clocks.assign([5.,0.,5.])
 art.pose_after_actor_sample(true)
 check(bom.restore_after_cast != null and art.art.stowed.size()>0,"Actual Saebom pose stows native sling meshes")
 art.tick(.73,positions,alive,clocks)
 art.pose_after_actor_sample(true)
 var capture:=OS.get_environment("ROXHISTORY_TEST_CAPTURE_DIR")
 if not capture.is_empty():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(capture.path_join("production-saebom-rally-wings.png"))
 check(art.active and art._has_active_buff() and art._valid(0) and not art._valid(1),"Wings and ground-up aura remain active for live applied recipients")
 art.pose_after_actor_sample(false)
 check(art.art.stowed.is_empty() and bom.restore_after_cast==null,"Concurrent native pose takes ownership without leaving sling hidden")
 clocks.assign([2.8,0.,2.8])
 art.tick(2.2,positions,alive,clocks)
 check(art.active and art._has_active_buff() and art.art.stowed.is_empty(),"Art outlives cast pose while real recipient timers stay active")
 clocks.assign([0.,0.,0.])
 art.tick(2.8,positions,alive,clocks)
 check(not art.active and art.recipients.is_empty(),"Real expiry removes the artistically faded aura and clears")
 art.start(2)
 art.tick(.4,positions,alive,clocks)
 art.pose_after_actor_sample(true)
 art.cancel()
 check(not art.active and art.art.stowed.is_empty(),"Early exit clears pose and stow state")
 print("Normal Saebom rally presentation: ",checks," checks; ",failed," failures")
 quit(int(failed>0))
