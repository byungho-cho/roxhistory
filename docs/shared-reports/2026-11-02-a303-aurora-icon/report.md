# A303 금빛 오로라 B·채택 앱 아이콘·선택음 회귀 수정

조사·개발일: 2026-11-02 KST. 버전 `0.1.17-aurora-icon` / versionCode 18.

## 인수와 반영 범위

- 착수 main: `6b07809fdf83860f67e5bd440bfef227f74a8a18`.
- PR #31은 Draft·미병합, HEAD `b578cffab38fb435b6d96a808d95748372a5c206`. 이 커밋에서 새 브랜치를 만들었으며 음악·PCM 반복 경계 보완·원본과 이전 APK를 그대로 보존했다.
- 구현 커밋: `0e9b67695e1b1d4e309a22fe28b371921474d6f7`. [PR #32](https://github.com/byungho-cho/roxhistory/pull/32)는 #31의 변경을 포함하는 통합 PR이다. #32 병합 뒤 #31도 GitHub에서 merged 상태로 확인됐다.
- 채택 B안은 아이콘 뒤에서 흐르는 금빛 커튼, 짧은 바닥 링 확산, 작은 빛 입자로 구현했다. 효과는 지도 좌표를 따라가며 입력을 가로채지 않고 앱 중단 시 멈춘다.
- 이전 코드의 선택 120%·기본 100%를 최신 명시 기준인 **110%·90%**로 교정했다. 바닥 기준점·고정 지도·수동 핀치·배경 탭 팝업 닫기를 유지한다.
- [Figma 채택 B안 보드](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=414-8)에 기존 원본을 재사용한 편집 가능한 화면과 기본·선택 순간·선택 유지 상태를 추가했다. 이전 `387:8` 시안은 보존했다. 오로라 편집 원본은 `414:209`, 게임 구현은 `game/shaders/region_aurora.gdshader`이다. 정지 Figma 시안과 엔진의 시간에 따른 흐름은 구분한다.

## 앱 아이콘 원본과 설치

채택 원본: [시대의 개척자](../../../design/app-icon/selected/roxhistory-app-icon-selected-v001.png)는 별도 파일로 게임에 복사하여 사용했다. 원본 1254×1254의 색·구도·해상도를 바꾸거나 회색 여백을 추가하지 않았다.

- 원본/게임 복사본 SHA-256: `62eee2ff9c5fe4976a1fa12ca6059299248bc711d9799c97b31cad80e91d4e80`.
- 게임 파일: `game/assets/app-icon-pioneer.png`; `project.godot`의 아이콘 참조를 교체했다.
- Godot 4.5.1 Android exporter는 프로젝트 아이콘을 legacy 및 adaptive foreground의 기본 원본으로 사용한다. APK 내부와 설치 리소스로 확인하며, Figma 보드 스크린샷을 잘라 쓰지 않는다.
- v001/v002/v003 다른 시안, 프롬프트·manifest, 기존 움집 아이콘 모두 보존했다. 출처·채택 기록은 [선정 기록](../../../design/app-icon/selected/README.md)과 [Figma 아이콘](https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS?node-id=402-120)을 따른다.
- 패키지: `com.roxhistory.demo`. 인증서 SHA-256: `cf65aeecb4e399ba9e2e6b9fa947f34f8c31bd75c8e3b686ad29d8431bb1695f` (기존 배포와 동일).

## FOLLOW-001: 원인과 수정

이전 [CI #47](https://github.com/byungho-cho/roxhistory/actions/runs/41356008927)의 실패를 화면 갱신마다 12ms를 추가하는 방법으로 재현했다. 원래 통합 검사는 18회 지역 선택이 모두 75ms 안에 끝난다고 가정하여 정확히 한 번의 선택음만 기대했다. 느린 렌더링 환경에서는 실제 경과 시간이 제한을 넘어 다음 음이 정상 허용되어 실패한다. 일반 UI음 중복 연결이 이 실패의 직접 원인은 아니었다.

동시에 75ms 간격으로 허용되는 약 250ms짜리 선택음의 꼬리가 여러 슬롯에 쌓일 수 있음을 확인했다. UI/선택음은 새 유효 음이 시작될 때 이전 인터페이스 음을 정리하여 **한 음성만 활성화**한다. 작업·새소리 슬롯은 이 정리의 대상이 아니다.

검사는 삭제하지 않았다. 시계 주입으로 같은 순간의 18회 입력→정확히 한 번, 74ms 거절, 75ms 허용, 일반 UI음 중복 부재, 이전 음 교체를 명확히 검사한다. 실제 화면 통합 검사는 측정된 경과 시간에 따른 허용 상한과 마지막 지역·단일 음성 상태를 검증한다.

| 조건 | 결과 |
| --- | --- |
| 이전 코드·정상 속도 | 26개 통과 |
| 이전 코드·선택마다 12ms 지연 | 해당 1건 실패 재현 |
| 수정 코드·정상 속도 | 33개 통과 |
| 수정 코드·선택마다 12ms 지연 | 33개 통과 |

[수정 전 재현](evidence/audio-slow-before.log), [수정 후 재현](evidence/audio-slow-after.log). CI에서도 같은 지연 경로를 실행한다. 이 검사는 청감 승인을 대신하지 않는다.

## 로컬 검사

Windows / Godot 4.5.1 / 1280×720 실제 렌더링, 2026-11-02 10:27~10:29 KST. 구현 커밋과 동일한 게임 파일 기준이다.

| 검사 | 통과 |
| --- | ---: |
| 상태 | 345 |
| 화면·합성 입력 | 93 |
| 지역 조작 | 82 |
| A303 아트 | 157 |
| 선택 효과 | 36 |
| 지도 환경 | 88 |
| 팝업 전환 | 18 |
| 신규 오로라 | 23 |
| 표현·음향 상태 | 56 |
| A303 오디오 | 33 |
| 합계 | **931** |

별도로 에셋 108개 SHA-256/크기, 음원 15개 검사를 통과했다. 게임 저장·데모 조건은 변경하지 않았다.

## Android·원격 CI·최종 전달

원격 [CI #48](https://github.com/byungho-cho/roxhistory/actions/runs/41373185731)은 **성공**했다. Ubuntu 24.04 / Godot 4.5.1 / llvmpipe에서 2026-11-02 10:35~10:48 KST에 **1,423개 검사**를 통과하고 Android APK를 빌드했다. 기준 SHA는 구현 커밋 `0e9b67695e1b1d4e309a22fe28b371921474d6f7`이다. [검사별 원격 결과](evidence/ci-checks.json)를 보존했다. 이전 실패 항목은 33개 오디오 검사 중 제어 시계·지연 통합 경로로 재검증되었다.

CI APK는 임시 키이며, 사용자 전달 APK는 기존 로컬 인증서로 서명한 파일이다. 설치·실행·아이콘·오디오 반복 결과는 최종 증거에 구분해 기록한다.

## 남은 범위

- 실물 Android/폴드 커버·펼침 화면, 실제 스피커·이어폰 청취 승인은 별도다.
- 이번 작업에서 새 게임 전체 채집·건설·보상 흐름을 Android에서 다시 완주하지 않았다. 상태·합성 입력 회귀 검사와 저장 보존 검사를 구분한다.
- Figma의 주요 활동 보조 문구는 현재 게임 패널에 별도 행으로 표시되지 않는 기존 차이로 남는다. 지역 특징·제목·시대·4개 자원 및 시작 가능 상태는 유지한다.
- 오로라의 강도·색감은 실제 APK 사용자 검토 대상이며, 자동 검사 통과를 시각적 최종 승인으로 표시하지 않는다.

## 최종 설치·실행 결과

- 병합 main: `d6b23163eab3e32b49faa50a9b2d28c52ef4a394`. 테스트한 개발 SHA와 게임 트리 `ec7959c6bf253dcf1f5688e8a6efd990cd5368d3`가 동일함을 확인하고 main에서 최종 APK를 다시 빌드했다.
- Android 15/API35 x86_64, `RoxHistoryP3` 에뮬레이터, host GPU, 게임 1280×720 / 런처 720×1280. 물리 기기 검증은 아니다.
- 9개 Android 조작·오디오 항목 통과: 세 지역·고정 지도, 빠른 18회 터치, 배경 탭 닫기/재선택, 실제 두 손가락 확대·복원, 음악 자연 반복, Home/복귀, 음소거/복원, 저장 파일 유지. [상태·시각 기록](evidence/android-checks.json), [실제 입력 시각](evidence/rapid-timing.txt).
- 빠른 선택 구간의 Android 이벤트 로그에는 추가 선택음 13개와 일반 UI음 0개가 기록됐다. 입력 18회의 첫/마지막 시각 차이는 1.053초이며, 75ms 제한의 경과 시간 상한 안이다. 같은 순간의 18개 입력은 별도 제어 시계 검사에서 정확히 1개 음으로 검증했다.
- 64.94초 실제 내부 오디오·화면 녹화에서 음악 위치가 51.43초 끝을 지나 돌아오며 재생을 지속했다. 스크립트/Android 런타임 오류 없음. AAC 48kHz 스테레오 출력은 평균 -27.8dBFS, 최대 -13.5dBFS로 검출됐다. 이는 음색·겹침에 대한 사람의 청취 승인과 다르다. 에뮬레이터는 `-no-audio`로 실행되어 스피커/이어폰 직접 청취는 미검증이다.
- 초기 기존 세션의 `/sdcard`는 `Transport endpoint is not connected` 오류였다. `adb install -r`는 120초 제한에 걸렸지만 설치된 APK 해시가 일치하여 완료를 확인했다. 데이터 삭제 없이 에뮬레이터 재부팅 후 저장소·런처·앱 제어가 정상화됐다. 같은 AVD의 읽기 전용 병렬 실행은 기존 쓰기 인스턴스 때문에 거절되어 사용하지 않았다.
- 기존 일반 저장 2개는 2026-10-30부터 0바이트였고 초기 테스트 저장도 없었다. 따라서 과거 완료 진행의 이어하기를 검증했다고 주장하지 않는다. 초기 업데이트 전 바이트 스냅샷도 남지 않았다. 이후 테스트 전용 새 게임을 실제 UI로 생성하고, **최종 main APK의 업데이트 설치 전후 그 유효 저장의 SHA-256 일치 및 이어하기**를 확인했다. 일반 저장은 그대로 두었다. [설치 전 해시](evidence/pre-final-update-hashes.json), [최종 설치 증명](evidence/final-build.json).
- Android launcher 홈과 앱 목록에서 새 아이콘 확인. 원형·둥근 사각형·48px에서는 눈·코·입과 영웅 인상이 유지된다. 원형 마스크는 바깥 머리카락과 하단 배경 일부를 자르며, 작은 크기에서는 세 시대 건물의 세부가 제한된다. 승인 원본의 구도를 별도 수정하지 않았다.

## 화면·영상 증거

| 자료 | 확인할 내용 |
| --- | --- |
| [Figma B안 보드](evidence/figma-aurora-b.png) | 최신 에셋을 이용한 편집 가능한 시안, 기본·선택 순간·유지 상태 |
| [홈 화면](evidence/android-home.png) · [앱 목록](evidence/android-drawer.png) | 설치된 실제 런처의 영웅 아이콘 |
| [마스크 비교](evidence/icon-masks.png) | 왼쪽 원형, 가운데 둥근 사각형, 오른쪽 48px 시스템 마스크. 설치된 AdaptiveIconDrawable의 레이어를 Android Canvas로 렌더링 |
| [전곡리](evidence/android-jeongok.png) · [암사동](evidence/android-amsa.png) · [동삼동](evidence/android-dongsam.png) | 지역별 선택·정보·금빛 오로라 |
| [수동 확대](evidence/android-zoom.png) | 유물과 효과의 지도 접점 유지 |
| [18초 원속도 영상](evidence/android-selection-preview.mp4) | 0~5초 지역 선택, 약 5~9초 빠른 전환, 약 10~16초 확대·복원. 내부 소리 포함 |
| [64.94초 전체 녹화](evidence/android-a303-loop.mp4) | 같은 실행의 전체 음악 반복. 약 50초 부근 첫 반복 경계, 중단 없는 화면·오디오 |
| [최종 main 설치·이어하기](evidence/final-main-installed.png) | 테스트 전용 저장을 유지한 최종 배포 APK 실행 |

기존 아이콘은 [움집 원본](../../../game/assets/app-icon-hut.png), 새 아이콘은 [채택 원본](../../../design/app-icon/selected/roxhistory-app-icon-selected-v001.png)으로 비교할 수 있다. 오로라의 신규 코드는 프로젝트 자체 제작이며 기존 Figma 유물·배경·종이·돌 제목은 재사용했다. [대화에서 채택한 B안 참고 이미지](evidence/approved-b-preview.png)는 시안 참고용이며 게임 배경에 합성해 사용하지 않았다.

## 배포 파일

- [APK 한 파일 직접 다운로드](https://github.com/byungho-cho/roxhistory/releases/download/v0.1.17-aurora-icon/RoxHistory-0.1.17-aurora-icon-debug.apk)
- 버전 `0.1.17-aurora-icon`, code 18 / arm64-v8a + x86_64 / signed debug.
- APK 기준 main `d6b23163eab3e32b49faa50a9b2d28c52ef4a394` / 크기 `144722958` bytes.
- APK SHA-256: `aa9c97195eeff2d1947106ab8cb19ed47889d6f98b40677532beff02decedcfe`.
- 기존 서명과 호환되며 최종 APK 설치·기존 테스트 저장 보존을 확인했다. 이전 릴리스는 그대로 보존했다.
- 검토 결과와 증거를 추가하는 문서 전용 커밋은 이 APK의 게임 소스 트리를 변경하지 않는다.
- [공개 다운로드 재검증](evidence/public-download-proof.json): GitHub의 안정적인 릴리스 URL에서 다시 받은 APK의 SHA-256을 위 설치·검증 파일과 대조했다. 만료되는 임시 `release-assets` 주소를 전달하지 않는다.
