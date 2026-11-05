# Figma 원본 에셋 · 1차 리팩토링

2026-11-05 사용자 지정 Figma `zkbflw9fCdAlWbphhw5pSS`에서 내려받은 개별 PNG/SVG 원본이다. 전체 화면 캡처를 배경으로 넣은 것이 아니다. 원본 픽셀은 보존하고 게임의 AtlasTexture와 마스크로 사용 영역을 지정한다.

- hut-stages.png: 957:293, 첫 단계 크롭만 사용.
- pad.png: 956:337 / 854:201, 지면 토대. 가장자리 마스크는 게임 셰이더.
- road.png: 826:107, 흙길 후보. 중앙 흙 텍스처를 1칸 타일로 사용하고 넓은 빛 번짐은 제외.
- world-village.png: 755:50 / 1006:423, 마을 축소판. 알파 50% 기준 가시 폭 1058 / 원본 폭 1536.
- map-button.png: 996:39. home-button.png: 1024:44. seeds.png: 988:39.
- mountain-map.png / mountain-mask.svg: 1036:425의 지도 부분과 마스크. 완성된 게임용 산 타일이 아니므로 연결감 검토 필요.
- world-river.png: 1047:36. world-lake.png: 1044:42. 분리 지형 후보, 반복 타일 검증 전.

원본 크기·SHA-256·크롭·기준점은 `res://data/assets.json`에 기록. 별도 라이선스 문서는 제공되지 않았으며 사용자가 지정한 프로젝트 디자인 자료로 사용한다. 제3자 재배포 권한을 새로 확인한 것은 아니다.
