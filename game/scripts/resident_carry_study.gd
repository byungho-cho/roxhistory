class_name ResidentCarryStudy
extends BoneAttachment3D
# Opt-in presentation prototype only. No resource or job state is changed here.
const PROP_PATHS:={
 "wood":"res://assets/characters/resident-study/carry-wood-blockout.glb",
 "stone":"res://assets/characters/resident-study/carry-stone-blockout.glb",
 "grain":"res://assets/characters/resident-study/carry-grain-blockout.glb"
}
var props:Dictionary={}
var displayed_kind:=""
func configure(skeleton:Skeleton3D)->void:
 bone_name="spine"
 var idx:=skeleton.find_bone("spine")
 if idx<0:return
 var correction:=skeleton.get_bone_global_rest(idx).basis.inverse()
 for kind in PROP_PATHS:
  var prop:Node3D=load(PROP_PATHS[kind]).instantiate()
  add_child(prop)
  # Match model-space placement despite imported bone rest orientations.
  prop.transform=Transform3D(correction,correction*Vector3(0,.02,-.28))
  prop.visible=false
  props[kind]=prop
func set_cargo(cargo:Dictionary)->void:
 var kind:=str(cargo.get("kind","")) if int(cargo.get("amount",0))>0 else ""
 if not props.has(kind):kind=""
 if kind==displayed_kind:return
 displayed_kind=kind
 for key in props:props[key].visible=key==kind
