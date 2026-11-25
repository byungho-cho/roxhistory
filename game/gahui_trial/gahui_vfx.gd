extends Node3D
## Image-sequence effects for the Gahui lab only. Motion, collision and timing belong to the rig.
const Rig = preload("res://gahui_trial/gahui_rig.gd")
const BASIC_ARROW = preload("res://gahui_trial/vfx/gahui-basic-projectile-a.png")
const BASIC_IMPACT = preload("res://gahui_trial/vfx/gahui-basic-hit-splash-a-strip.png")
const BARRAGE_ARROW = preload("res://gahui_trial/vfx/projectile.png")
const BARRAGE_IMPACT = preload("res://gahui_trial/vfx/impact.png")
const BARRAGE_FINISHER = preload("res://gahui_trial/vfx/finisher.png")
const SURGE = [preload("res://gahui_trial/vfx/heal-0.png"), preload("res://gahui_trial/vfx/heal-1.png")]

var _arrows: Array[Sprite3D] = []
var _impacts: Array[Sprite3D] = []
var _heal: Sprite3D

func _ready() -> void:
 for _index in range(3):
  _arrows.append(_make_sprite(2))
  _impacts.append(_make_sprite(3))
 _heal = _make_sprite(1)

func _make_sprite(priority: int) -> Sprite3D:
 var sprite := Sprite3D.new()
 sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 sprite.no_depth_test = true
 sprite.render_priority = priority
 sprite.region_enabled = true
 sprite.visible = false
 add_child(sprite)
 return sprite

func clear() -> void:
 for sprite in _arrows:
  sprite.hide()
 for sprite in _impacts:
  sprite.hide()
 if is_instance_valid(_heal):
  _heal.hide()

func draw(action: int, elapsed: float, rig: Rig, camera: Camera3D, deer_chest: Vector3) -> void:
 clear()
 if action == 5:
  var frame := floori((elapsed - Rig.HEAL_RELEASE) * 24.0)
  if frame >= 0 and frame < 30:
   # The painted pool centre is y=222; place it on the true ground below the boots.
   _draw_frame(_heal, SURGE[frame / 15], frame % 15, 5, Vector2i(384,384), Vector2(192,222),
     .014, camera, _heal_ground_point(rig), 0.0)
  return
 if action != 3 and action != 4: return
 var is_barrage := action == 4
 var releases: Array = Rig.TWO_SP_RELEASES if is_barrage else [Rig.BASIC_RELEASE]
 for i in range(releases.size()):
  var age := elapsed - float(releases[i])
  if age < 0.0 or not rig.launches.has(i): continue
  var origin: Vector3 = rig.launches[i]
  var direction := camera.unproject_position(deer_chest) - camera.unproject_position(origin)
  var angle := Vector2(direction.x,-direction.y).angle()
  var last := is_barrage and i == releases.size()-1
  if age < Rig.FLIGHT_SECONDS:
   var progress := age / Rig.FLIGHT_SECONDS
   var point := origin.lerp(deer_chest, progress)
   if is_barrage:
    _draw_frame(_arrows[i], BARRAGE_ARROW, mini(11, floori(progress * 12.0)), 6, Vector2i(192,192),
      Vector2(135,96), .0115 if last else .009, camera, point, angle)
   else:
    _draw_frame(_arrows[i], BASIC_ARROW, 0, 1, Vector2i(96,48), Vector2(68,24),
      .012, camera, point, angle)
  else:
   var impact_age := age - Rig.FLIGHT_SECONDS
   var frame := floori(impact_age * 30.0)
   if last:
    # Fit the complete stronger finish into the unchanged final pose/recovery.
    var tail := float(Rig.TIMES[4]) - float(releases[i]) - Rig.FLIGHT_SECONDS
    if impact_age < tail:
     var finish_frame := mini(17, floori(impact_age * 18.0 / tail))
     _draw_frame(_impacts[i], BARRAGE_FINISHER, finish_frame, 6, Vector2i(192,192), Vector2(96,96),
       .016, camera, deer_chest, 0.0)
   elif is_barrage and frame < 8:
    _draw_frame(_impacts[i], BARRAGE_IMPACT, frame, 4, Vector2i(192,192), Vector2(96,96),
      .009, camera, deer_chest, 0.0)
   elif not is_barrage and frame < 8:
    _draw_frame(_impacts[i], BASIC_IMPACT, frame, 8, Vector2i(112,96), Vector2(48,45),
      .010, camera, deer_chest, angle)

func _heal_ground_point(rig: Rig) -> Vector3:
 var sk := rig.skeletons[0]
 var left_index := sk.find_bone(&"LeftToeBase")
 var right_index := sk.find_bone(&"RightToeBase")
 if left_index < 0 or right_index < 0:
  return rig.global_position
 var left := sk.to_global(sk.get_bone_global_pose(left_index).origin)
 var right := sk.to_global(sk.get_bone_global_pose(right_index).origin)
 var midpoint := (left + right) * .5
 # This is also the ray/terrain intersection at the projected boot position;
 # the actor origin is on the flat arena ground even while the boots animate.
 return Vector3(midpoint.x, rig.global_position.y, midpoint.z)

func _draw_frame(sprite: Sprite3D, sheet: Texture2D, frame: int, columns: int, tile: Vector2i,
  anchor: Vector2, units_per_pixel: float, camera: Camera3D, at: Vector3, angle: float) -> void:
 if sprite.texture != sheet:
  sprite.texture = sheet
 sprite.region_rect = Rect2(Vector2((frame % columns) * tile.x, (frame / columns) * tile.y), Vector2(tile))
 var half := Vector2(tile) * .5
 sprite.offset = Vector2(half.x - anchor.x, anchor.y - half.y)
 sprite.pixel_size = units_per_pixel
 var plane := camera.global_basis.orthonormalized()
 sprite.global_transform = Transform3D(plane * Basis(Vector3.BACK, angle), at)
 sprite.show()

