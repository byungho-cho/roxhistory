extends SceneTree
class MockApp extends Node:
 var world:Node=null
 func button(parent:Node,_text:String,callback:Callable)->DemoButton:
  var result:=DemoButton.new();parent.add_child(result);result.pressed.connect(callback);return result
 func close_modal()->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(960,540)
 var bg:=ColorRect.new();bg.color=Color("526a47");bg.size=Vector2(960,540);root.add_child(bg)
 var mock:=MockApp.new();root.add_child(mock)
 for i in 4:
  var sprite:=Sprite2D.new();root.add_child(sprite);BuildingVisuals.apply(sprite,"training",i+1,230);sprite.position+=Vector2(140+i*220,270)
 var menu:=BuildingMenu.new(mock);root.add_child(menu);menu.set_process(false);menu.position=Vector2(100,380);menu.show()
 var hud:=UpgradeConfirmation.new(mock,"chief",{"wood":100,"stone":50},func():pass);root.add_child(hud);hud.set_process(false);hud.position=Vector2(520,365)
 for i in 4:await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/v0158-building-polish.png")
 quit()
