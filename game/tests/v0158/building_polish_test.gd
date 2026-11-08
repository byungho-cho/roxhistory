extends SceneTree
var errors:Array[String]=[]
class FakeApp extends Node:
 var world:Node=null
 func button(parent:Node,_text:String,callback:Callable)->DemoButton:
  var result:=DemoButton.new();parent.add_child(result);result.pressed.connect(callback);return result
 func close_modal()->void:pass
func check(ok:bool,msg:String)->void:
 if not ok:errors.append(msg);push_error(msg)
func _initialize()->void:call_deferred("run")
func run()->void:
 var button:=DemoButton.new();root.add_child(button)
 IntegratedMenuArt.install(button,"upgrade",Vector2(96,96))
 check(button.art_feedback.get_node_or_null("ActionIcon")!=null,"Upgrade uses separate arrow")
 check(button.art_feedback.get_node_or_null("ActionName") is Label,"Label remains text")
 var base:TextureRect=button.art_feedback.get_node("RoundBackground")
 var label:TextureRect=button.art_feedback.get_node("LabelBackground")
 check(is_equal_approx(base.position.y+base.size.y,label.position.y+label.size.y*.5),"Circle edge aligns with label midpoint")
 button.disabled=true;IntegratedMenuArt.refresh(button)
 check(button.art_feedback.get_node("ActionIcon").modulate.r<.7,"Disabled parts dim")
 var model:=GameState.new(SaveStore.new("user://v0158_polish_test"))
 model.start_new()
 var layout:=VillageLayout.new(model);root.add_child(layout);layout.road(Vector2(0,0),Vector2(5,0))
 var road:NaturalRoad=layout.get_child(layout.get_child_count()-1)
 check(road.get_meta("minimum_grid_width",0)>=1.0,"Road at least one complete grid cell wide")
 var edges:=road.edges()
 for i in road.cells.size():check(edges.left[i].distance_to(edges.right[i])>=1.0,"Continuous projected road width")
 var fake:=FakeApp.new();root.add_child(fake)
 var hud:=UpgradeConfirmation.new(fake,"chief",{"wood":100,"stone":50},func():pass);root.add_child(hud);hud.set_process(false)
 check(hud.cost_display.get_node("CostBrush") is TextureRect,"Approved brush is independent asset")
 check(hud.cost_display.confirm_button.size==Vector2(44,44),"Confirmation matches progress button touch target")
 check(hud.find_child("CancelUpgrade",true,false)!=null,"Explicit cancellation avoids camera-gesture ambiguity")
 check(ResourceLoader.exists("res://assets/ui/v0158/lock.png"),"Approved lock icon available")
 print("V0158 building polish: ",errors)
 quit(0 if errors.is_empty() else 1)
