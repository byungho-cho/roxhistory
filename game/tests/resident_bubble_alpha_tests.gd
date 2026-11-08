extends "res://tests/building_hold_v056_tests.gd"
func run()->void:
 root.size=Vector2i(1280,800)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.model=GameState.new(SaveStore.new("user://bubble_alpha_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
 var s:Dictionary=app.model.state.duplicate(true);s.chief_level=1;s.resident_count=0;s.resident_guide_seen=true;s.pending_family_count=1
 s.homes=[{"uid":"h1","style":1,"claimed":true,"level":1,"position":[900,900],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true;app.model.commit(s)
 app.enter_game();await frames(12)
 var family:FamilyArrival=app.family
 check(family.bubble.visible,"Resident invitation visible in isolated fixture")
 check(family.portrait.texture is AtlasTexture and family.portrait.texture.region==FamilyArrival.PORTRAIT_REGION,"Portrait crops transparent margins without editing source art")
 var visible_width:float=family.portrait.size.y*FamilyArrival.PORTRAIT_REGION.size.x/FamilyArrival.PORTRAIT_REGION.size.y
 var visible_start:float=family.portrait.position.x+(family.portrait.size.x-visible_width)*.5
 check(visible_start<family.background.position.x and visible_start+visible_width>family.background.position.x+6,"Visible portrait covers bubble front with real painted pixels")
 check(family.headline.position.x>=family.portrait.get_rect().end.x+10,"Text clears visible portrait")
 check(family.bubble.size.y>=44,"Original minimum touch target retained")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/integration-resident-bubble.png")
 print(JSON.stringify({"checks":checks,"failures":failures}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
