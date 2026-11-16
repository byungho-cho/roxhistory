extends RefCounted

const ENTRIES := {
	"0.2.202": ["촌장집의 양쪽 눈 불꽃이 교차하지 않도록 조정했습니다.", "굴뚝 연기가 위로 퍼지면서 자연스럽게 옅어지도록 다듬었습니다."],
	"0.2.203": ["촌장집 굴뚝 연기가 더 높고 풍성하게 올라옵니다.", "눈 불꽃이 양옆으로 벌어지며 여러 갈래로 일렁입니다."],
	"0.2.204": ["가방 배경에서 바구니와 토기가 잘 보이도록 원화를 교체했습니다.", "여정의 기록과 퀘스트 보상 팝업을 정리했습니다.", "설정과 업데이트 안내에 버전별 패치 노트를 추가했습니다.", "초원 멧돼지는 등장 후 무음 대기 동작을 반복합니다.", "마을 경계 안개에 실험실 전용 5단계 비교를 추가했습니다."]
}

static func rows(version: String) -> Array:
	return ENTRIES.get(version, [])

static func body(version: String) -> String:
	var notes := rows(version)
	if notes.is_empty():
		return "이 버전의 패치 노트가 아직 없습니다."
	var lines := PackedStringArray()
	for index in notes.size():
		lines.append("%02d  %s" % [index+1,notes[index]])
	return "\n\n".join(lines)
