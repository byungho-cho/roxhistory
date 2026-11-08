extends "res://tests/building_hold_v056_tests.gd"
func run()->void:
 var probe:=GameState.new(SaveStore.new("user://refill_%d"%Time.get_ticks_usec()));probe.start_new()
 check(probe.state.wood==0 and probe.state.stone==0 and probe.state.grain==0,"Fresh and reset data have no automatic development stock")
 for kind in ["wood","stone"]:
  for node in probe.nodes():
   if node.kind==kind:
    probe.gather(node.id);probe.gather(node.id);break
 check(probe.state.wood==20 and probe.state.stone==20 and probe.can_construct("chief"),"Zero-stock new game can gather materials and unlock chief construction")
 var s:Dictionary=probe.state.duplicate(true);s.copper=7;probe.commit(s)
 check(probe.debug_fill_resources() and probe.state.wood==9999 and probe.state.stone==9999 and probe.state.grain==9999,"Refill sets three resources to development stock")
 check(probe.resident_count()==0 and probe.state.copper==7,"Refill does not alter residents or copper")
 var reload:=GameState.new(probe.store);check(reload.state.wood==9999,"Filled stock survives reload above production cap")
 s=probe.state.duplicate(true);s.wood=12345;probe.commit(s);probe.debug_fill_resources();check(probe.state.wood==12345,"Refill preserves higher existing stock")
 s=probe.state.duplicate(true);s.stone=5;probe.commit(s);probe.store.blocked=true
 check(not probe.debug_fill_resources() and probe.state.stone==5,"Failed refill save preserves existing data")
 root.size=Vector2i(1280,800)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.model=GameState.new(SaveStore.new("user://readability_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
 s=app.model.state.duplicate(true);s.chief_level=4;s.resident_count=15;s.wood=99999;s.stone=99999;s.grain=99999;s.resident_guide_seen=true;s.family_next_at=Time.get_unix_time_from_system()+10000
 s.homes=[]
 for i in 3:s.homes.append({"uid":"h%d"%i,"style":1,"claimed":true,"level":4,"position":[650+i*260,1050+i%2*230],"cost":{"wood":20,"stone":10}})
 s.built=true;s.reward_claimed=true;s.facilities=[]
 for spec in [{"uid":"f1","kind":"farm","level":4,"position":[1350,1400]},{"uid":"f2","kind":"farm","level":2,"position":[1050,1550]},{"uid":"f3","kind":"farm","level":3,"position":[700,1500]},{"uid":"ws","kind":"wood_store","level":1,"position":[1600,650]},{"uid":"ss","kind":"stone_store","level":1,"position":[1600,950]},{"uid":"tr1","kind":"training","level":4,"position":[1800,1300]},{"uid":"tr2","kind":"training","level":2,"position":[1500,1150]},{"uid":"hr","kind":"hearth","level":3,"position":[1300,650]},{"uid":"sh","kind":"shrine","level":4,"position":[1750,1500]}]:
  spec.cost={"wood":20,"stone":20};s.facilities.append(spec)
 s.outposts=[{"uid":"p1","level":2,"position":[1300,950],"cost":{"wood":10,"stone":10}}]
 check(app.model.commit(s),"Dense review fixture accepted");app.enter_game();await frames(12)
 for actor in app.world.residents:actor.set_physics_process(false)
 app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,.75,Vector2(1250,1050));await frames()
 var expected_quest:String=app.objective.text
 check(app.model.state.wood==99999 and app.model.resident_count()==15,"Existing resource and population policy preserved")
 for child in app.world.get_children():
  if child is VillageLayout:
   var total:=0
   for pad in child.get_children():
    if pad.has_meta("foundation_level"):total+=1
   check(total==7,"Only chief, three huts, outpost and two training buildings keep shared pads")
 var bubble:Button=app.resident_panel.bubbles["wood_store:ws"]
 var visual:Control=bubble.get_node("BubbleVisual")
 var lower:Vector2=visual.get_global_transform()*Vector2(23,44)
 var roof:Vector2=bubble.get_meta("roof_anchor")
 check(absf(lower.y-roof.y-8)<1,"Visible bubble art meets visible roof with eight-pixel overlap")
 check(bubble.size==Vector2(46,44),"Assignment hit area remains unshrunk")
 app.build_side.show();await frames()
 check(BuildSideMenu.ART_SCALE==.9 and app.build_side.visible_slots==6,"Readable artwork and six-slot scrolling retained")
 var locked:Control=app.build_side.entries.wood_store.art_feedback.get_node("Composition/Artwork/MenuLabel")
 check(locked.modulate.a==1,"Locked building label remains readable")
 check(app.objective.text==expected_quest,"Quest content intentionally unchanged")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/readability-dense.png")
 app.build_side.hide();app.show_development_settings();await frames()
 var refill:Button=app.overlay.find_child("FillResourcesButton",true,false)
 check(refill!=null and refill.text=="자원 채우기","Development settings expose resource refill action")
 var fill_state:Dictionary=app.model.state.duplicate(true);fill_state.wood=0;fill_state.stone=0;fill_state.grain=0;app.model.commit(fill_state)
 refill.pressed.emit();await frames()
 check(app.model.state.wood==9999 and app.model.state.stone==9999 and app.model.state.grain==9999 and app.model.resident_count()==15,"Refill button is wired and leaves population alone")
 app.close_modal()
 var organic:OrganicRoadNetwork=null
 for layer in app.world.get_children():
  if layer is VillageLayout:
   for child in layer.get_children():
    if child is OrganicRoadNetwork:organic=child
 check(organic!=null and organic.paths.size()==13,"Dense layout uses a connected branch tree rather than perimeter rings")
 var path:=NaturalRoad.organic_path(Vector2(0,0),Vector2(8,6))
 check(path.size()>2 and path.size()<=25,"Fallback connection uses a gentle curve instead of broad L-shaped detour")
 print(JSON.stringify({"checks":checks,"failures":failures}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
