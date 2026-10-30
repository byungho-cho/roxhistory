"""Build roadmap Markdown, progress snapshot and PDF from docs/quality-progress.json."""
import argparse
import json
import os
from html import escape
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, Table, TableStyle

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'docs/quality-progress.json'
GREEN = colors.HexColor('#25483D')
GOLD = colors.HexColor('#A87732')
INK = colors.HexColor('#24382F')
MUTED = colors.HexColor('#607267')
PALE = colors.HexColor('#F1F5F0')
AMBER = colors.HexColor('#FFF2D8')
LINE = colors.HexColor('#D7E0D5')
WIDTH, HEIGHT = A4
MARGIN = 42
CONTENT = WIDTH - MARGIN * 2


def dash(value):
    return value or '미정'


def markdown(data):
    lines = [f"# {data['title']} v{data['version']}", '',
             f"기준일: {data['updatedAt']} KST. 단계 범위와 완료 기준은 최신 사용자 합의를 따릅니다.", '',
             '## 목표와 현재 위치', '', f"**{data['goal']}**", '', data['scope'], '',
             f"현재 초점: **{data['currentFocus']}**", '', data['progressPolicy'], '', data.get('operatingPolicy',''), '', data.get('testBuildGoal',''), '',
             f"기존 기준선: {data['baseline']['evidence']}", '', data['baseline']['notes'], '',
             f"아트 기준: {data['design']['style']}", '',
             '## 5단계 로드맵', '', '| 단계 | 경험 목표 | 상태 | 선행 조건 | 목표일 |',
             '| --- | --- | --- | --- | --- |']
    for stage in data['stages']:
        predecessor = ', '.join(stage['dependsOn']) or '기존 기능 데모 보존'
        lines.append(f"| {stage['id']} {stage['title']} | {stage['experience']} | {stage['status']} | {predecessor} | {dash(stage['targetDate'])} |")
    lines += ['', '## 일정 운영', '', data['schedulePolicy'], '',
              'P2를 먼저 마무리한 뒤 P3를 진행했으며, 다음 단계는 P4입니다. 각 단계의 실행·시각·회귀 검증을 우선합니다. 사용자 피드백은 수시 반영합니다. 날짜가 정해지기 전에는 지연·정상 판정을 하지 않습니다.', '',
              '## 단계별 범위와 완료 기준', '']
    for stage in data['stages']:
        lines += [f"### {stage['id']}. {stage['title']}", '', f"체험 목표: **{stage['experience']}**", '', '작업 범위:', '']
        lines += [f'- {item}' for item in stage['work']]
        if stage.get('tasks'):
            lines += ['', '| 작업 | 산출물 | 완료 확인 | 상태 |', '| --- | --- | --- | --- |']
            lines += [f"| {t['id']} {t['title']} | {t['result']} | {t['checks']} | {t['status']} |" for t in stage['tasks']]
        lines += ['', '단계 완료 기준:', ''] + [f'- {item}' for item in stage['gate']]
        lines += ['', '전달물:', ''] + [f'- {item}' for item in stage['deliverables']]
        lines += ['', f"이번 단계 제외: {stage['excluded']}", '', f"다음 행동: {stage['nextAction']}", '']
    lines += ['## 진행 상태의 정의', '', '| 상태 | 판정 기준 |', '| --- | --- |']
    lines += [f"| {row['status']} | {row['meaning']} |" for row in data['statusDefinitions']]
    lines += ['', '## 검토와 현행화', '']
    lines += [f"{i}. {item}" for i, item in enumerate(data['reviewFlow'], 1)]
    lines += ['', '현행화 규칙:', ''] + [f'- {item}' for item in data['updateRules']]
    lines += ['', '## 문서와 디자인의 연결', '',
              '- 상태 원본: [quality-progress.json](quality-progress.json)',
              '- 현재 현황표: [quality-progress.md](quality-progress.md)',
              '- 다음 P2 개발 지시: [stage2-character-instructions.md](stage2-character-instructions.md)',
              '- PDF: [RoxHistory_QualityRoadmap_v0.1.pdf](../presentations/RoxHistory_QualityRoadmap_v0.1.pdf)',
              f"- 기존 디자인: {data['design']['fileUrl']}",
              f"- Figma 로드맵: {data['design']['roadmapUrl'] or data['design']['roadmapStatus']}",
              '- 재생성: `python scripts/build_quality_roadmap.py`', '',
              '## 변경 이력', '', '| 날짜 | 단계 | 변경 |', '| --- | --- | --- |']
    lines += [f"| {h['date']} | {h['stage']} | {h['event']} |" for h in data['history']]
    lines += ['', '## 참고', ''] + [f"- [{r['label']}]({r['url']})" for r in data['references']]
    return '\n'.join(lines) + '\n'


