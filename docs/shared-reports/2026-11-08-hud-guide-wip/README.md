# 개발 인수인계 · 비용 HUD / 캐릭터 안내 · 2026-11-08

## 상태와 이어받는 방법
사용자 요청으로 작업을 임시 중지했습니다. 완성·배포본이 아닌 WIP입니다.
- 저장소: https://github.com/byungho-cho/roxhistory
- 브랜치: feat/hud-guide-20261108
- 기준 main: df1cb74 (이전 로컬 f22032c의 변경을 포함한 main으로 fast-forward 후 작업)
- 다른 PC에서는 해당 브랜치를 fetch/checkout하여 이어서 작업합니다. main에는 아직 병합하지 않았습니다.
- 프로젝트: game/project.godot, Godot 4.5.1
- 앱 버전은 main의 0.1.58 그대로이며 새 빌드·배포·버전 증가는 하지 않았습니다.
- 실제 사용자 저장을 초기화하거나 삭제하지 않았습니다. 테스트는 별도 user:// 경로를 사용했습니다.
- Figma는 읽기만 했으며 사용자 수정본을 변경하지 않았습니다.

## 확정 요구사항
1. S40100 02-2 사용자 수정본 1427:6916 / I10000 MAT-007 1426:318:
   금색 패널과 X 제거, 붓터치 380×39 / 알파60%, 자원 아이콘32px, 확인 터치 영역60px.
   표시 수량은 실제 건물·단계 비용. 20/10 고정값 금지.
   X 제거 후 새 취소 방식은 미정. 기존 취소 경로 및 진행 중 취소·전액 환급 유지.
2. U10400 1627:80 / 에셋 1626:340:
   크림 패널 알파80%, 검정 테두리·글자·작은 X, 은은한 그림자.
   캐릭터가 패널 왼쪽 전경을 가림. 패널 먼저, 캐릭터 다음 등장 및 약한 좌우 흔들림.
   X 또는 안내 바깥 터치로 닫고 월드 입력으로 전달하지 않음. 호출자가 전달한 문구를 표시.
3. 앞서 메모한 건물 이동 애니메이션의 기존 건설 효과음 연결은 아직 미반영. 이번 HUD 작업과 별도 후속 항목.

## 반영된 코드
- game/scripts/build_cost_display.gd: MAT-007 공통 분리 HUD. 붓터치·기존 목재/돌·실제 숫자·확인 버튼.
- game/scripts/upgrade_confirmation.gd: 위 공통 HUD를 건물 상단에 배치. X와 금색 패널 제거.
- game/scripts/build_preview.gd: 신규 건설에도 같은 HUD 연결. 기존 부지 선택 취소 경로 유지. 건물 이동 자체의 O/X는 유지.
  위치 선택 후 이전 위치 선택 토스트를 정리하여 비용과 겹치지 않도록 수정.
- game/scripts/character_guide.gd: 공통 안내 화면. 동적 제목/본문, 긴 본문 스크롤, 순차 등장, 캐릭터 흔들림, 닫기.
- game/scripts/main.gd: show_character_guide(title, body) 추가, 화면 비율 변경 시 열린 안내 내용 보존.
- game/scripts/building_workflow.gd: 촌장집 단계 상승 안내를 새 공통 안내로 연결. 다른 모달/배치 중에는 대기.
- game/tests/hud_guide_v0159_tests.gd: 확인·실제 비용·환급·닫기·입력 전달 방지·화면 비율·저장 재진입 검사.
- game/tests/v0158/building_polish_test.gd: 이전 금색 HUD 기대값을 이번 확정안으로 변경.

## 에셋과 출처
game/assets/ui/v0159/에 Figma에서 내려받은 PNG 원본 보존:
- guide-character.png: 1627:85 / 1625:340
- guide-panel.png: 1627:84 / 1625:341
- cost-brush.png: 1641:7286 / 1636:7303
- guide-close.png: 1626:347의 기존 검정 X 원본
기존 res://assets/figma-latest/b7632.png의 목재·돌 크롭과 res://assets/ui/v034/build-confirm.png 재사용.
런타임 임시 URL 없음. crop은 AtlasTexture로 비파괴 적용, 원본 PNG 유지.
패널·문구·캐릭터·버튼 분리. 실제 화면 크기는 기존 Godot 960×540 논리 UI 스케일을 따릅니다.

## 수행한 검사 / 실제 결과
- 신규 HUD·안내 실행 검사: 26개 통과 (Windows OpenGL, 1280×720 / 세로 전환, 합성 터치).
- building_model_v0151_tests.gd: 192개 통과.
- v0158/building_polish_test.gd: 오류 배열 없음.
- windows_v052_tests.gd: **실패 / 미완료**.
  73행 “Compact approved upgrade panel” 실패 후 77행 ConfirmUpgrade null 접근.
  전체 통과로 보고하지 마세요. 새 촌장집 성장 안내가 기존 회귀 흐름의 업그레이드 요청을 막았는지,
  기존 테스트 상태·타이밍 및 최신 HUD 탐색 경로를 확인해야 합니다. 원인 확정 전입니다.
- Godot import/스크립트 로딩 성공.
- 이번 변경의 APK/EXE export, Android 설치, 실제 모바일 터치·청취: 미수행.
- 자동 검사는 사용자 최종 시각 승인과 다릅니다.

## 이어서 할 일
1. 실패한 Windows 기존 회귀를 재현하고 원인을 확인. 안내/업그레이드 모달 간 충돌인지 검사하고 필요한 수정만 적용.
2. 비용 HUD와 guide의 크기·간격을 Figma와 최종 대조. 4자리 이상 비용은 27px로 축소하므로 필요한 비용 범위에서 겹침 검사.
3. 건설 자재 부족, 확인 연타, 배치 취소, 업그레이드 배경 닫기, 진행 중 X·환급 회귀를 마무리.
4. 캐릭터 안내를 띄운 상태에서 앱 중단·복귀, 기존 자동 이동/작업 복귀 확인.
5. 필요 시 건물 이동 출발·도착 효과음(기존 build cue, 음소거·중복 방지)을 후속 반영.
6. 사용자 요청에 맞춰 버전 확정 후 빌드. 최신 AGENTS.md 및 scripts/build-release.ps1 확인.
   현재 배포 규칙: 같은 소스/버전 APK·EXE 쌍, build/ 폴더, Roxhistory_<version> 이름.
   이번 턴은 임시 저장만 요청받았으므로 릴리스 게시/기존 파일 정리 하지 않음.
7. 서명 주의: 과거 로컬 서명과 별도 Cloud TEST 서명이 달랐음. 배포 대상의 기존 키 확인 필수.
   키 생성/교체 또는 사용자 앱 삭제로 우회하지 말 것.

## 실행 자료
![업그레이드 비용](evidence/v0159-upgrade.png)
![건설 배치 비용](evidence/v0159-placement.png)
![캐릭터 안내](evidence/v0159-guide.png)

검사 로그도 evidence/에 포함했습니다. 이번 자료는 임시 구현의 실제 PC 실행 캡처이며 최종 승인본이 아닙니다.
