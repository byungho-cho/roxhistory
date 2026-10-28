import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {constants as fsConstants} from 'node:fs';

const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const modules=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
const skill=process.env.ROX_PRESENTATION_SKILL;
const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON;
if(!modules||!skill||!python) throw new Error('Set CODEX_PRIMARY_RUNTIME_NODE_MODULES, CODEX_PRIMARY_RUNTIME_PYTHON and ROX_PRESENTATION_SKILL');
const {Presentation,PresentationFile}=await import(pathToFileURL(path.join(modules,'@oai/artifact-tool/dist/artifact_tool.mjs')).href);
const {finalizePresentation}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const font='Malgun Gothic';
const C={bg:'#FCFBF8',text:'#222B38',muted:'#626C79',accent:'#BA563E',line:'#D9DCE1',wash:'#F2EEE7',white:'#FFFFFF',blue:'#4E657F'};
const assetDir=process.env.ROX_DECK_ASSET_DIR||path.join(repo,'assets');
const mode=process.argv[2]||'all';
const baseNotes='근거: docs/synopsis-v0.1-handover.md, docs/synopsis-v0.1.md, docs/decision-register-v0.1.md 및 사용자 대화. 2026-10-29 발표자료 개편. 최신 기준과 기존 상세안을 구분한다. 2.5D 1안은 우선 검토 방향이며 최종 확정은 아니다.';

function txt(s,name,value,x,y,w,h,size=28,color=C.text,bold=false){
  const o=s.shapes.add({geometry:'textbox',name,position:{left:x,top:y,width:w,height:h},fill:'none',line:{style:'solid',fill:'none',width:0}});
  o.text=value;o.text.style={typeface:font,fontSize:size,color,bold,autoFit:'none',wrap:'square',insets:0};return o;
}
function rule(s,name,x,y,w,color=C.line,height=1){
  return s.shapes.add({geometry:'rect',name,position:{left:x,top:y,width:w,height},fill:color,line:{fill:'none',width:0,style:'solid'}});
}
function slide(p,index,title,subtitle,legacy=false){
  const s=p.slides.add();s.background.fill=C.bg;
  if(title){txt(s,'title',title,72,55,1136,70,46,C.text,true);if(subtitle)txt(s,'subtitle',subtitle,74,139,1132,52,27,C.muted);}
  rule(s,'footer-rule',72,663,1136);
  txt(s,'footer',legacy?'RoxHistory  /  초기 상세안 검토 기록':'RoxHistory  /  기획 방향',72,677,1000,26,16,C.muted);
  txt(s,'page',String(index).padStart(2,'0'),1160,674,48,30,18,C.muted);
  s.speakerNotes.text=baseNotes;return s;
}
function note(s,value){s.speakerNotes.text=baseNotes+'\n'+value;}
function footerMessage(s,text){txt(s,'takeaway',text,72,598,1136,47,26,C.accent,true);}
function lines(s,name,values,x,y,w,step=56,size=28,color=C.text){values.forEach((v,i)=>txt(s,`${name}-${i}`,v,x,y+i*step,w,step-8,size,color));}
function table(s,values,widths,y=222,height=328,size=26){
  const t=s.tables.add({rows:values.length,columns:values[0].length,left:72,top:y,width:1136,height,columnWidths:widths,values});
  t.borders.assign({style:'solid',fill:C.line,width:1});
  t.cells.block({row:0,column:0,rowCount:values.length,columnCount:values[0].length}).assign({fill:C.white,textStyle:{typeface:font,fontSize:size,color:C.text},margins:{left:18,right:14,top:16,bottom:16},anchor:'center'});
  t.cells.block({row:0,column:0,rowCount:1,columnCount:values[0].length}).assign({fill:C.wash,textStyle:{typeface:font,fontSize:size,color:C.text,bold:true}});
  return t;
}
function flow(s,labels,details,y=286){
  const w=254,gap=40;
  const boxes=labels.map((label,i)=>{
    const x=72+i*(w+gap);
    txt(s,`step-number-${i}`,String(i+1).padStart(2,'0'),x,y-60,w,38,23,C.accent,true);
    const o=s.shapes.add({geometry:'rect',name:`flow-${i}`,position:{left:x,top:y,width:w,height:96},fill:C.white,line:{style:'solid',fill:C.line,width:1}});
    o.text=label;o.text.style={typeface:font,fontSize:28,color:C.text,bold:true,alignment:'center',verticalAlignment:'middle',insets:10};
    if(details?.[i])txt(s,`step-detail-${i}`,details[i],x,y+124,w,96,25,C.muted);
    return o;
  });
  boxes.slice(0,-1).forEach((a,i)=>s.shapes.connect(a,boxes[i+1],{kind:'straight',fromSide:'right',toSide:'left',line:{fill:C.accent,width:1.5,style:'solid'},tail:{type:'triangle',width:'med',length:'med'}}));
  return boxes;
}
function cover(p,legacy){
  const s=slide(p,1,null,null,legacy);
  txt(s,'brand','RoxHistory',72,70,1100,75,54,C.accent,true);
  txt(s,'cover-title',legacy?'모험과 성장으로 만나는\n한국사의 큰 흐름':'지도에서 만나는\n한국 역사의 흐름',72,218,1136,188,68,C.text,true);
  txt(s,'cover-subtitle',legacy?'탐험, 생존, 마을 성장으로 풀어 본 초기 게임 구상':'게임을 즐기며 시대의 변화와 한국 지리를 이해하는 경험',76,450,1110,55,29,C.muted);
  txt(s,'cover-status',legacy?'초기 상세안 v0.1  /  재확인 항목 포함':'기획 방향 v0.1  /  인수인계 정합본',76,554,1100,37,23,C.accent,true);
  note(s,legacy?'기존 생존 RPG 상세안을 보존한 검토 자료다. 장르와 세부 규칙의 최종 승인 문서가 아니다. 원본의 사냥·마을 성장·3개 경로·약 40장·계승 구상을 후속 슬라이드에 유지한다.':'확정 방향은 지도 중심 역사 경험, 선사시대 시작, 역사·지리의 자연스러운 학습과 사실·가정 구분이다. 상세 규칙은 후속 협의한다.');
}

