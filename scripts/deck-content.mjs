/** Shared editable slide composition for native presentation and PPTX. */
export async function buildDeck(presentation, imageSources) {
  const C={bg:'#112D2B',text:'#F6F0E3',muted:'#B9C9BF',gold:'#F0BD6C',line:'#58726A',red:'#DE8D77',blue:'#8ABAC1'};
  const font='Noto Sans CJK KR';
  function text(s,name,value,x,y,w,h,size=26,color=C.text,bold=false){
    const o=s.shapes.add({geometry:'textbox',name,position:{left:x,top:y,width:w,height:h},fill:'none',line:{style:'solid',fill:'none',width:0}});
    o.text=value;o.text.style={fontSize:size,typeface:font,color,bold,autoFit:'none',wrap:'square',insets:0};return o;
  }
  function box(s,name,label,x,y,w,h,color=C.gold){
    const o=s.shapes.add({geometry:'rect',name,position:{left:x,top:y,width:w,height:h},fill:C.bg,line:{style:'solid',fill:color,width:2}});
    o.text=label;o.text.style={typeface:font,fontSize:26,color:C.text,alignment:'center',verticalAlignment:'middle',insets:12};return o;
  }
  function link(s,a,b,from='right',to='left'){
    s.shapes.connect(a,b,{kind:'elbow',fromSide:from,toSide:to,line:{style:'solid',fill:C.gold,width:2},tail:{type:'triangle',width:'med',length:'med'}});
  }
  function slide(i,title){
    const s=i===0&&presentation.slides.items.length?presentation.slides.items[0]:presentation.slides.add();s.background.fill=C.bg;
    if(i>0)text(s,'title',title,64,48,1152,76,44,C.text,true);
    text(s,'page',String(i+1).padStart(2,'0'),1160,666,56,26,16,C.muted);
    return s;
  }
  function note(s,t){s.speakerNotes.text=t;}
  function table(s,values,widths,x=64,y=185,h=340){
    const t=s.tables.add({rows:values.length,columns:values[0].length,left:x,top:y,width:1152,height:h,columnWidths:widths,values});
    t.borders.assign({style:'solid',fill:C.line,width:1});
    t.cells.block({row:0,column:0,rowCount:values.length,columnCount:values[0].length}).assign({fill:C.bg,textStyle:{typeface:font,fontSize:24,color:C.text},margins:{top:14,bottom:14,left:16,right:16},anchor:'center'});
    t.cells.block({row:0,column:0,rowCount:1,columnCount:values[0].length}).assign({fill:'#29483F',textStyle:{typeface:font,fontSize:24,color:C.gold,bold:true}});
    return t;
  }
  {
    const s=slide(0);text(s,'brand','RoxHistory',64,84,1120,110,76,C.gold,true);
    text(s,'cover-title','한국사 생존 RPG\n초기 시놉시스',64,224,1120,190,62,C.text,true);
    text(s,'cover-summary','사냥과 마을 성장에 몰입하며\n한국사와 우리 지리의 큰 흐름을 경험한다',68,460,1090,110,30,C.muted);
    text(s,'version','v0.1   2026년 10월 28일',68,636,850,36,21,C.muted);
    note(s,'대화에서 합의한 초기 콘셉트 요약. 게임의 재미가 우선이며 역사와 지리의 큰 흐름을 플레이를 통해 접한다. 장 수와 수치, 엔진과 최종 비주얼은 미정이다.');
  }
  {
    const s=slide(1,'게임의 재미와 성장 순환');
    text(s,'intro','내 인물의 행동이 마을과 다음 모험을 바꾼다',64,137,1152,50,30,C.gold);
    const names=['탐험과 사냥','파밍과 제작','거점과 도시 성장','새 지역과 사건'];
    const details=['추적하고 도전한다','재료를 얻고 강화한다','주민과 생산을 늘린다','새 목표와 보상을 만난다'];
    const bs=names.map((n,i)=>box(s,'loop-'+i,n,64+i*296,257,264,100));
    bs.slice(0,3).forEach((b,i)=>link(s,b,bs[i+1]));
    details.forEach((d,i)=>text(s,'detail-'+i,d,64+i*296,389,264,92,25,C.muted));
    text(s,'priority','역사 정보는 행동과 상황에 녹이고, 자세한 기록은 선택해서 본다',64,570,1152,76,27,C.text);
    note(s,'기본 순환의 개념도이며 실제 기능 순서와 밸런스는 후속 설계한다. 필수 퀴즈와 긴 교육 설명으로 플레이를 끊지 않는다.');
  }
  {
    const s=slide(2,'선사시대의 세 가지 시작 경로');
    table(s,[['시작 유형','첫 행동과 성장','주요 재미'],['사냥과 제작','추적, 재료 확보, 도구 강화','사냥의 손맛과 장비 성장'],['정착과 마을','거처 건설, 주민 합류, 생산 확장','공동체 운영과 건설'],['해안 생존과 교류','채집과 어로, 물자 확보와 교환','자원 탐색과 교류']],[260,480,412],64,180,370);
    text(s,'freedom','지역 선택이 초반 모험을 바꾼다. 이후에는 다른 활동도 즐길 수 있다',64,586,1152,68,26,C.gold);
    note(s,'지역 3곳은 미확정이다. 전곡리·수양개, 암사동, 동삼동 등은 유형별 후보이다. 구석기와 신석기의 시기 차이를 검토하고 공통 사건에 합류하는 시간 설정을 맞춰야 한다. 사냥형을 선택했다고 건설이 제한되는 고정 직업 구조는 아니다.');
  }
  {
    const s=slide(3,'지도 선택에서 첫 플레이까지');
    text(s,'intro','전체 지도 속 거점을 선택하면 그곳으로 들어간다',64,137,1152,52,30,C.gold);
    const a=box(s,'map-overview','전체 지도\n세 거점 표시',64,260,264,130);
    const b=box(s,'region-choice','지역 선택\n모험의 특징',360,260,264,130);
    const c=box(s,'zoom','지역 확대\n지형과 생활 터전',656,260,264,130);
    const d=box(s,'start','인물에 도착\n첫 행동 시작',952,260,264,130);
    link(s,a,b);link(s,b,c);link(s,c,d);
    text(s,'geography','산맥과 강, 해안을 위치의 기준으로 삼는다',64,465,1152,58,30,C.text);
    text(s,'scope','한반도 전역과 북방 확장 지역을 검토하며, 정확한 시작 위치와 시대 지형은 후속 조사한다',64,552,1152,90,25,C.muted);
    note(s,'화면 흐름을 설명한 도식이다. 실제 지도나 지리적 위치를 표현한 그림이 아니다. 선사시대 해안선이 현재와 같다고 가정하지 않는다.');
  }
  {
    const s=slide(4,'서로 다른 출발과 공통 사건');
    const a=box(s,'hunt','사냥과 제작',64,196,310,84),b=box(s,'village','정착과 마을',64,322,310,84),c=box(s,'coast','해안 생존과 교류',64,448,310,84);
    const m=box(s,'meeting','촌락 간 접촉\n교류와 협력, 갈등',500,302,300,124);
    const n=box(s,'common','공통의 큰 사건\n다음 시대의 이야기',916,302,300,124);
    [a,b,c].forEach(x=>link(s,x,m));link(s,m,n);
    text(s,'contribution','같은 사건에서도 전투, 식량 생산, 물자 확보 등 참여 방식은 달라진다',64,582,1152,70,26,C.gold);
    note(s,'합류 구조의 게임 기획 개념도. 촌락 간 관계와 국가 형성의 실제 과정은 단일 침략이나 합병으로 확정하지 않는다. 경로별 시간 차이와 시대 정합성을 먼저 검토한다.');
  }
  {
    const s=slide(5,'선사시대부터 근현대까지의 장 구성');
    const rows=[['1장','선사시대','지역 선택과 생존, 기본 성장의 맛보기'],['이후','국가 형성과 고대','역사적 인물과 사건 속에서 활동 범위 확장'],['이후','중세와 근세','시대에 맞는 생활과 생산, 주요 사건 참여'],['목표','근현대까지 약 40장','시대 흐름과 지역 변화가 이어지는 전체 구성']];
    rows.forEach((a,i)=>{const y=174+i*106;text(s,'period-'+i,a[0],64,y,125,52,24,C.gold,true);text(s,'era-'+i,a[1],200,y,365,58,30,C.text,true);text(s,'role-'+i,a[2],592,y+3,624,72,24,C.muted);});
    text(s,'planning','세부 장 목록과 시대별 분량은 미정',64,630,1152,36,23,C.gold);
    note(s,'약 40장은 목표 규모이다. 이 슬라이드는 장 목록이나 실제 연표를 확정하지 않는다. 고조선 이후 삼국 성장까지의 중간 과정 등은 정식 장 구성 시 검토한다. 실존 인물과 플레이어 인물의 관계도 후속 결정한다.');
  }
  {
    const s=slide(6,'시대 전환과 성과 계승');
    const labels=['시대 마무리','세계 재구성','인물 재선택','성과 기반 새 출발'];
    const boxes=labels.map((x,i)=>box(s,'transition-'+i,x,64+i*296,188,264,86));boxes.slice(0,3).forEach((x,i)=>link(s,x,boxes[i+1]));
    text(s,'carry-title','이전 시대에서 이어지는 성과',64,350,530,60,30,C.gold,true);
    text(s,'carry','모은 물자\n달성한 업적\n캐릭터와 공동체의 성장 성과',64,424,530,145,27,C.text);
    text(s,'new-title','새 시대에서 달라지는 조건',686,350,530,60,30,C.gold,true);
    text(s,'new','새로운 인물과 역할\n시대에 맞는 거점과 기술\n일부 이야기와 임무, 역할의 강점',686,424,530,145,27,C.text);
    text(s,'rule','일반 장은 이어서 진행한다. 큰 시대 전환에 세계 재시작을 적용한다',64,612,1152,56,24,C.muted);
    note(s,'세기말은 게임의 시대 전환 연출을 가리키는 작업 용어이다. 실제 역사에서 매번 세계가 멸망했다는 뜻이 아니다. 계승 비율, 물자 변환, 보너스와 역할 명칭은 미정이다.');
  }
  {
    const s=slide(7,'플레이를 통해 남는 역사와 지리');
    table(s,[['게임에서 겪는 일','자연스럽게 남길 큰 그림'],['지역을 고르고 탐험한다','강과 산, 해안과 거점의 위치'],['지역의 도구와 제작법을 쓴다','환경에 따라 다른 생활과 문화'],['역사적 인물과 큰 사건을 만난다','시대의 순서와 변화의 맥락'],['시대마다 달라지는 지도를 본다','나라의 등장과 영역의 대략적 변화']],[560,592],64,173,390);
    text(s,'accuracy','영역은 시기별로 검토하고, 불확실한 경계는 흐린 색이나 점선으로 표시한다',64,595,1152,66,24,C.gold);
    note(s,'교육 목표는 암기보다 큰 흐름과 위치 감각이다. 역사적 사실, 해석과 게임 창작을 구분한다. 고구려의 옛 영역을 검토 범위로 삼되 선사문화를 고구려 문화로 단정하지 않는다. 고조선과 삼국 영역 지도는 아직 제작하거나 확정하지 않았다.');
  }
  {
    const s=slide(8,'비주얼 방향 후보');
    const titles=['1안  아기자기한 2.5D','2안  생존 액션 RPG','3안  도트 RPG'];
    for(let i=0;i<3;i++){
      s.images.add({...imageSources[i],name:'visual-direction-'+(i+1),alt:titles[i]+' 검토용 생성 이미지',fit:'contain',position:{left:64+i*389,top:198,width:374,height:244}});
      text(s,'style-'+i,titles[i],64+i*389,475,374,60,27,C.text,true);
    }
    text(s,'unselected','최종 스타일은 미선택이다. 사냥 대상과 전리품, 다음 성장 목표가 먼저 보이게 한다',64,577,1152,82,25,C.gold);
    note(s,'대화에서 생성한 3가지 이미지 비교안. 생성형 비주얼 참고 자료이며 실제 역사 복원도, 확정 게임 화면, 최종 게임 에셋이 아니다. 기존 Figma는 구조 초안이다.');
  }
  {
    const s=slide(9,'현재 합의와 다음 디자인');
    text(s,'agreed-title','합의한 방향',64,170,500,60,31,C.gold,true);
    text(s,'agreed','재미를 우선하는 성장과 생존\n세 가지 지역 시작 경로\n변화하는 지도와 공통 사건\n주요 시대 전환과 성과 계승',64,250,530,230,28,C.text);
    text(s,'next-title','다음에 정할 내용',686,170,530,60,31,C.gold,true);
    text(s,'next','정확한 시작 지역과 시점\n역할, 계승 규칙과 장 목록\n아트 스타일과 전투의 느낌\n엔진과 저장, 서버 구성',686,250,530,230,28,C.text);
    text(s,'figma-next','다음 Figma 범위',64,553,1152,48,28,C.gold,true);
    text(s,'figma-scope','전체 지도와 지역 선택, 확대 흐름, 재미 중심 플레이 화면',64,610,1152,48,26,C.text);
    note(s,'기준 문서는 docs/synopsis-v0.1.md이다. React와 TypeScript를 우선 검토하며 Phaser는 후보이고 확정 엔진이 아니다. Figma https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS . 사용자 요청에 따라 이번에는 초기 문서화와 자료 보관을 완료하고 Figma는 후속 작업으로 둔다.');
  }
  return {slides:presentation.slides.items.length};
}
