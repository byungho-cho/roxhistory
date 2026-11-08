extends "res://tests/building_hold_v056_tests.gd"
func run()->void:
 root.size=Vector2i(1280,800)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.model=GameState.new(SaveStore.new("user://storage_ui_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
 var s:Dictionary=app.model.state.duplicate(true);s.chief_level=4;s.resident_count=3;s.resident_guide_seen=true;s.wood=20;s.stone=20;s.grain=20;s.family_next_at=Time.get_unix_time_from_system()+10000
 s.homes=[{"uid":"h1","style":1,"claimed":true,"level":4,"position":[900,900],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true
 s.facilities=[{"uid":"f1","kind":"farm","level":4,"position":[1300,1000],"cost":{"wood":10,"stone":5}},{"uid":"ss","kind":"stone_store","level":4,"position":[1700,1100],"cost":{"wood":20,"stone":20}},{"uid":"ws","kind":"wood_store","level":4,"position":[1500,1450],"cost":{"wood":20,"stone":20}}]
 check(app.model.commit(s),"Storage scene fixture accepted");app.enter_game();await frames(12)
 for actor in app.world.residents:actor.set_physics_process(false)
 var jobs:=ResidentJobs.new(app.model)
 check(jobs.assign("resident-0","wood","wood_store:ws") and jobs.assign("resident-1","wood","wood_store:ws"),"Two sawmill workers share chief assignment data")
 var worker:TrialResident=app.world.residents[0];worker.job_kind="wood"
 check(is_equal_approx(worker.gather_seconds(),float(DemoConfig.get_data().gather_seconds)*10),"Gather duration derives from hero base times ten")
 check(is_equal_approx(worker.job_walk_factor(),.5),"Outbound worker speed factor")
 s=app.model.state.duplicate(true);s.resident_jobs[worker.resident_id].cargo={"kind":"wood","amount":10};app.model.commit(s)
 check(is_equal_approx(worker.job_walk_factor(),.3),"Loaded return speed factor")
 check(app.resident_panel.bubbles.has("wood_store:ws") and app.resident_panel.bubbles.has("stone_store:ss"),"Both depots expose assignment bubbles")
 var bubble:Button=app.resident_panel.bubbles["wood_store:ws"]
 check(bubble.size==Vector2(46,44) and bubble.get_node("BubbleVisual").scale==Vector2(.5,.5),"Half-size bubble art retains full touch target")
 app.building_menu.selected_key="wood_store:ws";app.building_menu.show();await frames()
 check(bubble.get_node("BubbleVisual").scale==Vector2.ONE,"Selected building emphasizes full-size bubble")
 app.building_menu.close();app.resident_panel.show_building("wood_store:ws");await frames()
 check(app.modal and app.overlay.find_children("*","Button",true,false).size()>=5,"Multi-worker building management opens")
 app.close_modal();await frames()
 for level in range(1,5):
  check(BuildingVisuals.texture("stone_store",level)!=null and BuildingVisuals.texture("wood_store",level)!=null,"Both storage tier textures available")
  check(BuildingVisuals.texture("farm",level).resource_path.contains("v003/farm-empty"),"Farm uses empty base not baked-in crops")
 var farmer:TrialResident=app.world.residents[2];jobs.assign(farmer.resident_id,"farmer","farm:f1");farmer.job_kind="farmer";farmer.position=app.model.building_position("farm:f1")+Vector2(0,90)
 s=app.model.state.duplicate(true);s.farm_cycles={"farm:f1":{"phase":"ready","elapsed":600.0,"cycle_level":4,"cuts":0,"stock":0}};app.model.commit(s)
 farmer._job_tick(.6);check(jobs.entry(farmer.resident_id).cargo.is_empty(),"Farm cut is not subject to lumberjack multiplier")
 farmer._job_tick(.61);check(not jobs.entry(farmer.resident_id).cargo.is_empty(),"Farm harvest still finishes at 1.2 seconds")
 app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.2,Vector2(1400,1100));await frames(8)
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/storage-farm-v003.png")
 var preview:=Control.new();app.stage.add_child(preview);preview.position=Vector2(200,app.h-220)
 for i in 4:
  var kind:String="stone_store" if i<2 else "wood_store"
  var button:DemoButton=app.button(preview,"",func():pass);button.size=BuildSideMenu.TILE_SIZE;button.position=Vector2(i*110,0);BuildSideMenu.install_side_art(button,kind)
  button.art_feedback.get_node("Composition/Locked").visible=i%2==1
  button.art_feedback.get_node("Composition/Artwork").modulate.a=.35 if i%2==1 else 1.0
  check(button.art_feedback.get_node("Composition/Locked").size==Vector2(54,54),"Prepared storage menu lock follows Figma geometry")
 await frames(6);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/storage-menu-preview.png")
 print(JSON.stringify({"checks":checks,"failures":failures}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
