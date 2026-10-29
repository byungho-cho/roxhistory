from pathlib import Path
import math, re, random, xml.etree.ElementTree as ET
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader
import pypdfium2 as pdfium

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/pdf/app-plan-v03'; OUT.mkdir(parents=True,exist_ok=True)
for n,f in [('K','malgun.ttf'),('KB','malgunbd.ttf')]: pdfmetrics.registerFont(TTFont(n,'C:/Windows/Fonts/'+f))
W,H=1600,900
BG='#FCFBF8'; INK='#27313D'; MUTED='#697581'; ACC='#AF5438'; GOLD='#E5BB69'; DARK='#382C22'
C=canvas.Canvas(str(OUT/'RoxHistory_AppPlan_v0.3.pdf'),pagesize=(W,H),pageCompression=1)
C.setTitle('RoxHistory - 안드로이드 앱 기획과 시작 지도 v0.3'); C.setAuthor('Newrox')
def rect(x,y,w,h,fill,r=0,stroke=None,lw=1):
 C.setFillColor(HexColor(fill)); C.setStrokeColor(HexColor(stroke or fill)); C.setLineWidth(lw)
 if r:C.roundRect(x,y,w,h,r,fill=1,stroke=bool(stroke))
 else:C.rect(x,y,w,h,fill=1,stroke=bool(stroke))
def t(s,x,y,size=26,color=INK,bold=False):
 C.setFillColor(HexColor(color)); C.setFont('KB' if bold else 'K',size); C.drawString(x,y,s)
def lines(items,x,y,size=26,step=45,color=INK,bold=False):
 for i,s in enumerate(items):t(s,x,y-i*step,size,color,bold)
def title(n,head,sub):
 rect(0,0,W,H,BG);t('RoxHistory  /  ANDROID GAME',72,835,18,ACC,True)
 t(head,72,751,49,INK,True);t(sub,74,699,24,MUTED)
 t('기획·화면 시안 v0.3  |  2026.10.29',72,34,17,MUTED);t(f'{n:02d}',1480,34,19,MUTED)
def page():C.showPage()
def panel(x,y,w,h):rect(x,y,w,h,'#3B3025',20,'#B99157',3);rect(x+7,y+7,w-14,h-14,'#493A2B',15,'#806343',1)
def button(label,x,y,w,h,active=True):
 rect(x,y,w,h,'#664126' if active else '#4B4840',14,'#F1C879' if active else '#938D7C',3)
 rect(x+5,y+h-13,w-10,7,'#9D7040' if active else '#646152',3)
 tw=pdfmetrics.stringWidth(label,'KB',25);t(label,x+(w-tw)/2,y+(h-25)/2+6,25,'#FFF3D8',True)
def pin(x,y,num,selected=False):
 C.setStrokeColor(HexColor('#FFDE80' if selected else '#E8C281'));C.setLineWidth(4)
 C.setFillColor(HexColor('#4C3220'));C.circle(x,y,24,fill=1,stroke=1)
 if selected:
  C.setLineWidth(2);C.circle(x,y,36,fill=0,stroke=1)
 t(str(num),x-9,y-10,25,'#FFEAC2',True)
 p=C.beginPath();p.moveTo(x-9,y-25);p.lineTo(x+9,y-25);p.lineTo(x,y-37);p.close();C.drawPath(p,fill=1,stroke=0)
