extends SceneTree
var checks:=0
var errors:Array[String]=[]
func _initialize()->void:call_deferred('run')
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:errors.append(label)
func run()->void:
 var old:=HybridCharacter.new();old.model_path='res://assets/characters/residents/sturdy_male.glb';root.add_child(old)
 var study:=HybridCharacter.new();study.model_path='res://assets/characters/resident-study/woodcutter-study.glb';root.add_child(study)
 await process_frame
 study.set_enabled(true)
 check(study.rig.get_bone_count()==15,'15 bone count')
 for name in old.bones:
  check(study.bones.has(name),'bone exists '+name)
  var a:=old.rig.get_bone_rest(old.bones[name]);var b:=study.rig.get_bone_rest(study.bones[name])
  check(a.is_equal_approx(b),'rest unchanged '+name)
 for action in ['', 'wood','stone','farm_care','guard','training']:
  for i in range(60):
   study.animate(1.0/60.0,Vector2(1,1),float(i)/60.0*TAU,action=='',action,float(i)/60.0,false)
   study.rig.force_update_all_bone_transforms()
   for b in range(15):check(study.rig.get_bone_global_pose(b).is_finite(),'finite pose '+action+str(b))
 var result:={'checks':checks,'errors':errors,'scope':'headless rig/rest/action evaluation only; no full gameplay or visual guarantee'}
 FileAccess.open('res://../art-source/resident-retouch-study/rig-validation.json',FileAccess.WRITE).store_string(JSON.stringify(result,'  '))
 print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
