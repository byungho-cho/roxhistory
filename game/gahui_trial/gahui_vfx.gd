extends Node3D
## Image-sequence effects for the Gahui lab only. Motion, collision and timing belong to the rig.
const Rig = preload("res://gahui_trial/gahui_rig.gd")
const BASIC_ARROW = preload("res://gahui_trial/vfx/gahui-basic-projectile-a.png")
const BASIC_IMPACT = preload("res://gahui_trial/vfx/gahui-basic-hit-splash-a-strip.png")
const BARRAGE_ARROW = preload("res://gahui_trial/vfx/projectile.png")
const BARRAGE_IMPACT = preload("res://gahui_trial/vfx/impact.png")
const BARRAGE_FINISHER = preload("res://gahui_trial/vfx/finisher.png")
const BARRAGE_CAST_BACK = preload("res://gahui_trial/vfx/cast-back.png")
const BARRAGE_CAST_FRONT = preload("res://gahui_trial/vfx/cast-front.png")
const BARRAGE_RESERVOIR = preload("res://gahui_trial/vfx/reservoir.png")
const BARRAGE_HANDOFF = preload("res://gahui_trial/vfx/handoff.png")
const HEAL_PLUS = preload("res://gahui_trial/vfx/heal-plus.png")
const SURGE = [preload("res://gahui_trial/vfx/heal-0.png"), preload("res://gahui_trial/vfx/heal-1.png")]

# Source frame 28 (zero-based index 27) carries the original outer AND inner bands.
const HEAL_WAVE_BLUE = preload("res://gahui_trial/vfx/heal-ripple-sky-blue.png")
const HEAL_WAVE_ANCHOR := Vector2(192.0, 384.0 * .573)
const HEAL_WAVE_DELAY := .16
const HEAL_WAVE_START_RADIUS := 12.0
const HEAL_WAVE_SPEED := 315.0
const HEAL_WAVE_TEXTURE_RADIUS := .455
const LAB_DISPLAY_SCALE := .75 # 1280 × 720 subviewport -> 960 × 540 lab canvas
const HEAL_POOL_START := .48

var _arrows: Array[Sprite3D] = []
var _impacts: Array[Sprite3D] = []
var _heal: Sprite3D
var _heal_wave: Sprite3D
var _heal_pool: Sprite3D
var _heal_plus: Sprite3D
var _cast_back: Sprite3D
var _cast_front: Sprite3D
var _cast_reservoir: Sprite3D
var _cast_handoff: Sprite3D
var _heal_wave_origin := Vector3.INF

func _ready() -> void:
 for _index in range(3):
  _arrows.append(_make_sprite(2))
  _impacts.append(_make_sprite(3))
 _heal = _make_sprite(1)
 _heal_wave = _make_sprite(0)
 _heal_pool = _make_sprite(0)
 _heal_plus = _make_sprite(4)
 _cast_back = _make_sprite(0)
 _cast_back.no_depth_test = false
 _cast_front = _make_sprite(4)
 _cast_reservoir = _make_sprite(4)
 _cast_handoff = _make_sprite(4)

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
 _hide_effects()
 _heal_wave_origin = Vector3.INF

func _hide_effects() -> void:
 for sprite in _arrows:
  sprite.hide()
 for sprite in _impacts:
  sprite.hide()
 if is_instance_valid(_heal):
  _heal.hide()
 for sprite in [_heal_wave,_heal_pool,_heal_plus,_cast_back,_cast_front,_cast_reservoir,_cast_handoff]:
  if is_instance_valid(sprite):
   sprite.hide()

func draw(action: int, elapsed: float, rig: Rig, camera: Camera3D, deer_chest: Vector3) -> void:
 _hide_effects()
 if action == 5:
  var frame := floori((elapsed - Rig.HEAL_RELEASE) * 24.0)
  if frame >= 0 and frame < 30:
   # The painted pool centre is y=222; place it on the true ground below the boots.
   _draw_frame(_heal, SURGE[frame / 15], frame % 15, 5, Vector2i(384,384), Vector2(192,222),
     .014, camera, _heal_ground_point(rig), 0.0)
  _draw_heal_caster(elapsed, rig, camera)
  _draw_heal_wave(elapsed, rig, camera)
  return
 _heal_wave_origin = Vector3.INF
 if action != 3 and action != 4: return
 var is_barrage := action == 4
 var releases: Array = Rig.TWO_SP_RELEASES if is_barrage else [Rig.BASIC_RELEASE]
 var shot_time := elapsed - Rig.BARRAGE_LEAD_IN if is_barrage else elapsed
 if is_barrage:
  _draw_barrage_preparation(elapsed, shot_time, rig, camera)
 for i in range(releases.size()):
  var age := shot_time - float(releases[i])
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
    if i == 0 and progress < .20:
     _draw_frame(_cast_handoff, BARRAGE_HANDOFF, mini(4, floori(progress * 25.0)), 5, Vector2i(192,192),
       Vector2(96,96), .011, camera, point, 0.0)
   else:
    _draw_frame(_arrows[i], BASIC_ARROW, 0, 1, Vector2i(96,48), Vector2(68,24),
      .012, camera, point, angle)
  else:
   var impact_age := age - Rig.FLIGHT_SECONDS
   var frame := floori(impact_age * 30.0)
   if last:
    # Fit the complete stronger finish into the unchanged final pose/recovery.
    var tail := Rig.BARRAGE_LOCAL_DURATION - float(releases[i]) - Rig.FLIGHT_SECONDS
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

