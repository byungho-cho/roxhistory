extends SceneTree
var app:Node
var failed:Array[String]=[]
var checks:=0
var measured:Array=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failed.append(label);push_error(label)
func frames(n:int=3)->void:
 for i in n:await physics_frame;await process_frame
func tap(at:Vector2)->void:app.world_tap(app.world.get_global_transform_with_canvas()*at)
func snap(name:String)->void:
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/sites-"+name+".png")
func supplies(count:int=3)->void:
 var next:Dictionary=app.model.state.duplicate(true);next.wood=count;next.stone=count;app.model.commit(next)
func run()->void:
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.start_region();app.close_modal();await frames()
 for a in app.world.animals:a.set_physics_process(false)
 for r in app.world.residents:r.set_physics_process(false)
 # Legacy multi-home and pre-array saves keep their original ground anchors and rewards.
 var legacy:=DemoConfig.fresh();legacy.built=true;legacy.reward_claimed=true;legacy.tokens=10
 legacy.homes=[{"style":2,"claimed":true},{"style":1,"claimed":false}]
 check(app.model.commit(legacy),"Legacy two-home save accepted");await frames()
 for i in 2:
  check(app.world.homes[i].position==DemoConfig.HOME_SITES[i],"Legacy home position preserved "+str(i))
 check(app.model.state.tokens==10 and app.model.homes()[0].style==2 and app.model.reward_pending(1),"Legacy style/reward not rerolled")
 var extended:Dictionary=app.model.state.duplicate(true);extended.wood=1;extended.stone=1;app.model.commit(extended)
 check(app.model.build(Vector2.ZERO,3),"Old save can add a chosen new site")
 var migrated:=GameState.new(app.model.store)
 check(migrated.home_position(0)==DemoConfig.HOME_SITES[0] and migrated.home_position(1)==DemoConfig.HOME_SITES[1] and migrated.home_position(2)==DemoConfig.BUILD_SITES[3],"Mixed legacy/new positions survive save reload")
 check(migrated.state.tokens==10 and migrated.homes()[0].style==2 and migrated.reward_pending(1),"Mixed migration preserves rewards and appearance")
 var single:=legacy.duplicate(true);single.erase("homes");single.hut_style=1
 check(app.model.commit(single),"Pre-array save accepted");await frames()
 check(app.model.home_position(0)==DemoConfig.HOME_SITES[0] and not app.model.reward_pending(0),"Pre-array position and reward preserved")
 app.start_region();app.close_modal();await frames();supplies()
 for a in app.world.animals:a.set_physics_process(false)
 for r in app.world.residents:r.set_physics_process(false)
 await frames()
 check(DemoConfig.BUILD_SITES.size()==6,"Six candidate sites")
 for id in 6:
  app.world.player.position=Vector2(1150,900);await frames()
  check(app.world.site_available(id),"Footprint terrain/physics clear "+str(id))
  var point:Vector2=DemoConfig.BUILD_SITES[id]+Vector2(0,65)
  check(app.navigation.start("move","",point),"Actual route exists "+str(id))
  var segments:int=app.navigation.path.size()
  var limit:=1200
  while app.navigation.action!="" and limit>0:await frames(1);limit-=1
  check(app.world.player.position.distance_to(point)<5,"Actual physics arrival "+str(id))
  measured.append({"id":id,"at":str(DemoConfig.BUILD_SITES[id]),"segments":segments,"arrived":limit>0})
 app.world.player.position=Vector2(1150,900);await frames()
 var endpoint:Vector2=DemoConfig.BUILD_SITES[4]+Vector2(0,65)
 check(app.navigation.start("move","",endpoint),"Route starts before a new obstacle")
 var blocker:=StaticBody2D.new();var blocker_shape:=CollisionShape2D.new();var blocker_box:=RectangleShape2D.new();blocker_box.size=Vector2(80,80);blocker_shape.shape=blocker_box;blocker.add_child(blocker_shape);blocker.position=endpoint;app.world.add_child(blocker);await frames()
 app.navigation.stuck=2;app.navigation.previous=app.world.player.position;app.navigation._physics_process(.016)
 check(app.navigation.action=="","Failed route retry cancels instead of retrying every frame")
 blocker.queue_free();await frames()
 var obstacle:=StaticBody2D.new();var collision:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(70,70);collision.shape=box;obstacle.add_child(collision);obstacle.position=DemoConfig.BUILD_SITES[4]+Vector2(0,-40);app.world.add_child(obstacle);await frames()
 check(not app.world.site_available(4) and not app.world.select_site(4),"New obstruction rejects candidate")
 obstacle.queue_free();await frames()
 app.world.player.position=Vector2(1150,900);app.world.player.resume_camera();await frames()
 await snap("candidates")
 app.choosing_plot=true;app.world.show_candidates=true
 tap(DemoConfig.BUILD_SITES[3]);app.confirm_build_preview();check(app.world.selected_site==3 and app.task=="build" and app.navigation.action=="","Choose arbitrary site starts remote construction")
 app.inventory_summary();await frames(6)
 check(app.task=="build" and app.world.selected_site==3,"Informational UI preserves active construction")
 app.close_modal();app.cancel_task()
 app.choosing_plot=true;app.cancel_build_preview();check(not app.choosing_plot and app.world.selected_site==-1,"Explicit selection cancellation")
 app.world.select_site(3);app.world.player.position=DemoConfig.BUILD_SITES[3]+Vector2(0,65);await frames()
 app.build_action();check(app.task=="build" and app.task_site==3,"Construction locks selected site")
 var start_time:float=app.task_remaining
 tap(DemoConfig.BUILD_SITES[3]);tap(DemoConfig.BUILD_SITES[4]);app.build_action()
 check(app.task=="build" and app.task_site==3 and app.task_remaining==start_time,"Repeated work/site clicks do not restart or retarget")
 tap(Vector2(865,680));check(app.task=="build","Existing building click keeps work")
 tap(Vector2(1200,450));check(app.task=="build","Unreachable water click keeps work")
 app.inventory_summary();await frames(12)
 check(app.task=="build" and is_equal_approx(app.task_remaining,start_time),"Inventory pauses without cancelling work")
 app.close_modal();await frames(5);check(app.task_remaining<start_time,"Work resumes after UI closes")
 tap(DemoConfig.BUILD_SITES[3]+Vector2(150,150));await frames()
 check(app.task=="build" and app.pending_action.get("kind","")=="move" and app.model.built_count()==0 and app.model.state.wood==3,"Accepted ground movement queues without spending")
 app.cancel_task()
 app.navigation.cancel();app.world.player.position=DemoConfig.BUILD_SITES[3]+Vector2(0,65);await frames();app.build_action()
 await snap("construction-start")
 await frames(26);await snap("construction-mid")
 check(app.world.feedback.preview.visible and app.world.feedback.preview_progress>0,"Scaffold and progress displayed")
 while app.task_remaining>.08 and app.task=="build":await frames(1)
 app.build_action();tap(DemoConfig.BUILD_SITES[3]);await frames(8)
 check(app.model.built_count()==1 and app.model.state.wood==2 and app.model.state.stone==2,"Near-completion repeat input charges exactly once")
 check(app.model.homes()[0].cost=={"wood":1,"stone":1},"Actual paid build cost recorded, not a future refund calculation")
 check(int(app.model.homes()[0].site)==3 and app.world.homes[0].position==DemoConfig.BUILD_SITES[3],"Selected home stored and rendered at site")
 await snap("construction-complete")
 check(not app.world.select_site(3) and not app.model.build(Vector2.ZERO,3),"Occupied site rejected without spending")
 check(app.model.state.wood==2,"Occupied site preserves inventory")
 app.claim_home(0);app.claim_home(0);check(app.model.state.tokens==10,"Repeated reward claim pays once")
 var reload:=GameState.new(app.model.store)
 check(reload.home_position(0)==DemoConfig.BUILD_SITES[3] and reload.state.tokens==10 and not reload.reward_pending(0),"Selected position/reward survives reload")
 var duplicate:Dictionary=app.model.state.duplicate(true);duplicate.homes.append(duplicate.homes[0].duplicate())
 check(not app.model.store.valid(duplicate),"Duplicate site save rejected")
 duplicate=app.model.state.duplicate(true);duplicate.homes[0].site=99
 check(not app.model.store.valid(duplicate),"Out of range site save rejected")
 # Gather target/UI/camera clicks preserve work; joystick and lifecycle still cancel safely.
 var target:Vector2=app.world.art_nodes.wood_1.position
 app.world.player.position=target+Vector2(0,35);await frames();app.gather_action("wood_1")
 var remaining:float=app.task_remaining;tap(target);tap(Vector2(865,680))
 check(app.task=="gather" and app.task_remaining==remaining,"General resource/building clicks keep gather")
 app.quest_details();await frames(8);check(app.task=="gather" and app.task_remaining==remaining,"Quest UI does not cancel gather");app.close_modal()
 app.joystick.value=Vector2.RIGHT;await frames(2);app.joystick.clear()
 check(app.task=="" and app.model.state.wood==2,"Explicit joystick cancels gather without payout")
 app.world.player.position=target+Vector2(0,35);await frames();app.gather_action("wood_1")
 app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 check(app.task=="" and app.model.state.wood==2,"System interruption gives no duplicate/resource payout")
 # The count cap remains three even though six candidates exist.
 check(app.model.build(Vector2.ZERO,4) and app.model.build(Vector2.ZERO,5),"Two other arbitrary candidates can be built")
 check(app.model.built_count()==3 and not app.model.build(Vector2.ZERO,0),"Three-home limit unchanged")
 check(app.model.state.wood==0 and app.model.state.stone==0,"Each home consumes exactly one of each resource")
 check(DemoConfig.get_data().build_seconds==2 and DemoConfig.get_data().wood_cost==1 and DemoConfig.get_data().stone_cost==1 and DemoConfig.HOME_GOAL==3,"Existing duration/cost/goal preserved")
 var result:Dictionary={"checks":checks,"failed":failed,"candidates":measured,"runtime":"Native Godot physics/navigation/save + synthetic input; not physical Android"}
 FileAccess.open("res://reports/build-sites-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print(JSON.stringify(result));quit(0 if failed.is_empty() else 1)
