# Android 첫 데모 · 2026-10-30

Godot 4.5.1 기반 오프라인 데모 v0.1.0 소스는 `game/`에 있습니다. `game/project.godot`을 열어 실행합니다.
이동 → 나무·돌 채집 → 첫 움집 건설 → 보상 수령·저장·이어하기를 제공합니다.

- [실행·빌드·검증 상태](docs/android-demo-v0.1.0.md)
- [원본 에셋과 무결성 확인](game/assets/RESTORE.md)
- Android 빌드와 자동 검사는 `.github/workflows/android-demo.yml`에서 실행합니다.

# 현재 기획 기준 · 2026-10-29

RoxHistory는 **안드로이드 설치형 앱게임**으로 기획을 전환했습니다. Godot를 우선 검증하며, 기존 1안 기반 보강 시안의 그림체와 분위기를 유지합니다. 첫 화면은 전체 지도에서 후보지를 선택하고 지역 플레이로 진입하는 흐름입니다.

- [안드로이드 앱 기획과 시작 지도 v0.3](docs/app-plan-v0.3.md)
- [PDF 시안 보기](https://chatgpt.com/library?file_id=libfile_00be5e24f14481919eda290254ec4766&account_id=personal)

이하 내용은 이전 기록입니다. 플랫폼·기술·아트·첫 진입에 차이가 있으면 위 v0.3 기준을 우선합니다.

---

# 최신 설계 기준 안내

2026-10-28 인수인계 작업의 현재 기준은 [설계 문서 안내](docs/README.md)와 [시놉시스 정합본](docs/synopsis-v0.1-handover.md)입니다. 아래는 복원한 이전 README이며, 원격 미연결 안내와 상세안의 합의 상태는 과거 기록입니다.

---

# RoxHistory

한국사와 한국 지리의 큰 흐름을 사냥, 탐험, 파밍과 도시 성장으로 경험하는 웹게임.

현재 단계는 초기 시놉시스 v0.1이다. 게임 코드는 아직 포함하지 않는다.

## 기준 문서

- [초기 시놉시스](docs/synopsis-v0.1.md)
- [결정 기록](docs/decisions.md)
- `docs/RoxHistory_Synopsis_v0.1.docx` 문서 배포본
- `presentations/RoxHistory_Overview_v0.1.pptx` 한눈에 보는 발표 자료
- [디자인 작업 연결](design/README.md)

콘텐츠의 기준은 Markdown 시놉시스다. Word 문서와 발표 자료는 이를 바탕으로 만든 배포본이며, 내용 변경 시 함께 갱신한다.

## 저장소 구성

- `docs/` 시놉시스, 결정 기록과 참고 자료
- `presentations/` 발표 자료
- `design/` Figma 링크와 다음 작업 범위
- `assets/` 비주얼 방향 검토용 이미지
- `scripts/` 문서와 발표 자료 생성 소스

## 원격 저장소 연결

로컬 Git 이력을 포함한 전달본이다. 원격 저장소는 아직 연결하지 않았다. 빈 비공개 저장소를 생성한 뒤 다음 명령으로 연결할 수 있다.

```bash
git remote add origin <새_저장소_URL>
git push -u origin main
```

새 저장소를 만들 때 README, 라이선스, gitignore 초기화를 생략하면 기존 이력과 충돌을 피할 수 있다. 또는 전달 ZIP의 `roxhistory-v0.1.bundle`로 Git 이력을 복원한다.

```bash
git clone roxhistory-v0.1.bundle roxhistory
```

권리와 라이선스는 별도 결정 전까지 외부 배포 허가를 부여하지 않는다. 검토용 생성 이미지를 역사 복원 자료로 사용하지 않는다.
