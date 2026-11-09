extends "res://tests/building_hold_v056_tests.gd"
func snap(file:String)->void:
 if DisplayServer.get_name()=="headless":return
 await frames(8);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/guide-refactor-"+file+".png")
func run()->void:
 root.size=Vector2i(1200,675)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.model=GameState.new(SaveStore.new("user://guide_design_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
 var s:Dictionary=app.model.state.duplicate(true);s.chief_level=4;s.family_next_at=Time.get_unix_time_from_system()+10000;s.quests_done=FirstQuests.IDS.slice(0,3);s.quests_claimed=FirstQuests.IDS.slice(0,3);s.quests_guides=FirstQuests.IDS.slice(0,4);app.model.commit(s);app.enter_game();await frames(12)
 var before:Dictionary=app.model.state.duplicate(true);var hero:Vector2=app.world.player.position
 app.show_character_guide("새로운 지역을 탐험할 수 있어요!","옅어진 구름 너머에서 직접 채집해 보세요.");await frames(40)
 var guide:CharacterGuide=app.overlay
 check(is_equal_approx(guide.layout.scale.x,app.w/1200.0) and is_zero_approx(guide.layout.position.x),"Landscape uses edge-to-edge reference frame")
 check(guide.panel_group.get_node("CreamPanel").get_rect()==Rect2(142,430,992,204),"Cream panel matches exact design geometry")
 check(guide.character.size==Vector2(676,450.667) and guide.character.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"Character uses original artwork and design cover crop")
 check(is_zero_approx(guide.character.rotation),"Character sways horizontally without rotating away from reference")
 check(guide.find_child("CloseGuide",true,false)==null,"Only the guide drops its close icon")
 var hint:Control=guide.panel_group.get_node("GuideAdvanceHint")
 check(hint.position.y>guide.text_scroll.position.y,"Guide retains the lower advance arrow")
 check(absf(guide.text_scroll.position.y-475.5)<1,"Reference short copy matches Figma vertical alignment")
 check(is_equal_approx(guide.text_column.get_combined_minimum_size().y,85),"Reference font line boxes match39+12+34 design height")
 check(guide.text_scroll.position.y+guide.text_scroll.size.y<=CharacterGuide.PANEL_RECT.end.y-24,"Text remains inside panel padding")
 await snap("reference-landscape")
 var hint_at:=hint.get_global_rect().get_center()
 touch(hint_at,0,true);touch(hint_at,0,false);await frames()
 check(not app.modal and app.world.player.position.distance_to(hero)<1,"Advance hint touch dismisses without moving hero")
 app.show_character_guide("주민 안내","동적으로 받은 안내입니다.");await frames(35);guide=app.overlay
 app.show_character_guide("다음 안내","다음 페이지입니다.")
 var inside:Vector2=guide.layout.get_global_transform()*Vector2(700,550)
 touch(inside,0,true);touch(inside,0,false);await frames();check(app.overlay==guide and guide.heading=="다음 안내","Message body tap advances one page")
 var outside:=Vector2(app.w*.75,app.h*.2);touch(outside,0,true);touch(outside,0,false);await frames();check(not app.modal,"Backdrop touch dismisses and consumes pointer")
 root.size=Vector2i(1600,720);await frames(15);app.show_character_guide("새로운 지역을 탐험할 수 있어요!","옅어진 구름 너머에서 직접 채집해 보세요.");await frames(35);guide=app.overlay
 check(guide.character.get_global_rect().position.y>=app.safe.y-1,"Ultrawide layout keeps character top inside safe screen")
 await snap("wide");app.close_modal()
 root.size=Vector2i(720,960);await frames(15);app.show_character_guide("긴 안내도 읽을 수 있어요","길어진 주민 안내문도 스크롤하여 읽을 수 있습니다. ".repeat(25));await frames(35);guide=app.overlay
 check(guide.panel_group.has_node("GuideAdvanceHint"),"Portrait guide retains the advance cue")
 check(guide.text_labels[0].get_theme_font_size("font_size")*guide.layout.scale.x>=17.99 and guide.text_labels[1].get_theme_font_size("font_size")*guide.layout.scale.x>=13.99,"Portrait copy retains readable screen text minimum")
 check(guide.text_scroll.get_v_scroll_bar().max_value>guide.text_scroll.size.y,"Long copy actually overflows vertically for scrolling")
 var start:Vector2=guide.text_scroll.get_global_rect().get_center();touch(start,0,true);drag_touch(start-Vector2(0,80),0);touch(start-Vector2(0,80),0,false);await frames()
 check(guide.text_scroll.scroll_vertical>0 and app.modal,"Long message supports touch scrolling without dismissing")
 await snap("portrait-long")
 check(app.model.state.wood==before.wood and app.model.state.stone==before.stone,"Refactor does not mutate gameplay balances")
 print(JSON.stringify({"checks":checks,"failures":failures,"build":"deferred until farm assets"}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
