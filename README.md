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
