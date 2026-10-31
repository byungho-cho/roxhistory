# Android 검증 방법

저장한 Python 파일은 조사 시 사용한 조작 기록이다. 일반 배포용 자동 설치기가 아니며 저장소에서 그대로 실행하도록 구성한 도구도 아니다. `adb` 경로는 공개본에서 일반 명령으로 치환했다. 작업 루트, scrcpy 경로, 임시 파일과 화면 크기는 실행 환경에 맞게 지정해야 한다.

- 에뮬레이터는 기존 AVD의 `-read-only -no-snapshot-save` 세션이다.
- 앱은 `am start ... --esa command_line_params --,--test-ui`로 실행했다. 테스트 저장은 `files/tests/session`, 설정은 `files/tests/preferences.cfg`에 분리된다. 일반 `files/save.json`은 읽어서 전후 바이트 일치를 확인했고 보고서에 원문을 업로드하지 않았다.
- `android-play-loop.py`는 게임의 새 시작 UI부터 실제 터치로 이동·각 1회 채집·건설·보상·이어하기를 수행한다. 위치를 바꾸는 저장 편집은 이 흐름에서 하지 않았다.
- 확대 비교·도구 접촉 확대 영상·성능 비교는 좌표와 재고가 명시된 별도 테스트 저장을 준비했다. 이 자료를 처음부터 끝까지 이어진 플레이로 해석하지 않는다.
- `MultiTouch.java`는 Android shell의 InputManager를 통해 동시에 두 개의 실제 MotionEvent 포인터를 보낸다. javac(Android35 android.jar)와 d8로 dex jar를 만들고 `/data/local/tmp/rox-input.jar`에서 app_process로 실행했다. 일반 PC Godot 합성 입력과 구분한다.
- 영상과 PCM은 scrcpy의 Android playback 캡처이다. 마이크·주변 소리·계정 화면은 수집하지 않았다.
- `--test-ui`는 PC 포커스 전환 알림을 무시하지만 실제 Android PAUSED/RESUMED 알림은 처리한다. 홈 이동과 복귀를 별도로 확인했다.
- 첫 로딩 완료 전에 보낸 자동 입력과 이전 동선의 장애물·건설 입구 조건 때문에 실패한 시도는 완료 결과에 포함하지 않았다. 최종 성공 실행의 JSON·영상만 연결한다.

`pinch-release-probe.gd`와 `native-hero-capture.gd`는 최종 소스에 임시로 연결해 실행한 추가 Native 검사/촬영 스크립트다. 게임 기능에 포함되지 않는다. 후자는 고배율 렌더를 켠 뒤 같은 모델을 정면·옆·뒤로 촬영한다.