def progress_markdown(data):
    lines = ['# RoxHistory 품질 진행 현황', '', f"업데이트: {data['updatedAt']} KST / 로드맵 v{data['version']}", '',
             f"**현재: {data['currentFocus']}**", '', data['progressPolicy'], '',
             '## 단계별 현황', '', '| 단계 | 상태 | 구현 | 검증 | 팀장 판정 | 목표일 | 실제 완료일 |',
             '| --- | --- | --- | --- | --- | --- | --- |']
    for s in data['stages']:
        lines.append(f"| {s['id']} {s['title']} | {s['status']} | {s['implementation']} | {s['validation']} | {s.get('leaderReview','대기')} | {dash(s['targetDate'])} | {s['actualFinish'] or '미완료'} |")
    lines += ['', '## 일정 상세', '', '| 단계 | 예정 시작 | 목표 완료 | 실제 시작 | 실제 완료 |', '| --- | --- | --- | --- | --- |']
    lines += [f"| {s['id']} | {dash(s['plannedStart'])} | {dash(s['targetDate'])} | {s['actualStart'] or '미착수'} | {s['actualFinish'] or '미완료'} |" for s in data['stages']]
    lines += ['', data['schedulePolicy'], '', '## P1 완료 기록 / 다음 작업 P4', '', '[P2 캐릭터 개발 지시](stage2-character-instructions.md)', '', '| 작업 | 상태 | 산출물 |', '| --- | --- | --- |']
    lines += [f"| {t['id']} {t['title']} | {t['status']} | {t['result']} |" for t in data['stages'][0]['tasks']]
    lines += ['', '## 다음 행동과 막힘', '']
    for s in data['stages']:
        lines += [f"- {s['id']}: {s['nextAction']}. 막힘: {s['blocker'] or '기록 없음'}. 검증 근거: {'; '.join(s['evidence']) or '미등록'}"]
    lines += ['', '## 현황 갱신에 필요한 정보', '',
              '담당자는 단계·작업 ID, 상태, 실제 시작/완료일, 합의 목표일, 변경 커밋·PR, APK·영상, 검증 환경·결과, 막힘과 다음 조치를 보고합니다.', '',
              '품질 단계 완료는 구현·검증·팀장 판단이 기록된 경우에 표시합니다. 사용자 응답을 기다리는 승인 절차는 두지 않습니다. 사용자 플레이 확인은 기능 기준선이며 P1~P5 완료에 자동 반영하지 않습니다.', '',
              '문서는 요청 또는 개발 보고를 받을 때 현행화합니다. 자동 감시나 정기 알림은 아직 설정하지 않았습니다.', '',
              '[전체 로드맵](quality-roadmap-v0.1.md) / [상태 원본](quality-progress.json)', '']
    return '\n'.join(lines)


