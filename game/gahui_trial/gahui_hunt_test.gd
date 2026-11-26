extends "res://scripts/hunt_duel_lab.gd"
const Gahui = preload("res://gahui_trial/gahui_rig.gd")
const GahuiVfx = preload("res://gahui_trial/gahui_vfx.gd")
const GAHUI_LAB_SCALE := 1.5
const DEER_LAB_SCALE := 1.2
const DEER_IDS := ["idle","walk","run","attack","skill","hit","heavy_hit"]
const DEER_LABELS := ["대기","걷기","달리기","평타","3SP 들이받기","일반 피격","큰 피격"]
const STAG_ALL := ["idle","walk","run","attack","skill","hit","heavy_hit"]
const DEER_ALL := ["locomotion","attack","skill","hit","heavy_hit"]
const DEER_ORIGIN := Vector3(3.05,0,-1.0)
var gahui: Gahui
var vfx: GahuiVfx
var mode_label: Label
var help_label: Label
var selected_index := 0
var segment_t := 0.0
var autoplay := false
var recording := false
var end_hold := 0.0
var drill_buttons: Array[Button] = []
var start_position := Vector3.ZERO
var shot_total := 0
var motion_coverage := {}
var deer
var flower_driver
var stag_driver
var stag_actor
var subject := 0
var deer_action := "idle"
var sequence_index := 0
var subject_buttons: Array[Button] = []
var deer_buttons: Array[Button] = []
var impact_elapsed := 0.0
var close_button: Button
var run_walk_button: Button
var run_walk_elapsed:=-1.0
var run_walk_phase:=""
var drill_deer_fx: Node2D
var drill_deer_wake: Array = []
var drill_deer_contact := Vector2.ZERO
var drill_deer_floor := Vector2.ZERO
var drill_deer_struck := false
var drill_deer_tail := -1.0

func _ready():
 show_final_test35 = true
 super()
 arena.hide()
 set_process_input(false)
 set_process(false)
 call_deferred("_install_gahui")

