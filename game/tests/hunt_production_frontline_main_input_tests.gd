extends SceneTree
## Ordinary Windows integration: real Main entry/formation, and actual mouse up/down
## events dispatched by the Viewport. Never emits an input signal manually.
const Rules=preload("res://scripts/deer_hunt_rules.gd")
const NativeBoar=preload("res://scripts/hunt_production_boar_actor.gd")
var app
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")

func check(label:String,ok:bool)->void:
 checks+=1
 print(label,": ",ok)
 if not ok:
  failures+=1
  push_error(label)

func prepare(stage:int, front:int):
 if app.screen=="hunt":
  app.close_hunt()
 if app.modal:app.close_modal()
 app.hunt_stage=stage
 app.model.state.hunt_cleared=maxi(stage,int(app.model.state.get("hunt_cleared",0)))
 app.show_screen("hunt_select")
 await app.prepare_selected_hunt()
 await process_frame
 if app.screen!="hunt" or not is_instance_valid(app.hunt):
  check("Actual ordinary stage "+str(stage)+" opened",false)
  return null
 var hunt:Control=app.hunt
 hunt.set_process(false)
 hunt.arrival_finished=true
 hunt.transition_elapsed=-1.0
 var seats:Array[int]=[0,1,3]
 seats[front]=5
 hunt.assigned_cells.assign(seats)
 hunt.start_combat()
 hunt.advance_transition(hunt.TRANSITION_SECONDS)
 hunt.update_actors(.05)
 hunt.rules.exchange_clock=-100.0
 hunt.update_combat_ui()
 await process_frame
 return hunt

func click_button(button:Button, send_disabled:=false)->bool:
 if not is_instance_valid(button) or (not send_disabled and (button.disabled or not button.is_visible_in_tree())):
  return false
 var before:Array[int]=[0]
 var observe:=func():before[0]+=1
 button.pressed.connect(observe)
 var pt:=button.get_global_rect().get_center()
 for going_down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=going_down
  event.position=pt
  event.global_position=pt
  event.button_mask=MOUSE_BUTTON_MASK_LEFT if going_down else 0
  root.push_input(event,true)
  await process_frame
 button.pressed.disconnect(observe)
 return before[0]==1

func try_skill(stage:int,actor:int)->void:
 var hunt=await prepare(stage,actor)
 if hunt==null:return
 var pair:String=("adult" if hunt._prey_is_adult() else "deer")+"/"+["Han","Uram","Saebom"][actor]
 var expected:String=["han_spear_2","uram_club_2","team"][actor]
 var spend:=2
 var before_hp:int=hunt.rules.deer_hp
 hunt.rules.charges[actor]=3.0
 hunt.update_combat_ui()
 var hud:Control=hunt.party_cards[actor].hud
 check(pair+" actual mouse click reached real portrait",await click_button(hud.portrait_button))
 check(pair+" starts correct native action and spends two",hunt.pose==expected and is_equal_approx(float(hunt.rules.charges[actor]),3.0-spend))
 var metric_min:=INF
 var metric_when:=0.
 var metric_tip:=Vector3.INF
 var metric_body:=Vector3.INF
 var harms:=0
 var last_hp:=before_hp
 for frame in range(140):
  hunt._process(1.0/60.0)
  if actor!=Rules.SAEBOM and hunt.pose_clock>.10 and hunt.pose_clock<.61:
   var tip:Vector3=hunt._weapon_metric(actor)
   var capsule:Dictionary=hunt._deer_stone_capsule()
   if tip.is_finite() and not capsule.is_empty():
    var neck:Vector3=capsule.b
    var body:Vector3=capsule.a
    var near:=Geometry3D.get_closest_point_to_segment(tip,body,neck)
    var d:=tip.distance_to(near)-float(capsule.radius)
    if d<metric_min:
     metric_min=d
     metric_when=hunt.pose_clock
     metric_tip=tip
     metric_body=near
  if hunt.rules.deer_hp<last_hp:
   harms+=1
   last_hp=hunt.rules.deer_hp
 if actor!=Rules.SAEBOM: print("METRIC ",pair," clearance=",metric_min," at=",metric_when," tip=",metric_tip," body=",metric_body)
 check(pair+" native skill dealt configured once-only damage",harms==1 and before_hp-last_hp==[8,31,58][actor])

