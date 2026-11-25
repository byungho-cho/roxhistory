extends "res://scripts/hunt_duel_lab.gd"
const Gahui = preload("res://gahui_trial/gahui_rig.gd")
var gahui: Gahui
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
 set_process_input(false)
 set_process(false)
 call_deferred("_install_gahui")

func _install_gahui():
 if not is_instance_valid(shared_world):
  push_error("Gahui test requires the standard hunt shared world")
  get_tree().quit(2)
  return
 for c in arena.get_children():
  if c!=field and c is CanvasItem: c.hide()
 for c in field.get_children():
  if c!=shared_world and c is CanvasItem: c.hide()
 a.preview.pivot.hide()
 b.play("idle")
 shared_world.bodies[1].position = Vector3(3.05,0,-1.0)
 b.preview.pivot.rotation.y = -1.4
 gahui = Gahui.new()
 shared_world.scene.add_child(gahui)
 start_position = Vector3(-3.65,0,1.85)
 gahui.position = start_position
 gahui.look_at(Vector3(shared_world.bodies[1].position.x,0,shared_world.bodies[1].position.z),Vector3.UP,true)
 gahui.initialize(shared_world.bodies[1])
 if not gahui.rig_ready:
  get_tree().quit(3)
  return
 gahui.shot_started.connect(func(_point:Vector3):shot_total+=1)
 gahui.shot_arrived.connect(_hit_deer)
 _plaque(Rect2(26,18,323,45))
 mode_label = _label("",Rect2(30,18,308,45),18)
 mode_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 mode_label.position.x+=13
 help_label=_label("모션 확인용 · 실제 피해와 치유 수치는 적용하지 않습니다",Rect2(90,454,780,27),15)
 _plaque(Rect2(100,486,763,42))
 for i in Gahui.LABELS.size():
  drill_buttons.append(_button(Gahui.LABELS[i],Rect2(106+i*88,491,84,32),_on_action.bind(i)))
 drill_buttons.append(_button("전체 재생",Rect2(728,491,128,32),_start_all))
 drill_buttons.append(_button("닫기",Rect2(874,20,60,34),_exit))
 for btn in drill_buttons:
  btn.add_theme_font_size_override("font_size",14)
 _play(0)
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
 mode_label.text="가희 · 사냥 실험실 / "+Gahui.LABELS[i]
 motion_coverage[i] = true

func _process(delta:float):
 segment_t += delta
 if segment_t>=float(Gahui.TIMES[selected_index]):
  if autoplay:
   if selected_index == 6:
    if recording:
     print("RECORD 7 states; projectiles=",shot_total)
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
 if end_hold>0.0:
  end_hold=maxf(0.0,end_hold-delta)
  if end_hold==0.0: b.play("idle")
 b.sample(0.0 if end_hold==0.0 else .16-end_hold,false)

func _hit_deer(_index:int):
 end_hold=.16
 b.play("hit")

func _verify_gahui():
 for id in Gahui.LABELS.size():
  drill_buttons[id].pressed.emit()
  for frame in range(int(float(Gahui.TIMES[id])*60.0)):
   gahui.step_at(float(frame)/60.0)
 var h:=shared_world.camera.unproject_position(gahui.global_position).distance_to(shared_world.camera.unproject_position(gahui.global_position+Vector3.UP*Gahui.DISPLAY_HEIGHT))*shared_world.display.scale.y
 var tip_error:float=gahui.staff_tip().distance_to(gahui.global_position)
 print("GAHUI_QA motion_states=",motion_coverage.size()," projectiles=",shot_total," projected_height=",h," tip_distance=",tip_error)
 if motion_coverage.size()!=7 or shot_total!=4 or h<59.0 or h>62.0 or tip_error<.75 or tip_error>2.40:
  get_tree().quit(4)
  return
 print("GAHUI_QA PASS")
 get_tree().quit()



func _exit_tree():
 if is_instance_valid(battle_camera) and is_instance_valid(battle_camera.damage_numbers) and battle_camera.damage_numbers.get_parent()==null:
  battle_camera.damage_numbers.free()
 super()