func _install_gahui():
 if not is_instance_valid(shared_world):
  push_error("Gahui test requires the standard hunt shared world")
  _fail_trial(2)
  return
 touch_buttons.clear()
 for c in arena.get_children():
  if c!=field and c is CanvasItem: c.hide()
 for c in field.get_children():
  if c!=shared_world and c is CanvasItem: c.hide()
 a.preview.pivot.hide()
 b.play("idle")
 shared_world.bodies[1].position = DEER_ORIGIN
 b.preview.pivot.rotation.y = -1.4
 b.preview.pivot.scale *= DEER_LAB_SCALE

 gahui = Gahui.new()
 shared_world.scene.add_child(gahui)
 start_position = Vector3(-3.65,0,1.85)
 gahui.position = start_position
 gahui.look_at(Vector3(shared_world.bodies[1].position.x,0,shared_world.bodies[1].position.z),Vector3.UP,true)
 gahui.initialize(shared_world.bodies[1])
 if not gahui.rig_ready:
  _fail_trial(3)
  return
 # Resize the model about the original footline, without resizing the world effects.
 var visual := gahui.models[0]
 visual.scale *= GAHUI_LAB_SCALE
 visual.position.y *= GAHUI_LAB_SCALE
 vfx = GahuiVfx.new()
 shared_world.scene.add_child(vfx)
 gahui.shot_started.connect(func(_point:Vector3):shot_total+=1)
 gahui.shot_arrived.connect(_hit_deer)
 var driver := load("res://gahui_trial/deer_lab_motion.gd") as Script
 if driver==null:
  push_error("Flower deer lab driver missing")
  _fail_trial(5)
  return
 deer=driver.new()
 deer.setup(b,shared_world.bodies[1],gahui)
 flower_driver=deer
 drill_deer_fx=Node2D.new()
 drill_deer_fx.name="DeerDrillEffects"
 field.add_child(drill_deer_fx)
 drill_deer_fx.draw.connect(_draw_drill_deer_fx)
 _plaque(Rect2(26,18,628,45))
 subject_buttons.append(_lab_button("가희",Rect2(32,24,83,33),_select_subject.bind(0)))
 subject_buttons.append(_lab_button("꽃사슴",Rect2(121,24,83,33),_select_subject.bind(1)))
 subject_buttons.append(_lab_button("\uC22B\uC0AC\uC2B4",Rect2(210,24,83,33),_select_subject.bind(2)))
 mode_label = _label("",Rect2(297,18,337,45),18)
 mode_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 mode_label.position.x+=13
 help_label=_label("모션 확인용 · 실제 피해와 치유 수치는 적용하지 않습니다",Rect2(90,454,780,27),15)
 _plaque(Rect2(100,486,763,42))
 var button_widths := [54,54,68,52,89,103,91,101]
 var left := 106
 for i in Gahui.LABELS.size():
  var width: int=button_widths[i]
  var motion_button:=_lab_button("3SP 치유" if i == 5 else Gahui.LABELS[i],Rect2(left,491,width,32),_on_action.bind(i))
  motion_button.add_theme_font_size_override("font_size",14)
  motion_button.clip_text=true
  motion_button.size=Vector2(width,32)
  drill_buttons.append(motion_button)
  left+=width+4
 drill_buttons.append(_lab_button("전체 재생",Rect2(left,491,104,32),_start_all))
 run_walk_button=_lab_button("달리기 → 걷기",Rect2(508,20,154,34),_on_run_to_walk)
 run_walk_button.name="GahuiRunToWalk"
 if app != null:
  var one_on_one := _lab_button("1대1 전투 테스트",Rect2(727,20,134,34),func():app.call_deferred("open_one_on_one_from_gahui_lab"))
  one_on_one.name="OneOnOneEntry"
 close_button=_lab_button("닫기",Rect2(874,20,60,34),_exit)
 var deer_left := 113
 var deer_widths := [64,64,76,67,114,100,92,112]
 for i in DEER_LABELS.size():
  var width: int=deer_widths[i]
  deer_buttons.append(_lab_button(DEER_LABELS[i],Rect2(deer_left,491,width,32),_on_deer_action.bind(i)))
  deer_left+=width+4
 deer_buttons.append(_lab_button("전체 재생",Rect2(deer_left,491,deer_widths[-1],32),_start_all))
 _select_subject(0)
 arena.show()
 recording = "--record" in OS.get_cmdline_user_args()
 if "--verify" in OS.get_cmdline_user_args():
  _verify_gahui()
  return
 set_process_input(true)
 set_process(true)
 if recording:_start_all()

func _lab_button(value:String, rect:Rect2, pressed:Callable) -> Button:
 var button:=_button(value,rect,pressed)
 button.add_theme_font_size_override("font_size",14)
 button.clip_text=true
 button.size=rect.size
 touch_buttons.append(button)
 return button

func _input(event:InputEvent):
 if event is InputEventMouse or event is InputEventScreenTouch:
  super(event)
  return
 if event.is_action_pressed("ui_cancel"):
  _exit()
  get_viewport().set_input_as_handled()

func _ensure_stag() -> void:
 if stag_driver!=null:return
 stag_actor=Actor.new()
 stag_actor.create(field,"stag")
 stag_actor.preview.display.hide()
 stag_actor.preview.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 stag_actor.preview.pivot.reparent(shared_world.bodies[1],false)
 stag_actor.preview.pivot.position=Vector3.ZERO
 stag_actor.preview.pivot.rotation.y=-1.4
 stag_actor.preview.pivot.scale=Vector3.ONE*DEER_LAB_SCALE
 stag_driver=flower_driver.get_script().new()
 stag_driver.setup(stag_actor,shared_world.bodies[1],gahui,true)
 stag_driver.set_visible(false)

func _drill_tip()->Vector2:
 if subject!=2:return _deer_visual_tip()
 var sk:Skeleton3D=stag_actor.preview.skeleton
 var head:=sk.find_bone("head")
 return shared_world.project(sk.to_global(sk.get_bone_global_pose(head)*Vector3(0,0,.23)))

