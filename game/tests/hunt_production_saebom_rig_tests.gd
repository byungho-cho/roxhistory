extends SceneTree
const Rig=preload("res://scripts/hunt_production_saebom_rig.gd")
var failures:=0
func _initialize():call_deferred("run")
func check(condition:bool,msg:String)->void:
 if not condition:failures+=1;push_error(msg)
func run():
 var parent:=Node2D.new()
 root.add_child(parent)
 parent.position=Vector2(28,45)
 parent.scale=Vector2(.8,.8)
 var actor:=Rig.new()
 actor.render_size_factor=.5
 parent.add_child(actor)
 actor.position=Vector2(300,200)
 actor.scale=Vector2(.56,.56)
 actor.set_enabled(true)
 check(actor is HybridCharacter and actor.character=="saebom","actual production HybridCharacter Saebom")
 check(actor.has_anchor("sling_stone") and actor.has_anchor("hand.R") and actor.has_anchor("chest"),"physical authored anchors")
 var original_position:=actor.global_position
 actor.animate(.1,Vector2(1,0),1.5,true,"",0.,false)
 check(actor.animation.current_animation=="run" and actor.global_position==original_position,"authored locomotion without moving battle-owned position")
 actor.animate(.1,Vector2(1,0),0.,false,"hit",.2,false)
 check(actor.animation.current_animation=="hit_reaction","authored hit pose")
 actor.sample_native_release("heavy",3.566667)
 check(actor.animation.current_animation=="sling_heavy","authored 2SP release")
 var stone:=actor.stone_world()
 check(stone.is_finite() and stone.distance_to(actor.hand_world())>.5 and stone.distance_to(actor.global_position)>1.,"stone anchor tracks world-projected actual stone independently of palm")
 var chest:=actor.chest_world()
 actor.set_render_zoom(2.)
 check(chest.distance_to(actor.chest_world())<1.,"projection stable across viewport resize")
 actor.use_training_spear()
 check(actor.tool_3d.get_child_count()==0,"no legacy spear is created")
 var path:="res://scripts/hunt_duel_saebom_3p_effect.gd"
 if ResourceLoader.exists(path):
  var effect=load(path).new()
  actor.apply_support_pose(effect,.96)
  check(effect.stowed.size()==4,"actual authored sling meshes are hidden during cast")
  check(actor.animation.current_animation=="idle" and actor.global_position==original_position,"support uses planted idle foundation, not travel")
  actor.set_enabled(false)
  check(effect.stowed.is_empty(),"visibility restored on battle end")
 print("Saebom production rig assertions: ",failures)
 quit(int(failures>0))
