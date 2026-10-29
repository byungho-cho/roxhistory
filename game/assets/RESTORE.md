# 원본 에셋 복구 필요

작업 환경 연결 중단으로, 로컬에 다운로드했던 아래 PNG 원본을 GitHub로 옮기지 못했습니다.
이 3개 파일이 복구되기 전 현재 Draft PR은 실행/빌드 가능한 완성 전달본이 아닙니다.
대체 그림이나 스크린샷으로 확정 디자인을 바꾸지 않았습니다.

| 저장 경로 | Figma A003 원본 이미지 채움 | 이미지 해시 | 원본 바이트 수 |
| --- | --- | --- | --- |
| game/assets/figma/98398.png | 110:496 월드 배경 | f41aac0d5c1d57d28bbaedc32563707426259eba | 3343603 |
| game/assets/figma/3eebe.png | 110:451 지도 배경 | 0258253ae9c2aafc9706762272c7340a6277b402 | 3070469 |
| game/assets/figma/20204.png | I110:508;92:153 아이콘 atlas 원본 | 6dcc5583d26454f6f225fdabe4d9f0758daf5d83 | 2593822 |

디자인 파일: https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS

원본 이미지 채움을 그대로 저장합니다. 프레임 스크린샷을 사용하지 않습니다.
기존 Windows 작업 폴더 roxhistory/game/assets/figma에는 정상 다운로드 후 이미지 크기까지 확인한 원본이 있었습니다.
파일을 복구하면 동일 경로에 넣고 커밋하여 CI를 다시 실행합니다.
fac42.svg는 원본 금빛 뒤로가기 벡터를 복구했고, 캐릭터 임시 스프라이트도 원격에 보존했습니다.

막힘 근거:
- 로컬 실행 환경 unavailable / No usable execution environment.
- Figma MCP Full seat Professional tool call limit.
- 외부 CI의 임시 Figma URL 다운로드 결과가 빈 파일이라 원본으로 인정하지 않고 중단.
