# v0.1.37 검토본 — 메뉴·지도·구름 전환

기준 main `ed31a1ce6440be893fbefadf1cdee5f628e1e406`. 전용 브랜치 `fix/roxhistory-ui-review-20261105`. 기존 PC 체크아웃의 미커밋 작업과 사용자 저장은 수정하지 않았다. **병합 전 검토본이며 디자인 전체 완료 판정은 아니다.**

## 변경과 비교

기준: [Figma 대표 화면 956:242](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=956-242), HUD 956:419, 귀환 버튼 1024:39. Figma 연결로 실제 화면·하위 에셋·배치 정보를 확인했다. [기준 이미지](evidence/figma-reference.png).

- 하단 메뉴는 아이콘·받침·중앙 라벨을 유지하고 0.22초 이동·페이드로 접고 펼친다. 접힘 상태에서는 건설을 유지한다. 화살표 중심은 고정하고 방향만 반전한다. 연타·화면 회전 시 이전 애니메이션을 정리한다. 빈 메뉴 영역은 지도 입력을 가로채지 않는다.
- 채집·건설 중에도 이름을 `채집`, `건설`로 유지한다. 진행 상태는 기존 진행 표시가 담당한다. 미개방·재료 부족·건설 한도 조건은 유지했다.
- 자원 아래 원형 표식·별도 원형 아이콘·인공 타원 그림자를 제거했다. 나무와 돌 위에 동일한 화면 크기의 이름·잔여 횟수를 표시한다. 소진 시 함께 사라진다.
- 씨앗 보상은 사각 배경 없이 기존 투명 씨앗 PNG를 사용하고, 건물보다 앞인 독립 레이어에 그린다. 수령·중복 방지·저장 규칙은 그대로다.
- 주민 말풍선은 실제 주민 위치와 머리 높이를 기준으로 위에 배치한다. 주인공과 주민 모델은 변경하지 않았다.
- 귀환 버튼은 Figma의 **테두리까지 포함된 전체 컴포넌트**를 사용한다. 지도 그림 위에 갈색 패널과 움집을 덧씌우던 이중 배경을 제거했다. PNG의 사각 내보내기 배경만 런타임 원형 마스크로 제외한다.
- 마을↔월드맵은 구름이 0.36초 동안 덮고 완전히 가려졌을 때 장면을 전환한 뒤 0.44초 동안 걷힌다. 전환 중 중복 클릭·지도 제스처·단축키를 막고 이동·작업을 잠시 정지한다. 별도 구름 이미지가 없어서 두 단계 노이즈의 단일 셰이더로 구현했으며 유료 생성·추가 대형 텍스처는 사용하지 않았다.
- 미니맵은 정적 배경 대신 실제 마을 Canvas 및 같은 월드맵 렌더러를 192×192, 초당 최대 5회로 그린다. 원형 창은 지형을 찌그러뜨리지 않고 중앙을 자른다. 플레이어 점과 카메라 범위는 동일 좌표계로 투영한다. 월드맵에서 위치 버튼을 누르면 월드맵의 내 마을로 재중앙 정렬한다. 실제 장치 GPS 기능은 아니다.
- 마을 최대 확대는 기준 03 장면의 2배, 최소는 기존 1배로 맞췄다. 기존 자연 지형·모서리 구름과 2400×1350 경계·충돌을 유지한다. 길은 기존 64×32 아이소메트릭 1칸 규격을 유지했다.
- 월드맵 마을 폭은 최대 확대 화면의 1/5, 최대 축소 1/12를 유지·검사했다. 지형 밉맵과 필터를 활성화해 축소 시 거친 텍스처 샘플링을 줄였다.

|장면|실행 증거|
|---|---|
|마을 최소 / 최대 확대|[최소](evidence/review-village-min.png) · [최대](evidence/review-village-max.png)|
|접힌 메뉴|[접힘](evidence/review-collapsed.png)|
|건설 재료 부족 / 준비|[부족](evidence/review-construction-poor.png) · [준비](evidence/review-construction-ready.png)|
|씨앗 / 주민|[투명 씨앗](evidence/review-seed-reward.png) · [대화](evidence/review-residents.png)|
|월드맵 최소 / 최대 확대|[최소](evidence/review-world-min.png) · [최대](evidence/review-world-max.png)|
|구름 전환|[덮는 중](evidence/review-clouds-covering.png) · [가려진 상태](evidence/review-clouds-covered.png)|
|세로 화면|[세로](evidence/review-portrait.png)|

## 에셋 출처와 교체 구조

|에셋|경로|출처·규격|
|---|---|---|
|귀환 버튼 전체|`game/assets/ui/review-v037/home-toggle.png`|Figma 1024:39, 84×82 PNG, 원본 여백 유지|
|미니맵 금색 링|`game/assets/ui/review-v037/minimap-ring.png`|Figma 836:101 / HUD 956:419, 182×184 PNG|
|씨앗|`game/assets/refactor-v035/seeds.png`|기존 UI-SEED, Figma 988:39, 원본 1254×1254 RGBA|
|움집·초소|`game/assets/refactor-v035/hut-stages.png`, `game/assets/refactor-v036/watchtower.png`|기존 BLD-HUT-L1 / BLD-OUTPOST 재사용|
|지형·나무·돌·세계 요소|`game/assets/environment/`, `game/assets/refactor-v035/`|기존 catalog의 TERRAIN-VILLAGE / ENV-TREE / ENV-ROCK / WORLD-* 재사용|
|구름 전환|`game/shaders/cloud_transition.gdshader`|코드 기반 시각 효과, 게임 데이터 변경 없음|

