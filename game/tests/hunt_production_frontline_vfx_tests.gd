extends SceneTree
const FX=preload("res://scripts/hunt_production_frontline_vfx.gd")
func _initialize():
 var f:=FX.new()
 var ok:=f.prepare() and f.han_skill.size()==11 and f.han_chain.size()==21 and f.han_radial.size()==21
 if ok:
  ok=f._frame(f.han_skill,0.)==f.han_skill[0] and f._frame(f.han_skill,10.1/30.)==f.han_skill[10]
  ok=ok and f._frame(f.han_chain,20.1/30.)==f.han_chain[20] and f._frame(f.han_radial,20.1/30.)==f.han_radial[20]
 print("Frontline VFX approved sequences loaded and endpoints checked: ",ok)
 quit(0 if ok else 1)
