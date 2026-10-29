# 발표 자료와 PDF 열람본

PPTX 원본을 추가하거나 수정할 때는 **같은 폴더, 같은 이름의 PDF**를 반드시 함께 관리합니다. PDF는 웹 열람용이며 원본 PPTX를 대체하지 않습니다.

| 자료 | 웹에서 보기 | 편집 원본 |
| --- | --- | --- |
| 최신 인수인계 정합본 | [PDF 보기](RoxHistory_Overview_v0.1-handover.pdf) | [PPTX](RoxHistory_Overview_v0.1-handover.pptx) |
| 초기 상세안 | [PDF 보기](RoxHistory_Overview_v0.1.pdf) | [PPTX](RoxHistory_Overview_v0.1.pptx) |

## 자동 갱신

`Presentation PDFs` GitHub Actions는 PPTX를 추가·수정한 브랜치에 같은 이름의 PDF와 `pdf-manifest.json`을 생성해 커밋합니다. 기존 원본은 수정하지 않습니다. 기본 브랜치에서도 동일하게 작동합니다. 보호 규칙이 자동 커밋을 차단하면 해당 실행이 실패하며, 수정 브랜치에서 생성된 PDF를 원본과 함께 병합해야 합니다.

Pull Request에서는 원본/PDF의 SHA-256, 슬라이드 수와 PDF 페이지 수, 가로세로 비율, 슬라이드 본문과 표의 텍스트 보존을 검사합니다. PPTX만 바뀌었거나 PDF가 누락된 상태는 검사에 실패합니다. 해시 검사는 기록된 변환 쌍의 변경 여부를 검출하며 시각적 동일성까지 증명하지는 않습니다. 원본 변경 후 자동 변환 완료를 확인하고 PDF를 열어 레이아웃도 확인합니다.

GitHub 파일 화면에서 PDF를 바로 열람할 수 있습니다. `raw` 다운로드 주소 대신 위의 PDF 파일 링크를 사용합니다.

## 수동 변환 및 검사

LibreOffice, Python 3.12와 한국어 글꼴이 필요합니다. CI에서는 Noto CJK와 대체 글꼴을 설치하며, 원본의 맑은 고딕이 없는 환경에서는 글꼴 대체가 발생할 수 있습니다.

```sh
python -m pip install -r scripts/presentation_pdf_requirements.txt
python scripts/presentation_pdfs.py build
python scripts/presentation_pdfs.py check
```

PPTX는 먼저 Git에 추가해야 자동 검색에 포함됩니다. PDF와 manifest도 함께 커밋합니다. CI 변환은 외부 문서 변환 서비스로 원본을 전송하지 않습니다.

## 2026-10-29 발표용 디자인 개편

두 자료를 각각 10페이지로 유지하면서 밝은 아이보리 배경, 짙은 본문, 차분한 주황색 포인트로 개편했습니다. 제목과 본문 크기, 여백과 문장 길이를 정리하고 표·도식은 편집 가능한 개체로 유지합니다. 최신 정합본과 초기 상세안의 결정 상태를 구분하며, 비주얼은 2.5D 1안의 잠정 선호를 반영합니다. 이전 디자인과 원본은 Git 이력에 남습니다.

현재 생성 소스는 `scripts/build_presentations_refresh.mjs`이며 기존 두 생성 진입점도 이 소스를 사용합니다. 실행 환경에 `CODEX_PRIMARY_RUNTIME_NODE_MODULES`, `CODEX_PRIMARY_RUNTIME_PYTHON`, `ROX_PRESENTATION_SKILL`을 설정한 뒤 `node scripts/build_presentations_refresh.mjs`로 두 자료를 생성합니다. 선택 실행은 인수 `handover` 또는 `original`을 사용합니다. 글꼴은 맑은 고딕이며 PDF 변환 환경에서는 한국어 대체 글꼴을 사용합니다.

## 1안 기반 비주얼 보강 시안

`RoxHistory_Overview_v0.1.pptx`와 같은 이름의 PDF는 현재 **11페이지**입니다. 09장의 비교 화면 다음인 **10장**에 1안의 캐릭터·색감·UI를 유지하면서 2안의 자연광·배경 깊이·재질·사냥 동작을 접목한 단일 시안을 추가했습니다. 기존 마지막 장은 11장으로 이동했습니다. 인수인계 정합본은 기존 10페이지를 유지합니다.

[통합 시안 원본 이미지](../assets/visual-direction-1-enhanced.png)는 시각 검토용 생성 이미지이며, 실제 구현 화면이나 고증 승인 자료는 아닙니다. Figma에는 아직 추가되지 않았습니다.
