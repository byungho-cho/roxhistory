# v0.1.36 · 확정 디자인 대조와 화면 교정

2026-11-05. 기준 main `d9cda974`, 보존한 로컬 v0.1.35 작업 `7a77e8c`. 작업 브랜치 `feat/figma-visual-parity-20261105`.

기준: [대표 화면 956:242](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=956-242), HUD 956:419, 건설 사이드 메뉴 892:241, 월드 축소 977:356, 지형 타일 1006:424. 기획 설명 박스·예시 수치는 런타임 UI에 복사하지 않았다. 기존 실제 수량과 진행도를 유지한다.

## 변경

- 하단 버튼의 그림·돌 받침·이름을 분리하고 라벨을 중앙 정렬. 근접 여부에 따른 금빛 배경을 제거. 실제 미개방/진행 상태는 유지.
- 접기 버튼을 승인된 단일 PNG로 교체하고 이중 갈색 배경 제거. 닫힌 상태에서는 화살표를 반대로 회전. 터치 영역 56×56 유지.
- 건설 모달을 움집·초소 사이드 메뉴로 교체. 건설 바로 위에 움집, 왼쪽에 잠긴 초소. 움집은 나무20+돌20 부족 시 비활성·사유 안내. 선택 후 기존 부지 미리보기와 확인/취소 흐름 재사용.
- 확인 버튼 tooltip 제거. 실제 버튼·자재 수량·퀘스트는 보존. 가족 말풍선 폭186→166, 글자13→12, 터치 높이44 유지.
- 사용자 추가 확인에 따라 상단 자원의 나무·돌·씨앗 이름을 제거하고 아이콘과 실제 숫자만 표시. HUD/획득 효과를 월드보다 앞에 표시. 모달은 HUD보다 앞에 둠.
- 토대 앞부분이 건물 밑에 전부 숨지 않도록 지면 그림의 위치 교정. 점유 영역은 변경하지 않음. 길은 기존 64×32 투영의 1칸, 건설된 집 사이 연결만 유지. 흙길 질감은 재제작하지 않음.
- 마을 최저 배율0.641→1.0, 최고1.5 유지. 원본 지형을 화면에 맞춘 1.0 아래로 나가지 않게 하여 회녹색 여백·늘어진 외곽 샘플을 제거. 맵 크기2400×1350 및 이동/건설 영역 유지. 별도 확장 지형 없이 더 넓은 축소는 제공하지 않음.
- 월드맵 타일의 화면 크기 과대 적용과 음수 사각형 반사 렌더링 수정. 기준1672폭에서 타일253.021×133.248로 조정. 반사 변환으로 빈 타일 제거, 승인된 내부 지형 크롭 유지.
- 내 마을 짧은 탭으로 마을 복귀. 10px 이상 드래그와 핀치는 진입하지 않음. 마을 그림과 이름표 재사용.

## 비교 자료

|대상|수정 전|수정 후|
|---|---|---|
|마을 기본|[v35](../2026-11-05-first-refactor/evidence/refactor-village.png)|[v36](evidence/refactor-village.png)|
|월드 축소|[v35](../2026-11-05-first-refactor/evidence/refactor-world-min.png)|[v36](evidence/refactor-world-min.png)|
|월드 확대|[v35](../2026-11-05-first-refactor/evidence/refactor-world-max.png)|[v36](evidence/refactor-world-max.png)|

[Figma 마을](evidence/figma-village.png) · [Figma 월드](evidence/figma-world-min.png) · [최대 축소](evidence/refactor-village-min.png) · [건설 자재 부족](evidence/refactor-build-side-poor.png) · [건설 가능](evidence/refactor-build-side-ready.png) · [미리보기](evidence/refactor-preview.png).

## 주요 에셋

|ID/역할|게임 파일|Figma 출처|
|---|---|---|
|BLD-OUTPOST|`game/assets/refactor-v036/watchtower.png`|886:36|
|UI-MENU-COLLAPSE|`game/assets/refactor-v036/menu-collapse.png`|836:116|
|움집1단계|`game/assets/refactor-v035/hut-stages.png`|957:293 / 1061:476|
|돌 받침|`game/assets/ui/brush/action-stone-base@2x.png`|956:419|
|붓터치 배경|`game/assets/ui/brush/resource-slot-brush@2x.png`|MAT-004 / 3752b|
|기존 아이콘/잠금|`game/assets/figma-latest/023a3.png`, `game/assets/ui/s40000/`|I10000 및956:419|
|월드/토대/길|`game/assets/refactor-v035/`, `game/assets/environment/terrain-isometric-v034.png`|826:110, 1006:424, 956:337|

