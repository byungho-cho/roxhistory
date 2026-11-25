extends "res://scripts/hunt_duel_lab.gd"
const Gahui = preload("res://gahui_trial/gahui_rig.gd")
const GahuiVfx = preload("res://gahui_trial/gahui_vfx.gd")
const GAHUI_LAB_SCALE := 1.5
const DEER_LAB_SCALE := 1.2
const DEER_HOOVES := ["front_foot.R","front_foot.L","hind_foot.R","hind_foot.L"]
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
 shared_world.bodies[1].position = Vector3(3.05,0,-1.0)
 b.preview.pivot.rotation.y = -1.4
 b.preview.pivot.scale *= DEER_LAB_SCALE
 _sample_deer(0.0)
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
 _plaque(Rect2(26,18,323,45))
 mode_label = _label("",Rect2(30,18,308,45),18)
 mode_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 mode_label.position.x+=13
 help_label=_label("모션 확인용 · 실제 피해와 치유 수치는 적용하지 않습니다",Rect2(90,454,780,27),15)
 _plaque(Rect2(100,486,763,42))
 var button_widths := [54,54,68,52,89,103,91,101]
 var left := 106
 for i in Gahui.LABELS.size():
  var width: int=button_widths[i]
  var motion_button:=_button("3SP 치유" if i == 5 else Gahui.LABELS[i],Rect2(left,491,width,32),_on_action.bind(i))
  motion_button.add_theme_font_size_override("font_size",14)
  motion_button.clip_text=true
  motion_button.size=Vector2(width,32)
  drill_buttons.append(motion_button)
  left+=width+4
 drill_buttons.append(_button("전체 재생",Rect2(left,491,104,32),_start_all))
 drill_buttons.append(_button("닫기",Rect2(874,20,60,34),_exit))
 for btn in drill_buttons:
  btn.add_theme_font_size_override("font_size",14)
 _play(0)
 arena.show()
 recording = "--record" in OS.get_cmdline_user_args()
 if "--verify" in OS.get_cmdline_user_args():
  _verify_gahui()
  return
 set_process_input(true)
 set_process(true)
 if recording:_start_all()

func _input(event:InputEvent):
 if event is InputEventScreenTouch:
  super(event)
  return
 if event.is_action_pressed("ui_cancel"):
  _exit()
  get_viewport().set_input_as_handled()

func _on_action(i:int):
 autoplay=false
 gahui.position=start_position
 _play(i)

func _start_all():
 gahui.position=start_position
 autoplay=true
 _play(0)

func _play(i:int):
 selected_index=i
 segment_t=0.0
 gahui.switch_to(i)
 vfx.clear()
 mode_label.text="가희 · 사냥 실험실 / "+Gahui.LABELS[i]
 motion_coverage[i] = true

func _process(delta:float):
 segment_t += delta
 if segment_t>=float(Gahui.TIMES[selected_index]):
  if autoplay:
   if selected_index == Gahui.LABELS.size()-1:
    if recording:
     print("RECORD ",Gahui.LABELS.size()," states; projectiles=",shot_total)
     get_tree().quit()
     return
    _start_all()
   else:
    _play(selected_index+1)
  elif selected_index<=2:
   if selected_index!=0: gahui.position=start_position
   _play(selected_index)
  else:
   _play(0)
 gahui.step_at(segment_t)
 _draw_vfx(segment_t)
 if end_hold>0.0:
  end_hold=maxf(0.0,end_hold-delta)
  if end_hold==0.0: b.play("idle")
 _sample_deer(0.0 if end_hold==0.0 else .16-end_hold)

func _draw_vfx(t:float) -> void:
 var deer_chest := shared_world.bodies[1].global_position + Vector3.UP * (.95 * DEER_LAB_SCALE)
 vfx.draw(selected_index,t,gahui,shared_world.camera,deer_chest)

func _sample_deer(t:float) -> void:
 b.sample(t,false)
 var ground_y := shared_world.bodies[1].global_position.y
 var bottom := INF
 for hoof:String in DEER_HOOVES:
  bottom = minf(bottom,shared_world.bone_world(1,hoof).y)
 b.preview.pivot.position.y += ground_y - bottom

func _fail_trial(code:int) -> void:
 if app==null:
  get_tree().quit(code)
 else:
  _exit()

func _hit_deer(_index:int):
 end_hold=.16
 b.play("hit")

func _verify_gahui():
 for id in Gahui.LABELS.size():
  drill_buttons[id].pressed.emit()
  for frame in range(int(float(Gahui.TIMES[id])*60.0)):
   gahui.step_at(float(frame)/60.0)
 var h:=shared_world.camera.unproject_position(gahui.global_position).distance_to(shared_world.camera.unproject_position(gahui.global_position+Vector3.UP*(Gahui.DISPLAY_HEIGHT*GAHUI_LAB_SCALE)))*shared_world.display.scale.y
 var tip_error:float=gahui.staff_tip().distance_to(gahui.global_position)
 print("GAHUI_QA motion_states=",motion_coverage.size()," projectiles=",shot_total," projected_height=",h," tip_distance=",tip_error)
 var full_bounds:=true
 for k in range(drill_buttons.size()-2):
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
 print("GAHUI_QA PASS")
 get_tree().quit()



func _exit_tree():
 if is_instance_valid(battle_camera) and is_instance_valid(battle_camera.damage_numbers) and battle_camera.damage_numbers.get_parent()==null:
  battle_camera.damage_numbers.free()
 super()