func _select_subject(next:int) -> void:
 if next==2:_ensure_stag()
 if next!=subject:
  deer.reset()
  deer.set_visible(false)
  deer=stag_driver if next==2 else flower_driver
  deer.set_visible(true)
 subject=next
 autoplay=false
 end_hold=0.0
 impact_elapsed=0.0
 gahui.position=start_position
 gahui.switch_to(0)
 vfx.clear()
 deer.reset()
 deer.play("idle")
 deer.sample(0.0)
 for i in subject_buttons.size():
  subject_buttons[i].disabled=i==subject
 run_walk_button.visible=subject==0
 run_walk_elapsed=-1.0
 for button in drill_buttons:button.visible=subject==0
 for button in deer_buttons:button.visible=subject!=0
 help_label.text="두 캐릭터가 마주 보는 동작 실험실 · 본편 전투와 저장에는 영향이 없습니다"
 if subject==0:_play(0)
 else:_play_deer("idle")

func _on_action(i:int):
 autoplay=false
 gahui.position=start_position
 _play(i)

func _on_run_to_walk() -> void:
 if subject!=0:return
 autoplay=false
 impact_elapsed=0.0
 end_hold=0.0
 deer.play("idle")
 gahui.position=start_position
 _play(0)
 gahui.begin_run_to_walk()
 run_walk_elapsed=0.0
 run_walk_phase=gahui.step_run_to_walk(0.0)
 mode_label.text="가희 · 달리기 → 걷기"

func _on_deer_action(i:int):
 autoplay=false
 deer.reset()
 _play_deer(DEER_IDS[i])

func _start_all():
 autoplay=true
 sequence_index=0
 if subject==0:
  gahui.position=start_position
  _play(0)
 else:
  deer.reset()
  _play_deer(STAG_ALL[0] if subject==2 else DEER_ALL[0])

func _play(i:int):
 run_walk_elapsed=-1.0
 selected_index=i
 segment_t=0.0
 gahui.switch_to(i)
 gahui.step_at(0.0)
 vfx.clear()
 mode_label.text="가희 · "+Gahui.LABELS[i]
 motion_coverage[i] = true

func _play_deer(key:String, carry_fx:=false):
 drill_deer_tail=drill_deer_tail if carry_fx else -1.0
 if not carry_fx:drill_deer_wake.clear()
 drill_deer_struck=false
 drill_deer_fx.queue_redraw()
 segment_t=0.0
 if not deer.play(key):
  push_warning("Missing lab motion: "+key)
  deer.play("idle")
  key="idle"
 deer_action=key
 deer.sample(0.0)
 mode_label.text=("숫사슴 · " if subject==2 else "꽃사슴 · ")+("연속 이동" if key=="locomotion" else DEER_LABELS[DEER_IDS.find(key)])

func _process(delta:float):
 segment_t += delta
 if subject!=0:
  if drill_deer_tail>=0.0:
   drill_deer_tail+=delta
   if drill_deer_tail>=.53:drill_deer_tail=-1.0
   drill_deer_fx.queue_redraw()
  _process_deer()
  return
 if run_walk_elapsed>=0.0:
  run_walk_elapsed=minf(Gahui.RUN_WALK_SECONDS,run_walk_elapsed+delta)
  run_walk_phase=gahui.step_run_to_walk(run_walk_elapsed)
  deer.sample(run_walk_elapsed)
  if run_walk_elapsed>=Gahui.RUN_WALK_SECONDS:_play(0)
  return
 if segment_t>=float(Gahui.TIMES[selected_index]):
  # Always sample the ending pose and events, even after a long frame.
  gahui.step_at(float(Gahui.TIMES[selected_index]))
  if autoplay:
   if selected_index==Gahui.LABELS.size()-1:
    if recording:
     print("RECORD ",Gahui.LABELS.size()," states; projectiles=",shot_total)
     get_tree().quit()
     return
    autoplay=false
    _play(0)
   else:
    gahui.position=start_position
    _play(selected_index+1)
  else:
   _play(0)
 gahui.step_at(segment_t)
 _draw_vfx(segment_t)
 impact_elapsed+=delta
 if end_hold>0.0:
  end_hold=maxf(0.0,end_hold-delta)
  if end_hold==0.0:
   impact_elapsed=0.0
   deer.play("idle")
 deer.sample(impact_elapsed)