func try_guard(stage:int)->void:
 var hunt=await prepare(stage,1)
 if hunt==null:return
 await process_frame
 var pair:="guard "+("adult" if hunt._prey_is_adult() else "deer")
 hunt.rules.hunter_turn=false
 hunt.rules.next_target=1
 hunt.rules.charges.assign([3.0,3.0,3.0])
 hunt.rules.exchange_clock=Rules.AUTO_INTERVAL
 hunt._process(1.0/60.0)
 var hud:Control=hunt.party_cards[1].hud
 var hp:int=hunt.rules.party_hp[1]
 check(pair+" natural counter to Uram opens real HUD",hunt.pose=="counter" and hunt.rules.attacker==1 and not hud.chain_button.disabled)
 check(pair+" actual Uram 3SP click",await click_button(hud.chain_button))
 check(pair+" arms and reserves exactly three",hunt.guard_active and hunt.rules.charges[1]<.01)
 var input_deadline:float=hunt.chain_window.deadline
 var other:Control=hunt.party_cards[Rules.SAEBOM].hud
 check(pair+" early Saebom mouse attempt cannot skip unconfirmed guard",not (await click_button(other.chain_button,true)) and hunt.rules.orbs(Rules.SAEBOM)==3)
 var min_clear:=INF
 var last_local:=Vector3.INF
 var prev_local:=Vector3.INF
 for frame in range(29):
  hunt._process(1.0/60.0)
  if hunt.pose_clock>=.11 and hunt.pose_clock<=.28:
   var muzzle:Vector3=hunt._counter_muzzle()
   var face:Transform3D=hunt._shield_metric(hunt.hunters[1])
   var local:=face.affine_inverse()*muzzle
   var clear:=Vector3(maxf(absf(local.x)-.53,0.),maxf(absf(local.y)-.58,0.),absf(local.z)).length()
   if clear<min_clear:
    min_clear=clear
    prev_local=last_local
   last_local=local
   if frame%3==0:print("GUARD_METRIC ",pair," t=",hunt.pose_clock," loc=",local," muzzle=",muzzle," shield=",face.origin)
 print("GUARD_OUTCOME ",pair," min=",min_clear," before_nearest=",prev_local," event=",hunt.last_guard_contact," hp=",hp,"->",hunt.rules.party_hp[1])
 check(pair+" true muzzle/shield contact prevents native incoming HP",not hunt.last_guard_contact.is_empty() and hunt.rules.party_hp[1]==hp)
 check(pair+" physical confirmation preserves original two-second deadline",hunt.chain_window.deadline==input_deadline and hunt.chain_window.actionable()==&"saebom")
 if hunt.last_guard_contact.is_empty(): return
 var before_stone:int=hunt.rules.deer_hp
 check(pair+" ordered chain real Saebom button tap accepted",await click_button(other.chain_button))
 check(pair+" ordered chain grants next Han button and costs exactly 3",hunt.chain_window.actionable()==&"hangyeol" and hunt.rules.orbs(Rules.SAEBOM)==0)
 var han:Control=hunt.party_cards[0].hud
 check(pair+" chain real Han button tap accepted before rally completes",await click_button(han.chain_button))
 check(pair+" ordered chain ends only after actual Han click",not hunt.chain_window.active() and hunt.rules.orbs(0)==0)
 var saw_rally:=false
 var saw_han:=false
 var saw_visual:=false
 for i in range(135):
  hunt._process(1.0/60.0)
  saw_rally = saw_rally or hunt.rules.rally_remaining[Rules.SAEBOM]>0.0
  saw_han = saw_han or hunt.pose=="han_spear_3"
  saw_visual = saw_visual or (hunt.rally_art.active and hunt.rally_art.age>=.96 and hunt.rally_art.recipients.has(Rules.SAEBOM))
 print("CHAIN_OUTCOME "+pair+" ordered Rally=",saw_rally," visual=",saw_visual," Han=",saw_han," HP=",before_stone,"->",hunt.rules.deer_hp)
 check(pair+" ordered chain executes actual rally, wings and intended Han finisher",saw_rally and saw_han and saw_visual)
 check(pair+" ordered actual rear finisher contact deals compounded ten",hunt.rules.deer_hp==before_stone-10 and hunt.han_chain_travel.length()>0.0)

