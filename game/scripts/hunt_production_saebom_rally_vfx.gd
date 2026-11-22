extends RefCounted
## Rendering and authored body pose only. Caller owns skill release/recipient
## qualification, attack availability, pause, damage and the real buff clock.
const Art := preload("res://scripts/hunt_duel_saebom_3p_effect.gd")
const SaebomRig := preload("res://scripts/hunt_production_saebom_rig.gd")
const VISUAL_RELEASE := .96
const CAST_END := 2.24
const AURA_END := 2.1
const WING_SCALE := .34
const ALLY_SCALE := .60
const WING_JOIN := Vector2(0., -53.)
var back_layer:Node2D
var front_layer:Node2D
var rig:SaebomRig
var art:=Art.new()
var texture:Texture2D
var active:=false
var caster:=2
var age:=0.0
var aura_start:=INF
var recipients:Array[int]=[]
var positions:Array[Vector2]=[]
var alive:Array[bool]=[]

func setup(field:CanvasItem, actor_group:Node, hero:SaebomRig) -> void:
 if is_instance_valid(back_layer) or not is_instance_valid(field):return
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
 var g:=Gradient.new()
 g.offsets=PackedFloat32Array([0.0,.27,.64,1.0])
 g.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.73),Color(1,1,1,.15),Color(1,1,1,0)])
 var radial:=GradientTexture2D.new()
 radial.width=128
 radial.height=128
 radial.fill=GradientTexture2D.FILL_RADIAL
 radial.fill_from=Vector2(.5,.5)
 radial.fill_to=Vector2(1.0,.5)
 radial.gradient=g
 texture=radial

func start(caster_slot:=2) -> void:
 _clear_pose()
 caster=caster_slot
 active=true
 age=0.0
 aura_start=INF
 recipients.clear()
 _redraw()

func release(applied_slots:Array[int]) -> void:
 if not active or is_finite(aura_start):return
 for slot in applied_slots:
  if slot>=0 and slot not in recipients:recipients.append(slot)
 # Cosmetic beat is pinned to the approved animation. If gameplay applied
 # earlier, do not delay or lengthen its buff; only wait to light the actors.
 aura_start=maxf(VISUAL_RELEASE,age)
 _redraw()

func tick(delta:float, actual_feet:Array[Vector2], still_living:Array[bool]) -> void:
 positions=actual_feet.duplicate()
 alive=still_living.duplicate()
 if not active:return
 age+=maxf(0.0,delta)
 if age>=CAST_END:_clear_pose()
 if age>=CAST_END and (not is_finite(aura_start) or age>=aura_start+AURA_END):
  cancel()
 else:_redraw()

func pose_after_actor_sample(allow_pose:bool) -> void:
 if active and age<CAST_END and allow_pose and _valid(caster) and is_instance_valid(rig):
  rig.apply_support_pose(art,age)
 else:_clear_pose()

func _valid(slot:int)->bool:
 return slot>=0 and slot<positions.size() and slot<alive.size() and alive[slot] and positions[slot].is_finite()

func _draw(front:bool) -> void:
 if not active:return
 var layer := front_layer if front else back_layer
 if age<CAST_END and _valid(caster):
  art.draw_wings(layer,texture,positions[caster]+WING_JOIN,age,WING_SCALE,front)
 if age<aura_start or age>=aura_start+AURA_END:return
 for slot in recipients:
  if _valid(slot):art.draw_ally(layer,texture,positions[slot],VISUAL_RELEASE+age-aura_start,ALLY_SCALE,front)

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
 aura_start=INF
 _clear_pose()
 _redraw()