def register_fonts():
    regular = Path(os.environ.get('ROX_KOREAN_FONT', r'C:\Windows\Fonts\malgun.ttf'))
    bold = Path(os.environ.get('ROX_KOREAN_BOLD_FONT', r'C:\Windows\Fonts\malgunbd.ttf'))
    if not regular.exists():
        regular = ROOT / 'game/assets/fonts/NotoSansKR.ttf'
    if not bold.exists():
        bold = regular
    pdfmetrics.registerFont(TTFont('KR', str(regular)))
    pdfmetrics.registerFont(TTFont('KR-Bold', str(bold)))


def pdf(data, destination):
    register_fonts()
    destination.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(destination), pagesize=A4)
    c.setTitle(f"{data['title']} v{data['version']}")
    c.setAuthor('RoxHistory')
    normal = ParagraphStyle('Body', fontName='KR', fontSize=10, leading=15.5, textColor=INK, wordWrap='CJK')
    small = ParagraphStyle('Small', parent=normal, fontSize=8.2, leading=12)
    heading = ParagraphStyle('Heading', parent=normal, fontName='KR-Bold', fontSize=15, leading=22)

    def p(text, x, top, width=CONTENT, style=normal):
        para = Paragraph(escape(text).replace('\n', '<br/>'), style)
        _, h = para.wrap(width, HEIGHT)
        if top - h < 42:
            raise ValueError(f'Page overflow: {text[:45]} top={top} height={h}')
        para.drawOn(c, x, top - h)
        return top - h

    def begin(number, label, title, subtitle):
        c.setFillColor(GREEN)
        c.rect(0, HEIGHT - 96, WIDTH, 96, fill=1, stroke=0)
        c.setFillColor(colors.HexColor('#D9C59B'))
        c.setFont('KR-Bold', 9)
        c.drawString(MARGIN, HEIGHT - 27, 'ROXHISTORY  /  QUALITY ROADMAP')
        c.setFillColor(colors.white)
        c.setFont('KR-Bold', 21)
        c.drawString(MARGIN, HEIGHT - 58, title)
        c.setFont('KR', 9)
        c.drawString(MARGIN, HEIGHT - 78, subtitle)
        c.setStrokeColor(LINE)
        c.line(MARGIN, 35, WIDTH-MARGIN, 35)
        c.setFillColor(MUTED)
        c.setFont('KR', 8)
        c.drawString(MARGIN, 21, f"v{data['version']}  |  {data['updatedAt']} KST  |  {label}")
        c.drawRightString(WIDTH-MARGIN, 21, f'{number} / 6')
        return HEIGHT - 119

    def title(text, top):
        return p(text, MARGIN, top, style=heading) - 10

    def bullets(items, top, width=CONTENT, x=MARGIN, style=normal):
        for item in items:
            top = p('- ' + item, x, top, width, style) - 6
        return top

    def table(rows, widths, top, font=small):
        cells = [[Paragraph(escape(str(cell)), font) for cell in row] for row in rows]
        t = Table(cells, colWidths=widths, hAlign='LEFT')
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), PALE), ('VALIGN',(0,0),(-1,-1),'TOP'),
            ('LINEBELOW',(0,0),(-1,0),1,GREEN), ('LINEBELOW',(0,1),(-1,-1),0.4,LINE),
            ('LEFTPADDING',(0,0),(-1,-1),8), ('RIGHTPADDING',(0,0),(-1,-1),8),
            ('TOPPADDING',(0,0),(-1,-1),9), ('BOTTOMPADDING',(0,0),(-1,-1),9),
        ]))
        _, h = t.wrap(CONTENT, HEIGHT)
        if top-h < 45:
            raise ValueError('Table overflow')
        t.drawOn(c,MARGIN,top-h)
        return top-h-16

    def stage_block(stage, top):
        top = title(f"{stage['id']}  {stage['title']}", top)
        top = p(stage['experience'], MARGIN, top) - 12
        top = bullets(stage['work'], top, style=small)
        top = p('완료 확인', MARGIN, top-3, style=ParagraphStyle('Sub', parent=normal, fontName='KR-Bold')) - 7
        top = bullets(stage['gate'], top, style=small)
        top = p('전달물: ' + ' / '.join(stage['deliverables']), MARGIN, top-2, style=small)-8
        top = p('제외: ' + stage['excluded'], MARGIN, top, style=small)-20
        return top

    y = begin(1,'전체 목표','짧아도, 완성된 게임처럼','암사동 한 지역에서 시작하는 5단계 품질 로드맵')
    y = p(data['goal'], MARGIN,y,style=ParagraphStyle('Hero',parent=heading,fontSize=18,leading=28))-14
    y = p(data['scope'],MARGIN,y)-19
    c.setFillColor(AMBER)
    c.roundRect(MARGIN,y-59,CONTENT,59,9,fill=1,stroke=0)
    p('현재 초점: P2 보완·P3 연출 검증 완료 / 다음 P4',MARGIN+14,y-11,CONTENT-28,ParagraphStyle('Focus',parent=normal,fontName='KR-Bold'))
    p('P1~P3 개발 검증 완료  |  새 아트 피드백·실기기 검증 별도',MARGIN+14,y-34,CONTENT-28,small)
    y -= 82
    y = table([['단계','만들 경험','착수 조건']]+[[s['id']+' '+s['title'],s['experience'],'기존 기능 보존' if not s['dependsOn'] else s['dependsOn'][0]+' 팀장 검토'] for s in data['stages']], [172,217,CONTENT-389], y)
    y = title('이미 확인된 것과 앞으로 확인할 것',y-2)
    y = p(data['baseline']['evidence'],MARGIN,y)-9
    y = p('기존 기능 데모의 기본 실행 확인과 새로운 품질 단계의 완료를 구분합니다. 투자자 시연은 지향하는 용도이며 투자 성과를 보장하지 않습니다.',MARGIN,y,style=small)-13
    p('공통 아트: '+data['design']['style'],MARGIN,y,style=small)
    c.showPage()

    y=begin(2,'1단계 상세','P1  살아 있는 강변 정착지','개별 오브젝트와 물·식생의 움직임부터 완성')
    y=p(data['stages'][0]['experience'],MARGIN,y)-15
    for task in data['stages'][0]['tasks']:
        y=p(task['id']+'  '+task['title']+'  /  '+task['status'],MARGIN,y,style=ParagraphStyle('Task',parent=normal,fontName='KR-Bold',fontSize=12,leading=19))-6
        y=p('산출물: '+task['result'],MARGIN,y)-5
        y=p('확인: '+task['checks'],MARGIN,y,style=small)-18
    y=title('반드시 지킬 경계',y)
    y=bullets(['배경·지형·물·식생·돌·건물·소품을 필요한 단위로 분리','기존 이동·채집·건설·저장 기능과 현재 조작 UI 유지','시점·바닥 접점·그림자·앞뒤 가림·충돌을 일치','배경에 박힌 UI·인물과 실제 게임 요소의 중복 정리'],y,style=small)
    p('제외: '+data['stages'][0]['excluded'],MARGIN,y-3,style=small)
    c.showPage()

    y=begin(3,'2~3단계','움직임에서 손맛으로','각 단계의 검증과 팀장 판단으로 진행, 사용자 피드백은 수시 반영')
    y=stage_block(data['stages'][1],y)
    c.setStrokeColor(LINE); c.line(MARGIN,y+5,WIDTH-MARGIN,y+5)
    stage_block(data['stages'][2],y-10)
    c.showPage()

    y=begin(4,'4~5단계','연출에서 시연 경험으로','짧은 분량 안에서 전체 뼈대가 맞물리는지 검증')
    y=stage_block(data['stages'][3],y)
    c.setStrokeColor(LINE); c.line(MARGIN,y+5,WIDTH-MARGIN,y+5)
    stage_block(data['stages'][4],y-10)
    c.showPage()

    y=begin(5,'진행 현황','지금 어디까지 왔는가','계획·구현·검증·팀장 판정과 사용자 피드백을 구분해 기록')
    y=title('현재 현황 스냅샷',y)
    y=table([['단계','현재 상태','구현','검증','팀장 판정']]+[[s['id'],s['status'],s['implementation'],s['validation'],s.get('leaderReview','대기')] for s in data['stages']],[45,124,110,110,CONTENT-389],y)
    y=title('일정 관리',y)
    y=table([['단계','예정 시작','목표 완료','실제 시작','실제 완료']]+[[s['id'],dash(s['plannedStart']),dash(s['targetDate']),s['actualStart'] or '미착수',s['actualFinish'] or '미완료'] for s in data['stages']],[45,116,116,116,CONTENT-393],y)
    y=p(data['schedulePolicy'],MARGIN,y)-17
    y=title('다음 행동',y)
    y=p(data['stages'][1]['nextAction'],MARGIN,y)-12
    y=p('P2의 3D 캐릭터 원본 특징·관절·발 접점 보완을 먼저 검토한 뒤 P3 타격·획득·건설 연출을 통합했습니다. 나무1·돌1의 짧은 루프를 유지합니다. 새 아트 피드백과 Android 실기기·장시간 검증은 남았으며 전체 베타 완료가 아닙니다.',MARGIN,y,style=small)-12
    p('자동 감시·정기 알림은 설정하지 않았습니다. 개발 보고 또는 사용자 확인 요청이 있을 때 상태를 대조하고 현행화합니다.',MARGIN,y,style=small)
    c.showPage()

    y=begin(6,'운영 규칙','완료를 확인하는 방법','문서·실행 결과·Figma를 같은 상태로 유지')
    y=table([['상태','판정 기준']]+[[r['status'],r['meaning']] for r in data['statusDefinitions']],[95,CONTENT-95],y)
    y=title('단계별 전달과 현행화',y)
    y=bullets(['구현·검증 → 팀장 검토·보완 → main 병합·APK 단독 전달 → 다음 단계',
               '단계·작업 ID, 담당, 목표일·실제 날짜·근거를 기록. 사용자 응답을 필수 대기 조건으로 두지 않음',
               'APK·영상·검증에는 기준 커밋·기기·OS·시각·미검증 범위를 연결',
               'quality-progress.json 수정 후 로드맵·현황표·PDF·Figma 도식 상태를 함께 갱신',
               '기존 테스트 통과를 애니메이션·공간감·재미의 검증 완료로 대체하지 않음'],y,style=small)
    y=title('연결과 현재 Figma 상태',y-1)
    y=p('기존 디자인: '+data['design']['fileUrl'],MARGIN,y,style=small)-6
    y=p('Figma 로드맵: '+(data['design']['roadmapUrl'] or data['design']['roadmapStatus'])+'. 현재 연결에서는 Specs 문서 API를 사용할 수 없어 별도 FigJam 다이어그램으로 연결합니다.',MARGIN,y,style=small)-11
    y=title('변경 이력',y)
    for h in data['history'][-4:]:
        y=p(h['date']+' / '+h['stage']+' / '+h['event'],MARGIN,y,style=small)-6
    c.showPage()
    c.save()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--pdf',default=str(ROOT/'presentations/RoxHistory_QualityRoadmap_v0.1.pdf'))
    args=parser.parse_args()
    data=json.loads(DATA.read_text(encoding='utf-8'))
    (ROOT/'docs/quality-roadmap-v0.1.md').write_text(markdown(data),encoding='utf-8')
    (ROOT/'docs/quality-progress.md').write_text(progress_markdown(data),encoding='utf-8')
    pdf(data,Path(args.pdf))
    print(json.dumps({'stages':len(data['stages']),'acceptedStages':sum(s['status']=='완료' for s in data['stages']), 'pdf':args.pdf},ensure_ascii=False))


if __name__=='__main__':
    main()
