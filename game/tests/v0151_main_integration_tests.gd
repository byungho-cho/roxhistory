extends SceneTree
var app:Node
var checks:=0
var failed:Array[String]=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failed.append(message);push_error(message)
func frames(n:int=3)->void:
 for i in n:await physics_frame;await process_frame
func free_position(kind:String,ignore:String="")->Vector2:
 var rect:Rect2=app.world.playable_rect().grow(-220)
 for y in range(int(rect.position.y),int(rect.end.y),210):
  for x in range(int(rect.position.x),int(rect.end.x),240):
   var point:=Vector2(x,y)
   if app.model.placement_requirement(kind,point,ignore).is_empty() and app.world.placement_requirement(kind,point,ignore).is_empty():return point
 return Vector2.INF
func backdrop_tap()->void:
 var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=Vector2(3,3)
 app.overlay.get_child(0).gui_input.emit(touch)
func run()->void:
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.start_region();app.close_modal();await frames(6)
 check(app.model.chief_level()==0 and app.model.resident_count()==0,"Fresh entry has no HQ and no residents")
 check(app.model.state.wood==99999 and app.model.state.stone==99999 and app.model.state.tokens==99999,"All implemented starting resources are99999")
 check(app.objective.text.contains("본부를 건설"),"Fresh objective explains HQ construction")
 check(not app.world.get_node("ExistingHut").visible,"No phantom prebuilt HQ")
 app.show_development_settings();await frames()
 check(app.modal and app.overlay.find_child("FastBuildToggle",true,false)!=null,"Development settings opens full list")
 backdrop_tap();await frames();check(not app.modal,"Settings backdrop touch closes without side effects")
 app.confirm_development_reset();await frames();backdrop_tap();await frames()
 check(not app.modal and app.model.state.wood==99999,"Reset backdrop cancellation retains progress")
 var position:=free_position("chief")
 check(position.is_finite(),"Valid free position found")
 app.build_kind="chief";app.choosing_plot=true;app.build_preview.select_position(position,"chief")
 var before:int=app.model.state.wood
 app.confirm_build_preview();await frames()
 check(app.model.construction_jobs().size()==1,"Main confirm starts one persisted construction")
 check(app.model.state.wood==before-20,"Main confirms exact payment")
 app.confirm_build_preview();check(app.model.construction_jobs().size()==1,"Repeated confirm cannot duplicate")
 check(app.task=="","Construction is independent of hero tasks")
 var finish:float=app.model.construction_jobs()[0].finishes_at
 check(app.model.finish_constructions(finish+1),"Construction completes through persisted deadline")
 await frames(6)
 check(app.model.chief_level()==1 and app.world.get_node("ExistingHut").visible,"Built HQ becomes visible")
 var old:Vector2=app.model.building_position("chief")
 app.start_building_move("chief");await frames()
 check(app.build_preview.moving_key=="chief" and app.build_preview.active(),"Main move opens existing building ghost")
 app.cancel_build_preview();await frames()
 check(app.model.building_position("chief")==old,"Cancel move preserves saved position")
 app.start_building_move("chief");var moved:=free_position("chief","chief")
 if moved.distance_to(old)<1:moved+=Vector2(240,0)
 app.build_preview.select_position(moved,"chief","chief");await frames()
 var valid:bool=app.build_preview.validity()
 check(valid,"Move target has independent model and physics validation")
 if valid:app.confirm_build_preview()
 await frames(6)
 check(app.model.building_position("chief")==moved,"Confirm move saves new coordinates")
 check(app.model.state.wood==before-20,"Moving does not spend building costs")
 var reload:=GameState.new(app.model.store)
 check(reload.building_position("chief")==moved,"Moved HQ survives reload")
 app.model.set_debug_show_boundary(true);await frames()
 check(app.world.boundary_root.get_node("UnlockedPerimeter").visible,"Debug toggle shows actual boundary")
 app.model.set_debug_show_boundary(false);await frames()
 check(not app.world.boundary_root.get_node("UnlockedPerimeter").visible,"Debug off hides line but retains collision walls")
 check(app.world.boundary_root.get_child_count()==5,"Four collision edges remain with line hidden")
 app.pause_game();await frames();backdrop_tap();await frames()
 check(not app.modal,"Pause/settings backdrop dismisses")
 app.show_modal("Independent modal","Test",[{"text":"Close","action":app.close_modal}]);await frames()
 backdrop_tap();await frames();check(app.modal,"Nonsettings confirmation backdrop does not dismiss")
 app.close_modal();app.show_screen("title");app.enter_game();await frames(6)
 check(app.model.chief_level()==1 and app.model.building_position("chief")==moved,"Reenter play retains HQ state")
 var report:={"checks":checks,"failed":failed,"rendering":"headless-state-input-geometry-only"}
 FileAccess.open("res://reports/v0151-main-integration-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));app.queue_free();await frames();quit(0 if failed.is_empty() else 1)