func _process_deer():
 gahui.step_at(fposmod(segment_t,float(Gahui.TIMES[0])))
 var finished:bool=deer.sample(segment_t)
 _update_drill_deer_fx()
 if deer_action=="idle":
  if not (autoplay and subject==2 and segment_t>=.80):return
 elif not finished:return
 var sequence: Array = STAG_ALL if subject==2 else DEER_ALL
 if autoplay and sequence_index+1<sequence.size():
  sequence_index+=1
  deer.reset()
  _play_deer(sequence[sequence_index])
 else:
  autoplay=false
  if deer_action=="skill" and drill_deer_struck:
   drill_deer_tail=segment_t-deer.fx_contact_time("skill")
  _play_deer("idle",drill_deer_tail>=0.0)

func _update_drill_deer_fx()->void:
 drill_deer_fx.queue_redraw()
 if deer_action not in ["attack","skill"]:return
 var contact_t:float=deer.fx_contact_time(deer_action)
 var foot:=shared_world.project(deer.body.global_position)
 var tip:=_drill_tip()
 if deer_action=="skill" and segment_t>=deer.fx_release_time() and segment_t<=contact_t+.03:
  if drill_deer_wake.is_empty() or segment_t-float(drill_deer_wake.back().at)>=.025:
   drill_deer_wake.append({"foot":foot,"tip":tip,"at":segment_t})
 if not drill_deer_struck and segment_t>=contact_t:
  drill_deer_struck=true
  drill_deer_contact=tip
  drill_deer_floor=Vector2(tip.x,foot.y)

func _draw_drill_deer_fx()->void:
 if subject==0:return
 if drill_deer_tail>=0.0 and deer_action=="idle":
  var tail_p:=drill_deer_tail/.36
  if tail_p<1.0:
   _draw_deer_impact({"center":drill_deer_contact,"floor_point":drill_deer_floor},tail_p,drill_deer_fx)
  return
 if deer_action not in ["attack","skill"]:return
 var basic:=deer_action=="attack"
 var contact_t:float=deer.fx_contact_time(deer_action)
 if not basic:
  var foot:=shared_world.project(deer.body.global_position)
  var progress:=clampf(segment_t/deer.fx_release_time(),0.,.999) if segment_t<deer.fx_release_time() else -1.0
  _draw_silver_deer(foot,_drill_tip(),progress,false,drill_deer_wake,segment_t,drill_deer_fx)
 if drill_deer_struck:
  var lifetime:=.18 if basic else .36
  var p:=(segment_t-contact_t)/lifetime
  if p>=0.0 and p<1.0:
   var caster:=shared_world.project(deer.body.global_position)
   var toward:=shared_world.project(gahui.global_position)
   _draw_deer_impact({"center":drill_deer_contact,"basic":basic,"axis":caster.direction_to(toward),"floor_point":drill_deer_floor},p,drill_deer_fx)

func _draw_vfx(t:float) -> void:
 var deer_chest := shared_world.bodies[1].global_position + Vector3.UP * (.95 * DEER_LAB_SCALE)
 vfx.draw(selected_index,t,gahui,shared_world.camera,deer_chest)

func _fail_trial(code:int) -> void:
 if app==null:
  get_tree().quit(code)
 else:
  _exit()

func _hit_deer(_index:int):
 if subject!=0:return
 deer.play("hit")
 impact_elapsed=0.0
 end_hold=maxf(.14,float(deer.duration))
