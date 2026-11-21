extends RefCounted
## Pure ordinary-chain intake. The caller supplies finite monotonic, unscaled
## active-input seconds (no global speed/VFX clock) and does the real action/SP
## reservation inside authorize. No animations, HP, or buffs depend on this clock.

const ORDER: Array[StringName] = [&"uram", &"saebom", &"hangyeol"]
const WINDOW_SECONDS := 2.0

var phase := 0
var deadline := -INF
var generation := 0
var last_now := -INF
var guard_confirmed := false
var _reserving := false


func _set_time(now: float) -> bool:
	if not is_finite(now) or now < last_now:
		return false
	last_now = now
	return true


func _clear_window() -> void:
	phase = 0
	deadline = -INF
	guard_confirmed = false


func _expire_at(now: float) -> bool:
	if phase == 0 or now < deadline:
		return false
	_clear_window()
	return true


func advance(now: float) -> bool:
	# Expiration itself never schedules a finisher.
	return _set_time(now) and _expire_at(now)


func expected() -> StringName:
	return ORDER[phase]


func actionable() -> StringName:
	return &"" if phase == 1 and not guard_confirmed else expected()


func active() -> bool:
	return phase != 0


func confirm_guard(now: float, accepted_generation: int) -> bool:
	# The caller calls only after the accepted Uram arm really blocked a hit.
	if not _set_time(now):
		return false
	_expire_at(now)
	if phase != 1 or guard_confirmed or accepted_generation != generation:
		return false
	guard_confirmed = true
	return true  # Keep Uram's original tap deadline exactly unchanged.


func accept(hero: StringName, now: float, authorize: Callable) -> Dictionary:
	if _reserving or not _set_time(now):
		return {}
	_expire_at(now)
	if hero != expected() or hero != actionable() or not authorize.is_valid():
		return {}
	var which := phase
	_reserving = true
	var accepted := bool(authorize.call(hero))
	_reserving = false
	if not accepted:
		return {}
	if which == 0:
		generation += 1
	if which == ORDER.size() - 1:
		_clear_window()
	else:
		phase = which + 1
		deadline = now + WINDOW_SECONDS
	return {
		"hero": hero,
		"index": which,
		"generation": generation,
		"accepted_at": now,
		"next": expected() if active() else &"",
		"deadline": deadline,
		"await_guard": which == 0,
		"finished": which == ORDER.size() - 1,
	}


func reset() -> void:
	_clear_window()
	generation += 1  # Invalidate any accepted event from the previous fight.
	last_now = -INF
