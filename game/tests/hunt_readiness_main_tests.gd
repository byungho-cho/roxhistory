extends SceneTree
const Main=preload("res://scripts/main.gd")
const Result=preload("res://scripts/hunt_result.gd")
class FailedVideoResult extends Result:
 func build_field_video(_layout:Control)->bool:return false
var app
var failures:=0
var checks:Array=[]
var cold_wait_observed:=false
func _initialize():call_deferred("run")
func ck(ok:bool,text:String):
 checks.append({"ok":ok,"label":text})
 print(text,": ",ok)
 if not ok:failures+=1
func wait_hunt():
 for i in 600:
  if not app.hunt_preparing:break
  await process_frame
 await process_frame
func run():
 for role in preload("res://scripts/hunt_readiness_art.gd").ROLES:
  var texture:Texture2D=preload("res://scripts/hunt_readiness_art.gd").role_texture(role)
  ck(texture!=null and texture.get_size()==Vector2(376,376),"approved role asset available: "+role)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
 app.model.start_new({},true);app.model.state.hunt_cleared=6
 app.hunt_stage=5;app.show_screen("hunt_select")
 app.prepare_selected_hunt()
 cold_wait_observed=is_instance_valid(app.hunt_loading)
 if cold_wait_observed:
  ck(app.hunt_loading.get_child_count()==1,"loading overlay contains only one hourglass")
  ck(app.hunt_loading.get_child(0).get_global_rect().get_center().distance_to(app.hunt_loading.get_global_rect().get_center())<1,"loading hourglass is centered in viewport")
 app.prepare_selected_hunt()
 await wait_hunt()
 ck(app.screen=="hunt" and app.hunt_prey_id=="adult","cold repeated prepare enters exactly one selected hunt")
 var first=app.hunt
 ck(not is_instance_valid(app.hunt_loading) and not app.hunt_preparing,"waiting overlay and guard clear after readiness")
 ck(first.chapter_one_solo and first.rules.party_hp==[34,0,0] and not first.rules.skills_enabled,"chapter one starts Han-only with native stats")
 first.set_process(false);first.advance_arrival(first.arrival_duration)
 first.update_actors(0.)
 var feet:Vector2=first.hunters[0].position
 first.start_combat();first.start_combat();first.advance_transition(.20);first.update_actors(.20)
 ck(first.hunters[0].position.is_equal_approx(feet),"first resize never moves the planted feet")
 ck(first.branch_video.is_playing(),"single VS playback starts on battle request")
 first.advance_transition(first.TRANSITION_SECONDS);first.update_actors(0.)
 first.toggle_auto()
 ck(first.rules.auto_enabled and first.rules.reserved_skill=="" and first.auto_button.get_meta("toggle_icon").texture.resource_path.ends_with("AUTO-1.png"),"AUTO shows ON while solo skill reservation stays off")
 first.toggle_auto()
 ck(not first.rules.auto_enabled and first.speed==1. and first.auto_button.get_meta("toggle_icon").texture.resource_path.ends_with("AUTO-0.png"),"AUTO OFF has approved artwork and battle stays fixed at 1x")
 app.close_hunt();await process_frame
 app.hunt_stage=5
 app.prepare_selected_hunt()
 ck(app.screen=="hunt" and not is_instance_valid(app.hunt_loading),"warm ready re-entry has no loading overlay or waiting frame")
 await process_frame
 ck(not is_instance_valid(first),"previous hunt and its VS player are released")
 app.close_hunt();await process_frame
 app.hunt_stage=6;app.prepare_selected_hunt();await wait_hunt()
 ck(app.hunt.rules.skills_enabled and app.hunt.rules.party_hp==[34,33,33] and not app.hunt.chapter_one_solo,"later chapter keeps all three members and skills")
 var fallback:=FailedVideoResult.new();fallback.app=app;fallback.won=false;fallback.use_han_field=true
 app.hunt.add_child(fallback);fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 await process_frame
 ck(not is_instance_valid(fallback.result_video) and fallback.find_children("*","Button",true,false).size()==2,"video read failure retains both live result buttons")
 fallback.queue_free();await process_frame
 app.close_hunt();await process_frame
 app.hunt_stage=0;app.prepare_selected_hunt();await wait_hunt()
 app.hunt.set_process(false);app.hunt.rules.outcome="win";app.hunt.show_result();await process_frame
 var replay_ok:=false
 for label in app.hunt.find_children("*","Label",true,false):
  if label.text=="이미 완료한 사냥입니다.":replay_ok=true
 ck(replay_ok and app.model.state.hunt_cleared==6,"replayed chapter-one win never claims a new unlock or changes progress")
 print("cold wait observed=",cold_wait_observed)
 FileAccess.open("D:/workspace/roxhistory/build/hunt-readiness-results/main-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"cold_wait_observed":cold_wait_observed},"  "))
 app.queue_free();await process_frame;await process_frame
 print("Readiness Main: ",checks.size()," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
