extends RefCounted

const WARNING_MS := 2250
const CHARGE_MS := 650
const EARLIEST_MS := -320
const LATEST_MS := -30
const LATE_MS := 240
const STUN_MS := 1350
const HANGEUL_CONTACT_MS := 210
const SAEBOM_WINDOW_MS := 2000

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
var hangeul_input := -1
var hangeul_hit := -1
var saebom_input := -1
var saebom_until := -1

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
	if hangeul_input >= 0 and hangeul_hit < 0 and now >= hangeul_input + HANGEUL_CONTACT_MS:
		hangeul_hit = now
		saebom_until = now + SAEBOM_WINDOW_MS
		boar_hp -= 10
	if now >= impact and contact < 0 and stun_end < 0:
		contact = now
		party_hp -= 24
	if now > impact + LATE_MS and outcome.is_empty():
		outcome = "미입력"

func parry_window(now: int) -> bool:
	return input < 0 and outcome.is_empty() and now-impact >= EARLIEST_MS and now-impact <= LATEST_MS

func can_followup(index: int, now: int) -> bool:
	if stun_end < 0 or followups[index]: return false
	if index == 1: return saebom_until >= 0 and now < saebom_until
	return now < stun_end

func use_followup(index: int, now: int) -> bool:
	if not can_followup(index,now): return false
	followups[index] = true
	if index == 0:
		hangeul_input = now
	else:
		saebom_input = now
		boar_hp -= 12
	return true

func finished(now: int) -> bool:
	if stun_end < 0: return now > impact + 750
	if hangeul_input >= 0 and hangeul_hit < 0: return false
	var deadline := maxi(stun_end,saebom_until if not followups[1] else saebom_input)
	return now >= deadline + 500

func elapsed(value: int) -> String:
	return "%dms" % (value - start) if value >= 0 else "—"

func report(index: int, average_fps: int, now: int) -> String:
	var result := outcome if not outcome.is_empty() else "중간 종료"
	if normal_defense: result += " · 일반 방어 사용"
	return "%d회차 | 예고 %s → 입력 %s → 예상 충돌 %s (차이 %s) | 실제 접촉 %s | %s · 스턴 %s | 한결 입력 %s / 적중 %s · %s | 새봄 입력 %s · %s | 한결 적중→새봄 %s | UI 갱신 %s · 평균 FPS %s" % [
		index, elapsed(warning if now >= warning else -1), elapsed(input), elapsed(impact),
		"%+dms" % (input - impact) if input >= 0 else "—", elapsed(contact),
		result, "O" if stun_end >= 0 else "없음", elapsed(hangeul_input), elapsed(hangeul_hit), "성공" if hangeul_hit >= 0 else ("대기" if followups[0] else "미사용"),
		elapsed(saebom_input), "성공" if followups[1] else "미사용", "%dms" % (saebom_input-hangeul_hit) if hangeul_hit >= 0 and saebom_input >= hangeul_hit else "—", "%dms" % feedback_ms if feedback_ms >= 0 else "—",
		str(average_fps) if average_fps > 0 else "—"]
