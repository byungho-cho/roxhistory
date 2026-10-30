> 원본 에셋 복구와 Windows 자동 검사·APK 빌드·서명 검증 완료. Android 실기기 검증은 미완료입니다. [원본 에셋](../game/assets/RESTORE.md)

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
새 게임 확인 후 초기화하며 이전 백업도 별도 보존해 옛 게임이 복원되지 않도록 처리.
완성·보상 상태를 독립 저장해 보상 전 종료해도 이어서 수령.

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
- 저장/복원/손상 복구/중복 지급/쓰기 실패/이전 게임 백업 분리: 로컬 337개 검사 통과
- 터치 조이스틱·동시 터치·팝업·채집·건설·보상·실제 충돌·4개 화면 비율: 로컬 UI 검사 76개 통과
- 강둑 검사는 고정 Y좌표 대신 실제 RiverBank 충돌과 매 프레임 물 영역 미진입으로 검증
- 로컬 APK 내보내기·zipalign 및 apksigner v2/v3 서명 검증 통과
- Windows 제한 환경에서는 임시 내보내기 엔진의 safe-save 설정만 끄고 unsigned APK를 생성한 뒤 `apksigner sign --out`으로 별도 파일에 서명. 저장 게임의 체크섬·백업 로직과 배포용 서명 설정은 유지
- CI는 원본 파일의 크기·SHA-256, 스크립트 가져오기, 상태·UI 검사와 서명된 APK를 재검증
- Android 실기기: 연결 없음. 기기명/OS/실제 터치/설치·종료복원/발열·성능 측정 없음
- 에뮬레이터: Android35 이미지·도구 설치까지만 확인, 부팅·APK 설치 미검증
- 검사 크기: 1280×720, 896×370, 725×396, 816×616. 캡처·JSON은 실행 시 game/reports 생성
- APK 설치, 실제 전체 플레이, Figma 최종 시각 대조 전까지 데모 완료 기준 전체 충족으로 처리하지 않음
