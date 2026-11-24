# 선택 효과음 · 실제 녹음 기반 (2026-11-06)

## 확정 매핑
- 목재 채집: Wood_01_Recorded_Axe_5s.wav (나무 1안)
- 석재 채집: Stone_01_Recorded_Short_Chip_5s.wav (석재 1안)
- 건설: Build_02_Recorded_Wood_Mallet_5s.wav (건축 2안)
- 철거: Build_01_Recorded_Hammer_5s.wav (건축 1안 재사용)

이전 합성 후보와 구분되는 실제 녹음 기반 선택본입니다. 현재 폴더는 승인 음원 보관이며 이 커밋은 게임 코드나 기존 런타임 음원을 변경하지 않습니다. 업그레이드 혼합 시안은 별도이며 이 4개 매핑을 변경하지 않습니다.

## 형식과 게임 재생
모두 5초, 48kHz, PCM 16bit, mono WAV입니다. 동일 파일을 이름 그대로 보존했습니다.
5초 파일은 비교 청취를 위해 여러 타격을 간격을 두고 배치한 음원입니다. 단일 타격이나 이음새 없는 무한 루프가 아닙니다.
매 타격마다 5초 파일을 중첩 재생하거나 자동 연속 루프하지 마세요. 실제 동작 시간과 타격 지점에 맞춰 구간을 추출하거나 독립 재생을 예약하세요. 원본을 덮어쓰지 말고 파생본을 별도 버전으로 관리하세요.
건설 및 향후 업그레이드는 시작과 진행 중 드문 시점에만 재생하며 연속 루프하지 않습니다. 행동 취소·완료 시 남는 재생을 정리하고 음량을 기존 BGM과 함께 확인하세요.
기술 검사(디코딩·길이·포맷·클리핑)는 통과했으나 게임 내 청취 검증은 별도입니다.

## 출처 및 이용 조건
Joseph SARDIN / BigSoundBank의 CC0 원음을 편집했습니다. 제작 담당이 각 원출처 페이지의 CC0 및 상업 이용·수정·재배포 허용을 확인했습니다. 자발적 출처 표기를 보존합니다.
- 목재: Ax on Wood — https://bigsoundbank.com/hache-sur-bois-s0536.html
- 석재: Fall of Stone — https://bigsoundbank.com/fall-of-stone-s1022.html
- 철거(건축 1안): Nail and Hammer #1 — https://bigsoundbank.com/nail-and-hammer-1-s0005.html
- 건설(건축 2안): Gavel, 1 blow — https://bigsoundbank.com/gavel-1-blow-s1588.html
- 라이선스: https://creativecommons.org/publicdomain/zero/1.0/
- 출처 사이트 이용 조건: https://bigsoundbank.com/licenses.html

편집: 원음 발췌, 경계 짧은 페이드, 90Hz 하이패스, 피크 정규화, 간격을 둔 리듬 구성. 합성 타격 레이어는 없습니다. 원출처 파일 자체가 아니라 편집 파생 음원입니다.