에셋 ID와 원본 경로는 `game/data/assets.json`, 무결성은 `game/assets/manifest.json`. 다운로드 URL을 런타임에서 사용하지 않는다. 초소는 신규 게임 시스템이 아니라 미개방 메뉴 표시만 제공한다.

## 검증과 한계

- Windows11 / NVIDIA RTX5060 / Godot4.5.1 Compatibility / 1280×720 / 고정60Hz / 별도 테스트 저장 사용.
- 상태·저장343, 마을·건설48, 화면·월드 전환38 검사 통과. 자산148 및 음원16 무결성 통과. 시각 캡처는 자동 검사의 통과와 별개로 직접 비교했다.
- 확인한 핵심: 건설 자재 부족/충족, 미리보기 취소 무지출, 원격 건설, 자원 점유, 저장 이전/중복 철거 방지, 가족 합류, 월드 줌·드래그·내 마을 탭.
- GPS의 전체 월드 전용 렌더링은 보류. 현재 미니맵은 마을 지형 기반이며 월드에서 완전한 지형·카메라 표시와 일치하지 않는다. 후속 작업 필요.
- 추가 답변으로 PC 자원 아이콘의 나무·돌·씨앗 이름 표시를 제거 대상으로 확인하여 반영. 건설 확인 tooltip도 제거했으며 실제 자원 수량은 유지. 추가 제보한 확인 버튼의 흰 사각형은 기본 포커스 스타일이 남아 있던 것으로 확인해 확인/취소 버튼의 포커스와 기본 테두리를 제거했다. 부족 상태 확인은 무지출·건설 차단 검증을 추가했다.
- Figma 산은 기존 지도 크롭+마스크여서 가장자리 및 강 연결이 완전한 독립 에셋 수준은 아니다. 자연스러운 대규모 확장에는 이음새 검증된 타일과 독립 산 PNG가 필요하다. 현재 반복 타일은 기획과 동일한 임시 구조다.
- 움집1단계는 Figma에서도 게임 검증 전 시안으로 명시되어 있다. 적용 가능성은 확인했으나 최종 품질 승인으로 간주하지 않는다. 사이드 이름표는 기존 붓터치 재사용으로 MAT-006의 양끝 대칭과 세부 차이가 남는다.
- 실물 Fold 커버/펼침 터치, 직접 청취, 장시간 성능, Android 전체 플레이는 미검증. APK 설치·업데이트 및 배포 결과는 아래에 추가한다.

## 배포 및 Android 확인

- 버전 0.1.36 / versionCode 37 / 생성일 2026-11-05.
- [구현 PR #64](https://github.com/byungho-cho/roxhistory/pull/64), APK 소스 main `7040fdf545893fc12e1807b3c6a0ffbd0d74db9b`.
- [CI run 72](https://github.com/byungho-cho/roxhistory/actions/runs/42025958891) 성공. 문서 후속 커밋은 APK 소스를 변경하지 않는다.
- APK SHA-256: `07b895512a6e617ccd10a623992ca40552036097b65c04effa2172684bdb5c8e`.
- 기존 `com.roxhistory.demo`와 인증서 SHA-256 `cf65aeecb4e399ba9e2e6b9fa947f34f8c31bd75c8e3b686ad29d8431bb1695f` 유지.
- Android 15 RoxHistory35 AVD, 읽기 전용 임시 세션. v0.1.34에 테스트 저장을 넣고 v0.1.36으로 삭제 없이 업데이트했다. 나무7/돌8/씨앗10, built-8 건물과 수령 상태가 유지됐으며 재실행 후 저장 해시도 동일했다. 원본 AVD 저장은 변경하지 않았다.
- SwiftShader 환경은 이전 버전부터 GL uniform 제한으로 화면 출력이 실패했다. host GPU(NVIDIA RTX5060)로 새 읽기 전용 세션을 실행하여 1280×720 가로 시작 화면 정상 표시를 확인했다. 최초 셰이더 캐시 재컴파일 경고 외 앱 오류는 관찰되지 않았다. 이 결과는 Android 전체 플레이·터치 검증을 뜻하지 않는다.
- [Android 시작 화면](evidence/android-launch.png). 전체 플레이와 디자인 비교 캡처는 위 Windows 실행 결과이며 실물 기기 검증과 구분한다.

[APK 직접 다운로드](https://github.com/byungho-cho/roxhistory/releases/download/v0.1.36/RoxHistory-0.1.36-20261105-212759.apk)
