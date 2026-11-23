extends RefCounted
## Rendering and authored body pose only. Caller owns skill release/recipient
## qualification, attack availability, pause, damage and the real buff clock.
const Art := preload("res://scripts/hunt_duel_saebom_3p_effect.gd")
const SaebomRig := preload("res://scripts/hunt_production_saebom_rig.gd")
const Silver := preload("res://scripts/saebom_rally_silver_vfx.gd")
const Rules := preload("res://scripts/deer_hunt_rules.gd")
const CAST_END := 2.24
var back_layer:Node2D
var front_layer:Node2D
var rig:SaebomRig
var art:=Art.new()
var active:=false
var caster:=2
var age:=0.0
var buff_clocks:Array[float]=[]
var recipients:Array[int]=[]
var positions:Array[Vector2]=[]
var alive:Array[bool]=[]

func setup(field:CanvasItem, actor_group:Node, hero:SaebomRig) -> void:
 if is_instance_valid(back_layer) or not is_instance_valid(field):return
 Silver.prepare()
 rig=hero
 back_layer=Node2D.new()
 front_layer=Node2D.new()
 back_layer.name="SaebomRallyBack"
 front_layer.name="SaebomRallyFront"
 field.add_child(back_layer)
 field.add_child(front_layer)
 if is_instance_valid(actor_group) and actor_group.get_parent()==field:
  field.move_child(back_layer,actor_group.get_index())
 front_layer.z_index=2
 back_layer.draw.connect(_draw.bind(false))
 front_layer.draw.connect(_draw.bind(true))
func start(caster_slot:=2) -> void:
 _clear_pose()
 caster=caster_slot
 active=true
 age=0.0
 buff_clocks.clear()
 recipients.clear()
 _redraw()

func release(applied_slots:Array[int]) -> void:
 if not active:return
 for slot in applied_slots:
  if slot>=0 and slot not in recipients:recipients.append(slot)
 _redraw()

func tick(delta:float, actual_feet:Array[Vector2], still_living:Array[bool],actual_remaining:Array[float]) -> void:
 positions=actual_feet.duplicate()
 alive=still_living.duplicate()
 buff_clocks=actual_remaining.duplicate()
 if not active:return
 age+=maxf(0.0,delta)
 if age>=CAST_END:_clear_pose()
 if age>=3.74 and not _has_active_buff():
  cancel()
 else:_redraw()

func pose_after_actor_sample(allow_pose:bool) -> void:
 if active and age<CAST_END and allow_pose and _valid(caster) and is_instance_valid(rig):
  rig.apply_support_pose(art,age)
 else:_clear_pose()

func _valid(slot:int)->bool:
 return slot>=0 and slot<positions.size() and slot<alive.size() and alive[slot] and positions[slot].is_finite()

func _has_active_buff() -> bool:
 for slot in recipients:
  if _valid(slot) and slot<buff_clocks.size() and buff_clocks[slot]>0.:return true
 return false

func _draw(front:bool) -> void:
 if not active:return
 if not front:
  if _valid(caster):Silver.wings(back_layer,positions[caster],age)
  return
 for slot in recipients:
  if _valid(slot) and slot<buff_clocks.size():
   Silver.aura(front_layer,positions[slot],buff_clocks[slot],Rules.RALLY_SECONDS)

func _clear_pose() -> void:
 if is_instance_valid(rig):rig.clear_support_pose()
 else:art.restore_sling()

func _redraw() -> void:
 if is_instance_valid(back_layer):back_layer.queue_redraw()
 if is_instance_valid(front_layer):front_layer.queue_redraw()

func cancel() -> void:
 active=false
 age=0.0
 recipients.clear()
 buff_clocks.clear()
 _clear_pose()
 _redraw()
