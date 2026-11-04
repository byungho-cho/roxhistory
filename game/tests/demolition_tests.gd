extends SceneTree
var app:Node
var checks:=0
var failed:Array[String]=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failed.append(label);push_error(label)
func frames(n:int=3)->void:
 for i in n:await physics_frame;await process_frame
func point(index:int=0)->Vector2:
 return app.world.get_global_transform_with_canvas()*(app.model.home_position(index)+Vector2(0,-100))
func run()->void:
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.start_region();await frames()
 check(not app.modal and app.screen=="play","Fresh game enters directly")
 for animal in app.world.animals:animal.set_physics_process(false)
 for resident in app.world.residents:resident.set_physics_process(false)
 var fresh:Dictionary=app.model.state.duplicate(true);fresh.wood=3;fresh.stone=3;app.model.commit(fresh)
 check(app.model.build(Vector2.ZERO,3),"Build paid one wood and stone")
 await frames()
 var key:String=app.model.home_key(0)
 check(not app.model.demolish(key),"Unclaimed earned reward cannot be silently deleted")
 app.request_demolition(point());check(not app.modal,"Unclaimed reward asks for normal collection first")
 app.claim_home(0);await frames()
 var initial:Dictionary=app.model.state.duplicate(true)
 var save_path:String=app.model.store.directory.path_join("save.json")
 var bytes:=FileAccess.get_file_as_bytes(save_path)
 var resident_ids:Array=[]
 for r in app.world.residents:resident_ids.append(r.get_instance_id())
 app.request_demolition(point());await frames()
 check(app.modal and app.demolition_key==key,"Longpress request opens confirmation")
 check(app.model.state==initial and FileAccess.get_file_as_bytes(save_path)==bytes,"Opening confirmation does not mutate state or save")
 app.close_modal();await frames()
 check(app.model.state==initial,"Cancel preserves all state")
 app.request_demolition(point());app.overlay.get_child(0).emit_signal("gui_input",mouse(Vector2.ZERO,true));await frames()
 check(not app.modal and app.model.state==initial,"Outside click closes without demolition")
 app.request_demolition(point());app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 app.confirm_demolition(key);app._notification(Node.NOTIFICATION_APPLICATION_RESUMED);await frames()
 check(not app.modal and app.model.state==initial and FileAccess.get_file_as_bytes(save_path)==bytes,"Interruption clears confirmation without save/refund")
 # A physical-input sequence: short click must not demolish; held click consumes release.
 app.gestures._input(mouse(point(),true));app.gestures._process(.2);app.gestures._input(mouse(point(),false));await frames()
 check(app.model.built_count()==1 and not app.modal,"Short click does not demolish")
 # Short click may collect the existing completion reward; retain this legitimate payout.
 var tokens:int=app.model.state.tokens
 app.gestures._input(mouse(point(),true));app.gestures._process(.66);await frames()
 check(app.modal,"Mouse hold opens confirmation at 650ms")
 app.gestures._input(mouse(point(),false));check(app.modal,"Hold release does not click through")
 app.confirm_demolition(key);app.confirm_demolition(key);await frames()
 check(app.model.built_count()==0 and app.model.state.wood==3 and app.model.state.stone==3,"Confirmed demolition refunds exactly 1+1 once")
 check(not app.model.demolish(key),"Stale duplicate model transaction rejected")
 check(app.model.state.tokens==tokens,"Demolition does not grant or remove seed rewards")
 check(not app.world.has_node("HomeCollision0") and not app.world.homes[0].visible,"Removed visual and collision cleared")
 check(app.world.get_node("ExistingHut").visible,"Default world hut preserved")
 for i in resident_ids.size():check(app.world.residents[i].get_instance_id()==resident_ids[i],"Resident retained "+str(i))
 check(app.world.feedback.particles.size()>0,"Committed demolition emits dust")
 var reload:=GameState.new(app.model.store)
 check(reload.built_count()==0 and reload.state.wood==3 and not reload.demolish(key),"Reload retains refund and rejects replay")
 check(app.world.site_available(3),"Former plot becomes available")
 check(app.model.build(Vector2.ZERO,3),"Rebuild on same plot succeeds")
 check(app.model.home_key(0)!=key and not app.model.demolish(key),"New building identity rejects stale confirmation after rebuild")
 # Old indexed homes retain coordinates after deleting an earlier entry.
 var legacy:=DemoConfig.fresh();legacy.built=true;legacy.reward_claimed=true
 legacy.homes=[{"style":2,"claimed":true},{"style":1,"claimed":false}]
 app.model.commit(legacy);await frames()
 check(app.model.demolish(app.model.home_key(0)),"Legacy home demolition supported at historical 1+1 cost")
 check(app.model.home_position(0)==DemoConfig.HOME_SITES[1] and app.model.homes()[0].style==1 and app.model.reward_pending(0),"Survivor retains location/style/pending reward")
 reload=GameState.new(app.model.store)
 check(reload.home_position(0)==DemoConfig.HOME_SITES[1] and reload.state.wood==1,"Legacy survivor and refund survive restart")
 await frames();check(not app.world.has_node("HomeCollision1"),"Shifted legacy array leaves no stale collision")
 for amount in [1,10,11,15,20]:
  var sample:Dictionary=app.model.state.duplicate(true);sample.homes[0].cost={"wood":amount,"stone":1};app.model.commit(sample)
  var quote:Dictionary=app.model.demolition_quote(app.model.home_key(0))
  check(quote.stone==1,"Refund calculated independently per resource "+str(amount))
  if amount<=10:check(quote.wood==amount and quote.supported,"Full return boundary "+str(amount))
  elif amount==20:check(quote.wood==18 and quote.supported,"Exact integer 90 percent future cost")
  else:check(not quote.supported and not app.model.demolish(app.model.home_key(0)),"Unapproved fractional return never rounded "+str(amount))
 # No active demonstration building uses those future costs.
 var sample:Dictionary=app.model.state.duplicate(true);sample.homes[0].cost={"wood":1,"stone":1};app.model.commit(sample);await frames()
 app.gestures.hold_at=point();app.gestures.hold_time=.6;app.gestures.clear();app.gestures._process(1)
 check(not app.modal,"Cleared/aborted longpress cannot open confirmation")
 app.claim_home(0);await frames()
 var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=point();touch.pressed=true
 app.gestures._input(touch);app.gestures._process(.66)
 check(app.modal,"Touch hold opens same confirmation")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/demolition-confirmation.png")
 app.close_modal()
 app.gestures._input(touch)
 var second:=InputEventScreenTouch.new();second.index=1;second.position=point()+Vector2(60,0);second.pressed=true
 app.gestures._input(second);app.gestures._process(.8)
 check(not app.modal,"Two-finger pinch does not trigger demolition")
 app.gestures.clear()
 app.gestures._input(touch)
 var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=point()+Vector2(30,0);drag.relative=Vector2(30,0)
 app.gestures._input(drag);app.gestures._process(.8)
 check(not app.modal,"Drag cancels demolition hold")
 app.gestures.clear()
 app._process(.01);check(not app.context_panel.visible,"Passive lower hint hidden")
 app.toast("저장 오류",2);app._process(.01);check(app.toast_panel.visible,"Required error toast retained")
 app.show_screen("title");await frames()
 var horn:Control=app.stage.get_node("SoundToggle")
 check(horn.size.is_equal_approx(app.design_rect(1357,30,176,176).size),"Title horn doubled within design bounds")
 for size in [Vector2i(360,780),Vector2i(1100,900),Vector2i(1280,720)]:
  root.size=size;await frames(6)
  horn=app.stage.get_node("SoundToggle")
  check(Rect2(Vector2.ZERO,Vector2(app.w,app.h)).encloses(horn.get_global_rect()),"Horn stays visible in logical viewport "+str(size))
 FileAccess.open("res://reports/demolition-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
 print("DEMOLITION ",checks," ",failed);quit(0 if failed.is_empty() else 1)
func mouse(at:Vector2,pressed:bool)->InputEventMouseButton:
 var event:=InputEventMouseButton.new();event.position=at;event.pressed=pressed;event.button_index=MOUSE_BUTTON_LEFT;return event
