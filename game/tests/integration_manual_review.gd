extends SceneTree
var app:Node
var elapsed:=0.0
func _initialize()->void:call_deferred("start")
func start()->void:
 if not "--test-ui" in OS.get_cmdline_user_args():push_error("Manual review requires --test-ui");quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 await process_frame;await process_frame
 app.model=GameState.new(SaveStore.new("user://tests/integration-capture-20261109" if "--capture-review" in OS.get_cmdline_user_args() else "user://tests/integration-20261109"))
 if app.model.state.is_empty():
  app.model.start_new()
  var s:Dictionary=app.model.state.duplicate(true);s.chief_level=4;s.resident_count=3;s.wood=297;s.stone=90;s.grain=20;s.resident_guide_seen=true;s.pending_family_count=1;s.family_next_at=0
  s.homes=[{"uid":"h1","style":1,"claimed":true,"level":4,"position":[800,1000],"cost":{"wood":20,"stone":10}},{"uid":"h2","style":1,"claimed":true,"level":1,"position":[1200,850],"cost":{"wood":20,"stone":10}},{"uid":"h3","style":1,"claimed":true,"level":1,"position":[900,1400],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true
  s.facilities=[{"uid":"f1","kind":"farm","level":4,"position":[1450,1200],"cost":{"wood":10,"stone":5}},{"uid":"ws","kind":"wood_store","level":1,"position":[1600,1500],"cost":{"wood":20,"stone":20}},{"uid":"ss","kind":"stone_store","level":1,"position":[1700,850],"cost":{"wood":20,"stone":20}}]
  s.outposts=[{"uid":"p1","level":1,"position":[600,750],"cost":{"wood":10,"stone":10}}]
  s.farm_cycles={"farm:f1":{"phase":"grow","elapsed":570.0,"cycle_level":4,"cuts":0,"stock":0}}
  app.model.commit(s)
 app.model.changed.connect(app.update_hud)
 app.enter_game();await process_frame
 app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,.8,Vector2(1250,1050))
 print("MANUAL_REVIEW_ISOLATED_SAVE "+app.model.store.directory)
 if "--capture-review" in OS.get_cmdline_user_args():
  for i in 20:await process_frame
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/integration-brush-roads.png")
  ProjectSettings.set_setting("roxhistory/visuals/brush_roads",false)
  for child in app.world.get_children():
   if child is VillageLayout:child.rebuild_art()
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/integration-legacy-roads.png")
  print("CAPTURED_BRUSH_AND_LEGACY_NOT_INTERACTIVE_PLAY")
  app.queue_free();await process_frame;quit()

func _process(delta:float)->bool:
 if not is_instance_valid(app) or not is_instance_valid(app.world):return false
 elapsed+=delta
 if elapsed>=2:
  elapsed=0
  var f:=FileAccess.open("res://reports/integration-live.json",FileAccess.WRITE)
  f.store_string(JSON.stringify({"wood":app.model.state.wood,"stone":app.model.state.stone,"grain":app.model.state.get("grain",0),"residents":app.model.resident_count(),"jobs":app.model.state.get("resident_jobs",{}),"farm":app.model.state.get("farm_cycles",{}),"save":app.model.store.directory,"menu":app.build_side.visible,"scroll":app.build_side.scroll_offset,"hero":app.world.player.position,"camera":app.world.player.camera.global_position}))
 return false
