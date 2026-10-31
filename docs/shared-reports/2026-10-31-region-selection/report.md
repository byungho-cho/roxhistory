# Meshy 주인공과 첫 터전 선택 v0.1.10

작업일: 2026-10-31~2026-11-01 KST. 상태: 로컬 기능·Android 에뮬레이터 검증 완료 / 사용자 외형 승인·실기기 검증은 후속.

## 범위와 기준

사용자 제공 Meshy 모델 두 개를 비교하고 01을 실제 3D 주인공으로 적용했다. 첫 터전 선택은 [A300](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=208-541), [A303](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=219-1031), [I100](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=226-6)을 기준으로 구현했다. A303의 세로 행을 앱의 첫 화면으로 사용하지 않는다.

원래 로컬 저장소의 미반영 변경은 건드리지 않고 `76f9419098a2db46245c107cb9820f068f36a4db`에서 분기한 별도 체크아웃/작업 브랜치를 사용했다. 기존 강변 배경·다른 화면·저장 구조·소리는 보존했다. 전곡리·동삼동의 신규 플레이 맵, 사냥·낚시·요리는 추가하지 않았다.

## 주인공 모델

- 동일한 조명에서 두 원본을 정면·사선·후면으로 비교했다. 01의 따뜻하고 무광에 가까운 피부·가죽이 현재 배경에 더 잘 맞아 선택했다. 두 모델 모두 1,745,859삼각형이고 리그·동작 클립이 없었으며, 동일한 메시라는 뜻은 아니다.
- 원본의 얼굴·눈·자연스러운 머리 실루엣·통통한 체형·의상을 재사용했다. 60,000삼각형으로 최적화하고 15본 리그와 표면 가중치를 만들었다. 팔·몸통 또는 다리·손 사이의 가중치 튐은 표면 연결 기반 평활화로 수정했다.
- 거칠기 0.92, 스페큘러 0.12, 노멀 강도 0.22와 기존 따뜻한 조명을 사용했다. 모바일 임포트는 2,048px·밉맵·GPU 압축을 적용했다. 얼굴을 새 그림으로 덮거나 평면 캐릭터로 바꾸지 않았다.
- 기존 걷기·회전·대기·채집·건설 동작을 실제 관절로 연결하고 도구를 오른손 뼈에 부착했다. 새 골격의 관절 방향과 다리 길이를 반영했다. 초상화도 게임에서 사용한 모델로 다시 렌더했다.
- 편집 원본: [BLEND와 제작 절차](../../../art-source/meshy01/README.md), [입력 해시·관절 기록](../../../art-source/meshy01/model-provenance.json), [재현 스크립트](../../../tools/prepare_meshy_hero.py).
- 사용자가 제공한 Meshy 결과물이다. 제작 계정의 플랜별 이용 조건·상용 권한은 독립적으로 확인하지 않았다. 얼굴 표정·눈 깜박임·개별 손가락 리그는 아직 없다.

## 지도 조작과 실제 지원 상태

- 진입은 대한민국 지도를 모두 보여주는 최소 배율이다. 지도와 표식은 같은 좌표 변환을 쓰고, 상단 UI·우측 패널·복원 버튼은 고정한다. 해역/제주 글자, 배율 숫자, ±와 ‘전체 보기’ 글자 버튼은 없다.
- 한 손가락 이동, 두 손가락 중심 기준 연속 확대·축소(1~2배), 이동 경계, 탭/드래그 구분, UI에서 시작한 손가락의 소유권을 처리했다.
- 아이콘 또는 이름 선택 시 0.6초 이동·확대와 선택/상세 정보 갱신. 빠른 재선택은 기존 전환을 취소한다. 복원은 0.5초이며 선택과 상세 정보는 유지한다.
- Android 안전 영역에서 제목/뒤로가기, 복원/안내가 겹치지 않도록 묶어서 배치했다. 가로로 긴 화면은 상세 패널 크기를 별도로 보정한다. 지도 가장자리 픽셀을 길게 늘이는 표현을 제거했다.
- 암사동만 기존 데모로 시작할 수 있다. 나머지 두 지역은 선택·정보·확대가 가능하지만 시작은 ‘준비 중’이며 암사동으로 몰래 진입하지 않는다.

| 지역 | 상징 | 기본 세 자원 다음 네 번째 먹거리 | 플레이 |
| --- | --- | --- | --- |
| 전곡리 | 주먹도끼 | 고기 | 준비 중 |
| 암사동 | 빗살무늬토기 | 도토리 | 기존 데모 지원 |
| 동삼동 | 길쭉한 홍합 | 홍합 | 준비 중 |