func _draw_barrage_preparation(elapsed: float, shot_time: float, rig: Rig, camera: Camera3D) -> void:
 var ground := _heal_ground_point(rig)
 var sk := rig.skeletons[0]
 var hand_id := sk.find_bone(&"RightHand")
 var staff := rig.staff_tip()
 var hand := sk.to_global(sk.get_bone_global_pose(hand_id).origin) if hand_id >= 0 else staff
 var endpoint := hand.lerp(staff, smoothstep(1.66, 1.80, elapsed))
 if elapsed < 1.80:
  var frame := clampi(floori(elapsed * 30.0), 0, 53)
  var plane := camera.global_basis.orthonormalized()
  var shift := endpoint - ground
  var strength := smoothstep(.95, 1.56, elapsed)
  const PIXEL := .020
  var yscale := lerpf(1.0, clampf(shift.dot(plane.y)/(77.0*PIXEL), .57, 1.95), strength)
  var xshift := lerpf(0.0, clampf((shift.dot(plane.x)-36.0*PIXEL)/(77.0*PIXEL), -.87, .87), strength)
  _draw_frame(_cast_back, BARRAGE_CAST_BACK, frame, 9, Vector2i(192,192), Vector2(96,169), PIXEL,
    camera, ground, 0.0)
  _draw_frame(_cast_front, BARRAGE_CAST_FRONT, frame, 9, Vector2i(192,192), Vector2(96,169), PIXEL,
    camera, ground, 0.0)
  var rising := Basis(plane.x, plane.y * yscale + plane.x * xshift, plane.z)
  _cast_back.global_transform = Transform3D(rising, ground - plane.z * .018)
  _cast_front.global_transform = Transform3D(rising, ground)
 if elapsed < 1.56: return
 var used := 0
 for release in Rig.TWO_SP_RELEASES:
  if shot_time >= float(release): used += 1
 if used >= 3: return
 var volume := smoothstep(1.56, 1.68, elapsed) * (1.0 - float(used)/3.0)
 var charge_frame := clampi(roundi(volume * 15.0), 0, 15)
 _cast_reservoir.modulate.a = 1.0 - smoothstep(2.32,2.88,elapsed)*.18
 _draw_frame(_cast_reservoir, BARRAGE_RESERVOIR, charge_frame, 4, Vector2i(192,192), Vector2(96,96), .014,
   camera, endpoint, 0.0)

func _draw_heal_caster(elapsed: float, rig: Rig, camera: Camera3D) -> void:
 # The solo lab has no allied recipients other than the caster. The enemy is never a heal anchor.
 var ground := _heal_ground_point(rig)
 var screen_px_per_unit := _lab_world_to_screen(ground, camera)
 if screen_px_per_unit <= .001: return
 if elapsed >= HEAL_POOL_START and elapsed < Rig.HEAL_RELEASE:
  var fill := smoothstep(HEAL_POOL_START, Rig.HEAL_RELEASE, elapsed)
  _heal_pool.modulate.a = fill * .92
  _draw_frame(_heal_pool, SURGE[0], 4, 5, Vector2i(384,384), HEAL_WAVE_ANCHOR,
    lerpf(27.0,136.0,fill)/(384.0*screen_px_per_unit), camera, ground, 0.0)
 var plus_frame := floori((elapsed - Rig.HEAL_RELEASE) * 24.0)
 if plus_frame >= 0 and plus_frame < 30:
  _draw_frame(_heal_plus, HEAL_PLUS, plus_frame, 6, Vector2i(192,192), Vector2(96,149),
    127.0 / (192.0 * screen_px_per_unit), camera, ground + camera.global_basis.y.normalized() * 25.0 / screen_px_per_unit, 0.0)

func _lab_world_to_screen(at: Vector3, camera: Camera3D) -> float:
 return camera.unproject_position(at).distance_to(camera.unproject_position(at + camera.global_basis.x.normalized())) * LAB_DISPLAY_SCALE

func _draw_heal_wave(elapsed: float, rig: Rig, camera: Camera3D) -> void:
 if elapsed < Rig.HEAL_RELEASE:
  _heal_wave_origin = Vector3.INF
  return
 if not _heal_wave_origin.is_finite():
  _heal_wave_origin = _heal_ground_point(rig)
 var age := elapsed - Rig.HEAL_RELEASE - HEAL_WAVE_DELAY
 var end := minf(1.40, float(Rig.TIMES[5]) - Rig.HEAL_RELEASE - HEAL_WAVE_DELAY)
 if age <= 0.0 or age >= end: return
 var opacity := .91 * smoothstep(0.0, .12, age) * (1.0 - smoothstep(1.08, end, age))
 var radius := HEAL_WAVE_START_RADIUS + HEAL_WAVE_SPEED * age
 # Match the review's logical-pixel expansion on the arena's orthographic camera.
 var world_to_lab := _lab_world_to_screen(_heal_wave_origin, camera)
 if world_to_lab <= .001: return
 var units_per_pixel := radius / (HEAL_WAVE_TEXTURE_RADIUS * 384.0 * world_to_lab)
 _heal_wave.modulate.a = opacity
 _draw_frame(_heal_wave, HEAL_WAVE_BLUE, 0, 1, Vector2i(384,384),
   HEAL_WAVE_ANCHOR, units_per_pixel, camera, _heal_wave_origin, 0.0)

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

