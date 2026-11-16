extends RefCounted

const WARNING_MS := 1150
const CHARGE_MS := 650
const EARLIEST_MS := -220
const LATEST_MS := -55
const LATE_MS := 240
const STUN_MS := 1350

var start: int
var warning: int
var impact: int
var input := -1
var contact := -1
var stun_end := -1
var feedback_ms := -1
var normal_defense := false
var outcome := ""
var party_hp := 100
var boar_hp := 100
var followups := [false, false]

func _init(now: int) -> void:
	start = now
	warning = start + 1200
	impact = warning + WARNING_MS + CHARGE_MS

func parry(now: int) -> void:
	if input >= 0 or not outcome.is_empty(): return
	if now < warning:
		if not normal_defense:
			normal_defense = true
			boar_hp -= 5
		return
	if now > impact + LATE_MS: return
	input = now
	var offset := now - impact
	if offset < EARLIEST_MS:
		outcome = "너무 이름"
	elif offset <= LATEST_MS:
		outcome = "성공"
		stun_end = now + STUN_MS
		boar_hp -= 18
	else:
		outcome = "너무 늦음"

func advance(now: int) -> void:
	if now >= impact and contact < 0 and stun_end < 0:
		contact = now
		party_hp -= 24
	if now > impact + LATE_MS and outcome.is_empty():
		outcome = "미입력"

func use_followup(index: int, now: int) -> bool:
	if stun_end < 0 or now >= stun_end or followups[index]: return false
	followups[index] = true
	boar_hp -= 10 if index == 0 else 12
	return true

func finished(now: int) -> bool:
	return now >= stun_end + 500 if stun_end >= 0 else now > impact + 750

func elapsed(value: int) -> String:
	return "%dms" % (value - start) if value >= 0 else "—"

func report(index: int, average_fps: int, now: int) -> String:
	var result := outcome if not outcome.is_empty() else "중간 종료"
	if normal_defense: result += " · 일반 방어 사용"
	return "%d회차 | 예고 %s → 입력 %s → 예상 충돌 %s (차이 %s) | 실제 접촉 %s | %s · 스턴 %s | 한결 찌르기 %s, 새봄 협동 %s | UI 갱신 %s · 평균 FPS %s" % [
		index, elapsed(warning if now >= warning else -1), elapsed(input), elapsed(impact),
		"%+dms" % (input - impact) if input >= 0 else "—", elapsed(contact),
		result, "O" if stun_end >= 0 else "없음", "O" if followups[0] else "미사용",
		"O" if followups[1] else "미사용", "%dms" % feedback_ms if feedback_ms >= 0 else "—",
		str(average_fps) if average_fps > 0 else "—"]
