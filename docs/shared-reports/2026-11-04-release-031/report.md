# RoxHistory v0.1.31 배포 — 2026-11-04

[APK 직접 다운로드](https://github.com/byungho-cho/roxhistory/releases/download/v0.1.31/RoxHistory-0.1.31-20261104-133220.apk)

- APK: `RoxHistory-0.1.31-20261104-133220.apk`, versionCode32, 189,210,969바이트. APK 한 파일이며 소스/로그 ZIP을 요구하지 않는다.
- 구현 PR: [#56](https://github.com/byungho-cho/roxhistory/pull/56)
- 최종 APK 빌드 소스 main: `d8446208876f69b33ecb5ac71c76526f804821cf`. 이 커밋 병합 후 다시 빌드·설치·실행했다. 이후 문서 커밋은 APK 소스와 구분한다.
- SHA-256: `8654405c655e3e12ef35716d8d433404c221b9227da95492a4c3e8f6c8df0eb5`
- 패키지 `com.roxhistory.demo`, 기존 인증서 SHA-256 `cf65aeecb4e399ba9e2e6b9fa947f34f8c31bd75c8e3b686ad29d8431bb1695f` 유지.

## 변경

상시5메뉴 HUD, 독립 자원 표시, 프로필 금색 테두리 제거, 원화의 돌 픽셀을 사용한 받침, 타이틀 소리 버튼2배를 적용했다.6개 건설 부지 선택·이동·취소와 기존 건물 위치를 보존하는 저장을 추가했다. 건물 길게 누르기→간단 확인→철거/환급,0.32초 페이드와 먼지 효과를 구현했다. 현재 건설비1+1은 전액 반환하며 기본 움집과 주민은 유지한다. 첫 보금자리 안내 모달과 수동 안내성 하단 메시지를 제거했다.

[건설 상세·영상](../2026-11-04-selected-hud-sites/build-sites.md) · [철거 상세·영상](../2026-11-04-selected-hud-sites/demolition.md)

## 검증

- 최종 동작 코드 전체33묶음 새 실행 통과. 부지61항목/철거48항목/HUD145항목 포함.138개 에셋 크기/해시 일치. 이후 변경은 버전0.1.31/code32 메타데이터다.
- Android15/API35 x86_64 에뮬레이터,1280×720, RTX5060 host GPU. 기존 v0.1.30에서 업데이트 설치 성공, 설치 직후 기존 저장 파일이 바뀌지 않음을 비교했다.
- 원본 저장을 별도 `files/tests/session/save.json`으로 복사한 격리 모드에서 이어하기·실제 터치 길게 누르기·취소·확정 철거·재실행을 검사했다. 취소 후2채 유지, 철거 후1채/나무1/돌1/씨앗20, 남은 기존 건물의 `legacy_slot=1` 유지. 재실행에도 환급 중복 없음. 원본 저장 파일은 검사 전후 동일하다.
- 병합된 main의 최종 APK를 다시 설치하고 격리 저장으로 재진입했다. 런타임 SCRIPT ERROR/FATAL EXCEPTION/ERROR 기록0. 서명검증v2/v3 통과.
- 공개된 APK를 다시 다운로드해 위 SHA-256과 바이트 수가 같은 것을 확인했다. 그 후 이전 v0.1.30 공개 APK1개만 삭제했다. 소스·태그·기록·원본 에셋은 보존했다.
- GitHub Actions 추가 CI는 게시 시점 [실행 중](https://github.com/byungho-cho/roxhistory/actions/runs/41773080320)이다. 로컬 전체 회귀 통과와 원격 CI 완료를 혼동하지 않는다.

## 남은 검증·품질 차이

실물 Android 기기, 직접 청취, 장시간 성능은 미검증이다. 식물/바위의 정확한 앵커를 기준으로 한 최종 앞뒤 가림·접지·충돌/경로 시각 검토는 후속 작업이다. 메뉴 받침의 전체 굴곡·질감은 원화와 완전 일치하지 않는다.10초과 비용 중 소수가 생기는 미래 환급 정책은 미정이므로 해당 미사용 비용은 거절한다. 현재1+1 철거에는 영향이 없다. 미수령 씨앗은 기존 방식으로 먼저 수령해야 철거할 수 있다.

자동 승인 검토가 최초 검증 명령의 ‘저장 복사 전에 입력’ 순서를 차단했다. 실행되지 않았으며, 원본을 조작하지 않고 먼저 사본을 만든 후 격리 모드에서만 검증하는 방식으로 해결했다.

## 증거

- [APK·최종 설치 결과](evidence/final-main-install.json) · [공개 다운로드 검증](evidence/release.json) · [서명](evidence/signature.txt)
- [타이틀](evidence/android-title.png) · [기존 저장 이어하기](evidence/android-test-play.png)
- [철거 확인](evidence/android-demolition-confirm.png) · [철거 후](evidence/android-demolished.png) · [최종 main 재진입](evidence/android-final-main.png)
- [구버전 APK 정리](evidence/old-apk-cleanup.json)
