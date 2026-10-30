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
    return value or '����'


def markdown(data):
    lines = [f"# {data['title']} v{data['version']}", '',
             f"������: {data['updatedAt']} KST. �ܰ� ������ �Ϸ� ������ �ֽ� ����� ���Ǹ� �����ϴ�.", '',
             '## ��ǥ�� ���� ��ġ', '', f"**{data['goal']}**", '', data['scope'], '',
             f"���� ����: **{data['currentFocus']}**", '', data['progressPolicy'], '', data.get('operatingPolicy',''), '', data.get('testBuildGoal',''), '',
             f"���� ���ؼ�: {data['baseline']['evidence']}", '', data['baseline']['notes'], '',
             f"��Ʈ ����: {data['design']['style']}", '',
             '## 5�ܰ� �ε��', '', '| �ܰ� | ���� ��ǥ | ���� | ���� ���� | ��ǥ�� |',
             '| --- | --- | --- | --- | --- |']
    for stage in data['stages']:
        predecessor = ', '.join(stage['dependsOn']) or '���� ��� ���� ����'
        lines.append(f"| {stage['id']} {stage['title']} | {stage['experience']} | {stage['status']} | {predecessor} | {dash(stage['targetDate'])} |")
    lines += ['', '## ���� �', '', data['schedulePolicy'], '',
              '1�ܰ��� P1.1���� �����ϰ�, �� ǰ�� �ܰ��� ������ ���� �Ǵ� �� ���� �ܰ踦 �����մϴ�. ����� �ǵ���� ���� �ݿ��մϴ�. ��¥�� �������� ������ ���������� ������ ���� �ʽ��ϴ�.', '',
              '## �ܰ躰 ������ �Ϸ� ����', '']
    for stage in data['stages']:
        lines += [f"### {stage['id']}. {stage['title']}", '', f"ü�� ��ǥ: **{stage['experience']}**", '', '�۾� ����:', '']
        lines += [f'- {item}' for item in stage['work']]
        if stage.get('tasks'):
            lines += ['', '| �۾� | ���⹰ | �Ϸ� Ȯ�� | ���� |', '| --- | --- | --- | --- |']
            lines += [f"| {t['id']} {t['title']} | {t['result']} | {t['checks']} | {t['status']} |" for t in stage['tasks']]
        lines += ['', '�ܰ� �Ϸ� ����:', ''] + [f'- {item}' for item in stage['gate']]
        lines += ['', '���޹�:', ''] + [f'- {item}' for item in stage['deliverables']]
        lines += ['', f"�̹� �ܰ� ����: {stage['excluded']}", '', f"���� �ൿ: {stage['nextAction']}", '']
    lines += ['## ���� ������ ����', '', '| ���� | ���� ���� |', '| --- | --- |']
    lines += [f"| {row['status']} | {row['meaning']} |" for row in data['statusDefinitions']]
    lines += ['', '## ����� ����ȭ', '']
    lines += [f"{i}. {item}" for i, item in enumerate(data['reviewFlow'], 1)]
    lines += ['', '����ȭ ��Ģ:', ''] + [f'- {item}' for item in data['updateRules']]
    lines += ['', '## ������ �������� ����', '',
              '- ���� ����: [quality-progress.json](quality-progress.json)',
              '- ���� ��Ȳǥ: [quality-progress.md](quality-progress.md)',
              '- ���� P2 ���� ����: [stage2-character-instructions.md](stage2-character-instructions.md)',
              '- PDF: [RoxHistory_QualityRoadmap_v0.1.pdf](../presentations/RoxHistory_QualityRoadmap_v0.1.pdf)',
              f"- ���� ������: {data['design']['fileUrl']}",
              f"- Figma �ε��: {data['design']['roadmapUrl'] or data['design']['roadmapStatus']}",
              '- �����: `python scripts/build_quality_roadmap.py`', '',
              '## ���� �̷�', '', '| ��¥ | �ܰ� | ���� |', '| --- | --- | --- |']
    lines += [f"| {h['date']} | {h['stage']} | {h['event']} |" for h in data['history']]
    lines += ['', '## ����', ''] + [f"- [{r['label']}]({r['url']})" for r in data['references']]
    return '\n'.join(lines) + '\n'