`game/data/assets.json`의 UI-HOME-TOGGLE ID로 교체 가능하다. 기존 원화 바이트와 crop/anchor는 보존했다. 새 PNG의 크기·SHA-256은 `game/assets/manifest.json`에 기록했다. 임시 Figma URL은 런타임에 사용하지 않는다.

## 검증

- Windows 11 / RTX 5060 / Godot 4.5.1 Compatibility, 격리 저장 프로필. 상태·저장 **343**, 아이소메트릭·건설 **48**, 기존 흐름 **38**, 이번 UI·구름·미니맵·주민 **45**: 총 **474개 통과**. [상태](evidence/state-tests.json), [지형](evidence/isometric-tests.json), [흐름](evidence/first-refactor-tests.json), [UI](evidence/ui-review-tests.json).
- 실제 채집 접촉 보상, 확인을 통한 건설, 재료 부족 거절, 미리보기 취소, 씨앗 중복 수령 거절, 주민 대화·합류·재로드, 메뉴 연타·세로 재배치, 지도 탭·드래그 구분, 구름 전환 중 중복 입력을 검사했다. 모든 검사가 실물 터치 시험을 뜻하지는 않는다.
- 패키지 에셋 150개와 음원 16개 무결성 통과. 원화는 추가 2개 외 변경하지 않았다.
- Android 0.1.37 / versionCode 38, `com.roxhistory.demo`. 기존 인증서 SHA-256 `cf65aeecb4e399ba9e2e6b9fa947f34f8c31bd75c8e3b686ad29d8431bb1695f`, APK v2/v3 서명 검증 통과. Windows EXE와 APK를 로컬에서 생성했다.
- 별도 `RoxHistory35 -read-only` 에뮬레이터에서 v0.1.36에 **테스트용** 건물·주민·보상 저장을 넣고 v0.1.37로 삭제 없이 업데이트했다. 주 저장·백업 모두 업데이트 전후 SHA-256 `c90d403da60b74b51f4b987e4c2784a463fb0aef069d6d6f4feda26e68b90003` 일치. 원본 AVD 및 기존 실행 세션은 수정하지 않았다.

## 남은 차이와 필요한 자료

- 월드맵 지형은 여전히 마을 배경 중앙을 반복·반사한 임시 재질이다. 산·강·호수의 원화 색감·접지와 반복 패턴은 Figma와 완전히 같다고 판정하지 않는다. 이전 보고서의 타일 노드 1006:424는 현재 파일에서 조회되지 않았다. 최종 교체에는 **좌우·상하 이음 가능한 1024×512 PNG 타일**, 투명 강 연결부와 산 발밑 접지용 **RGBA 512~1024px 레이어**, 공통 밝기·채도와 기준점 명세가 필요하다.
- 신규 주민 원화는 기존 3D 주민의 리그·보행과 바로 교환 가능한 동작 세트로 확인되지 않았다. 현재 `game/assets/characters/residents/female.glb`, `sturdy_male.glb`를 유지했다. 교체용은 기존 발 원점·스케일·방향을 맞춘 GLB/리그/idle·walk 클립, 또는 같은 발 기준점의 투명 방향별 프레임 세트가 필요하다. 정적 크롭만으로 주민 동작을 완성했다고 보고하지 않는다.
- 움집 1단계는 Figma에도 게임 검증 전 시안으로 표시되어 있다. 기존 승인된 에셋 구조를 유지했으며 원화 최종 승인으로 간주하지 않는다. 사이드 이름표는 기존 붓터치 재사용이라 MAT-006 세부 형태 차이가 남는다.
- 구름의 최종 미술 승인, 실물 Fold 커버·펼침 터치, 저사양 GPU 성능·발열·장시간 플레이, 직접 음원 청취는 미검증이다. 미니맵은 중앙 원형 크롭이므로 지도 전체 직사각형의 바깥 구석은 보이지 않는다.
- PR은 draft로 제출하며 사용자 승인 없이 main에 병합하지 않는다. APK는 검토용 빌드로 구분한다.

## 최종 전달 및 기기 검증

- [검토용 APK 다운로드](https://github.com/byungho-cho/roxhistory/releases/download/v0.1.37-review/RoxHistory-0.1.37-review.apk), 208,436,206 bytes. 공개 URL에서 다시 내려받아 SHA-256 `f01736593cc191df01ae8271784a5a19dae85f64676eaeda5ebe8a019c236f20` 일치를 확인했다.
- 빌드 소스: `a865af8de14dbd330673a04221f977ea9310fb31`. 이후 보고서 추가 커밋은 바이너리에 영향을 주지 않는다. [Draft PR #66](https://github.com/byungho-cho/roxhistory/pull/66), main 미병합. 원격 CI 결과는 이 보고서에서 검증하지 않았다.
- 최종 APK 재설치에서도 테스트 저장/백업 파일의 전후 해시가 같았다. [보존 결과](evidence/android-update.json). Android 에뮬레이터에서 이어 하기, 마을 진입, 월드맵 이동과 마을 복귀를 확인했다. [최종 마을 화면](evidence/android-village-final.png), [월드맵 화면](evidence/android-world.png).
- 에뮬레이터 600프레임 표본은 평균 25.44ms, 95백분위 41.8ms였다. 실제 저사양 기기 성능이나 60fps 보장은 검증하지 않았다.
- Windows EXE는 같은 소스로 생성했다. 격리된 테스트 저장 프로필로 PC 프로세스를 실행했으나 최종 전면 창에서 게임 화면을 확인하지 못했다. 자동 실행·렌더 검증과 별개로 최종 EXE의 PC 직접 조작 확인은 미검증이다. 기존 사용자 저장은 변경하지 않았다.