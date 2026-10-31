# C001 원화 기반 3D 주인공·화면 교정 — v0.1.9 검토 빌드

조사·검증일: **2026-10-31 KST**. 상태: **게임 적용·기능 검증 / 외형 품질과 사용자 승인은 미완료**.

## 기준과 범위

- 원본 로컬 저장소의 로드맵 관련 수정·미추적 파일은 보존했다. 별도 작업 복제본의 `feat/c001-character-ui-v019` 브랜치에서 구현·검증했다.
- 기준 코드: main `b545fc36255df98eb164740d0109e05c70b3c1be` → 구현 `53fd8de69704b56680ee4dfcb224f6cf124d83df`.
- [PR #19](https://github.com/byungho-cho/roxhistory/pull/19). 문서 후속 커밋은 같은 game 트리를 유지한다.
- 최우선 원화: [C001 v0.3 / Figma 196:11](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=196-11), 실제 삽입 이미지 `198:868`. [원본](evidence/c001-v03-authoritative.png).
- UI: [110:352](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=110-352)의 첫 실행·시작·터전·플레이 화면. 기존 나무·움집·2D 배경은 교체하지 않았다.
- 이전 시험 조형은 승인된 최종 모델이 아니다. 이 보고서는 초기 ‘미적용’ 기록을 현재의 검토 빌드 상태로 현행화한다. [요청 원문](brief.md).

## 실제 적용

갈색 머리의 앞·옆·뒤 흐름과 불규칙한 끝선을 별도 입체 조형으로 수정했다. 얼굴·몸통은 연속 단면, 팔·다리는 스킨 가중치로 연결했다. 갈색 가죽·밝은 비대칭 털 장식·허리끈·손목 보호대·발목 장식·신발을 적용하고 UV 재질 텍스처를 만들었다. 초상화는 이 모델의 실제 렌더다.

15개 뼈대의 대기·걷기·채집·건설을 유지·보완했다. 실제 이동 거리로 보폭을 계산하고, 작업 접촉 프레임에서 도구·파편·소리를 함께 처리한다. 돌 작업은 나무보다 낮은 팔 자세와 다른 손목 각도를 사용한다. 새 체형 때문에 벗어난 접점을 작업 자세를 수정해 맞췄으며 검사를 완화하지 않았다.

첫 실행은 암각화 패널·움집 로고·두 소리 선택 버튼, 시작 화면은 오른쪽 세 버튼·상단 소리·장 표시, 터전은 금색 선택·어두운 미선택·상세 패널로 교정했다. 지역 표식은 기존 215×72/230×88의 80%, 동삼동은 기존 폭215의40%인86 UI 단위 왼쪽으로 이동하고 세로 위치는 유지했다.

플레이 HUD는 좌측 초상화/이름/상태바, 우측 네 자원칸/원형 지도, 하단 사냥·채집·제작·건설과 두루마리·가방, ‘움막을 지어라’ 목표 상자로 바꿨다. 핀치에서 새 UI의 터치 소유권도 제외한다. 지도는 기존 월드 지형과 실제 플레이어 위치를 연결하며, 정지 중에는 다시 그리지 않는다.

| 표시 | 실제 연결 |
| --- | --- |
| 나무·돌 | 실제 재고·지급·저장과 연결 |
| 퀘스트 | 나무1·돌1, 건설·보상 상태와 연결 |
| 지도 점 | 실제 월드 좌표와 연결; 길찾기/지도 탐색 기능은 추가하지 않음 |
| 레벨·상태바 | `Lv.—`, `— / —`로 미연결 표시. 성장·에너지 소비 규칙 없음; 색 막대는 시안 배치용 |
| 고기·열매 | `—`로 미구현 표시 |
| 사냥·제작 | 준비 중 안내만 표시; 전투·제작 시스템 없음 |
| 가방 | 현재 나무·돌·완료 씨앗 요약; 신규 인벤토리 시스템 아님 |

앱 아이콘은 사용자가 준 움집 이미지다. 강물 전용 볼륨 범위만 `-30…-20 dB`에서 `-36.0206…-26.0206 dB`로 변경하여 진폭을약50%로 낮췄다. 강물 음원 파일·바람·다른 효과음·마스터는 유지했다. 이 수치는 체감 음량이 정확히 절반이라는 뜻은 아니다.

## 비교 이미지와 영상

아래 native 비교는 같은1280×720, 플레이어(1060,1030), 기본1×/확대2×, 동일 카메라 대기60프레임 조건이다. 이전 main을 별도 읽기용 작업 트리에서 실행했다.

| 장면 | 이전 v0.1.8 | 현재 v0.1.9 |
| --- | --- | --- |
| 첫 실행 | [이전](evidence/before/onboarding.png) | [현재](evidence/after/onboarding.png) |
| 시작 | [이전](evidence/before/title.png) | [현재](evidence/after/title.png) |
| 터전 | [이전](evidence/before/region.png) | [현재](evidence/after/region.png) |
| 기본 플레이 | [이전](evidence/before/play.png) | [현재](evidence/after/play.png) |
| 확대 | [이전](evidence/before/zoom.png) | [현재](evidence/after/zoom.png) |

- [원화/모델 네 방향 대조](../../../assets/characters/c001/source/c001-reference-comparison.png): 위 원화, 아래 실제 모델. 전체 높이를 비슷하게 배치했으며 신체 비율 차이는 숨기지 않았다.
- [정면·사선·측면·후면 모델](../../../assets/characters/c001/source/c001-study-04.png).
- [Android 전체 루프 원속도 영상](evidence/clips/android-loop.mp4): 앞35초에 이동·나무·돌·건설·보상, 이후 종료·이어하기. 실제 터치이며 이동 경로 측정을 위한 일시정지 창이 잠깐 포함된다.
- [Android 확대·방향·복귀 원속도 영상](evidence/clips/android-controls.mp4): 초반 핀치, 이어서8방향 이동, 후반 입력 충돌·HOME 전환. 마지막 핀치 중 HOME 시험은 아래 런처 ANR 때문에 통과로 판정하지 않았다.
- [Android 같은 위치 이전](evidence/android/android-0.1.8-scene-matched.png) / [현재](evidence/android/android-0.1.9-c001-matched.png).
- [강물 포함 환경음 이전](evidence/audio/audio-0.1.8-scene.wav) / [현재](evidence/audio/audio-0.1.9-c001.wav). 같은 좌표·미디어15/15의 Android playback PCM 녹음이며 바람도 포함한다.

## 검증 결과

구현 기준은 위 소스 커밋의 game 트리 `92ddfaf085b11e5cbdc5f74d546815cdbe60a5f5`다. 로그의 시각은 UTC이며 KST는+9시간이다. 관련 검사는 마지막 수정 후 다시 실행했다. [로컬 상세 결과](evidence/validation/)를 함께 제공한다.

- 에셋61개 크기·SHA-256, 음원12개 무결성/출처 검사 통과. Godot4.5.1 임포트 성공.
- Native Godot/Windows/RTX5060: **985건 통과**. 상태345, 환경17, 화면·합성 입력101, 환경 이동·가림13, 캐릭터68, 혼합30, 혼합 가림13, polish62, 상호작용27, presentation53, hero51, 핀치·플레이45, 채집 접점160.
- GLB 재임포트: skeleton1/뼈15, idle/walk/gather/build 네 클립 재생·seek 성공. [로그](evidence/validation/glb-validate.log).
- Android15/API35 x86_64 에뮬레이터, 호스트 RTX5060, 물리1280×720/게임960×540. 기존 서명으로 `install -r` 성공, 일반 save.json 동일성 확인.
- 새 게임→나무1→돌1→건설→보상1회→종료·이어하기 통과. 측정한 실제 핵심 루프 **31.43초**(첫 안내·재시작 시간 제외). 중복탭, 팝업/뒤로가기, HOME복귀, 입력 해제, legacy2D=false에도3D표시 확인. [루프 결과](evidence/validation/android-loop.json).
- 실제 Android MotionEvent 두 손가락 핀치와 조이스틱/UI 소유권, 재고 보존을 확인했다. 일반 HOME 복귀와 이동은 전체 루프에서 확인했다. [입력 결과](evidence/validation/android-controls.json).
- 현재 안전 영역에 맞는 버튼 중심을 사용해 [임무창 열기](evidence/android/android-journal.png) → [Android 뒤로 닫기](evidence/android/android-journal-closed.png) → 일반 HOME 복귀 후 실제 이동을 별도로 확인했다. [결과](evidence/validation/android-popup-resume.json).
- 같은 조건600프레임: v0.1.8 평균65.932ms/p9575.868ms, v0.1.9 평균66.936ms/p9575.331ms. 평균 차이 +1.52%. 두 버전 모두 약15fps여서 부드러운 실기기 성능을 입증하지 않는다. [측정과 조건](evidence/validation/android-comparison.json).
- 녹음 RMS는0.001973→0.001157(환경음 전체 약58.6%). 강물만50%이고 바람이 유지되어 전체 녹음 비율은 다르다. 음소거·백그라운드는0, 복귀는 정상. **스피커·헤드폰 직접 청취는 수행하지 못했으며 출력 장치 청감 미검증**이다.
- 화면 비율은 에뮬레이터 크기 변경으로 확인했다: [커버](evidence/android/android-cover.png), [펼침](evidence/android/android-unfolded.png), [Android 아이콘 마스크](evidence/android/android-icon-mask.png). 실제 폴드/휴대폰·다른GPU·장시간 발열은 미검증.
- **두 손가락 강제 입력 중 HOME 전환은 통합 검증 미완료다.** 입력 주입이 화면 전환 뒤에도 이어지는 시험에서 Pixel Launcher의 swipe-up 제스처 감시기에 ANR이 발생했다. [실제 오류 화면](evidence/android/android-launcher-anr.png)과 [Android 원인 기록](evidence/validation/launcher-anr.txt)을 남겼으며 통과 항목에서 제외했다. RoxHistory 충돌로 단정하지 않는다. 런처 오류 창을 닫은 뒤 성능·음향을 별도로 재측정했다. 실기기에서 실제 손가락으로 전환을 재검증해야 한다.
- 검증 도구의 고정 복귀 대기와 이전 UI 좌표 때문에 이동 확인이 실패한 시도가 있었다. 게임 코드의 오류로 단정하지 않고 실제 Android 터치 수신을 기다리며 현재 버튼 위치를 사용하도록 검증 절차를 수정했다. 최종 결과와 실패 원인 검토를 구분한다.
- 원격 CI: 초기 [run #34](https://github.com/byungho-cho/roxhistory/actions/runs/41191532352)는 llvmpipe 렌더 제한150초로 중단됐다. 곡면 세분화를 줄여 GLB 약12MB→4MB로 개선했고, 검사·시간 조건은 유지했다. [모델 수정본 run #35](https://github.com/byungho-cho/roxhistory/actions/runs/41192430878)는 코드832b68f 기준985건·Android 빌드·서명 검증이 성공했다(2026-10-31 19:22~19:34 KST). [집계](evidence/validation/ci35.json). 이후 완료 퀘스트의 아이콘·문구 겹침을 수정한 최종 HEAD 결과는 PR와 릴리스 기록을 참조한다. 로컬 검사와 원격 검사를 혼동하지 않는다.

## 외형·화면 품질 판단과 남은 문제

**원화 재현 완료로 판정하지 않는다.** 같은 크기 대조에서 지나치게 큰 머리·짧은 팔다리를 재수정했고, 몸통·무릎·팔꿈치 단면과 채집 시 굽히는 자세를 함께 조정했다. 다만 원화보다 얼굴·손·신발과 옷 장식이 단순한 인상은 남아 있다. 앞머리·묶은 머리의 겹침은 개선했으나 원화의 풍성한 실루엣과 작은 붓질 표현, 털과 가죽의 불규칙한 겹침·주름·매듭은 아직 단순하다. 신발과 손도 원화보다 둥글고 단순하다. 별도 헤어/옷 시뮬레이션과 얼굴 표정 리깅은 없다. 초상화는 일치하지만 원화의 인상 재현과는 별도다.

UI는 배치·색·아이콘·정보 순서를 교정했으나 패널의 투명도·모서리·질감·서체 굵기까지 픽셀 단위 일치한 것은 아니다. 버튼 글자 중복과 HUD 매프레임 재그리기, 완료 퀘스트의 아이콘·문구 겹침을 시각/자동 검사에서 발견해 수정했다. 미연결 상태바의 장식적 의미는 사용자 검토 대상이다.

작은 플레이 크기의 구분, 기능 검증, 외형 제작, 사용자 품질 승인은 별도다. 다음 단계는 현재 네 방향 비교를 기준으로 비율·털·머리의 조형을 더 정교하게 다듬고 실제 기기에서 검토하는 것이다. 주민·동물·새 지역·전투는 착수하지 않았다.

## 제작 원본·권리·전달

[모델 자산 안내](../../../assets/characters/c001/README.md), [GLB](../../../assets/characters/c001/source/c001-rigged.glb), [편집 소스](../../../assets/characters/c001/source/), [재질 텍스처](../../../assets/characters/c001/source/textures/). Godot 절차식 메시 제작 원본이며 Blender 원본이라고 표기하지 않는다. 게임은 동일 모델 생성 코드와 실시간 동작을 사용하고, GLB는 해당 메시·리그·베이크한4클립을 교환 가능한 형태로 제공한다.

형상·UV 재질·동작은 기존 RoxHistory 코드와 이번 작성 코드로 제작했다. 원화·배경·아이콘은 프로젝트 소유자가 제공한 Figma/첨부 자료를 재사용했다. 제3자 공개 라이선스를 새로 부여하거나 권리를 주장하지 않는다. 강물 원음의 기존 CC0 출처는 유지하며 새 음원은 추가하지 않았다.

앱`0.1.9-c001`/코드10, `com.roxhistory.demo`, 서명된 debug APK. 크기 **96,963,524bytes**, SHA-256 `f20b92c5ca1df0b8b1ab8bbd2dc48c5ef01bc837ac22aac3c307505e3fade608`. 서명 인증서SHA-256 `cf65aeecb4e399ba9e2e6b9fa947f34f8c31bd75c8e3b686ad29d8431bb1695f`로 v0.1.8과 동일하다. [빌드 정보](evidence/validation/build.json).

[APK 단일 파일 직접 다운로드](https://github.com/byungho-cho/roxhistory/releases/download/v0.1.9-c001/RoxHistory-0.1.9-c001-debug.apk). 원격 임시 서명 URL을 복사하지 않고 이 영구 Release 경로를 사용한다. 소스·로그 ZIP을 APK 대신 전달하지 않는다.

[FigJam 상태 카드](evidence/figjam-status.png)는 구현 검증과 외형 미승인, 실기기·청감 미검증을 구분한다. PDF는 만들지 않았다.
