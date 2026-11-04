extends SceneTree
var app:Node
var failed:Array[String]=[]
var checks:=0
func _initialize()->void:
 root.unfocusable=true
 call_deferred("run")
func frames(n:int=4)->void:
 for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failed.append(label);push_error(label)
func snap(name:String)->void:
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/selected-hud-"+name+".png")
func tap(control:DemoButton)->void:
 var down:=InputEventScreenTouch.new();down.index=8;down.pressed=true;down.position=control.size*.5;control._gui_input(down)
 var up:=InputEventScreenTouch.new();up.index=8;up.pressed=false;up.position=control.size*.5;control._gui_input(up)
func run()->void:
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.start_region();app.close_modal();await frames()
 app.world.player.position=Vector2(1150,810)
 await snap("unavailable")
 check(app.gather_button.disabled and app.build_button.disabled,"Distant actions unavailable")
 tap(app.gather_button);await frames()
 check(app.task.is_empty() and app.toast_time>0,"Unavailable touch explains without starting work")
 for size in [Vector2i(1280,720),Vector2i(896,370),Vector2i(816,616),Vector2i(370,896)]:
  root.size=size;await frames(8)
  check(app.action_row.visible and app.action_row.get_child_count()==5,"Always visible five actions "+str(size))
  check(not app.stage.has_node("ActionToggle") and not app.stage.has_node("ExpandActions"),"No fold controls "+str(size))
  var prior:=Rect2()
  for button in app.action_row.get_children():
   var rect:Rect2=button.get_global_rect()
   check(rect.position.x>=0 and rect.end.x<=app.w+1 and rect.end.y<=app.h+1,"Action inside viewport "+button.text+str(size))
   check(not rect.intersects(app.joystick.get_global_rect()),"Action clear of joystick "+button.text+str(size))
   check(not rect.intersects(prior),"Action touch targets separate "+button.text+str(size))
   check(button.size.x>=44 and button.size.y>=44,"Minimum touch target "+button.text+str(size));prior=rect
   check(button.text!="사냥","No future hunting action")
  var previous:=Rect2()
  for kind in ["wood","stone","tokens"]:
   var slot:Rect2=app.chrome.slot(kind)
   check(not slot.intersects(previous),"Independent resource slots "+kind+str(size));previous=slot
   check(slot.end.x<app.w-100 and slot.position.x>=0,"Resource slots clear of minimap "+kind+str(size))
  await snap("layout-%dx%d"%[size.x,size.y])
 root.size=Vector2i(1280,720);await frames(8)
 var target:Vector2=app.world.art_nodes.wood_1.position
 app.world.player.position=target+Vector2(0,35);await frames()
 check(not app.gather_button.disabled and app.gather_button.get_meta("action_state")=="ready","Nearby gather gold-ready state")
 check(app.gather_button.icon==DemoArt.play_icon("berries"),"Existing gather asset")
 await snap("gather-ready")
 tap(app.gather_button);await frames(2)
 check(app.gather_button.working and app.gather_button.get_meta("action_state")=="working","Gather working feedback")
 await snap("gather-working");app.cancel_task()
 check(app.model.state.wood==0,"HUD cancellation never grants resource")
 app.model.gather("wood_1");app.model.gather("stone_1")
 app.world.player.position=app.world.site.position+Vector2(0,65);await frames()
 check(not app.build_button.disabled and app.build_button.get_meta("action_state")=="ready","Prepared nearby build gold-ready state")
 await snap("build-ready")
 tap(app.build_button);await frames(2)
 check(app.build_button.working and app.build_button.get_meta("action_state")=="working","Build working feedback")
 await snap("build-working");app.cancel_task()
 check(app.model.built_count()==0 and app.model.state.wood==1 and app.model.state.stone==1,"Interrupted presentation preserves materials")
 tap(app.stage.get_node("Actions/InventoryButton"));await frames();check(app.modal,"Inventory action still opens existing flow");app.close_modal()
 tap(app.stage.get_node("Actions/JournalButton"));await frames();check(app.modal,"Journal action still opens existing flow");app.close_modal()
 check(is_equal_approx(DemoConfig.get_data().move_speed,181.5),"Movement unchanged")
 check(app.chrome.portrait.resource_path=="res://assets/ui/s40000/portrait.png","Original portrait unchanged")
 var report:Dictionary={"checks":checks,"failed":failed,"runtime":"Native Godot offscreen render and synthetic input, not physical Android"}
 FileAccess.open("res://reports/selected-hud-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
