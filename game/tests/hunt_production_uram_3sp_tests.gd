
extends SceneTree
const Rules=preload("res://scripts/deer_hunt_rules.gd")
var app
var checks:=0
var fails:=0
func _initialize()->void:call_deferred("run")
func ck(label:String,ok:bool)->void:
 checks+=1
 print("CH1_URAM ",ok," ",label)
 if not ok:fails+=1
func prepare(stage:int):
 if app.screen=="hunt":app.close_hunt()
 if app.modal:app.close_modal()
 app.hunt_stage=stage
 app.model.state.hunt_cleared=maxi(stage,int(app.model.state.get("hunt_cleared",0)))
 app.show_screen("hunt_select")
 await app.prepare_selected_hunt()
 await process_frame
 if app.screen!="hunt" or not is_instance_valid(app.hunt):
  ck("real hunt opened",false)
  return null
 var hunt:Control=app.hunt
 hunt.set_process(false)
 hunt.arrival_finished=true
 hunt.transition_elapsed=-1.0
 hunt.assigned_cells.assign([0,5,3])
 hunt.start_combat()
 hunt.advance_transition(hunt.TRANSITION_SECONDS)
 hunt.update_actors(.05)
 hunt.rules.exchange_clock=-100.
 hunt.rules.charges.assign([3.,3.,3.])
 hunt.update_combat_ui()
 return hunt
func tap(hunt)->bool:
 var button:Button=hunt.party_cards[1].hud.chain_button
 if button.disabled or not button.is_visible_in_tree():return false
 for down in [true,false]:
  var e:=InputEventMouseButton.new()
  e.button_index=MOUSE_BUTTON_LEFT
  e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
  e.position=button.get_global_rect().get_center()
  e.global_position=e.position
  e.pressed=down
  root.push_input(e,true)
  await process_frame
 return hunt.rules.orbs(1)==0
func incoming(hunt,who:int)->void:
 hunt.rules.hunter_turn=false
 hunt.rules.next_target=who
 hunt.rules.exchange_clock=Rules.AUTO_INTERVAL
 hunt._process(1./60.)
 hunt.rules.exchange_clock=-100.
func count_strike(hunt,frames:int)->Array:
 var old:int=hunt.rules.deer_hp
 var hits:=0
 var peak:=0.
 for i in frames:
  hunt._process(1./60.)
  if int(hunt.rules.deer_hp)<old:
   hits+=1
   old=int(hunt.rules.deer_hp)
  peak=maxf(peak,float(hunt.rules.prey_stun_remaining))
 return [hits,peak]
func scenario(mode:String,stage:int)->void:
 var h=await prepare(stage)
 if h==null:return
 var initial:int=h.rules.deer_hp
 var ours:int=h.rules.party_hp[1]
 if mode in ["guard","miss","late","other"]:
  incoming(h,0 if mode=="other" else 1)
  ck(mode+" preserves actual initial enemy windup",h.pose=="counter" and h.rules.pending_counter and h.rules.attacker==(0 if mode=="other" else 1))
 if mode=="late":
  for i in range(10):h._process(1./60.)
  ck("late is beyond original guard window but before enemy impact",not h._guard_can_arm() and h.rules.pending_counter)
 var hp0:int=h.rules.party_hp[0]
 ck(mode+" actual 3SP tap accepted and paid exactly once",await tap(h) and is_zero_approx(float(h.rules.charges[1])))
 if mode=="early":
  ck("neutral/early starts standalone action immediately with no chain",h.pose==h.URAM_FIELD_CAST and not h.chain_window.active())
 elif mode in ["late","other"]:
  ck(mode+" queues without clearing incoming or creating ordered chain",h.rules.pending_counter and h.uram_field_reserved and not h.guard_active and not h.chain_window.active())
 else:
  ck(mode+" starts original guard, not fallback yet",h.guard_active and h.chain_window.actionable()==&"")
 if mode=="miss":h.manual_guard.cancel() # Force no physical intersection, despite real accepted arm.
 var old_deadline:float=h.chain_window.deadline
 var result:Array=await count_strike(h,75)
 if mode=="guard":
  ck("true shield contact blocks 2 HP and opens only Saebom, keeping deadline",not h.last_guard_contact.is_empty() and h.rules.party_hp[1]==ours and h.chain_window.actionable()==&"saebom" and h.chain_window.deadline==old_deadline)
 else:
  ck(mode+" cannot create true parry or chain progress",h.last_guard_contact.is_empty() and h.chain_window.actionable()!=&"saebom")
  if mode in ["miss","late"]:ck(mode+" preserves enemy's 2 damage",h.rules.party_hp[1]==ours-Rules.COUNTER_DAMAGE)
  if mode=="other":ck("attack targeting another hero lands unaltered",h.rules.party_hp[0]==hp0-Rules.COUNTER_DAMAGE)
 ck(mode+" hits sole prey 18 once and applies nominal 1.15s stun",result[0]==1 and initial-h.rules.deer_hp==18 and result[1]>=1.13 and result[1]<=1.15)
 ck(mode+" only one B3 visual event",h.manual_effects.filter(func(e):return e.kind==h.URAM_FIELD_CAST).size()==1)
func run()->void:
 root.size=Vector2i(960,540)
 app=load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 for mode in ["early","late","miss","other","guard"]:await scenario(mode,0)
 for mode in ["late","guard"]:await scenario(mode,5)
 var r:=Rules.new()
 r.hunter_turn=false;r.exchange_clock=Rules.AUTO_INTERVAL
 r.prey_stun_remaining=.11
 ck("stun forbids scheduling a fresh enemy windup but still ticks resource clock",r.advance(.05)=="" and not r.pending_counter and r.charges[1]>.0)
 ck("same held turn resumes after stun rather than vanishing",r.advance(.07)=="counter" and r.pending_counter)
 app.queue_free()
 await process_frame
 print("CH1 Uram shield counter: ",checks," checks, ",fails," failures")
 quit(int(fails>0))