func try_late_or_timeout(stage:int, mode:String)->void:
 var hunt=await prepare(stage,1)
 if hunt==null:return
 hunt.rules.hunter_turn=false
 hunt.rules.next_target=1
 hunt.rules.charges.assign([3.0,3.0,3.0])
 hunt.rules.exchange_clock=Rules.AUTO_INTERVAL
 hunt._process(1.0/60.0)
 var hud:Control=hunt.party_cards[1].hud
 var hp:int=hunt.rules.party_hp[1]
 if mode in ["timeout","timeout2"]:
  check("Timeout setup receives actual Uram tap",await click_button(hud.chain_button))
  for i in range(33): hunt._process(1.0/60.0)
  check("Timeout setup confirms actual adult shield block",not hunt.last_guard_contact.is_empty())
  if mode=="timeout2":
   var s:Control=hunt.party_cards[Rules.SAEBOM].hud
   check("Second window: actual Saebom mouse click accepted",await click_button(s.chain_button))
   var next_deadline:float=hunt.chain_window.deadline
   var han:Control=hunt.party_cards[0].hud
   check("Second window: real fresh 2s deadline and Han enabled",is_equal_approx(next_deadline-hunt.manual_input_clock,2.0) and not han.chain_button.disabled)
   hunt.rules.exchange_clock=-100.0
   var saw_wings:=false
   for i in range(121):
    hunt._process(1.0/60.0)
    saw_wings=saw_wings or (hunt.rally_art.active and hunt.rally_art.age>=.96 and hunt.rally_art.recipients.has(Rules.SAEBOM))
   check("Second window: real rally applied and wings appeared; skill buff still active",saw_wings and hunt.rules.rally_remaining[Rules.SAEBOM]>0.0)
   check("Second window: expired Han click rejected without spending or auto-strike",not hunt.chain_window.active() and hunt.manual_pending.is_empty() and not (await click_button(han.chain_button,true)) and hunt.rules.orbs(0)==3 and hunt.rules.deer_hp==hunt.rules.deer_max_hp-Rules.URAM_SHIELD_COUNTER_DAMAGE)
   return
  hunt.speed=2.0
  hunt.rules.exchange_clock=-100.0
  for i in range(121):hunt._process(1.0/60.0)
  var bom:Control=hunt.party_cards[Rules.SAEBOM].hud
  check("Timeout is real unscaled two-second gate with no automatic finisher",not hunt.chain_window.active() and hunt.manual_pending.is_empty() and not (await click_button(bom.chain_button,true)) and hunt.rules.orbs(Rules.SAEBOM)==3 and hunt.rules.orbs(0)==3)
 else:
  for i in range(12):hunt._process(1.0/60.0)
  var fired:=false
  if mode=="late":fired=await click_button(hud.chain_button,true)
  for i in range(21):hunt._process(1.0/60.0)
  check(mode+" stage "+str(stage)+" input preserves genuine incoming damage",hunt.last_guard_contact.is_empty() and hunt.rules.party_hp[1]==hp-2)
  if mode=="late":
   var before:int=hunt.rules.deer_hp
   check("Late tap consumes three without creating ordered guard/chain",fired and hunt.rules.orbs(1)==0 and not hunt.chain_window.active())
   hunt.rules.exchange_clock=-100.0
   for i in range(75):hunt._process(1.0/60.0)
   check("Late paid follow-up strikes prey exactly once",hunt.rules.deer_hp==before-Rules.URAM_SHIELD_COUNTER_DAMAGE)
  else:
   check("Unpressed guard neither spends nor deals damage",not fired and hunt.rules.orbs(1)==3 and hunt.rules.deer_hp==hunt.rules.deer_max_hp)

func try_front_finisher(stage:int)->void:
 var hunt=await prepare(stage,0)
 if hunt==null:return
 # Simulate a previously defeated ally, in the normal 3-character fight, so
 # this is an allowed unaided Han 3SP. Stage6 is not a public 1v1 route.
 hunt.rules.party_hp[Rules.SAEBOM]=0
 hunt.rules.charges[0]=3.0
 hunt.update_combat_ui()
 var han:Control=hunt.party_cards[0].hud
 var before_hp:int=hunt.rules.deer_hp
 check("Stage "+str(stage)+" front solo real Han 3SP click",await click_button(han.chain_button))
 for frame in range(100):hunt._process(1.0/60.0)
 check("Stage "+str(stage)+" front solo native contact deals unboosted eight",hunt.rules.deer_hp==before_hp-8)

func run()->void:
 app=load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.application_active=true
 check("Isolated fresh ordinary game started",app.model.start_new({},true))
 if OS.get_environment("ROX_FRONTLINE_FIXTURE_SECOND_TIMEOUT_ONLY")=="1":
  await try_late_or_timeout(5,"timeout2")
 elif OS.get_environment("ROX_FRONTLINE_FIXTURE_INPUT_ONLY")=="1":
  var hunt=await prepare(4,Rules.SAEBOM)
  var hud:Control=hunt.party_cards[Rules.SAEBOM].hud
  hunt.rules.charges[Rules.SAEBOM]=3.0
  hunt.update_combat_ui()
  check("Smoke: real stone button dispatched in ordinary Main",await click_button(hud.portrait_button) and hunt.pose=="team")
 else:
  for stage in [4,5]:
   if OS.get_environment("ROX_FRONTLINE_FIXTURE_GUARD_ONLY")!="1":
    for actor in 3:await try_skill(stage,actor)
   await try_guard(stage)
   await try_late_or_timeout(stage,"late")
   await try_late_or_timeout(stage,"idle")
   await try_front_finisher(stage)
  await try_late_or_timeout(5,"timeout")
  await try_late_or_timeout(5,"timeout2")
 app.queue_free()
 await process_frame
 print("Normal frontend real-input fixture: ",checks," checks; ",failures," failures")
 quit(int(failures!=0))