def progress_markdown(data):
    lines = ['# RoxHistory ǰ�� ���� ��Ȳ', '', f"������Ʈ: {data['updatedAt']} KST / �ε�� v{data['version']}", '',
             f"**����: {data['currentFocus']}**", '', data['progressPolicy'], '',
             '## �ܰ躰 ��Ȳ', '', '| �ܰ� | ���� | ���� | ���� | ���� ���� | ��ǥ�� | ���� �Ϸ��� |',
             '| --- | --- | --- | --- | --- | --- | --- |']
    for s in data['stages']:
        lines.append(f"| {s['id']} {s['title']} | {s['status']} | {s['implementation']} | {s['validation']} | {s.get('leaderReview','���')} | {dash(s['targetDate'])} | {s['actualFinish'] or '�̿Ϸ�'} |")
    lines += ['', '## ���� ��', '', '| �ܰ� | ���� ���� | ��ǥ �Ϸ� | ���� ���� | ���� �Ϸ� |', '| --- | --- | --- | --- | --- |']
    lines += [f"| {s['id']} | {dash(s['plannedStart'])} | {dash(s['targetDate'])} | {s['actualStart'] or '������'} | {s['actualFinish'] or '�̿Ϸ�'} |" for s in data['stages']]
    lines += ['', data['schedulePolicy'], '', '## P1 �Ϸ� ��� / ���� �۾� P2', '', '[P2 ĳ���� ���� ����](stage2-character-instructions.md)', '', '| �۾� | ���� | ���⹰ |', '| --- | --- | --- |']
    lines += [f"| {t['id']} {t['title']} | {t['status']} | {t['result']} |" for t in data['stages'][0]['tasks']]
    lines += ['', '## ���� �ൿ�� ����', '']
    for s in data['stages']:
        lines += [f"- {s['id']}: {s['nextAction']}. ����: {s['blocker'] or '��� ����'}. ���� �ٰ�: {'; '.join(s['evidence']) or '�̵��'}"]
    lines += ['', '## ��Ȳ ���ſ� �ʿ��� ����', '',
              '����ڴ� �ܰ衤�۾� ID, ����, ���� ����/�Ϸ���, ���� ��ǥ��, ���� Ŀ�ԡ�PR, APK������, ���� ȯ�桤���, ������ ���� ��ġ�� �����մϴ�.', '',
              'ǰ�� �ܰ� �Ϸ�� ���������������� �Ǵ��� ��ϵ� ��쿡 ǥ���մϴ�. ����� ������ ��ٸ��� ���� ������ ���� �ʽ��ϴ�. ����� �÷��� Ȯ���� ��� ���ؼ��̸� P1~P5 �Ϸῡ �ڵ� �ݿ����� �ʽ��ϴ�.', '',
              '������ ��û �Ǵ� ���� ������ ���� �� ����ȭ�մϴ�. �ڵ� ���ó� ���� �˸��� ���� �������� �ʾҽ��ϴ�.', '',
              '[��ü �ε��](quality-roadmap-v0.1.md) / [���� ����](quality-progress.json)', '']
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
        top = p('�Ϸ� Ȯ��', MARGIN, top-3, style=ParagraphStyle('Sub', parent=normal, fontName='KR-Bold')) - 7
        top = bullets(stage['gate'], top, style=small)
        top = p('���޹�: ' + ' / '.join(stage['deliverables']), MARGIN, top-2, style=small)-8
        top = p('����: ' + stage['excluded'], MARGIN, top, style=small)-20
        return top

    y = begin(1,'��ü ��ǥ','ª�Ƶ�, �ϼ��� ����ó��','�ϻ絿 �� �������� �����ϴ� 5�ܰ� ǰ�� �ε��')
    y = p(data['goal'], MARGIN,y,style=ParagraphStyle('Hero',parent=heading,fontSize=18,leading=28))-14
    y = p(data['scope'],MARGIN,y)-19
    c.setFillColor(AMBER)
    c.roundRect(MARGIN,y-59,CONTENT,59,9,fill=1,stroke=0)
    p('���� ����: P1 �Ϸ� / P2 ĳ���� �ִϸ��̼� ���� �غ�',MARGIN+14,y-11,CONTENT-28,ParagraphStyle('Focus',parent=normal,fontName='KR-Bold'))
    p('���� �ܰ� ���� �Ϸ� 1/5  |  ����� �ǵ�� ���� �ݿ�',MARGIN+14,y-34,CONTENT-28,small)
    y -= 82
    y = table([['�ܰ�','���� ����','���� ����']]+[[s['id']+' '+s['title'],s['experience'],'���� ��� ����' if not s['dependsOn'] else s['dependsOn'][0]+' ���� ����'] for s in data['stages']], [172,217,CONTENT-389], y)
    y = title('�̹� Ȯ�ε� �Ͱ� ������ Ȯ���� ��',y-2)
    y = p(data['baseline']['evidence'],MARGIN,y)-9
    y = p('���� ��� ������ �⺻ ���� Ȯ�ΰ� ���ο� ǰ�� �ܰ��� �ϷḦ �����մϴ�. ������ �ÿ��� �����ϴ� �뵵�̸� ���� ������ �������� �ʽ��ϴ�.',MARGIN,y,style=small)-13
    p('���� ��Ʈ: '+data['design']['style'],MARGIN,y,style=small)
    c.showPage()

    y=begin(2,'1�ܰ� ��','P1  ��� �ִ� ���� ������','���� ������Ʈ�� �����Ļ��� �����Ӻ��� �ϼ�')
    y=p(data['stages'][0]['experience'],MARGIN,y)-15
    for task in data['stages'][0]['tasks']:
        y=p(task['id']+'  '+task['title']+'  /  '+task['status'],MARGIN,y,style=ParagraphStyle('Task',parent=normal,fontName='KR-Bold',fontSize=12,leading=19))-6
        y=p('���⹰: '+task['result'],MARGIN,y)-5
        y=p('Ȯ��: '+task['checks'],MARGIN,y,style=small)-18
    y=title('�ݵ�� ��ų ���',y)
    y=bullets(['��桤�����������Ļ��������ǹ�����ǰ�� �ʿ��� ������ �и�','���� �̵���ä�����Ǽ������� ��ɰ� ���� ���� UI ����','�������ٴ� �������׸��ڡ��յ� �������浹�� ��ġ','��濡 ���� UI���ι��� ���� ���� ����� �ߺ� ����'],y,style=small)
    p('����: '+data['stages'][0]['excluded'],MARGIN,y-3,style=small)
    c.showPage()

    y=begin(3,'2~3�ܰ�','�����ӿ��� �ո�����','�� �ܰ��� ������ ���� �Ǵ����� ����, ����� �ǵ���� ���� �ݿ�')
    y=stage_block(data['stages'][1],y)
    c.setStrokeColor(LINE); c.line(MARGIN,y+5,WIDTH-MARGIN,y+5)
    stage_block(data['stages'][2],y-10)
    c.showPage()

    y=begin(4,'4~5�ܰ�','���⿡�� �ÿ� ��������','ª�� �з� �ȿ��� ��ü ���밡 �¹������� ����')
    y=stage_block(data['stages'][3],y)
    c.setStrokeColor(LINE); c.line(MARGIN,y+5,WIDTH-MARGIN,y+5)
    stage_block(data['stages'][4],y-10)
    c.showPage()

    y=begin(5,'���� ��Ȳ','���� ������ �Դ°�','��ȹ������������������ ������ ����� �ǵ���� ������ ���')
    y=title('���� ��Ȳ ������',y)
    y=table([['�ܰ�','���� ����','����','����','���� ����']]+[[s['id'],s['status'],s['implementation'],s['validation'],s.get('leaderReview','���')] for s in data['stages']],[45,124,110,110,CONTENT-389],y)
    y=title('���� ����',y)
    y=table([['�ܰ�','���� ����','��ǥ �Ϸ�','���� ����','���� �Ϸ�']]+[[s['id'],dash(s['plannedStart']),dash(s['targetDate']),s['actualStart'] or '������',s['actualFinish'] or '�̿Ϸ�'] for s in data['stages']],[45,116,116,116,CONTENT-393],y)
    y=p(data['schedulePolicy'],MARGIN,y)-17
    y=title('���� �ൿ',y)
    y=p(data['stages'][1]['nextAction'],MARGIN,y)-12
    y=p('P1�� PR #7�� CI��ȯ�桤�̵� ���䡤Android �⺻ ���� ����� �ٰŷ� �ܰ� �Ϸ� ó���߽��ϴ�. P2 ���� �غ��̸�, ��ü ��ǰ�� ��Ÿ �ϷḦ ������ �ʽ��ϴ�.',MARGIN,y,style=small)-12
    p('�ڵ� ���á����� �˸��� �������� �ʾҽ��ϴ�. ���� ���� �Ǵ� ����� Ȯ�� ��û�� ���� �� ���¸� �����ϰ� ����ȭ�մϴ�.',MARGIN,y,style=small)
    c.showPage()

    y=begin(6,'� ��Ģ','�ϷḦ Ȯ���ϴ� ���','���������� �����Figma�� ���� ���·� ����')
    y=table([['����','���� ����']]+[[r['status'],r['meaning']] for r in data['statusDefinitions']],[95,CONTENT-95],y)
    y=title('�ܰ躰 ���ް� ����ȭ',y)
    y=bullets(['���������� �� ���� ���䡤���� �� main ���ա�APK �ܵ� ���� �� ���� �ܰ�',
               '�ܰ衤�۾� ID, ���, ��ǥ�ϡ����� ��¥���ٰŸ� ���. ����� ������ �ʼ� ��� �������� ���� ����',
               'APK�����󡤰������� ���� Ŀ�ԡ���⡤OS���ð����̰��� ������ ����',
               'quality-progress.json ���� �� �ε�ʡ���Ȳǥ��PDF��Figma ���� ���¸� �Բ� ����',
               '���� �׽�Ʈ ����� �ִϸ��̼ǡ�������������� ���� �Ϸ�� ��ü���� ����'],y,style=small)
    y=title('����� ���� Figma ����',y-1)
    y=p('���� ������: '+data['design']['fileUrl'],MARGIN,y,style=small)-6
    y=p('Figma �ε��: '+(data['design']['roadmapUrl'] or data['design']['roadmapStatus'])+'. ���� ���ῡ���� Specs ���� API�� ����� �� ���� ���� FigJam ���̾�׷����� �����մϴ�.',MARGIN,y,style=small)-11
    y=title('���� �̷�',y)
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
    print(json.dumps({'stages':len(data['stages']),'acceptedStages':sum(s['status']=='�Ϸ�' for s in data['stages']), 'pdf':args.pdf},ensure_ascii=False))


if __name__=='__main__':
    main()
