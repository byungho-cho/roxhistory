# 1대1 실험실 스킬 준비 HUD

기준 소스: 최신 개발 브랜치 `codex/walk-stride-276`, `66095cad7999278b54f1939ae242cfbd73c5f736`.
작업 범위: 독립 1대1 실험실 연결 및 HUD 준비 효과. 본편 전투·세이브·보상·레벨링은 변경하지 않음.

자료:
- 인수인계서: https://drive.google.com/file/d/1bp6HFvz6Pwj94FA3v_DY_rL1c9bdTRuo/view
- HUD: Figma `zkbflw9fCdAlWbphhw5pSS`, `4001:839`
- 새봄 돌팔매 / 강화: `3764:12` / `3764:14`
- 참고 ZIP: `17eCAeV-u1rCeTFfB5gySLZtOazWes1Zs`. 기존 추적 파일을 덮어쓰지 않고 새 독립 전장 두 스크립트·장면과 승인 WAV 19개만 검토해 추가. main 진입부만 명시적으로 연결.

구현:
- `duel_skill_hud.gd`: 2 SP 초상화 클릭, 좌하단 반쪽 가로·세로 표시용 배지. 따뜻한 광원은 얼굴을 분리한 투명 초상 뒤에 배치. 진입 0.48초 후 고정.
- 3 SP 독립 연계 버튼은 초상화 가로·세로 80%. 배경광 0.36초 상승 후 유지. 짧은 테두리 광원만 순환하며 이미지·버튼은 흔들거나 축소하지 않음.
- readiness edge를 따로 추적하므로 2→3 SP가 일반 준비광을 재시작하지 않음. 소비·KO·선택 변경·리셋 시 즉시 갱신.
- 터치 캡처와 합성 마우스 차단으로 동일 입력을 두 동작에 전달하지 않음. 손을 버튼 밖에서 놓거나 터치를 취소하면 발동하지 않음.
- 기존 모델 테스트 유지. 1대1 전장 좌하단의 받아치기로 이전 실험실에도 접근 가능.

검증 명령:
`godot --headless --path game --script res://tests/hunt_duel_lab_tests.gd`
`godot --headless --path game --script res://tests/hunt_duel_hud_tests.gd`

기본 동작 23개, HUD/실제 GUI 입력 51개 검사 통과. 한결/우람/새봄 × 꽃사슴/큰 멧돼지 조합, 일반·연계, 자연 충전, 입력 분리, 자동·수동 초기화 검증.
실제 화면 렌더와 별도 QA 세이브를 통한 마을 → 실험실/모델 테스트 복귀도 검수. 물리 Fold 및 실제 스피커 청감은 미검증.
headless 종료 시 리소스 정리 경고는 별도 로그에 남기며 전체 기존 회귀검사 통과로 표현하지 않음.