하단 네 아이콘은 지역 생활 소개이며 보유 수량이 아니다. 전곡리 고기는 일반적인 구석기 사냥 생활의 게임적 재구성으로 특정 출토 동물이나 독점 특산품이라고 표시하지 않는다. 암사동 도토리는 탄화 도토리 기록, 동삼동 홍합은 식용 어패류 자료에 따른 I100 선정이다.

고증 기준: [전곡선사박물관](https://jgpm.ggcf.kr/leaflet/index.html), [암사동 관련 역사 자료](https://contents.history.go.kr/mobile/kc/view.do?levelId=kc_r000400), [동삼동패총 전시](https://museum.busan.go.kr/dongsam/dsexhib2th). 원문을 새로 발굴 조사한 것이 아니라 지정된 [I100 고증 메모](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=239-41)를 적용했다.

## 검증 기록

검증 소스: `e66ad3e00dab33f7fea938dc2f71b3a7907baa0b` (game 트리 `8605b8060eed6ff0ce9e8684d44205b084654609`). Windows / Godot 4.5.1 / Android 15 API 35 x86_64 / RTX 5060 호스트. 현재 임시 에뮬레이터는 원본 AVD 읽기 전용, 4GB·4코어, 기본 1280×720이다.

| 구분 | 실행 시각(KST) | 결과 / 근거 |
| --- | --- | --- |
| 에셋·음원 | 10월 31일 | [에셋 75개 크기·SHA](evidence/checks/assets.log), [음원 12검사](evidence/checks/audio.log) 통과 |
| Native 회귀 | 10월 31일 22:33 종료 | [1,056검사](evidence/checks/native-tests.log) 통과. 상태·입력·환경·가림·캐릭터·접촉·지도 포함 |
| Android 지도 | 10월 31일 22:49 | [14항목](evidence/checks/android-region-tests.json) 통과. 실제 탭·드래그와 Android 두 포인터 MotionEvent 입력 |
| Android 전체 플레이 | 11월 1일 06:24 | [11항목](evidence/checks/android-loop.json) 통과. 새 게임→나무1→돌1→건설→보상10 한 번→종료/이어하기, 팝업/뒤로가기·HOME 복귀 후 이동·일반 저장 보존 |

이번 전체 루프는 지역 진입 후 보상까지 27.91초였다. 자동 입력·중간 상태 확인이 포함된 재현 시간이며 사람이 처음 플레이하는 시간이나 속도 경쟁 지표가 아니다. 이전 저장의 2D 비교 설정을 넣어도 실제 3D가 표시됐다. 일반 저장은 수정하지 않고 별도 테스트 슬롯만 사용했다. 검증 도구의 빈 저장 비교 파일 생성 누락은 수정 후 전체 흐름을 다시 실행해 통과했다.

성능: 이전의 장시간 실행된 2GB 에뮬레이터에서 동일 위치(1060,1030), 1280×720, 녹화 없이 준비 60프레임 뒤 600프레임 측정 시 [v0.1.9 평균 114.713ms](evidence/checks/perf-v019-current.json), [이번 버전 113.971ms](evidence/checks/profile-modes.json)였다. 이 환경에서는 둘 다 낮은 성능으로, 차이를 유의미한 개선으로 주장하지 않는다. 해당 세션에서 System UI ANR도 발생해 원본 저장을 보존하고 읽기 전용 콜드 부팅으로 복구했다. 새 4GB 환경의 플레이 결과와 이 측정을 직접 비교하지 않는다. 실기기 성능 승인 근거가 아니다.

11월 1일 06:26 KST 콜드 부팅 4GB 환경에서 같은 위치·해상도·600프레임 조건으로 이번 버전을 다시 측정했다. [평균 16.671ms(약 60fps), p95 20.918ms](evidence/checks/perf-cold-4gb.json). 녹화·다른 렌더 작업 없이 실행했다. 이는 환경 복구 후 현재 실행 가능성 확인이며 이전 2GB 수치 대비 코드 최적화율이 아니다.

데모 밸런스는 나무 1 + 돌 1, 종류별 1회 채집, 채집 1.2초·건설 2초를 유지한다. 정상 저장과 별도인 테스트 세션을 사용한다. 실제 기기·실제 폴드 힌지/컷아웃·장시간 발열·직접 출력 장치 청취는 미검증이다.

## 비교와 영상

- [지도 최초 전체 보기](evidence/screenshots/android-region-overview.png)
- [전곡리](evidence/screenshots/android-region-jeongok.png) · [암사동](evidence/screenshots/android-region-amsa.png) · [동삼동](evidence/screenshots/android-region-dongsam.png): 선택·확대 후 상세 패널과 지역 먹거리.
- [핀치](evidence/screenshots/android-region-pinch.png) · [복원](evidence/screenshots/android-region-restored.png): 선택 상태 유지.
- [커버 비율](evidence/screenshots/android-region-cover.png) · [펼침 비율](evidence/screenshots/android-region-unfolded.png): 에뮬레이터 해상도 변경 검증이며 실제 폴드 장치가 아니다.
- [정면 확대](evidence/screenshots/play-front.png) · [측면](evidence/screenshots/play-side.png) · [후면](evidence/screenshots/play-back.png): Native 실제 엔진 렌더.
- [Android 나무 획득](evidence/screenshots/android-wood.png) · [돌 획득](evidence/screenshots/android-stone.png) · [완공·보상](evidence/screenshots/android-completed.png) · [종료 후 이어하기](evidence/screenshots/android-continued.png).

### 같은 구도 전후 비교

Native 1280×720, 위치 (1060,1030), 기본/2배 카메라, 같은 캡처 스크립트. 물·식생의 시간 위상은 고정하지 않았다.

| 구도 | 이전 v0.1.9 | 이번 v0.1.10 |
| --- | --- | --- |
| 기본 플레이 | [이전](evidence/screenshots/before-play.png) | [이후](evidence/screenshots/after-play.png) |
| 2배 확대 | [이전](evidence/screenshots/before-zoom.png) | [이후](evidence/screenshots/after-zoom.png) |
| 첫 터전 | [이전](evidence/screenshots/before-region.png) | [이후](evidence/screenshots/after-region.png) |

### 실제 Android 원속도 영상

- [지역 선택·핀치·복원 24초](evidence/clips/region-selection.mp4): 약 2초 전곡리, 6초 암사동, 10초 동삼동, 13~20초 핀치·이동·복원. 선택 상세 유지와 표식 움직임을 본다. 지도 조작 영상은 무음.
- [이동·채집·건설·보상 28초](evidence/clips/gameplay-short.mp4): 새 테스트 세션에서 나무·돌 각 1회와 건설을 이어간다. Android 재생 오디오를 포함하며 실제 출력 장치 청취 검증을 뜻하지 않는다. 상태 확인을 위해 일시적으로 메뉴를 여는 장면이 있다.

자동 검사 통과는 외형에 대한 사용자 승인과 구분한다.

## 남은 품질 항목

주인공 얼굴 표정·손가락·극단적인 자세의 의상 변형, 사용자 외형 검토, Android 실기기 성능과 실제 폴드 조작은 후속이다. 주민·동물과 전체 3D 배경 전환은 이번 범위가 아니다. 게임 전체 또는 베타 완료로 판정하지 않는다.

## 원격 반영과 APK

- [PR #20](https://github.com/byungho-cho/roxhistory/pull/20): 최신 커밋의 CI 결과·병합 여부와 병합 SHA를 확인한다. [검사 목록](https://github.com/byungho-cho/roxhistory/pull/20/checks).
- [v0.1.10-region 배포](https://github.com/byungho-cho/roxhistory/releases/tag/v0.1.10-region): 병합 후 main에서 재빌드한 APK의 기준 커밋·SHA-256·크기·최종 설치 결과를 기록하는 배포 원장이다. 이 문서 작성 시점의 후보 APK를 최종 파일로 단정하지 않는다.
- 최종 배포 파일명은 `RoxHistory-0.1.10-region-debug.apk`이며 소스/로그 ZIP과 구분한다. Release 파일만 기존 개발 서명으로 제공한다. CI 검사용 APK의 임시 서명과 구분해야 한다.
- 기존 배포 인증서 SHA-256: `cf65aeecb4e399ba9e2e6b9fa947f34f8c31bd75c8e3b686ad29d8431bb1695f`. 후보 APK의 v2/v3 서명과 업데이트 설치는 확인했다. 최종 main 빌드도 동일 인증서를 재확인한다.

### 원격 검사 제한 시간 보완

11월 1일 첫 원격 실행 [#38](https://github.com/byungho-cho/roxhistory/actions/runs/41243744696)은 채집 접촉 검사에서 300초 제한(exit 124)에 도달했다. 그 이전 상태·화면·캐릭터·가림·상호작용·UI 검사는 통과했다. Ubuntu llvmpipe 소프트웨어 렌더링에서 실제 스킨 메시를 그리는 26개 접근 사례가 대상이다. 사례·단정 조건·60fps 시뮬레이션·게임 타이머를 바꾸지 않고 해당 프로세스의 벽시계 제한만 900초로 조정하고 전체 작업 한도를 35분으로 확보했다. 동일 실패를 단순 재시도하지 않고 이 변경 커밋에서 전체 CI를 실행한다. 최종 성공 여부와 기준 커밋은 PR의 최신 검사 기록을 따른다.