func _verify_gahui():
 for id in Gahui.LABELS.size():
  drill_buttons[id].pressed.emit()
  for frame in range(int(float(Gahui.TIMES[id])*60.0)):
   gahui.step_at(float(frame)/60.0)
 var h:=shared_world.camera.unproject_position(gahui.global_position).distance_to(shared_world.camera.unproject_position(gahui.global_position+Vector3.UP*(Gahui.DISPLAY_HEIGHT*GAHUI_LAB_SCALE)))*shared_world.display.scale.y
 var tip_error:float=gahui.staff_tip().distance_to(gahui.global_position)
 print("GAHUI_QA motion_states=",motion_coverage.size()," projectiles=",shot_total," projected_height=",h," tip_distance=",tip_error)
 var full_bounds:=true
 for k in range(drill_buttons.size()-1):
  full_bounds=full_bounds and drill_buttons[k].get_rect().end.x<=drill_buttons[k+1].position.x
 var sk:=gahui.skeletons[0]
 var head:=sk.find_bone(&"Head")
 drill_buttons[Gahui.STRONG_HIT].pressed.emit()
 var origin_pos:=gahui.position
 gahui.step_at(.10)
 var instant:=gahui.position.is_equal_approx(origin_pos) and sk.get_bone_pose_rotation(head).angle_to(gahui.hit_anchor[head].basis.get_rotation_quaternion())>.10
 gahui.step_at(.49)
 var recoil:=gahui.position-origin_pos
 var back_only:=recoil.dot(gahui.transform.basis.z)<-.48 and absf(recoil.dot(gahui.transform.basis.x))<.001
 gahui.step_at(Gahui.STRONG_HIT_RECOVERY)
 var recovered:=gahui.position.is_equal_approx(origin_pos) and sk.get_bone_pose_rotation(head).angle_to(gahui.hit_anchor[head].basis.get_rotation_quaternion())<.01
 drill_buttons[5].pressed.emit()
 gahui.step_at(0.0)
 var tip_start:=gahui.staff_tip()
 gahui.step_at(Gahui.HEAL_RELEASE)
 var heal_lift:=gahui.staff_tip().y-tip_start.y
 gahui.step_at(Gahui.HEAL_DURATION)
 var heal_end:=gahui.staff_tip().distance_to(tip_start)
 print("GAHUI_QA strong snap-first=",instant," back-only=",back_only," exact return=",recovered," heal tip rise=",heal_lift," heal return=",heal_end," nonoverlapping buttons=",full_bounds)
 if motion_coverage.size()!=8 or shot_total!=4 or h<88.5 or h>93.0 or tip_error<1.125 or tip_error>3.60 or not full_bounds or not instant or not back_only or not recovered or heal_lift<.23 or heal_end>.16:
  get_tree().quit(4)
  return
 var deer_seen:=0
 _select_subject(1)
 for i in DEER_IDS.size():
  deer_buttons[i].pressed.emit()
  if deer_action!=DEER_IDS[i]:continue
  deer.sample(0.0)
  deer.sample(float(deer.duration))
  deer_seen+=1
 _start_all()
 var passed_series:=deer_action=="locomotion"
 if passed_series:
  _process(float(deer.duration)+.02)
  passed_series=deer_action=="attack"
 _select_subject(0)
 var tabs_restore:=subject_buttons[0].disabled and drill_buttons[0].visible and not deer_buttons[0].visible
 if deer_seen!=7 or not passed_series or not tabs_restore:
  printerr("DEER_LAB_QA failed ",deer_seen," ",passed_series," ",tabs_restore)
  get_tree().quit(7)
  return
 print("DEER_LAB_QA PASS ",deer_seen," motions, sequence and tabs")
 print("GAHUI_QA PASS")
 get_tree().quit()



func _exit_tree():
 if is_instance_valid(battle_camera) and is_instance_valid(battle_camera.damage_numbers) and battle_camera.damage_numbers.get_parent()==null:
  battle_camera.damage_numbers.free()
 super()

