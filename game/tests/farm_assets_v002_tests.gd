extends "res://tests/building_hold_v056_tests.gd"
func run()->void:
 root.size=Vector2i(1280,800)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.model=GameState.new(SaveStore.new("user://farm_art_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
 var s:Dictionary=app.model.state.duplicate(true);s.chief_level=4;s.resident_guide_seen=true;s.facilities=[]
 for level in range(1,5):s.facilities.append({"uid":"art%d"%level,"kind":"farm","level":level,"position":[700+level*260,1100],"cost":{"wood":10,"stone":5}})
 check(app.model.commit(s),"Farm art fixture commits");app.enter_game();await frames(12)
 for level in range(1,5):
  check(BuildingVisuals.texture("farm",level).resource_path.ends_with("farm-empty-l%d.png"%level),"Level %d uses delivered art"%level)
  check(BuildingWorkflow.approved_texture("BLD-FARM-L%d"%level)==BuildingVisuals.texture("farm",level),"Preview and completed level %d agree"%level)
  check(BuildingVisuals.display_size("farm",level).x<=230,"Farm size follows world footprint")
 var menu:BuildingMenu=app.building_menu
 menu.selected_key="farm:art2";menu.show();menu.refresh();await frames()
 check(menu.upgrade_button.position.y>menu.move_button.position.y,"Central upgrade sits lower")
 check(menu.upgrade_button.art_feedback.get_node("RoundBackground").size.x>menu.move_button.art_feedback.get_node("RoundBackground").size.x,"Central action is larger")
 check(menu.close_button.size.x>=44,"Close keeps minimum touch target")
 menu.hide()
 app.build_side.show();app.build_side.refresh();await frames()
 var farm:DemoButton=app.build_side.entries.farm
 check(farm.text.is_empty(),"Delivered menu label is not duplicated")
 check(farm.art_feedback.get_node("Composition/Locked").visible==farm.disabled,"Exactly one lock follows build availability")
 var order:Array[String]=[]
 for kind in BuildSideMenu.KINDS:order.append(kind)
 check(order==["outpost","shrine","hearth","wood_store","stone_store","training","farm","hut"],"Right to left construction order matches design")
 check(app.build_side.entries.hut.position.x>app.build_side.entries.farm.position.x,"Hut is rightmost")
 var lock:Control=farm.art_feedback.get_node("Composition/Locked")
 check(lock.position.x<0 and lock.position.y>100 and lock.size==Vector2(54,54),"Lock uses reference lower-left 1.5x geometry")
 await frames(5);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/construction-side-v006.png")
 var saved_width:float=app.w
 app.w=400;app.build_side.refresh()
 check(app.build_side.scale.x<1 and is_equal_approx(app.build_side.scale.x,app.build_side.scale.y),"Narrow menu scales all artwork proportionally")
 check(app.build_side.size.x*app.build_side.scale.x<=400-app.safe.x*2+.1,"Eight items fit within safe width")
 app.w=saved_width;app.build_side.refresh()
 app.build_side.hide()
 app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.2,app.model.building_position("farm:art2"));await frames(8)
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/farm-assets-v002.png")
 print(JSON.stringify({"checks":checks,"failures":failures}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