def label(s,x,y,w):panel(x,y,w,48);t(s,x+16,y+14,21,'#FFF0D1',True)
def path_from_svg():
 data=ET.parse(ROOT/'assets/maps/korea-modern-coast-reference.svg').getroot()[1].get('d')
 p=C.beginPath()
 for m in re.finditer(r'([MLZ])([^MLZ]*)',data):
  cmd=m.group(1)
  if cmd=='Z':p.close();continue
  nums=[float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',m.group(2))]
  for i in range(0,len(nums),2):
   x,y=nums[i],720-nums[i+1]
   (p.moveTo if cmd=='M' and i==0 else p.lineTo)(x,y)
 return p
def xy(lon,lat):
 merc=lambda a:math.log(math.tan(math.pi/4+math.radians(a)/2))
 return 120+(450+(lon-127.5)*47.088)*1.05,65+(merc(lat)-merc(32))/(merc(44)-merc(32))*720*1.05
def map_scene(selected=False):
 # Accurate modern shoreline reference; decorative terrain is not historical reconstruction.
 rect(0,0,W,H,'#69A6AA')
 for i in range(30):
  rect(0,i*30,W,31,'#%02x%02x%02x'%(83+i,148+i//2,154+i//2))
 random.seed(11)
 for i in range(120):
  x=random.randrange(30,1110);y=random.randrange(40,830)
  C.setStrokeColor(Color(1,1,1,alpha=.15));C.setLineWidth(1);C.arc(x,y,x+45,y+9,195,140)
 C.saveState();C.translate(120,65);C.scale(1.05,1.05);p=path_from_svg()
 C.setLineJoin(1);C.setStrokeColor(HexColor('#387D7D'));C.setLineWidth(18);C.drawPath(p,fill=0,stroke=1)
 C.setStrokeColor(HexColor('#E9D39A'));C.setFillColor(HexColor('#94A666'));C.setLineWidth(7);C.drawPath(p,fill=1,stroke=1)
 C.clipPath(p,fill=0,stroke=0)
 # Softly shaded terrain and rounded canopies, always clipped to source coastline.
 for i in range(420):
  x=random.uniform(0,900);y=random.uniform(0,720);r=random.uniform(8,35)
  C.setFillColor(random.choice([HexColor('#9FAF72'),HexColor('#B0B77C'),HexColor('#879E64')]))
  C.ellipse(x-r*1.8,y-r*.6,x+r*1.8,y+r*.6,fill=1,stroke=0)
 for i in range(640):
  x=random.uniform(100,800);y=random.uniform(0,720);r=random.uniform(3,9)
  C.setFillColor(HexColor('#557A50'));C.ellipse(x-r,y-r*.3,x+r,y+r,fill=1,stroke=0)
  C.setFillColor(HexColor('#709158'));C.ellipse(x-r*.8,y+r*.05,x+r*.5,y+r*.9,fill=1,stroke=0)
 # Decorative low ridges, not a claimed topographic dataset.
 for i in range(32):
  x=random.uniform(330,600);y=random.uniform(120,670);r=random.uniform(9,22)
  m=C.beginPath();m.moveTo(x-r,y-r*.3);m.lineTo(x,y+r);m.lineTo(x+r,y-r*.3);m.close()
  C.setFillColor(HexColor('#7B8873'));C.drawPath(m,fill=1,stroke=0)
  m=C.beginPath();m.moveTo(x-r,y-r*.3);m.lineTo(x,y+r);m.lineTo(x-2,y-r*.2);m.close()
  C.setFillColor(HexColor('#B4BA91'));C.drawPath(m,fill=1,stroke=0)
 C.restoreState()
 t('서해',285,390,28,'#D5ECE3');t('동해',885,470,28,'#D5ECE3');t('제주',555,82,19,'#F1E3B7')
 # Header and chapter strip; actual game has no modern political boundary overlay.
 panel(34,760,605,108);t('RoxHistory',59,816,36,'#FFF0D0',True);t('첫 터전을 고르세요',61,781,23,'#DFC69C')
 panel(1190,790,370,73);t('1장  /  선사시대',1220,813,26,'#FFF0D0',True)
 pts=[xy(127.06,38.01),xy(127.13,37.56),xy(129.08,35.08)]
 # Close sites use offset callouts with leaders; geographic anchors stay in place.
 for i,(x,y) in enumerate(pts,1):
  dx,dy=((-37,34) if i==1 else (38,-16) if i==2 else (0,0))
  C.setStrokeColor(HexColor('#FFE0A0'));C.setFillColor(HexColor('#FFE0A0'));C.setLineWidth(2)
  C.circle(x,y,5,fill=1,stroke=0);C.line(x,y,x+dx,y+dy)
  pin(x+dx,y+dy,i,selected and i==2)
 x,y=pts[0];label('전곡리 · 사냥과 제작',x-322,y+12,247)
 x,y=pts[1];label('암사동 · 강변 정착',x+84,y-40,248)
 x,y=pts[2];label('동삼동 · 해안 생활',x+48,y-16,247)
 # Short connector leaders separate the two nearby northern labels without moving the pins.
 C.setStrokeColor(HexColor('#FFE0A0'));C.setLineWidth(2)
 x,y=pts[0];C.line(x-26,y,x-43,y+30)
 x,y=pts[1];C.line(x+28,y,x+53,y-10)
 panel(1120,126,440,620)
 if selected:
  t('선택한 터전',1152,692,20,'#D8B981');t('암사동 강변',1152,642,37,'#FFF0D0',True)
  t('정착과 마을',1153,601,25,'#F0CD8D',True)
  rect(1152,465,376,108,'#68563C',12)
  t('강가에 첫 보금자리를 만들고',1170,532,22,'#FFF0D0')
  t('마을 사람들과 생활을 시작하세요.',1170,494,22,'#FFF0D0')
  lines(['첫 경험','채집 · 도구 제작 · 작은 거처','이후 사냥과 탐험으로 확장'],1153,411,23,42,'#F1DFBD')
  button('이곳에서 시작',1152,167,376,76)
 else:
  t('어디서 시작할까요?',1152,689,31,'#FFF0D0',True)
  cards=[('01','전곡리','사냥과 제작'),('02','암사동','정착과 마을'),('03','동삼동','해안 생활과 교류')]
  for j,(num,name,desc) in enumerate(cards):
   yy=530-j*139;rect(1150,yy,380,113,'#55432E',12,'#93734A',1)
   t(num,1170,yy+71,21,'#E3BB74',True);t(name,1220,yy+69,28,'#FFF0D0',True);t(desc,1220,yy+29,21,'#DCCAA7')
  t('지도 표식이나 지역 카드를 누르세요.',1151,163,18,'#E3D3B5')
 panel(38,25,850,62);t('드래그로 이동   ·   두 손가락으로 확대   ·   표식을 눌러 선택',60,47,21,'#FFF0D0')
 panel(976,25,584,62);t('후보지 비교안  /  장소·시대 최종 검토 전',999,47,20,'#EAD4AF')

# 1 - Updated plan
title(1,'안드로이드에서 시작하는 역사 모험','전체 지도에서 터전을 고르고, 그곳의 생활과 모험으로 들어갑니다.')
for x,heading,body in [(72,'서비스 기준',['설치형 안드로이드 앱게임','직접 설치 APK · 스토어용 AAB','실제 기기에서 조작·성능 검증']),(582,'첫 플레이 흐름',['전체 지도 → 후보지 선택','시작 확인 → 지역 확대 연출','강변 마을 도착 → 첫 행동']),(1092,'기술 방향',['Godot 우선 검증','엔진 확정은 실제 기기 검증 후','서버·결제·멀티플레이는 후속 결정'])]:
 rect(x,330,436,298,'#F1EEE7',20);t(heading,x+26,570,30,INK,True);lines(body,x+26,506,24,52)
t('공통 아트 기준',74,249,28,ACC,True)
lines(['기존 10페이지의 아기자기한 2.5D, 둥근 형태, 따뜻한 자연광과 풍부한 자연 재질을 유지합니다.',
       '게임 UI는 짙은 갈색과 금빛 테두리로 통일합니다. 새 지도 역시 같은 분위기로 제작합니다.'],74,194,25,45)
t('이번 산출물은 화면과 동작 흐름을 확인하는 디자인 초안입니다. 실행 APK와 최종 맵 에셋은 아직 아닙니다.',74,91,21,MUTED)
page()
# 2,3 - Full screen mockups, same coastline and marker coordinates.
map_scene(False);page();map_scene(True);page()
# 4 - Entering existing screen
title(4,'선택한 터전으로 들어갑니다','암사동형 강변 정착 경로를 예시로, 기존 플레이 시안과 연결합니다.')
for i,(a,b) in enumerate([('01  시작 확인','선택 지역 ID와 시작 조건 저장'),('02  지역 확대','지도 표식 중심으로 카메라 접근'),('03  장면 전환','같은 색감과 조명으로 자연스럽게 연결')]):
 x=74+i*510;rect(x,560,472,94,'#F1EEE7',14);t(a,x+20,615,25,INK,True);t(b,x+20,579,21,MUTED)
C.drawImage(ImageReader(str(ROOT/'assets/visual-direction-1-enhanced.png')),325,110,950,420,preserveAspectRatio=True,anchor='c',mask='auto')
t('기존 플레이 시안 참조. 첫 진입에서는 레벨·재화·퀘스트·거점 상태를 새 게임 설정에 맞게 초기화합니다.',74,64,20,MUTED)
page()
# 5 - Interaction and research constraints
title(5,'개발에 연결할 화면 규칙','지도 연출과 플레이 상태를 분리하고, 같은 아트 기준으로 제작합니다.')
rows=[('선택 전','지도와 카드 모두 같은 후보 ID를 가리킴. 선택 없이 바로 시작하지 않음.'),('선택 후','표식 강조 + 지역 카드 표시. 다른 후보를 누르면 선택을 교체함.'),('시작 버튼','중복 입력을 막고 선택 정보를 저장한 뒤 지역 장면을 준비함.'),('전환·복귀','불러오기가 끝나면 진입. 실패하면 선택 상태를 유지하고 재시도 안내.'),('모바일 조작','터치 영역 최소 48dp 목표. 노치·시스템 영역과 버튼 겹침을 실제 기기에서 검증.'),('화면 방향','가로 화면을 이번 시안의 기본으로 제안. 폴더블 비율과 여백은 별도 검증.')]
for i,(a,b) in enumerate(rows):
 y=612-i*69;rect(74,y-25,1452,60,'#F2EFE8' if i%2==0 else '#FCFBF8',7);t(a,94,y,23,ACC,True);t(b,290,y,22)
t('시대·지도 검토',74,167,26,ACC,True)
lines(['전곡리는 구석기, 암사동·동삼동은 신석기 유적입니다. 세 후보를 같은 시점의 동시 마을로 확정하지 않습니다.',
       '지도는 현대 해안선 참고 형태입니다. 선사 해안선 복원·지형·시대 설정은 고증 검토 후 제작합니다.'],74,123,22,36,MUTED)
page()
# 6 - Art bible and references
title(6,'그림체는 고정하고, 화면을 확장합니다','기준 화면의 캐릭터 비율·색감·재질·조명을 다음 시안에도 이어갑니다.')
C.drawImage(ImageReader(str(ROOT/'assets/visual-direction-1-enhanced.png')),74,335,750,335,preserveAspectRatio=True,anchor='c')
lines(['유지할 것','친근한 캐릭터와 둥근 실루엣','올리브·청록 자연색 + 따뜻한 햇빛','나무·돌·짚의 풍부한 재질','갈색 패널 + 금빛 테두리 UI'],897,622,28,58,INK,True)
t('제작 구분',75,283,25,ACC,True)
lines(['이번 지도는 해안선과 선택 동선을 먼저 검증하는 구성 시안입니다.', '최종 지형·나무·마커는 기준 그림체의 에셋으로 교체합니다.'],75,252,21,30,MUTED)
t('자료 출처',75,182,24,ACC,True)
refs=[('해안선','Natural Earth 1:50m land / 현대 육지 참고, 국가·역사 경계 없음','https://www.naturalearthdata.com/about/terms-of-use/'),('전곡리','국가유산포털 / 구석기시대','https://www.heritage.go.kr/heri/cul/culSelectDetail.do?VdkVgwKey=13%2C02680000%2C31&pageNo=1_1_2_0'),('암사동','국사편찬위원회 우리역사넷 / 신석기시대 강변 마을','https://contents.history.go.kr/mobile/kc/view.do?levelId=kc_r000400'),('동삼동','부산광역시 동삼동패총전시관 / 신석기시대','https://museum.busan.go.kr/dongsam/index')]
for i,(a,b,url) in enumerate(refs):
 y=145-i*26;t(a+'  |  '+b,75,y,17,MUTED);C.linkURL(url,(75,y-3,1460,y+20),relative=0,thickness=0)
page();C.save()
pdf=OUT/'RoxHistory_AppPlan_v0.3.pdf';r=PdfReader(pdf);assert len(r.pages)==6
doc=pdfium.PdfDocument(str(pdf))
review=OUT/'review';review.mkdir(exist_ok=True)
for i in range(len(doc)):doc[i].render(scale=.8).to_pil().save(review/f'page-{i+1:02d}.png')
print(str(pdf));print('Verified six pages; all pages rendered.')

