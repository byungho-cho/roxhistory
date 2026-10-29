> 현재 상태: 구현 초안. **원본 PNG 3개 복구 전에는 실행·APK 빌드 불가.** [복구 목록](../game/assets/RESTORE.md)

# RoxHistory Android 첫 데모 v0.1.0

## 실행·빌드
Godot 4.5.1 stable 일반판에서 game/project.godot 실행.
데스크톱 보조: WASD/방향키 이동, E 채집, B 건설, Esc 뒤로가기.
휴대폰: 가로 화면, 왼쪽 조이스틱, 오른쪽 채집·건설·임무.

OpenJDK 17, Android SDK Platform 35, Build-Tools 35.0.0, Platform-Tools 35 이상,
Godot 동일 버전 export templates 필요. Editor Settings > Export > Android에서 SDK 경로 설정.
명령: godot --headless --path game --export-debug Android <APK 절대경로>
또는 Project > Export > Android > Export With Debug.
CI: .github/workflows/android-demo.yml.
패키지 com.roxhistory.demo / versionCode 1 / 0.1.0 / arm64-v8a·x86_64 / debug 서명.
로그인·서버·전투·결제·멀티플레이 없음. 오프라인 실행.

## 저장
위치·자원·소진 노드·건설·보상·안내 상태를 앱 전용 user://에 보관.
채집·건설·보상은 저장 성공 후 반영. 위치 8초 체크포인트와 포커스 상실·백그라운드·종료 시 저장.
임시 파일 flush·체크섬·스키마 재검증 후 rename. 이전 정상 파일은 backup.
손상 원본은 preserved 파일로 보존. 두 파일 손상 시 자동 덮어쓰기 차단.
새 게임 확인 후 초기화. 완성·보상 상태를 독립 저장해 보상 전 종료해도 이어서 수령.

## 디자인 및 임시 에셋
Figma A003: 110:358 안내, 110:430 시작, 110:450 지역, 110:495 플레이, 176:489 뒤로.
배경·아이콘 atlas·금빛 화살표는 원본 채움을 다운로드해 로컬 사용.
다크 스톤 80% 원형 뒤로, 아이보리 패널, 골드 버튼은 실제 Godot Control/Theme.
Figma의 모든 그라데이션·암각화 질감·미니맵까지 최종 일치하는 단계는 아님.

| 에셋 | 임시 상태와 교체 지점 |
| --- | --- |
| 강변 배경 | UI 없는 콘셉트 아트. 정적인 주민·동물·기존 마을이 포함됨. 후속 지형/오브젝트 분리 필요 |
| 지도 | Figma 원본, 역사적 지형과 정확한 좌표가 아닌 구성 참고 |
| 캐릭터 | 생성한 4방향 임시 캐릭터. 걷기 프레임 대신 방향 전환·상하 움직임. assets/characters/villager.png |
| 자원·움집 | Figma 아이콘 atlas를 월드에도 임시 재사용. scripts/art.gd에서 교체 |
| 충돌 | 그림에 맞춘 단순 도형. 세밀한 지형 검증 필요 |
| 소리 | 합성 조작 효과음만 제공. 환경음/배경음 후속 |

Noto Sans KR 라이선스는 assets/fonts/OFL.txt. 원본별 해시는 assets/manifest.json.
자원·퀘스트는 data/demo.json에 집중. 나무40/돌24, 획득2, 채집3.5초, 건설4초, 씨앗10.
총 7개 노드. 재생성/자유 배치 없음. 수량·보상·임무는 게임 창작, 역사 설명과 분리.
5~10분은 목표이며 처음부터 끝까지 사람의 플레이 시간은 아직 측정하지 않음.

## 검증 상태 · 2026-10-30 KST
- Windows Godot 실행 및 초기 장면 런타임: 확인
- 저장/복원/손상 복구/중복 지급/쓰기 실패: 로컬 334개 검사 통과
- 로컬 첫 APK 내보내기: 설정 오류. ETC2/ASTC 설정 보완 후 결과 회수 전 환경 연결 중단
- 로컬 UI 검사 스크립트: 타입 추론 오류 발견. 수정본 CI 검증 필요
- 원격 최신 소스에는 추가 변경이 있어 CI 결과가 최신 검증 근거
- Android 실기기: 연결 없음. 기기명/OS/실제 터치/설치·종료복원/발열·성능 측정 없음
- 에뮬레이터: Android35 이미지·도구 설치까지만 확인, 부팅·APK 설치 미검증
- 일반/커버/펼침 비율과 캡처: CI game/reports 확인
- APK 설치, 실제 전체 플레이, Figma 최종 시각 대조 전까지 데모 완료 기준 전체 충족으로 처리하지 않음