async function handover(){
  const p=Presentation.create({slideSize:{width:1280,height:720}});cover(p,false);
  {
    const s=slide(p,2,'누구를 위한 게임인가','세부 암기보다 시대와 지역의 관계를 이해하는 경험');
    table(s,[['주요 사용자','기대하는 경험'],['중·고등학생','처음 배우는 한국사의 큰 흐름'],['역사를 다시 배우는 성인','나라, 시대, 지역을 연결하는 이해'],['역사·지리에 관심 있는 사용자','지도와 변화로 이어지는 역사 경험']],[450,686],226,318,28);
    footerMessage(s,'역사 지식이 부족해도 쉽게 시작할 수 있도록');
  }
  {
    const s=slide(p,3,'게임을 연결하는 세 가지 축','지도, 시간, 플레이를 하나의 역사 경험으로 연결한다');
    [['지도','한반도와 주변 지역','지역과 장소를 연결'],['시간','선사시대부터 주요 시대까지','국가와 세력의 변화'],['플레이','재미를 경험하는 과정','역사와 지리의 맥락']].forEach((v,i)=>{
      const x=72+i*392;txt(s,`concept-n-${i}`,`0${i+1}`,x,234,330,42,25,C.accent,true);
      txt(s,`concept-title-${i}`,v[0],x,300,330,70,48,C.text,true);
      txt(s,`concept-body-${i}`,v[1]+'\n'+v[2],x,412,350,116,29,C.muted);
    });
    note(s,'경험의 방향이다. 국가 운영·영토 확장·자원 관리·생존 RPG를 확정하지 않는다.');
  }
  {
    const s=slide(p,4,'같은 장소에서 달라지는 역사','지도는 시대가 바뀌어도 경험을 이어 주는 중심 화면');
    const source=await fs.readFile(path.join(assetDir,'korea-modern-coast-reference.svg'),'utf8').catch(()=>fs.readFile(path.join(repo,'assets/maps/korea-modern-coast-reference.svg'),'utf8'));
    const svg=Buffer.from(source.replace(/#112d2b/gi,'#EFF3F5').replace(/#c9cfb1/gi,'#788C9D').replace(/#91af76/gi,'#657B8E'));
    s.images.add({blob:svg.buffer.slice(svg.byteOffset,svg.byteOffset+svg.byteLength),contentType:'image/svg+xml',name:'modern-coast-reference',alt:'현대 해안선 참고도. 역사적 영토 경계 없음',fit:'contain',position:{left:72,top:216,width:564,height:388}});
    [['국가와 세력','등장, 발전, 소멸과 관계'],['지형과 장소','지역의 위치와 지리적 맥락'],['사건과 변화','시점에 따라 달라지는 지도']].forEach((v,i)=>{
      txt(s,`map-title-${i}`,v[0],716,233+i*124,492,42,31,C.text,true);
      txt(s,`map-body-${i}`,v[1],716,286+i*124,492,44,27,C.muted);
    });
    txt(s,'map-disclosure','현대 해안선 참고도. 시대별 지형과 영역은 후속 고증',80,612,1120,34,20,C.muted);
    note(s,'출처: Natural Earth ne_50m_land.geojson https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_50m_land.geojson / 이용 조건 https://www.naturalearthdata.com/about/terms-of-use/ . 현대 육지 자료를 120~135E,32~44N으로 자른 Mercator 투영 참고도이며 역사적 경계나 선사시대 지형이 아니다. 원본 SVG 도형을 유지하고 색상만 밝은 문서 테마로 조정했다.');
  }
  {
    const s=slide(p,5,'선사시대부터 현대까지','전체 흐름을 이해하기 위한 잠정 시대 구분');
    const eras=['선사시대','고조선과 초기 국가','삼국시대 및 가야','남북국시대','후삼국과 고려','조선','근대 및 일제강점기','현대 대한민국'];
    eras.forEach((e,i)=>{const x=72+(i<4?0:600),y=223+(i%4)*84;txt(s,`era-n-${i}`,String(i+1).padStart(2,'0'),x,y,72,46,25,C.accent,true);txt(s,`era-${i}`,e,x+88,y-2,452,54,32,C.text,true);});
    footerMessage(s,'실제 장 수, 분량과 시대 진행 조건은 다음 설계에서 결정');
  }
  {
    const s=slide(p,6,'플레이어에게 남길 경험','같은 공간에서 이어지는 변화를 이해한다');
    flow(s,['지역을 이해','관계를 파악','변화를 체험','흐름을 연결'],['어디에 있는가','무엇과 연결되는가','무엇이 달라졌는가','앞뒤 시대의 관계']);
    footerMessage(s,'반복해서 하고 싶은 행동과 보상 구조를 먼저 구체화');
    note(s,'편집 가능한 경험 개념도이며 확정 게임 루프가 아니다. 지도 클릭이나 시대 버튼만으로 게임이 완성된다고 가정하지 않는다.');
  }
  {
    const s=slide(p,7,'플레이 속에 남는 역사와 지리','맥락에 필요한 핵심부터 짧게 전달한다');
    table(s,[['플레이에서 접하는 변화','자연스럽게 이해할 맥락'],['지역과 장소를 지도에서 접한다','위치와 주변 지리의 관계'],['여러 국가와 세력의 변화를 본다','국가의 등장, 발전과 세력 관계'],['사건과 장소를 연결한다','어디에서 무엇이 달라졌는지'],['앞뒤 시대의 지도를 비교한다','시대의 순서와 큰 전환']],[570,566],216,344,25);
    footerMessage(s,'상세 정보의 양과 열람 방식은 플레이 흐름에 맞춰 검토');
    note(s,'교육적 설계 목표이며 학습 효과를 실증한 결과가 아니다. 정보 열람 방식과 플레이 조작은 미확정이다.');
  }
  {
    const s=slide(p,8,'역사적 사실과 게임적 가정','확인된 사실, 해석과 불확실성, 게임 창작을 구분한다');
    txt(s,'history-title','역사 자료의 기준',72,234,520,58,36,C.text,true);
    txt(s,'design-title','게임 설계의 기준',680,234,528,58,36,C.text,true);
    lines(s,'history',['시점과 출처를 함께 관리','영토, 영향권, 문화권을 구분','논쟁과 불확실성을 표시','시대별 지형과 정치 변화 검토'],72,332,530,57,28);
    lines(s,'fiction',['확인된 사실과 가정을 구분','가상 전개를 실제 역사와 구별','설명보다 맥락과 경험을 우선','분기와 선택 규칙은 미확정'],680,332,528,57,28);
    footerMessage(s,'고증 전의 영토 도형을 확정된 역사 지도처럼 사용하지 않는다');
  }
  {
    const s=slide(p,9,'이전 상세안에서 이어서 검토할 것','기존 구상은 보존하고, 현재 결정 상태를 명확히 구분한다');
    table(s,[['이전 구상','현재 상태'],['생존 RPG, 사냥, 제작, 도시 성장','기존 상세안으로 보존, 재확인 필요'],['세 가지 지역 시작 경로','기존 상세안으로 보존, 재확인 필요'],['근현대까지 약 40장','이전 목표 규모, 현재 분량 미정'],['세계 재구성, 인물 재선택, 계승','기존 상세안으로 보존, 재확인 필요']],[572,564],218,350,25);
    footerMessage(s,'장르와 상세 게임 규칙을 현재 개발 사양으로 자동 확정하지 않는다');
  }
  {
    const s=slide(p,10,'다음 설계에서 결정할 것','작은 플레이 구간으로 재미를 검증한 뒤 시스템을 확장한다');
    txt(s,'direction-title','유지할 방향',72,228,520,55,34,C.text,true);
    txt(s,'next-title','먼저 정할 내용',680,228,528,55,34,C.text,true);
    lines(s,'fixed',['지도 중심의 역사 경험','선사시대부터 이어지는 흐름','역사와 지리의 자연스러운 학습','사실, 해석, 게임 가정의 구분'],72,310,535,52,27);
    lines(s,'next',['반복 행동과 플레이어 역할','목표, 보상과 시대 진행 조건','지도와 실제 플레이의 관계','React·TypeScript 구현 범위'],680,310,528,52,27);
    txt(s,'visual-preference','비주얼 우선 방향: 아기자기한 2.5D 1안',72,548,1136,41,28,C.accent,true);
    txt(s,'figma','Figma 검토: 메인, 지도, 시대 진행, 국가·지역 정보, 역사 이벤트',72,606,1136,38,23,C.muted);
    note(s,'2026-10-29 사용자 대화에서 2.5D 1안을 선호한다고 표현했다. 우선 검토 방향이며 최종 확정은 아니다. 기획·설계와 전체 진행 관리는 팀장 역할로 담당하고 큰 방향은 사용자와 협의한다. Node.js는 서버 필요성 결정 후 검토하며 엔진·저장·멀티플레이는 미확정이다. Figma https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS 는 구조 초안이다.');
  }
  return {p,name:'RoxHistory_Overview_v0.1-handover',tables:[2,7,9]};
}

async function original(){
  const p=Presentation.create({slideSize:{width:1280,height:720}});cover(p,true);
  {
    const s=slide(p,2,'탐험이 성장으로 이어지는 순환','내 인물의 행동이 마을과 다음 모험을 바꾼다',true);
    flow(s,['탐험과 사냥','파밍과 제작','거점과 도시 성장','새 지역과 사건'],['추적하고 도전한다','재료를 얻고 강화한다','주민과 생산을 늘린다','새 목표와 보상을 만난다']);
    footerMessage(s,'역사 정보는 행동과 상황에 담고, 자세한 기록은 선택해서');
    note(s,'보존한 초기 생존 RPG 구상의 개념도다. 실제 기능 순서와 밸런스는 후속 설계한다. 필수 퀴즈나 긴 교육 설명으로 플레이를 끊지 않는 방향이다. 구체 장르는 최신 정합본에서 재확인 대상으로 구분한다.');
  }
  {
    const s=slide(p,3,'서로 다른 세 가지 시작 경험','지역 선택이 초반 모험을 바꾸고, 이후에는 다른 활동도 즐긴다',true);
    table(s,[['시작 유형','첫 행동과 성장','주요 재미'],['사냥과 제작','추적, 재료 확보, 도구 강화','사냥과 장비 성장'],['정착과 마을','거처 건설, 주민 합류, 생산 확장','공동체 운영과 건설'],['해안 생존과 교류','채집과 어로, 물자 확보와 교환','자원 탐색과 교류']],[246,512,378],228,326,25);
    footerMessage(s,'시작 지역과 시대 정합성은 후속 검토');
    note(s,'세 지역은 미확정이다. 전곡리·수양개, 암사동, 동삼동은 유형별 후보다. 구석기와 신석기의 시기 차이, 공통 사건에 합류하는 시간 설정을 검토한다. 고정 직업 구조가 아니며 기존 상세안이다.');
  }
  {
    const s=slide(p,4,'지도에서 첫 플레이까지','전체 지도 속 거점을 선택하면 그곳으로 들어간다',true);
    flow(s,['전체 지도','지역 선택','지역 확대','인물에 도착'],['세 거점 표시','모험의 특징 확인','지형과 생활 터전','첫 행동 시작']);
    footerMessage(s,'산맥과 강, 해안을 위치의 기준으로 삼는다');
    note(s,'화면 흐름의 도식이며 실제 지도나 지리적 위치를 그린 그림이 아니다. 한반도 전역과 북방 확장 지역을 검토하되 정확한 위치와 시대 지형은 조사한다. 선사 해안선이 현재와 같다고 가정하지 않는다.');
  }
  {
    const s=slide(p,5,'다른 출발이 하나의 이야기로','출발 경로마다 공통 사건에 기여하는 방식이 달라진다',true);
    const labels=['사냥과 제작','정착과 마을','해안 생존과 교류'];
    const starters=labels.map((v,i)=>{const o=s.shapes.add({geometry:'rect',name:`start-${i}`,position:{left:72,top:228+i*108,width:306,height:78},fill:C.white,line:{style:'solid',fill:C.line,width:1}});o.text=v;o.text.style={typeface:font,fontSize:28,color:C.text,alignment:'center',verticalAlignment:'middle',insets:10};return o;});
    const nodes=['촌락 간 접촉\n교류, 협력과 갈등','공통의 큰 사건\n다음 시대의 이야기'].map((v,i)=>{const o=s.shapes.add({geometry:'rect',name:`merge-${i}`,position:{left:492+i*392,top:330,width:324,height:104},fill:C.white,line:{style:'solid',fill:C.line,width:1}});o.text=v;o.text.style={typeface:font,fontSize:28,color:C.text,bold:true,alignment:'center',verticalAlignment:'middle',insets:10};return o;});
    starters.forEach(a=>s.shapes.connect(a,nodes[0],{kind:'elbow',fromSide:'right',toSide:'left',line:{fill:C.accent,width:1.5,style:'solid'},tail:{type:'triangle',width:'med',length:'med'}}));
    s.shapes.connect(nodes[0],nodes[1],{kind:'straight',fromSide:'right',toSide:'left',line:{fill:C.accent,width:1.5,style:'solid'},tail:{type:'triangle',width:'med',length:'med'}});
    footerMessage(s,'전투, 식량 생산, 물자 확보처럼 다양한 참여 방식을 검토');
    note(s,'초기 기획의 합류 구조다. 실제 국가 형성과 촌락 관계를 단일 침략이나 합병으로 확정하지 않는다. 경로별 시간 차이와 시대 정합성을 먼저 검토한다.');
  }
  {
    const s=slide(p,6,'긴 역사 여정을 나누는 장 구성','선사시대부터 근현대까지 이어지는 초기 목표 규모',true);
    const rows=[['1장','선사시대','지역 선택, 생존과 기본 성장'],['이후','국가 형성과 고대','인물과 사건 속에서 활동 범위 확장'],['이후','중세와 근세','시대에 맞는 생활, 생산과 주요 사건'],['목표','근현대까지 약 40장','시대 흐름과 지역 변화가 이어지는 구성']];
    rows.forEach((r,i)=>{const y=224+i*85;txt(s,`period-${i}`,r[0],72,y,112,48,25,C.accent,true);txt(s,`era-${i}`,r[1],204,y-1,410,54,31,C.text,true);txt(s,`role-${i}`,r[2],654,y+2,554,62,25,C.muted);if(i<3)rule(s,`row-rule-${i}`,72,y+63,1136);});
    footerMessage(s,'약 40장은 이전 목표이며, 장 목록과 시대별 분량은 미정');
    note(s,'약 40장은 확정 분량이 아닌 기존 상세안의 목표다. 고조선 이후 삼국 성장까지의 중간 과정과 실존 인물·플레이어 관계를 후속 검토한다.');
  }
  {
    const s=slide(p,7,'시대가 바뀌어도 남는 성과','일반 장은 이어서 진행하고, 큰 시대 전환에서 새 출발을 검토',true);
    flow(s,['시대 마무리','세계 재구성','인물 재선택','성과 기반 새 출발'],null,266);
    txt(s,'carry-title','이어지는 성과',72,424,530,45,30,C.accent,true);
    txt(s,'change-title','달라지는 조건',680,424,528,45,30,C.accent,true);
    lines(s,'carry',['모은 물자와 달성한 업적','캐릭터와 공동체의 성장 성과'],72,488,530,52,27);
    lines(s,'change',['새 인물, 역할, 시대에 맞는 거점과 기술','일부 이야기와 임무, 역할의 강점'],680,488,528,52,25);
    note(s,'초기 시대 전환·계승 구상이며 재확인 대상이다. 실제 역사에서 매번 세계가 멸망했다는 뜻이 아니다. 계승 비율, 물자 변환과 보너스는 미정이다.');
  }
  {
    const s=slide(p,8,'재미 속에 남길 역사와 지리','플레이에서 겪는 일과 이해할 맥락을 연결한다',true);
    table(s,[['게임에서 겪는 일','자연스럽게 남길 큰 그림'],['지역을 고르고 탐험한다','강과 산, 해안과 거점의 위치'],['지역의 도구와 제작법을 쓴다','환경에 따라 다른 생활과 문화'],['역사적 인물과 큰 사건을 만난다','시대의 순서와 변화의 맥락'],['시대마다 달라지는 지도를 본다','나라의 등장과 영역의 대략적 변화']],[570,566],216,344,25);
    footerMessage(s,'시기별 영역을 검토하고, 불확실한 경계를 구분해서 표시');
    note(s,'역사적 사실, 해석과 게임 창작을 구분한다. 고구려의 옛 영역을 검토 범위로 삼되 선사문화를 고구려 문화로 단정하지 않는다. 고조선·삼국 영역 지도는 아직 확정하지 않았다.');
  }
  {
    const s=slide(p,9,'우선 검토할 비주얼 방향','1안의 아기자기한 2.5D를 중심으로 구체화한다',true);
    for(let i=1;i<=3;i++){
      let source=path.join(assetDir,`visual-direction-${i}.png`),contentType='image/png';
      const bytes=await fs.readFile(source).catch(async()=>{source=path.join(assetDir,`visual-direction-${i}.jpg`);contentType='image/jpeg';return fs.readFile(source);});
      const frame=i===1?{left:72,top:214,width:660,height:352}:{left:790,top:211+(i-2)*205,width:270,height:154};
      s.images.add({blob:bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),contentType,name:`visual-direction-${i}`,alt:`${i}안 검토용 생성 이미지. 실제 역사 복원도나 확정 게임 화면이 아님`,fit:'contain',position:frame});
    }
    txt(s,'preferred-label','1안  아기자기한 2.5D',72,581,670,46,29,C.accent,true);
    txt(s,'option-two','2안  생존 액션 RPG',790,369,418,34,22,C.muted);
    txt(s,'option-three','3안  도트 RPG',790,574,418,34,22,C.muted);
    note(s,'2026-10-29 사용자 대화: 아기자기한 2.5D 1안을 선호하는 잠정 방향. 최종 확정은 아니다. 생성 비주얼 3개 원본의 내용과 비율을 유지한 비교안이며 실제 역사 복원도·확정 게임 화면·최종 에셋이 아니다. 사냥 대상, 전리품과 다음 성장 목표가 먼저 보이도록 검토한다.');
  }
  {
    const s=slide(p,10,'다음 논의를 위한 정리','이전 게임 구상을 보존하고 현재 기획 기준과 맞춘다',true);
    txt(s,'kept-title','보존한 게임 구상',72,231,530,55,34,C.text,true);
    txt(s,'next-title','다음에 결정할 내용',680,231,528,55,34,C.text,true);
    lines(s,'kept',['성장과 생존의 재미','세 가지 지역 시작 경로','변화하는 지도와 공통 사건','주요 시대 전환과 성과 계승'],72,318,530,53,27);
    lines(s,'next',['정확한 시작 지역과 시점','역할, 계승 규칙과 장 목록','2.5D 스타일과 전투의 느낌','엔진, 저장과 서버 구성'],680,318,528,53,27);
    txt(s,'figma-next','다음 Figma 검토',72,555,1136,40,29,C.accent,true);
    txt(s,'figma-scope','전체 지도, 지역 선택, 확대 흐름, 재미 중심 플레이 화면',72,607,1136,36,24,C.muted);
    note(s,'현재 기준은 docs/synopsis-v0.1-handover.md와 결정 기록이다. 이 자료의 구체 게임 규칙은 기존 상세안으로 재확인한다. React·TypeScript를 우선 검토하며 특정 엔진은 미확정이다. Figma https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS 는 구조 초안이다.');
  }
  return {p,name:'RoxHistory_Overview_v0.1',tables:[3,8]};
}

async function save({p,name,tables}){
  const build=path.join(repo,'.work/refresh-build',name);await fs.mkdir(build,{recursive:true});
  const finalDir=path.join(repo,'.work/refresh-final',process.env.ROX_DECK_REVISION||'r1');await fs.mkdir(finalDir,{recursive:true});
  for(const [i,s] of p.slides.items.entries()){
    try {const png=await p.export({slide:s,format:'png',scale:1});await fs.writeFile(path.join(build,`slide-${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));}
    catch(e){console.log('Local preview unavailable: '+e.message);break;}
  }
  const candidate=path.join(build,'candidate.pptx');const blob=await PresentationFile.exportPptx(p);await fs.writeFile(candidate,blob.data);
  const finalPath=path.join(finalDir,name+'.pptx');
  const hash=createHash('sha256').update(await fs.readFile(candidate)).digest('hex');
  let result;
  try {result=await finalizePresentation({workspaceDir:repo,candidatePath:candidate,finalPath,pythonExecutable:python,integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit',...tables.flatMap(n=>['--require-native-table-slide',String(n)])],explicitTotalSlideCount:10,requiredNativeTableOwnerSlides:tables,requiredNativeChartOwnerSlides:[],fontPolicy:{basis:'design',families:[font]},verifyArtifactToolImport:true,receiptPath:path.join(build,'validation.json')});}
  catch(e){
    // Some Windows workspaces permit file copies but do not support hard links.
    // The finalizer reaches this link only after all declared checks have passed.
    if(e.code!=='EPERM'||e.syscall!=='link')throw e;
    if(createHash('sha256').update(await fs.readFile(candidate)).digest('hex')!==hash)throw new Error('Candidate changed after validation');
    await fs.copyFile(candidate,finalPath,fsConstants.COPYFILE_EXCL);
    if(createHash('sha256').update(await fs.readFile(finalPath)).digest('hex')!==hash)throw new Error('Final bytes differ from validated candidate');
    result={finalPath,finalSha256:hash,checks:'Finalizer passed validation; hard-link publication unavailable',publication:'exclusive-copy fallback'};
    await fs.writeFile(path.join(build,'validation-copy-fallback.json'),JSON.stringify(result,null,2));
  }
  await fs.mkdir(path.join(repo,'presentations'),{recursive:true});await fs.copyFile(path.join(finalDir,name+'.pptx'),path.join(repo,'presentations',name+'.pptx'));console.log(JSON.stringify(result));
}
try {if(mode==='all'||mode==='handover')await save(await handover());if(mode==='all'||mode==='original')await save(await original());}
catch(e){console.error(e.message);process.exitCode=1;}
